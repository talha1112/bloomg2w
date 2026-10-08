import 'package:cloud_firestore/cloud_firestore.dart';

import 'speaker_application.dart';

/// Public, non-PII view of an approved + published Guest Speaker —
/// what the member-facing Guest Speakers Bureau reads. Never contains
/// email, phone, or any other contact/address information.
class SpeakerProfile {
  SpeakerProfile({
    required this.uid,
    required this.fullName,
    required this.professionalTitle,
    required this.profession,
    required this.organization,
    required this.yearsExperience,
    required this.professionalExperience,
    required this.speakingTopic,
    required this.presentationTitle,
    required this.presentationDescription,
    required this.targetAudiences,
    required this.expertiseAreas,
    required this.publishedAt,
    this.photoUrl,
  });

  final String uid;
  final String fullName;
  final String? photoUrl;
  final String professionalTitle;
  final String profession;
  final String organization;
  final String yearsExperience;
  final String professionalExperience;
  final String speakingTopic;
  final String presentationTitle;
  final String presentationDescription;
  final List<String> targetAudiences;
  final List<String> expertiseAreas;
  final DateTime publishedAt;

  factory SpeakerProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SpeakerProfile(
      uid: doc.id,
      fullName: data['fullName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      professionalTitle: data['professionalTitle'] as String? ?? '',
      profession: data['profession'] as String? ?? '',
      organization: data['organization'] as String? ?? '',
      yearsExperience: data['yearsExperience'] as String? ?? '',
      professionalExperience: data['professionalExperience'] as String? ?? '',
      speakingTopic: data['speakingTopic'] as String? ?? '',
      presentationTitle: data['presentationTitle'] as String? ?? '',
      presentationDescription: data['presentationDescription'] as String? ?? '',
      targetAudiences: (data['targetAudiences'] as List?)?.cast<String>() ?? const [],
      expertiseAreas: (data['expertiseAreas'] as List?)?.cast<String>() ?? const [],
      publishedAt: data['publishedAt'] is Timestamp ? (data['publishedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  static Map<String, dynamic> fromApplication(SpeakerApplication app) {
    return {
      'fullName': app.fullName,
      'photoUrl': app.photoUrl,
      'professionalTitle': app.professionalTitle,
      'profession': app.profession,
      'organization': app.organization,
      'yearsExperience': app.yearsExperience,
      'professionalExperience': app.professionalExperience,
      'speakingTopic': app.speakingTopic,
      'presentationTitle': app.presentationTitle,
      'presentationDescription': app.presentationDescription,
      'targetAudiences': app.targetAudiences,
      'expertiseAreas': app.expertiseAreas,
      'publishedAt': FieldValue.serverTimestamp(),
    };
  }
}
