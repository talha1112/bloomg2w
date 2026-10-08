import 'package:cloud_firestore/cloud_firestore.dart';

enum SupportMessageType { contact, reportProblem, feedback }

extension SupportMessageTypeX on SupportMessageType {
  String get value => name;

  static SupportMessageType fromValue(String? value) {
    return SupportMessageType.values.firstWhere(
      (t) => t.value == value?.trim(),
      orElse: () => SupportMessageType.contact,
    );
  }

  String get label {
    switch (this) {
      case SupportMessageType.contact:
        return 'Contact';
      case SupportMessageType.reportProblem:
        return 'Problem Report';
      case SupportMessageType.feedback:
        return 'Feedback';
    }
  }
}

enum SupportMessageStatus { open, resolved }

extension SupportMessageStatusX on SupportMessageStatus {
  String get value => name;

  static SupportMessageStatus fromValue(String? value) {
    return SupportMessageStatus.values.firstWhere(
      (s) => s.value == value?.trim(),
      orElse: () => SupportMessageStatus.open,
    );
  }

  String get label {
    switch (this) {
      case SupportMessageStatus.open:
        return 'Open';
      case SupportMessageStatus.resolved:
        return 'Resolved';
    }
  }
}

/// A submission from Contact & Support — a contact-form message, a
/// reported problem, or general feedback. Always tied to the submitting
/// user's uid; admins triage everything from the admin portal.
class SupportMessage {
  SupportMessage({
    required this.id,
    required this.uid,
    required this.userName,
    required this.userEmail,
    required this.type,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    this.adminNotes = '',
  });

  final String id;
  final String uid;
  final String userName;
  final String userEmail;
  final SupportMessageType type;
  final String category;
  final String subject;
  final String message;
  final SupportMessageStatus status;
  final String adminNotes;
  final DateTime createdAt;

  factory SupportMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SupportMessage(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      type: SupportMessageTypeX.fromValue(data['type'] as String?),
      category: data['category'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      message: data['message'] as String? ?? '',
      status: SupportMessageStatusX.fromValue(data['status'] as String?),
      adminNotes: data['adminNotes'] as String? ?? '',
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'uid': uid,
      'userName': userName,
      'userEmail': userEmail,
      'type': type.value,
      'category': category,
      'subject': subject,
      'message': message,
      'status': 'open',
      'adminNotes': '',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
