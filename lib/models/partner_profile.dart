import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin approval lifecycle for a Community Partner. A partner is never
/// exposed to participants (partner_profiles) or eligible to have their
/// rewards approved until an admin sets them to [approved].
enum PartnerStatus { pending, approved, rejected, suspended }

extension PartnerStatusX on PartnerStatus {
  String get value => name;

  static PartnerStatus fromValue(String? value) {
    return PartnerStatus.values.firstWhere(
      (s) => s.value == value?.trim(),
      orElse: () => PartnerStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case PartnerStatus.pending:
        return 'Pending Review';
      case PartnerStatus.approved:
        return 'Approved';
      case PartnerStatus.rejected:
        return 'Rejected';
      case PartnerStatus.suspended:
        return 'Suspended';
    }
  }
}

/// Community Partner business profile — Step 1 & 2 of the
/// Community Partner Program onboarding.
class PartnerProfile {
  PartnerProfile({
    required this.uid,
    required this.businessName,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.website,
    required this.description,
    required this.supportTypes,
    required this.contributionDetails,
    required this.createdAt,
    this.logoUrl,
    this.status = PartnerStatus.pending,
    this.statusUpdatedAt,
    this.statusUpdatedBy,
  });

  final String uid;
  final String businessName;
  final String contactPerson;
  final String email;
  final String phone;
  final String website;
  final String description;
  final List<String> supportTypes;
  final String contributionDetails;
  final DateTime createdAt;
  final String? logoUrl;

  /// Admin approval lifecycle — see class doc.
  final PartnerStatus status;
  final DateTime? statusUpdatedAt;
  final String? statusUpdatedBy;

  factory PartnerProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PartnerProfile(
      uid: doc.id,
      businessName: data['businessName'] as String? ?? '',
      contactPerson: data['contactPerson'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      website: data['website'] as String? ?? '',
      description: data['description'] as String? ?? '',
      supportTypes: (data['supportTypes'] as List?)?.cast<String>() ?? const [],
      contributionDetails: data['contributionDetails'] as String? ?? '',
      logoUrl: data['logoUrl'] as String?,
      status: PartnerStatusX.fromValue(data['status'] as String?),
      statusUpdatedAt: data['statusUpdatedAt'] is Timestamp ? (data['statusUpdatedAt'] as Timestamp).toDate() : null,
      statusUpdatedBy: data['statusUpdatedBy'] as String?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'businessName': businessName,
      'contactPerson': contactPerson,
      'email': email,
      'phone': phone,
      'website': website,
      'description': description,
      'supportTypes': supportTypes,
      'contributionDetails': contributionDetails,
      'logoUrl': logoUrl,
      'status': PartnerStatus.pending.value,
      'statusUpdatedAt': null,
      'statusUpdatedBy': null,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Supported ways a Community Partner can help, per the program spec.
const kPartnerSupportOptions = [
  'Sponsor participant rewards',
  'Provide gift cards or certificates',
  'Sponsor a workshop or activity',
  'Provide products or services',
  'Provide educational or career resources',
  'Make a financial contribution',
];
