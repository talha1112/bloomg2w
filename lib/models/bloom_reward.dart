import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-review lifecycle for a reward OFFER, per the Community Partner
/// Rewards spec. A reward is never visible in the participant marketplace
/// until an admin sets it to [approved] — see [BloomReward.isAvailable].
enum RewardStatus { pending, approved, paused, expired, depleted, rejected }

extension RewardStatusX on RewardStatus {
  String get value => name;

  static RewardStatus fromValue(String? value) {
    return RewardStatus.values.firstWhere(
      (s) => s.value == value?.trim(),
      orElse: () => RewardStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case RewardStatus.pending:
        return 'Pending Review';
      case RewardStatus.approved:
        return 'Approved';
      case RewardStatus.paused:
        return 'Paused';
      case RewardStatus.expired:
        return 'Expired';
      case RewardStatus.depleted:
        return 'Depleted';
      case RewardStatus.rejected:
        return 'Rejected';
    }
  }
}

/// A reward OFFER a Community Partner configures in the Rewards
/// Marketplace — a template, not a single redeemable unit. Many
/// participants can redeem from the same reward while [quantityAvailable]
/// (tracked as [remainingQuantity]) lasts; each individual claim is its
/// own [RewardRedemption] doc with its own unique one-time code.
///
/// [status] and [active] are deliberately separate: [status] is the
/// admin-controlled approval lifecycle (a partner can never self-approve
/// their own reward), while [active] is a lightweight pause/unpause toggle
/// the OWNING PARTNER may flip on an already-approved reward (e.g. to
/// temporarily hide it without losing its approval). Both must hold for a
/// reward to appear in the marketplace.
class BloomReward {
  BloomReward({
    required this.id,
    required this.partnerUid,
    required this.partnerName,
    required this.name,
    required this.value,
    required this.quantityAvailable,
    required this.remainingQuantity,
    required this.badgeCost,
    required this.createdAt,
    this.description = '',
    this.expirationDate,
    this.restrictions,
    this.active = true,
    this.status = RewardStatus.pending,
    this.reviewNotes = '',
  });

  final String id;
  final String partnerUid;
  final String partnerName;
  final String name;
  final double value;

  /// Total units this offer started with — fixed at creation.
  final int quantityAvailable;

  /// Units not yet claimed by a redemption — decremented atomically by
  /// the redeemReward Cloud Function transaction. This is the number the
  /// marketplace actually gates eligibility on.
  final int remainingQuantity;

  /// How many of the participant's unredeemed session badges this reward
  /// costs. Configured per-reward by the partner/admin — never hard-coded.
  final int badgeCost;
  final DateTime createdAt;
  final String description;
  final DateTime? expirationDate;
  final String? restrictions;

  /// Partner/admin pause toggle on an already-approved reward.
  final bool active;

  /// Admin approval lifecycle — see class doc.
  final RewardStatus status;

  /// Optional admin note explaining a rejection/pause, shown to the partner.
  final String reviewNotes;

  bool get isAvailable =>
      status == RewardStatus.approved &&
      active &&
      remainingQuantity > 0 &&
      (expirationDate == null || expirationDate!.isAfter(DateTime.now()));

  factory BloomReward.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BloomReward(
      id: doc.id,
      partnerUid: data['partnerUid'] as String? ?? '',
      partnerName: data['partnerName'] as String? ?? '',
      name: data['name'] as String? ?? '',
      value: (data['value'] as num?)?.toDouble() ?? 0,
      quantityAvailable: (data['quantityAvailable'] as num?)?.toInt() ?? 0,
      remainingQuantity: (data['remainingQuantity'] as num?)?.toInt() ?? 0,
      badgeCost: (data['badgeCost'] as num?)?.toInt() ?? 1,
      description: data['description'] as String? ?? '',
      restrictions: data['restrictions'] as String?,
      active: data['active'] as bool? ?? true,
      status: RewardStatusX.fromValue(data['status'] as String?),
      reviewNotes: data['reviewNotes'] as String? ?? '',
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      expirationDate: data['expirationDate'] is Timestamp ? (data['expirationDate'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'partnerUid': partnerUid,
      'partnerName': partnerName,
      'name': name,
      'value': value,
      'quantityAvailable': quantityAvailable,
      'remainingQuantity': quantityAvailable,
      'badgeCost': badgeCost,
      'description': description,
      'expirationDate': expirationDate != null ? Timestamp.fromDate(expirationDate!) : null,
      'restrictions': restrictions,
      'active': true,
      'status': RewardStatus.pending.value,
      'reviewNotes': '',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

enum RedemptionStatus { pending, used }

extension RedemptionStatusX on RedemptionStatus {
  String get value => name;

  static RedemptionStatus fromValue(String? value) {
    return RedemptionStatus.values.firstWhere(
      (s) => s.value == value?.trim(),
      orElse: () => RedemptionStatus.pending,
    );
  }
}

/// One participant's individual claim of a [BloomReward] offer — created
/// atomically (badge deduction + quantity decrement + this doc, all in one
/// transaction) by the redeemReward Cloud Function. Never created,
/// updated, or marked used directly by a client — see firestore.rules.
class RewardRedemption {
  RewardRedemption({
    required this.id,
    required this.rewardId,
    required this.rewardName,
    required this.partnerUid,
    required this.partnerName,
    required this.participantUid,
    required this.badgeCost,
    required this.code,
    required this.status,
    required this.createdAt,
    this.usedAt,
    this.usedByPartnerUid,
  });

  final String id;
  final String rewardId;
  final String rewardName;
  final String partnerUid;
  final String partnerName;
  final String participantUid;
  final int badgeCost;
  final String code;
  final RedemptionStatus status;
  final DateTime createdAt;
  final DateTime? usedAt;
  final String? usedByPartnerUid;

  factory RewardRedemption.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RewardRedemption(
      id: doc.id,
      rewardId: data['rewardId'] as String? ?? '',
      rewardName: data['rewardName'] as String? ?? '',
      partnerUid: data['partnerUid'] as String? ?? '',
      partnerName: data['partnerName'] as String? ?? '',
      participantUid: data['participantUid'] as String? ?? '',
      badgeCost: (data['badgeCost'] as num?)?.toInt() ?? 0,
      code: data['code'] as String? ?? '',
      status: RedemptionStatusX.fromValue(data['status'] as String?),
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      usedAt: data['usedAt'] is Timestamp ? (data['usedAt'] as Timestamp).toDate() : null,
      usedByPartnerUid: data['usedByPartnerUid'] as String?,
    );
  }
}
