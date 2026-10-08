import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_notification.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'bloomg2w-db',
  );

  CollectionReference get _notificationsRef => _db.collection('app_notifications');

  Future<void> send({
    required String uid,
    required AppNotificationType type,
    required String title,
    required String body,
    String? sessionId,
  }) {
    final notification = AppNotification(
      id: '',
      uid: uid,
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      sessionId: sessionId,
    );
    return _notificationsRef.doc().set(notification.toCreateMap());
  }

  Stream<List<AppNotification>> watchForUser(String uid) {
    return _notificationsRef.where('uid', isEqualTo: uid).snapshots().map(
          (s) => s.docs.map(AppNotification.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<void> markRead(String notificationId) {
    return _notificationsRef.doc(notificationId).update({'read': true});
  }

  Future<void> markAllReadForUser(String uid) async {
    final snapshot = await _notificationsRef.where('uid', isEqualTo: uid).where('read', isEqualTo: false).get();
    for (final doc in snapshot.docs) {
      await doc.reference.update({'read': true});
    }
  }
}
