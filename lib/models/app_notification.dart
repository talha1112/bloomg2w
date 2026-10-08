import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType {
  registrationConfirmed,
  sessionReminder,
  sessionStarting,
  sessionUpdated,
  sessionCancelled,
  general,
}

extension AppNotificationTypeX on AppNotificationType {
  String get value => name;

  static AppNotificationType fromValue(String? value) {
    return AppNotificationType.values.firstWhere(
      (t) => t.value == value?.trim(),
      orElse: () => AppNotificationType.general,
    );
  }
}

/// A real, Firestore-backed in-app notification for one user. Written by
/// the client at concrete trigger points (registering for a session, an
/// admin publishing/editing/cancelling a session) — see
/// NotificationService for exactly when each is created.
class AppNotification {
  AppNotification({
    required this.id,
    required this.uid,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.sessionId,
  });

  final String id;
  final String uid;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? sessionId;

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      type: AppNotificationTypeX.fromValue(data['type'] as String?),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      sessionId: data['sessionId'] as String?,
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'uid': uid,
      'type': type.value,
      'title': title,
      'body': body,
      'read': false,
      'sessionId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
