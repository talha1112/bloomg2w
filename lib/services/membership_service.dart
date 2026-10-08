import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/membership_application.dart';

class MembershipService {
  MembershipService._();
  static final MembershipService instance = MembershipService._();

  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'bloomg2w-db',
  );

  CollectionReference get _applicationsRef => _db.collection('membership_applications');

  Future<void> submitApplication(MembershipApplication application) {
    return _applicationsRef.doc().set(application.toCreateMap());
  }

  Stream<List<MembershipApplication>> watchOwnApplications(String uid) {
    return _applicationsRef.where('uid', isEqualTo: uid).snapshots().map(
          (s) => s.docs.map(MembershipApplication.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  /// All submissions — admin portal only.
  Stream<List<MembershipApplication>> watchAllApplications() {
    return _applicationsRef.orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map(MembershipApplication.fromFirestore).toList(),
        );
  }

  Future<void> setStatus({required String id, required MembershipStatus status, String? adminNotes}) {
    return _applicationsRef.doc(id).update({
      'status': status.value,
      'adminNotes': ?adminNotes,
    });
  }
}
