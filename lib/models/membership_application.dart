import 'package:cloud_firestore/cloud_firestore.dart';

enum MembershipType { girls, women }

extension MembershipTypeX on MembershipType {
  String get value => name;

  static MembershipType fromValue(String? value) {
    return MembershipType.values.firstWhere(
      (t) => t.value == value?.trim(),
      orElse: () => MembershipType.girls,
    );
  }

  String get label {
    switch (this) {
      case MembershipType.girls:
        return 'Girls Membership';
      case MembershipType.women:
        return "Women's Membership";
    }
  }
}

enum MembershipStatus { pending, approved, declined }

extension MembershipStatusX on MembershipStatus {
  String get value => name;

  static MembershipStatus fromValue(String? value) {
    return MembershipStatus.values.firstWhere(
      (s) => s.value == value?.trim(),
      orElse: () => MembershipStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case MembershipStatus.pending:
        return 'Pending';
      case MembershipStatus.approved:
        return 'Approved';
      case MembershipStatus.declined:
        return 'Declined';
    }
  }
}

/// A Membership Registration submission — separate from the lightweight
/// account created at sign-up. Captures the fuller application (type,
/// parent/guardian info for Girls Membership, member profile, interests,
/// membership question, terms acceptance) for admin review.
class MembershipApplication {
  MembershipApplication({
    required this.id,
    required this.uid,
    required this.type,
    required this.fullName,
    required this.dateOfBirth,
    required this.email,
    required this.phone,
    required this.interests,
    required this.membershipQuestion,
    required this.acceptedTerms,
    required this.status,
    required this.createdAt,
    this.parentName = '',
    this.parentEmail = '',
    this.parentPhone = '',
    this.parentConsent = false,
    this.adminNotes = '',
  });

  final String id;
  final String uid;
  final MembershipType type;
  final String fullName;
  final String dateOfBirth;
  final String email;
  final String phone;
  final String parentName;
  final String parentEmail;
  final String parentPhone;
  final bool parentConsent;
  final List<String> interests;
  final String membershipQuestion;
  final bool acceptedTerms;
  final MembershipStatus status;
  final String adminNotes;
  final DateTime createdAt;

  factory MembershipApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MembershipApplication(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      type: MembershipTypeX.fromValue(data['type'] as String?),
      fullName: data['fullName'] as String? ?? '',
      dateOfBirth: data['dateOfBirth'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      parentName: data['parentName'] as String? ?? '',
      parentEmail: data['parentEmail'] as String? ?? '',
      parentPhone: data['parentPhone'] as String? ?? '',
      parentConsent: data['parentConsent'] as bool? ?? false,
      interests: (data['interests'] as List?)?.cast<String>() ?? const [],
      membershipQuestion: data['membershipQuestion'] as String? ?? '',
      acceptedTerms: data['acceptedTerms'] as bool? ?? false,
      status: MembershipStatusX.fromValue(data['status'] as String?),
      adminNotes: data['adminNotes'] as String? ?? '',
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'uid': uid,
      'type': type.value,
      'fullName': fullName,
      'dateOfBirth': dateOfBirth,
      'email': email,
      'phone': phone,
      'parentName': parentName,
      'parentEmail': parentEmail,
      'parentPhone': parentPhone,
      'parentConsent': parentConsent,
      'interests': interests,
      'membershipQuestion': membershipQuestion,
      'acceptedTerms': acceptedTerms,
      'status': 'pending',
      'adminNotes': '',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
