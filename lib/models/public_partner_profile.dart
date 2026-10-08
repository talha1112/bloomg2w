import 'package:cloud_firestore/cloud_firestore.dart';

/// A PII-free mirror of [PartnerProfile] — no contactPerson, email, or
/// phone — safe for any signed-in member to browse in the Community
/// Partners directory. Written automatically alongside the private
/// `partners/{uid}` doc when a Community Partner finishes registration.
class PublicPartnerProfile {
  PublicPartnerProfile({
    required this.uid,
    required this.businessName,
    required this.description,
    required this.supportTypes,
    required this.createdAt,
    this.logoUrl,
  });

  final String uid;
  final String businessName;
  final String description;
  final List<String> supportTypes;
  final DateTime createdAt;
  final String? logoUrl;

  factory PublicPartnerProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PublicPartnerProfile(
      uid: doc.id,
      businessName: data['businessName'] as String? ?? '',
      description: data['description'] as String? ?? '',
      supportTypes: (data['supportTypes'] as List?)?.cast<String>() ?? const [],
      logoUrl: data['logoUrl'] as String?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'businessName': businessName,
      'description': description,
      'supportTypes': supportTypes,
      'logoUrl': logoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
