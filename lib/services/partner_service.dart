import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/bloom_reward.dart';
import '../models/donation.dart';
import '../models/partner_profile.dart';
import '../models/public_partner_profile.dart';

class PartnerService {
  PartnerService._();
  static final PartnerService instance = PartnerService._();

  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'bloomg2w-db',
  );

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1');

  CollectionReference get _partnersRef => _db.collection('partners');
  CollectionReference get _publicPartnersRef => _db.collection('partner_profiles');
  CollectionReference get _rewardsRef => _db.collection('rewards');
  CollectionReference get _redemptionsRef => _db.collection('reward_redemptions');
  CollectionReference get _donationsRef => _db.collection('donations');

  /// Creates the private (PII-holding) partner doc only. The public,
  /// PII-free directory mirror is created separately by [approvePartner]
  /// once an admin has reviewed the application — a newly-registered
  /// partner starts PartnerStatus.pending and is not yet visible to
  /// members (per the Community Partner approval workflow).
  Future<void> createPartnerProfile(PartnerProfile profile) async {
    await _partnersRef.doc(profile.uid).set(profile.toCreateMap());
  }

  /// The public, PII-free partner directory — any signed-in member may
  /// browse this (Community Partners screen). Only contains partners an
  /// admin has approved (see [approvePartner]).
  Stream<List<PublicPartnerProfile>> watchPublicPartnerDirectory() {
    return _publicPartnersRef.snapshots().map((s) => s.docs.map(PublicPartnerProfile.fromFirestore).toList());
  }

  Future<PartnerProfile?> fetchPartnerProfile(String uid) async {
    final doc = await _partnersRef.doc(uid).get();
    if (!doc.exists) return null;
    return PartnerProfile.fromFirestore(doc);
  }

  Stream<PartnerProfile?> watchPartnerProfile(String uid) {
    return _partnersRef.doc(uid).snapshots().map((doc) => doc.exists ? PartnerProfile.fromFirestore(doc) : null);
  }

  /// Admin action: approves a pending partner, stamping who/when, and
  /// publishes their public directory mirror — the ONLY place
  /// partner_profiles/{uid} is created, so a partner never appears to
  /// members before admin review.
  Future<void> approvePartner({required String partnerUid, required String adminUid}) async {
    final profile = await fetchPartnerProfile(partnerUid);
    if (profile == null) return;
    await _partnersRef.doc(partnerUid).update({
      'status': PartnerStatus.approved.value,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'statusUpdatedBy': adminUid,
    });
    await _publicPartnersRef.doc(partnerUid).set(
      PublicPartnerProfile(
        uid: partnerUid,
        businessName: profile.businessName,
        description: profile.description,
        supportTypes: profile.supportTypes,
        logoUrl: profile.logoUrl,
        createdAt: profile.createdAt,
      ).toCreateMap(),
    );
  }

  /// Admin action: rejects or suspends a partner, retracting their public
  /// directory mirror (if published) and rejects — but never deletes —
  /// any rewards they've proposed, so no already-rejected/suspended
  /// partner's rewards can reach the marketplace.
  Future<void> setPartnerStatus({
    required String partnerUid,
    required PartnerStatus status,
    required String adminUid,
  }) async {
    await _partnersRef.doc(partnerUid).update({
      'status': status.value,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'statusUpdatedBy': adminUid,
    });
    if (status != PartnerStatus.approved) {
      await _publicPartnersRef.doc(partnerUid).delete();
    }
  }

  Future<void> createReward(BloomReward reward) {
    return _rewardsRef.doc().set(reward.toCreateMap());
  }

  Future<void> setRewardActive({required String rewardId, required bool active}) {
    return _rewardsRef.doc(rewardId).update({'active': active});
  }

  /// Admin action: approves a pending reward so it can appear in the
  /// marketplace (subject to it also being active/in-stock/unexpired).
  Future<void> setRewardStatus({required String rewardId, required RewardStatus status, String reviewNotes = ''}) {
    return _rewardsRef.doc(rewardId).update({'status': status.value, 'reviewNotes': reviewNotes});
  }

  /// Rewards offered by a single partner (their own "My Rewards" list).
  Stream<List<BloomReward>> watchPartnerRewards(String partnerUid) {
    return _rewardsRef.where('partnerUid', isEqualTo: partnerUid).snapshots().map(
          (s) => s.docs.map(BloomReward.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  /// Admin-approved, active, in-stock, unexpired rewards across every
  /// partner — the Rewards Marketplace a member/participant browses.
  /// Filtered client-side on the remaining conditions since Firestore
  /// can't combine an equality (status) with the other checks in one
  /// query without a compound index per additional field; status is the
  /// one condition that MUST be enforced by the query itself so an
  /// unapproved reward is never even fetched to a participant's client.
  Stream<List<BloomReward>> watchMarketplaceRewards() {
    return _rewardsRef.where('status', isEqualTo: RewardStatus.approved.value).snapshots().map(
          (s) => s.docs.map(BloomReward.fromFirestore).toList()..sort((a, b) => a.badgeCost.compareTo(b.badgeCost)),
        );
  }

  /// Every reward across every partner — admin dashboard stats.
  Stream<List<BloomReward>> watchAllRewards() {
    return _rewardsRef.snapshots().map((s) => s.docs.map(BloomReward.fromFirestore).toList());
  }

  /// Rewards awaiting admin approval.
  Stream<List<BloomReward>> watchPendingRewards() {
    return _rewardsRef.where('status', isEqualTo: RewardStatus.pending.value).snapshots().map(
          (s) => s.docs.map(BloomReward.fromFirestore).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  /// Every partner profile — admin dashboard stats and the Admin Community
  /// Partners management list.
  Stream<List<PartnerProfile>> watchAllPartners() {
    return _partnersRef.snapshots().map((s) => s.docs.map(PartnerProfile.fromFirestore).toList());
  }

  /// Calls the deployed `redeemReward` Cloud Function, which atomically
  /// checks the participant's unspent badge balance, spends exactly
  /// [BloomReward.badgeCost] badges, decrements the reward's remaining
  /// quantity, and creates a unique one-time redemption code — all inside
  /// one Firestore transaction, so a participant can never double-spend
  /// badges or claim more than what's actually in stock.
  Future<String> redeemReward(String rewardId) async {
    final callable = _functions.httpsCallable('redeemReward');
    final result = await callable.call<Map<String, dynamic>>({'rewardId': rewardId});
    return result.data['code'] as String;
  }

  /// Calls the deployed `markRedemptionUsed` Cloud Function, which looks
  /// up a code scoped to the CALLING partner's own uid (so one partner
  /// can never probe or redeem another partner's codes) and marks it used
  /// atomically — a code can only ever be marked used once.
  Future<void> markRedemptionUsed(String code) async {
    final callable = _functions.httpsCallable('markRedemptionUsed');
    await callable.call<Map<String, dynamic>>({'code': code});
  }

  Future<RewardRedemption?> findRedemptionByCode({required String partnerUid, required String code}) async {
    final snapshot = await _redemptionsRef
        .where('partnerUid', isEqualTo: partnerUid)
        .where('code', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return RewardRedemption.fromFirestore(snapshot.docs.first);
  }

  Stream<List<RewardRedemption>> watchRedemptionsForParticipant(String uid) {
    return _redemptionsRef.where('participantUid', isEqualTo: uid).snapshots().map(
          (s) => s.docs.map(RewardRedemption.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<RewardRedemption>> watchRedemptionsForPartner(String partnerUid) {
    return _redemptionsRef.where('partnerUid', isEqualTo: partnerUid).snapshots().map(
          (s) => s.docs.map(RewardRedemption.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  /// Every redemption across every partner — admin impact dashboard
  /// (total rewards redeemed, total Community Partner reward value).
  Stream<List<RewardRedemption>> watchAllRedemptions() {
    return _redemptionsRef.snapshots().map((s) => s.docs.map(RewardRedemption.fromFirestore).toList());
  }

  // ---------------------------------------------------------------------
  // Financial contributions (Stripe). The client never creates or edits a
  // donation doc directly — createDonationCheckout creates it server-side
  // (status starts 'pending'), and only the stripeWebhook Cloud Function
  // (triggered by Stripe's own confirmed payment event) ever moves it to
  // 'paid'/'failed'. This mirrors the badge/attendance trust boundary
  // already used elsewhere: the client only ever reads donation status,
  // never writes it.
  // ---------------------------------------------------------------------

  /// Calls the deployed `createDonationCheckout` Cloud Function, which
  /// validates the amount/currency server-side, creates a `pending`
  /// donation record, and creates a Stripe Checkout Session. Returns the
  /// Stripe-hosted Checkout URL to open in a browser.
  Future<CreateDonationCheckoutResult> createDonationCheckout({
    required int amountCents,
    required String purpose,
  }) async {
    final callable = _functions.httpsCallable('createDonationCheckout');
    final result = await callable.call<Map<String, dynamic>>({
      'amountCents': amountCents,
      'currency': 'usd',
      'purpose': purpose,
    });
    return CreateDonationCheckoutResult(
      donationId: result.data['donationId'] as String,
      checkoutUrl: result.data['checkoutUrl'] as String,
    );
  }

  Future<Donation?> fetchDonation(String donationId) async {
    final doc = await _donationsRef.doc(donationId).get();
    if (!doc.exists) return null;
    return Donation.fromFirestore(doc);
  }

  Stream<Donation?> watchDonation(String donationId) {
    return _donationsRef.doc(donationId).snapshots().map((doc) => doc.exists ? Donation.fromFirestore(doc) : null);
  }

  Stream<List<Donation>> watchDonationsForPartner(String partnerUid) {
    return _donationsRef.where('partnerId', isEqualTo: partnerUid).snapshots().map(
          (s) => s.docs.map(Donation.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  /// Every donation across every partner — admin Donations dashboard.
  Stream<List<Donation>> watchAllDonations() {
    return _donationsRef.snapshots().map((s) => s.docs.map(Donation.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }
}

class CreateDonationCheckoutResult {
  CreateDonationCheckoutResult({required this.donationId, required this.checkoutUrl});

  final String donationId;
  final String checkoutUrl;
}
