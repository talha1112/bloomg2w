import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationLikelihood { yes, maybe, notYet }

extension ApplicationLikelihoodX on ApplicationLikelihood {
  String get value => name;

  static ApplicationLikelihood fromValue(String? value) {
    return ApplicationLikelihood.values.firstWhere(
      (v) => v.value == value?.trim(),
      orElse: () => ApplicationLikelihood.maybe,
    );
  }

  String get label {
    switch (this) {
      case ApplicationLikelihood.yes:
        return 'Yes';
      case ApplicationLikelihood.maybe:
        return 'Maybe';
      case ApplicationLikelihood.notYet:
        return 'Not Yet';
    }
  }
}

enum FutureSupportInterest { yes, no, maybe }

extension FutureSupportInterestX on FutureSupportInterest {
  String get value => name;

  static FutureSupportInterest fromValue(String? value) {
    return FutureSupportInterest.values.firstWhere(
      (v) => v.value == value?.trim(),
      orElse: () => FutureSupportInterest.maybe,
    );
  }

  String get label {
    switch (this) {
      case FutureSupportInterest.yes:
        return 'Yes';
      case FutureSupportInterest.no:
        return 'No';
      case FutureSupportInterest.maybe:
        return 'Maybe';
    }
  }
}

/// Post-session exit survey (spec section 8 lifecycle: Exit Survey ->
/// Badge Award -> Impact Metrics). One survey per participant/session —
/// enforced by using `${sessionId}_${uid}` as the document ID.
///
/// IMPORTANT data-integrity note: [learningRating] and [confidenceAfter]
/// are POST-session self-ratings. They are only comparable to a BEFORE
/// rating when a matching [SessionCheckin] exists for the same
/// participant/session — see SessionService.fetchOutcomeComparison, which
/// is the only place a "confidence change" is computed, and only when
/// both sides exist for the same person. Never diff these against a
/// population average or an unrelated session's check-in.
class SessionSurvey {
  SessionSurvey({
    required this.id,
    required this.sessionId,
    required this.participantUid,
    required this.learningRating,
    required this.confidenceAfter,
    required this.applicationLikelihood,
    required this.mostValuableLearning,
    required this.futureSupportInterest,
    required this.submittedAt,
  });

  final String id;
  final String sessionId;
  final String participantUid;

  /// "I learned something new today." 1-5.
  final int learningRating;

  /// "I feel more confident about today's topic after participating." 1-5.
  final int confidenceAfter;

  /// "I can use something I learned today in my school, work, home, or
  /// everyday life." Yes / Maybe / Not Yet.
  final ApplicationLikelihood applicationLikelihood;

  /// Short free-text response.
  final String mostValuableLearning;

  /// Interest in future support/programming. Yes / No / Maybe.
  final FutureSupportInterest futureSupportInterest;

  final DateTime submittedAt;

  static String idFor({required String sessionId, required String uid}) => '${sessionId}_$uid';

  factory SessionSurvey.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SessionSurvey(
      id: doc.id,
      sessionId: data['sessionId'] as String? ?? '',
      participantUid: data['participantUid'] as String? ?? '',
      learningRating: (data['learningRating'] as num?)?.toInt() ?? 0,
      confidenceAfter: (data['confidenceAfter'] as num?)?.toInt() ?? 0,
      applicationLikelihood: ApplicationLikelihoodX.fromValue(data['applicationLikelihood'] as String?),
      mostValuableLearning: data['mostValuableLearning'] as String? ?? '',
      futureSupportInterest: FutureSupportInterestX.fromValue(data['futureSupportInterest'] as String?),
      submittedAt: data['submittedAt'] is Timestamp ? (data['submittedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'sessionId': sessionId,
      'participantUid': participantUid,
      'learningRating': learningRating,
      'confidenceAfter': confidenceAfter,
      'applicationLikelihood': applicationLikelihood.value,
      'mostValuableLearning': mostValuableLearning,
      'futureSupportInterest': futureSupportInterest.value,
      'submittedAt': FieldValue.serverTimestamp(),
    };
  }
}
