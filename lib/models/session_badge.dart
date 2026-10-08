import 'package:cloud_firestore/cloud_firestore.dart';

/// An earned "attended & completed a session" badge (spec section 8
/// lifecycle: Exit Survey -> Badge Award -> Impact Metrics Updated).
/// Auto-awarded by SessionService when a participant who met the
/// session's minimum attendance requirement completes the exit survey —
/// never manually awarded by an admin. One badge per participant/session,
/// enforced by using `${sessionId}_${uid}` as the document ID.
class SessionBadge {
  SessionBadge({
    required this.id,
    required this.sessionId,
    required this.participantUid,
    required this.sessionTitle,
    required this.program,
    required this.awardedAt,
    this.celebrationSeen = false,
    this.redemptionId,
  });

  final String id;
  final String sessionId;
  final String participantUid;
  final String sessionTitle;
  final String program;
  final DateTime awardedAt;

  /// Whether the one-time "new badge!" celebration has already been shown
  /// to the participant — prevents repeatedly celebrating the same badge
  /// on every app open.
  final bool celebrationSeen;

  /// Set by the redeemReward Cloud Function transaction once this badge
  /// has been spent toward a reward redemption. A spent badge is never
  /// deleted (history/celebration state survive) but can never be spent
  /// again — see redeemReward's `where('redemptionId', '==', null)` query.
  final String? redemptionId;

  bool get isSpent => redemptionId != null;

  static String idFor({required String sessionId, required String uid}) => '${sessionId}_$uid';

  factory SessionBadge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SessionBadge(
      id: doc.id,
      sessionId: data['sessionId'] as String? ?? '',
      participantUid: data['participantUid'] as String? ?? '',
      sessionTitle: data['sessionTitle'] as String? ?? '',
      program: data['program'] as String? ?? '',
      awardedAt: data['awardedAt'] is Timestamp ? (data['awardedAt'] as Timestamp).toDate() : DateTime.now(),
      celebrationSeen: data['celebrationSeen'] as bool? ?? false,
      redemptionId: data['redemptionId'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'sessionId': sessionId,
      'participantUid': participantUid,
      'sessionTitle': sessionTitle,
      'program': program,
      'awardedAt': FieldValue.serverTimestamp(),
      'celebrationSeen': false,
      'redemptionId': null,
    };
  }
}
