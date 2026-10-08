import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/speaker_application.dart';
import '../models/speaker_interest.dart';
import '../models/speaker_profile.dart';

class SpeakerService {
  SpeakerService._();
  static final SpeakerService instance = SpeakerService._();

  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'bloomg2w-db',
  );

  CollectionReference get _applicationsRef => _db.collection('speaker_applications');
  CollectionReference get _profilesRef => _db.collection('speaker_profiles');
  CollectionReference get _interestsRef => _db.collection('speaker_interests');

  Future<void> submitApplication(SpeakerApplication application) {
    return _applicationsRef.doc(application.uid).set(application.toCreateMap());
  }

  Future<SpeakerApplication?> fetchApplication(String uid) async {
    final doc = await _applicationsRef.doc(uid).get();
    if (!doc.exists) return null;
    return SpeakerApplication.fromFirestore(doc);
  }

  Stream<SpeakerApplication?> watchApplication(String uid) {
    return _applicationsRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SpeakerApplication.fromFirestore(doc);
    });
  }

  /// All applications, for the admin review queue. Contains PII —
  /// admin-only per the security rules.
  Stream<List<SpeakerApplication>> watchAllApplications() {
    return _applicationsRef.orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map(SpeakerApplication.fromFirestore).toList(),
        );
  }

  /// The public, non-PII Guest Speakers Bureau — only speakers an admin
  /// has explicitly published appear here.
  Stream<List<SpeakerProfile>> watchPublishedSpeakers() {
    return _profilesRef.snapshots().map((s) => s.docs.map(SpeakerProfile.fromFirestore).toList());
  }

  Future<SpeakerProfile?> fetchPublishedSpeaker(String uid) async {
    final doc = await _profilesRef.doc(uid).get();
    if (!doc.exists) return null;
    return SpeakerProfile.fromFirestore(doc);
  }

  Future<void> setStatus({required String uid, required SpeakerStatus status, String adminNotes = ''}) async {
    await _applicationsRef.doc(uid).update({
      'status': status.value,
      'adminNotes': adminNotes,
      // Approving does not auto-publish — admin controls visibility separately.
      if (status != SpeakerStatus.approved) 'published': false,
    });
    // Un-approving must also retract the public profile, if one exists.
    if (status != SpeakerStatus.approved) {
      await _profilesRef.doc(uid).delete();
    }
  }

  /// Publishing/unpublishing writes or deletes the public, PII-free
  /// speaker_profiles doc that the Bureau actually reads from.
  Future<void> setPublished({required String uid, required bool published}) async {
    await _applicationsRef.doc(uid).update({'published': published});
    if (published) {
      final application = await fetchApplication(uid);
      if (application != null) {
        await _profilesRef.doc(uid).set(SpeakerProfile.fromApplication(application));
      }
    } else {
      await _profilesRef.doc(uid).delete();
    }
  }

  Future<void> submitInterest(SpeakerInterest interest) {
    return _interestsRef.doc().set(interest.toCreateMap());
  }

  /// All interest records — for admin's speaker interest tracking dashboard.
  Stream<List<SpeakerInterest>> watchAllInterests() {
    return _interestsRef.orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map(SpeakerInterest.fromFirestore).toList(),
        );
  }

  Stream<List<SpeakerInterest>> watchInterestsForSpeaker(String speakerUid) {
    return _interestsRef.where('speakerUid', isEqualTo: speakerUid).snapshots().map(
          (s) => s.docs.map(SpeakerInterest.fromFirestore).toList(),
        );
  }

  /// Interest records that requested "notify me when scheduled" for a
  /// given speaker and haven't been notified yet.
  Future<List<SpeakerInterest>> fetchUnnotifiedScheduleRequests(String speakerUid) async {
    final snapshot = await _interestsRef
        .where('speakerUid', isEqualTo: speakerUid)
        .where('interestType', isEqualTo: InterestType.notifyWhenScheduled.value)
        .where('notified', isEqualTo: false)
        .get();
    return snapshot.docs.map(SpeakerInterest.fromFirestore).toList();
  }

  Future<void> markInterestNotified(String interestId) {
    return _interestsRef.doc(interestId).update({'notified': true});
  }
}
