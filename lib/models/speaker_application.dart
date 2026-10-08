import 'package:cloud_firestore/cloud_firestore.dart';

enum SpeakerStatus { pending, approved, changesRequested, declined }

extension SpeakerStatusX on SpeakerStatus {
  String get value => name;

  static SpeakerStatus fromValue(String? value) {
    return SpeakerStatus.values.firstWhere(
      (s) => s.value == value?.trim(),
      orElse: () => SpeakerStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case SpeakerStatus.pending:
        return 'Pending';
      case SpeakerStatus.approved:
        return 'Approved';
      case SpeakerStatus.changesRequested:
        return 'Changes Requested';
      case SpeakerStatus.declined:
        return 'Declined';
    }
  }
}

const kSpeakerAudienceOptions = [
  'Girls 8–10',
  'Girls 11–13',
  'Girls 14–17',
  'Young Women 18+',
  'Adult Women',
  'Parents/Families',
  'All Audiences',
];

const kSpeakerExpertiseOptions = [
  'Leadership',
  'Career Development',
  'Entrepreneurship',
  'Financial Literacy',
  'Artificial Intelligence',
  'Technology/STEM',
  'Education',
  'Emotional Intelligence',
  'Health & Wellness',
  "Women's Empowerment",
  'Self-Esteem & Confidence',
  'College/Career Readiness',
  'Workforce Development',
  'Communication',
  'Personal Development',
  'Safety & Awareness',
  'Other',
];

enum SpeakerAvailability { virtual, inPerson, either }

extension SpeakerAvailabilityX on SpeakerAvailability {
  String get value => name;

  static SpeakerAvailability fromValue(String? value) {
    return SpeakerAvailability.values.firstWhere(
      (a) => a.value == value?.trim(),
      orElse: () => SpeakerAvailability.either,
    );
  }

  String get label {
    switch (this) {
      case SpeakerAvailability.virtual:
        return 'Virtual via Zoom';
      case SpeakerAvailability.inPerson:
        return 'In-Person';
      case SpeakerAvailability.either:
        return 'Either';
    }
  }
}

/// A Guest Speaker's application — private to the applicant and admins
/// until approved AND published, at which point a public-safe subset
/// is what the Bureau shows (never email/phone/address).
class SpeakerApplication {
  SpeakerApplication({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.profession,
    required this.speakingTopic,
    required this.presentationDescription,
    required this.targetAudiences,
    required this.expertiseAreas,
    required this.availability,
    required this.status,
    required this.published,
    required this.createdAt,
    this.photoUrl,
    this.cityState = '',
    this.professionalTitle = '',
    this.organization = '',
    this.yearsExperience = '',
    this.linkedInUrl = '',
    this.education = '',
    this.certifications = '',
    this.professionalExperience = '',
    this.volunteerExperience = '',
    this.previousSpeakingExperience = '',
    this.presentationTitle = '',
    this.otherExpertiseDetail = '',
    this.availableDaysTimes = '',
    this.whySpeak = '',
    this.additionalInfo = '',
    this.adminNotes = '',
  });

  final String uid;
  final String fullName;
  final String? photoUrl;
  final String email;
  final String phone;
  final String cityState;
  final String professionalTitle;
  final String profession;
  final String organization;
  final String yearsExperience;
  final String linkedInUrl;

  final String education;
  final String certifications;
  final String professionalExperience;
  final String volunteerExperience;
  final String previousSpeakingExperience;

  final String speakingTopic;
  final String presentationTitle;
  final String presentationDescription;
  final List<String> targetAudiences;

  final List<String> expertiseAreas;
  final String otherExpertiseDetail;

  final SpeakerAvailability availability;
  final String availableDaysTimes;

  final String whySpeak;
  final String additionalInfo;

  final SpeakerStatus status;
  final bool published;
  final String adminNotes;
  final DateTime createdAt;

  factory SpeakerApplication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SpeakerApplication(
      uid: doc.id,
      fullName: data['fullName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      cityState: data['cityState'] as String? ?? '',
      professionalTitle: data['professionalTitle'] as String? ?? '',
      profession: data['profession'] as String? ?? '',
      organization: data['organization'] as String? ?? '',
      yearsExperience: data['yearsExperience'] as String? ?? '',
      linkedInUrl: data['linkedInUrl'] as String? ?? '',
      education: data['education'] as String? ?? '',
      certifications: data['certifications'] as String? ?? '',
      professionalExperience: data['professionalExperience'] as String? ?? '',
      volunteerExperience: data['volunteerExperience'] as String? ?? '',
      previousSpeakingExperience: data['previousSpeakingExperience'] as String? ?? '',
      speakingTopic: data['speakingTopic'] as String? ?? '',
      presentationTitle: data['presentationTitle'] as String? ?? '',
      presentationDescription: data['presentationDescription'] as String? ?? '',
      targetAudiences: (data['targetAudiences'] as List?)?.cast<String>() ?? const [],
      expertiseAreas: (data['expertiseAreas'] as List?)?.cast<String>() ?? const [],
      otherExpertiseDetail: data['otherExpertiseDetail'] as String? ?? '',
      availability: SpeakerAvailabilityX.fromValue(data['availability'] as String?),
      availableDaysTimes: data['availableDaysTimes'] as String? ?? '',
      whySpeak: data['whySpeak'] as String? ?? '',
      additionalInfo: data['additionalInfo'] as String? ?? '',
      status: SpeakerStatusX.fromValue(data['status'] as String?),
      published: data['published'] as bool? ?? false,
      adminNotes: data['adminNotes'] as String? ?? '',
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'fullName': fullName,
      'photoUrl': photoUrl,
      'email': email,
      'phone': phone,
      'cityState': cityState,
      'professionalTitle': professionalTitle,
      'profession': profession,
      'organization': organization,
      'yearsExperience': yearsExperience,
      'linkedInUrl': linkedInUrl,
      'education': education,
      'certifications': certifications,
      'professionalExperience': professionalExperience,
      'volunteerExperience': volunteerExperience,
      'previousSpeakingExperience': previousSpeakingExperience,
      'speakingTopic': speakingTopic,
      'presentationTitle': presentationTitle,
      'presentationDescription': presentationDescription,
      'targetAudiences': targetAudiences,
      'expertiseAreas': expertiseAreas,
      'otherExpertiseDetail': otherExpertiseDetail,
      'availability': availability.value,
      'availableDaysTimes': availableDaysTimes,
      'whySpeak': whySpeak,
      'additionalInfo': additionalInfo,
      'status': 'pending',
      'published': false,
      'adminNotes': '',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
