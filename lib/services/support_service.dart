import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/support_message.dart';

class SupportService {
  SupportService._();
  static final SupportService instance = SupportService._();

  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'bloomg2w-db',
  );

  CollectionReference get _messagesRef => _db.collection('support_messages');

  Future<void> submitMessage(SupportMessage message) {
    return _messagesRef.doc().set(message.toCreateMap());
  }

  /// A user's own submitted messages (so they could see their own history
  /// if that's ever surfaced in-app).
  Stream<List<SupportMessage>> watchOwnMessages(String uid) {
    return _messagesRef.where('uid', isEqualTo: uid).snapshots().map(
          (s) => s.docs.map(SupportMessage.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  /// All submissions — admin portal only.
  Stream<List<SupportMessage>> watchAllMessages() {
    return _messagesRef.orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map(SupportMessage.fromFirestore).toList(),
        );
  }

  Future<void> setStatus({required String id, required SupportMessageStatus status, String? adminNotes}) {
    return _messagesRef.doc(id).update({
      'status': status.value,
      'adminNotes': ?adminNotes,
    });
  }
}
