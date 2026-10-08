import 'package:cloud_firestore/cloud_firestore.dart';

/// Pre-session check-in — a short, encouraging 3-question pulse taken
/// before a session starts. Distinct from [SessionSurvey] (the exit
/// survey): this captures BEFORE-session self-ratings only. One check-in
/// per participant per session, so registering for a different session
/// never overwrites an earlier one — enforced via `${sessionId}_${uid}`.
class SessionCheckin {
  SessionCheckin({
    required this.id,
    required this.sessionId,
    required this.participantUid,
    required this.knowledgeBefore,
    required this.confidenceBefore,
    required this.learningGoal,
    required this.submittedAt,
  });

  final String id;
  final String sessionId;
  final String participantUid;
  final int knowledgeBefore; // 1-5
  final int confidenceBefore; // 1-5
  final String learningGoal; // optional short response
  final DateTime submittedAt;

  static String idFor({required String sessionId, required String uid}) => '${sessionId}_$uid';

  factory SessionCheckin.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SessionCheckin(
      id: doc.id,
      sessionId: data['sessionId'] as String? ?? '',
      participantUid: data['participantUid'] as String? ?? '',
      knowledgeBefore: (data['knowledgeBefore'] as num?)?.toInt() ?? 0,
      confidenceBefore: (data['confidenceBefore'] as num?)?.toInt() ?? 0,
      learningGoal: data['learningGoal'] as String? ?? '',
      submittedAt: data['submittedAt'] is Timestamp ? (data['submittedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'sessionId': sessionId,
      'participantUid': participantUid,
      'knowledgeBefore': knowledgeBefore,
      'confidenceBefore': confidenceBefore,
      'learningGoal': learningGoal,
      'submittedAt': FieldValue.serverTimestamp(),
    };
  }
}
