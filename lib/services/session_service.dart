import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_notification.dart';
import '../models/bloom_session.dart';
import '../models/session_badge.dart';
import '../models/session_checkin.dart';
import '../models/session_registration.dart';
import '../models/session_survey.dart';
import 'notification_service.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'bloomg2w-db',
  );

  CollectionReference get _sessionsRef => _db.collection('bloom_sessions');
  CollectionReference get _registrationsRef => _db.collection('session_registrations');
  CollectionReference get _surveysRef => _db.collection('session_surveys');
  CollectionReference get _checkinsRef => _db.collection('session_checkins');
  CollectionReference get _badgesRef => _db.collection('session_badges');
  CollectionReference get _syncLogRef => _db.collection('attendance_sync_log');

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1');

  // ---------------------------------------------------------------------
  // Admin: session CRUD
  // ---------------------------------------------------------------------

  Future<String> createSession(BloomSession session) async {
    final doc = await _sessionsRef.add(session.toMap());
    return doc.id;
  }

  /// [previous] is the session's state before this edit, used to decide
  /// whether the change is actually attendee-critical (date, time, or Zoom
  /// details) — a title or description typo fix must never tell every
  /// registrant the session was "rescheduled". Pass null only when there
  /// is no prior state to compare (which should not happen for an update).
  Future<void> updateSession(String sessionId, BloomSession session, {BloomSession? previous}) async {
    await _sessionsRef.doc(sessionId).update({
      'title': session.title,
      'topic': session.topic,
      'description': session.description,
      'date': timestampFromCalendarDate(session.date),
      'startTime': session.startTime,
      'endTime': session.endTime,
      'zoomMeetingLink': session.zoomMeetingLink,
      'zoomMeetingId': session.zoomMeetingId,
      'zoomPasscode': session.zoomPasscode,
      'minAttendancePercent': session.minAttendancePercent,
      'program': session.program,
      'ageGroup': session.ageGroup,
      'status': session.status.value,
      'registrationDeadline': session.registrationDeadline != null ? timestampFromCalendarDate(session.registrationDeadline!) : null,
      'guestSpeakerUid': session.guestSpeakerUid,
      'guestSpeakerNameSnapshot': session.guestSpeakerNameSnapshot,
    });

    final scheduleChanged = previous != null &&
        session.status == SessionStatus.published &&
        (!_isSameCalendarDay(previous.date, session.date) ||
            previous.startTime != session.startTime ||
            previous.endTime != session.endTime ||
            previous.zoomMeetingLink != session.zoomMeetingLink ||
            previous.zoomMeetingId != session.zoomMeetingId ||
            previous.zoomPasscode != session.zoomPasscode);

    if (scheduleChanged) {
      await _notifyRegistrants(sessionId: sessionId, kind: 'sessionUpdated');
    }
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> cancelSession(String sessionId, String sessionTitle, {String? reason}) async {
    await _sessionsRef.doc(sessionId).update({
      'status': SessionStatus.cancelled.value,
      'cancellationReason': reason,
    });

    final registrants = await fetchRegistrationsForSession(sessionId);
    for (final r in registrants) {
      await _registrationsRef.doc(r.id).update({'status': RegistrationStatus.cancelled.value});
    }
    await _notifyRegistrants(sessionId: sessionId, kind: 'sessionCancelled');
  }

  /// Routes admin-initiated fan-out through the notifySessionRegistrants
  /// Cloud Function — clients may only create a notification addressed to
  /// themself (see firestore.rules isValidNewNotification), so notifying
  /// every registrant of a session change can only happen server-side.
  Future<void> _notifyRegistrants({required String sessionId, required String kind}) async {
    final callable = _functions.httpsCallable('notifySessionRegistrants');
    await callable.call<Map<String, dynamic>>({'sessionId': sessionId, 'kind': kind});
  }

  /// Calls the deployed `createZoomMeetingForSession` Cloud Function, which
  /// creates a real Zoom meeting under the assigned guest speaker's own
  /// licensed Zoom user account and saves the join link/ID/passcode onto
  /// the session (the host-only start link goes to the private
  /// subcollection the speaker's dashboard reads separately).
  Future<void> createZoomMeetingForSession(String sessionId) async {
    final callable = _functions.httpsCallable('createZoomMeetingForSession');
    await callable.call<Map<String, dynamic>>({'sessionId': sessionId});
  }

  /// The Zoom host-only start link for a session — readable only by the
  /// assigned speaker (or an admin), per the private subcollection's rules.
  Future<SessionZoomHost?> fetchZoomHostInfo(String sessionId) async {
    final doc = await _sessionsRef.doc(sessionId).collection('private').doc('zoomHost').get();
    if (!doc.exists) return null;
    return SessionZoomHost.fromFirestore(doc);
  }

  /// Sessions where the given uid is the assigned guest speaker — what the
  /// Speaker Dashboard's "My Sessions" list reads.
  Stream<List<BloomSession>> watchSessionsForSpeaker(String speakerUid) {
    return _sessionsRef.where('guestSpeakerUid', isEqualTo: speakerUid).snapshots().map(
          (s) => s.docs.map(BloomSession.fromFirestore).toList()..sort((a, b) => a.date.compareTo(b.date)),
        );
  }

  /// Calls the deployed `syncSessionAttendance` Cloud Function, which pulls
  /// the authoritative Zoom past-meeting report, matches registrants by
  /// their Bloom account email, and writes attendance directly to each
  /// registration. Every call — including a re-sync — appends one entry to
  /// attendance_sync_log for audit history; it never fabricates a result
  /// client-side.
  Future<ZoomSyncResult> syncAttendanceFromZoom(String sessionId) async {
    final callable = _functions.httpsCallable('syncSessionAttendance');
    final result = await callable.call<Map<String, dynamic>>({'sessionId': sessionId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return ZoomSyncResult.fromCallableResponse(data);
  }

  Stream<List<Map<String, dynamic>>> watchSyncLogForSession(String sessionId) {
    return _syncLogRef.where('sessionId', isEqualTo: sessionId).snapshots().map(
          (s) => s.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList()
            ..sort((a, b) {
              final at = a['startedAt'] as Timestamp?;
              final bt = b['startedAt'] as Timestamp?;
              return (bt?.toDate() ?? DateTime(0)).compareTo(at?.toDate() ?? DateTime(0));
            }),
        );
  }

  /// Admin-triggered reminder for all registrants of a session — created at
  /// this explicit trigger point (an admin tapping "Send Reminder Now"),
  /// not by a scheduled job. Routed through the notifySessionRegistrants
  /// Cloud Function (see _notifyRegistrants) so the client never writes
  /// notifications directly into other users' inboxes.
  Future<void> sendReminderNow(String sessionId) async {
    await _notifyRegistrants(sessionId: sessionId, kind: 'sessionReminder');
  }

  /// Admin-triggered "session is starting" notification with a join
  /// prompt — created when an admin taps "Notify: Session Starting",
  /// not by a scheduled job.
  Future<void> sendSessionStartingNow(String sessionId) async {
    await _notifyRegistrants(sessionId: sessionId, kind: 'sessionStarting');
  }

  Stream<List<BloomSession>> watchAllSessions() {
    return _sessionsRef.snapshots().map(
          (s) => s.docs.map(BloomSession.fromFirestore).toList()..sort((a, b) => a.date.compareTo(b.date)),
        );
  }

  /// Published, non-cancelled, upcoming sessions — what participants see.
  Stream<List<BloomSession>> watchUpcomingPublishedSessions() {
    return _sessionsRef.where('status', isEqualTo: SessionStatus.published.value).snapshots().map(
          (s) => s.docs.map(BloomSession.fromFirestore).toList()..sort((a, b) => a.date.compareTo(b.date)),
        );
  }

  Future<BloomSession?> fetchSession(String sessionId) async {
    final doc = await _sessionsRef.doc(sessionId).get();
    if (!doc.exists) return null;
    return BloomSession.fromFirestore(doc);
  }

  // ---------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------

  Future<void> registerForSession({
    required String sessionId,
    required String uid,
    required String participantName,
    required String sessionTitle,
  }) async {
    final id = SessionRegistration.idFor(sessionId: sessionId, uid: uid);
    final existing = await _registrationsRef.doc(id).get();
    if (existing.exists) return; // one active registration per participant/session

    final registration = SessionRegistration(
      id: id,
      sessionId: sessionId,
      participantUid: uid,
      participantName: participantName,
      registeredAt: DateTime.now(),
      status: RegistrationStatus.registered,
    );
    await _registrationsRef.doc(id).set(registration.toCreateMap());

    await NotificationService.instance.send(
      uid: uid,
      type: AppNotificationType.registrationConfirmed,
      title: "🌸 You're Registered!",
      body: "You're registered for $sessionTitle.",
      sessionId: sessionId,
    );
  }

  Future<SessionRegistration?> fetchRegistration({required String sessionId, required String uid}) async {
    final doc = await _registrationsRef.doc(SessionRegistration.idFor(sessionId: sessionId, uid: uid)).get();
    if (!doc.exists) return null;
    return SessionRegistration.fromFirestore(doc);
  }

  Stream<SessionRegistration?> watchRegistration({required String sessionId, required String uid}) {
    return _registrationsRef.doc(SessionRegistration.idFor(sessionId: sessionId, uid: uid)).snapshots().map(
          (doc) => doc.exists ? SessionRegistration.fromFirestore(doc) : null,
        );
  }

  Stream<List<SessionRegistration>> watchRegistrationsForUser(String uid) {
    return _registrationsRef.where('participantUid', isEqualTo: uid).snapshots().map(
          (s) => s.docs.map(SessionRegistration.fromFirestore).toList()..sort((a, b) => b.registeredAt.compareTo(a.registeredAt)),
        );
  }

  Future<List<SessionRegistration>> fetchRegistrationsForSession(String sessionId) async {
    final snapshot = await _registrationsRef.where('sessionId', isEqualTo: sessionId).get();
    return snapshot.docs.map(SessionRegistration.fromFirestore).toList();
  }

  Stream<List<SessionRegistration>> watchRegistrationsForSession(String sessionId) {
    return _registrationsRef.where('sessionId', isEqualTo: sessionId).snapshots().map(
          (s) => s.docs.map(SessionRegistration.fromFirestore).toList()..sort((a, b) => a.participantName.compareTo(b.participantName)),
        );
  }

  // ---------------------------------------------------------------------
  // Admin: attendance (entered from the Zoom attendance report — never
  // participant self-reported, per program direction).
  // ---------------------------------------------------------------------

  /// Manual admin correction — retained as a fallback for exceptional
  /// cases (e.g. a Zoom-import mismatch), stamped with who made the
  /// correction and when for audit history. Primary attendance should
  /// come from [syncAttendanceFromZoom] wherever a Zoom meeting ID is set.
  Future<void> recordAttendance({
    required String registrationId,
    required bool attended,
    required String correctedByUid,
  }) {
    final status = attended ? RegistrationStatus.attended : RegistrationStatus.missed;
    return _registrationsRef.doc(registrationId).update({
      'attended': attended,
      'status': status.value,
      'attendanceSource': 'manual',
      'attendanceCorrectedBy': correctedByUid,
      'attendanceCorrectedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> checkIn({required String sessionId, required String uid}) {
    return _registrationsRef.doc(SessionRegistration.idFor(sessionId: sessionId, uid: uid)).update({
      'checkedIn': true,
      'status': RegistrationStatus.checkInAvailable.value,
    });
  }

  // ---------------------------------------------------------------------
  // Pre-session check-in (3-question pulse: knowledge, confidence, goal).
  // Stored separately from the exit survey and keyed per session so
  // registering for a different session never overwrites an earlier
  // check-in's historical data.
  // ---------------------------------------------------------------------

  Future<SessionCheckin?> fetchCheckin({required String sessionId, required String uid}) async {
    final doc = await _checkinsRef.doc(SessionCheckin.idFor(sessionId: sessionId, uid: uid)).get();
    if (!doc.exists) return null;
    return SessionCheckin.fromFirestore(doc);
  }

  /// Submits the pre-session check-in questions, then flips the existing
  /// checkedIn/status flags exactly as [checkIn] does — one participant
  /// action covers both.
  Future<void> submitCheckin({
    required String sessionId,
    required String uid,
    required int knowledgeBefore,
    required int confidenceBefore,
    required String learningGoal,
  }) async {
    final checkinId = SessionCheckin.idFor(sessionId: sessionId, uid: uid);
    final checkin = SessionCheckin(
      id: checkinId,
      sessionId: sessionId,
      participantUid: uid,
      knowledgeBefore: knowledgeBefore,
      confidenceBefore: confidenceBefore,
      learningGoal: learningGoal,
      submittedAt: DateTime.now(),
    );
    await _checkinsRef.doc(checkinId).set(checkin.toCreateMap());
    await checkIn(sessionId: sessionId, uid: uid);
  }

  // ---------------------------------------------------------------------
  // Exit survey -> badge award -> impact metrics (spec section 8 lifecycle).
  // The admin never manually awards a badge or calculates outcomes: a
  // completed survey after an admin-recorded "attended" is the only
  // trigger, and completionMet already reflects the session's minimum
  // attendance requirement (set alongside `attended` in recordAttendance).
  // ---------------------------------------------------------------------

  Future<SessionSurvey?> fetchSurvey({required String sessionId, required String uid}) async {
    final doc = await _surveysRef.doc(SessionSurvey.idFor(sessionId: sessionId, uid: uid)).get();
    if (!doc.exists) return null;
    return SessionSurvey.fromFirestore(doc);
  }

  /// Submits the exit survey, marks the registration completed, and —
  /// only if the participant was recorded attended — auto-awards a
  /// session badge. No admin action is involved in any of this.
  Future<void> submitExitSurvey({
    required String sessionId,
    required String uid,
    required String sessionTitle,
    required String program,
    required int learningRating,
    required int confidenceAfter,
    required ApplicationLikelihood applicationLikelihood,
    required String mostValuableLearning,
    required FutureSupportInterest futureSupportInterest,
  }) async {
    final registration = await fetchRegistration(sessionId: sessionId, uid: uid);
    if (registration == null) return;

    // Exit-survey completion is only a valid self-write once the admin
    // has already recorded attended == true on this registration — the
    // security rule (isValidSelfSurveyCompletion) enforces the same
    // precondition server-side, so this early return keeps the client
    // from attempting a write the rule would reject anyway.
    if (!registration.attended) return;

    final surveyId = SessionSurvey.idFor(sessionId: sessionId, uid: uid);
    final survey = SessionSurvey(
      id: surveyId,
      sessionId: sessionId,
      participantUid: uid,
      learningRating: learningRating,
      confidenceAfter: confidenceAfter,
      applicationLikelihood: applicationLikelihood,
      mostValuableLearning: mostValuableLearning,
      futureSupportInterest: futureSupportInterest,
      submittedAt: DateTime.now(),
    );
    // Each step is skipped if already done, so a retry after a mid-flow
    // failure resumes instead of failing forever: surveys are immutable
    // once written, and the completion update is only allowed while
    // surveyCompleted is still false.
    if (!(await _surveysRef.doc(surveyId).get()).exists) {
      await _surveysRef.doc(surveyId).set(survey.toCreateMap());
    }

    if (!registration.surveyCompleted) {
      final registrationId = SessionRegistration.idFor(sessionId: sessionId, uid: uid);
      await _registrationsRef.doc(registrationId).update({
        'surveyCompleted': true,
        'completionMet': true,
        'status': RegistrationStatus.completed.value,
      });
    }

    final badgeId = SessionBadge.idFor(sessionId: sessionId, uid: uid);
    final existingBadge = await _badgesRef.doc(badgeId).get();
    if (!existingBadge.exists) {
      final badge = SessionBadge(
        id: badgeId,
        sessionId: sessionId,
        participantUid: uid,
        sessionTitle: sessionTitle,
        program: program,
        awardedAt: DateTime.now(),
      );
      await _badgesRef.doc(badgeId).set(badge.toCreateMap());
    }
  }

  Stream<List<SessionBadge>> watchBadgesForUser(String uid) {
    return _badgesRef.where('participantUid', isEqualTo: uid).snapshots().map(
          (s) => s.docs.map(SessionBadge.fromFirestore).toList()..sort((a, b) => b.awardedAt.compareTo(a.awardedAt)),
        );
  }

  /// Badges earned but not yet celebrated — drives the one-time "new
  /// badge!" popup. Marking celebrationSeen immediately after showing it
  /// ensures the same badge is never celebrated twice.
  Stream<List<SessionBadge>> watchUncelebratedBadges(String uid) {
    return _badgesRef.where('participantUid', isEqualTo: uid).where('celebrationSeen', isEqualTo: false).snapshots().map(
          (s) => s.docs.map(SessionBadge.fromFirestore).toList(),
        );
  }

  Future<void> markBadgeCelebrationSeen(String badgeId) {
    return _badgesRef.doc(badgeId).update({'celebrationSeen': true});
  }

  /// Impact metrics for a single session — computed on read from
  /// registrations, never manually tallied by an admin.
  Future<({int registered, int attended, int completed})> fetchSessionImpactMetrics(String sessionId) async {
    final registrants = await fetchRegistrationsForSession(sessionId);
    final active = registrants.where((r) => r.status != RegistrationStatus.cancelled);
    return (
      registered: active.length,
      attended: active.where((r) => r.attended).length,
      completed: active.where((r) => r.completionMet).length,
    );
  }

  Future<List<SessionSurvey>> fetchSurveysForSession(String sessionId) async {
    final snapshot = await _surveysRef.where('sessionId', isEqualTo: sessionId).get();
    return snapshot.docs.map(SessionSurvey.fromFirestore).toList();
  }

  Future<List<SessionCheckin>> fetchCheckinsForSession(String sessionId) async {
    final snapshot = await _checkinsRef.where('sessionId', isEqualTo: sessionId).get();
    return snapshot.docs.map(SessionCheckin.fromFirestore).toList();
  }

  /// A session's full impact bundle — every number here is computed
  /// directly from Firestore records, never hard-coded or invented.
  /// Confidence CHANGE is only reported when a matching pre-session
  /// check-in exists for the same participant; where it doesn't, that
  /// participant's post-survey confidence is excluded from the "change"
  /// figure (though still counted in aggregate post-confidence) — see
  /// [SessionImpactBundle] for exactly which numbers are measured change
  /// vs. self-reported aggregate.
  Future<SessionImpactBundle> fetchSessionImpactBundle(BloomSession session) async {
    final registrants = (await fetchRegistrationsForSession(session.id)).where((r) => r.status != RegistrationStatus.cancelled).toList();
    final surveys = await fetchSurveysForSession(session.id);
    final checkins = await fetchCheckinsForSession(session.id);
    final checkinByUid = {for (final c in checkins) c.participantUid: c};

    final attended = registrants.where((r) => r.attended).length;
    final completed = registrants.where((r) => r.completionMet).length;

    final comparablePairs = <({int before, int after})>[];
    for (final survey in surveys) {
      final checkin = checkinByUid[survey.participantUid];
      if (checkin != null) {
        comparablePairs.add((before: checkin.confidenceBefore, after: survey.confidenceAfter));
      }
    }

    double? avgConfidenceBefore;
    double? avgConfidenceAfter;
    double? avgConfidenceChange;
    if (comparablePairs.isNotEmpty) {
      avgConfidenceBefore = comparablePairs.map((p) => p.before).reduce((a, b) => a + b) / comparablePairs.length;
      avgConfidenceAfter = comparablePairs.map((p) => p.after).reduce((a, b) => a + b) / comparablePairs.length;
      avgConfidenceChange = avgConfidenceAfter - avgConfidenceBefore;
    }

    final learnedYesCount = surveys.where((s) => s.applicationLikelihood != ApplicationLikelihood.notYet).length;
    final appliedYesCount = surveys.where((s) => s.applicationLikelihood == ApplicationLikelihood.yes).length;

    return SessionImpactBundle(
      registeredCount: registrants.length,
      attendedCount: attended,
      completedCount: completed,
      surveyResponseCount: surveys.length,
      checkinResponseCount: checkins.length,
      comparableConfidencePairCount: comparablePairs.length,
      avgConfidenceBefore: avgConfidenceBefore,
      avgConfidenceAfter: avgConfidenceAfter,
      avgConfidenceChange: avgConfidenceChange,
      reportedLearningPercent: surveys.isEmpty ? null : (surveys.where((s) => s.learningRating >= 4).length / surveys.length) * 100,
      reportedApplicationPercent: surveys.isEmpty ? null : (appliedYesCount / surveys.length) * 100,
      reportedApplicationOrMaybePercent: surveys.isEmpty ? null : (learnedYesCount / surveys.length) * 100,
    );
  }
}

/// One session's computed impact numbers. Every field is either a direct
/// Firestore count, or — for confidence change specifically — an average
/// computed ONLY over participants who have both a pre-session check-in
/// and a post-session survey (the only mathematically comparable pair).
/// A null confidence field means there is not enough comparable data yet,
/// and the UI must show that as "not enough data," never as 0%.
class SessionImpactBundle {
  SessionImpactBundle({
    required this.registeredCount,
    required this.attendedCount,
    required this.completedCount,
    required this.surveyResponseCount,
    required this.checkinResponseCount,
    required this.comparableConfidencePairCount,
    required this.avgConfidenceBefore,
    required this.avgConfidenceAfter,
    required this.avgConfidenceChange,
    required this.reportedLearningPercent,
    required this.reportedApplicationPercent,
    required this.reportedApplicationOrMaybePercent,
  });

  final int registeredCount;
  final int attendedCount;
  final int completedCount;
  final int surveyResponseCount;
  final int checkinResponseCount;

  /// How many participants have BOTH a check-in and a survey — the
  /// denominator for the confidence-change figures below.
  final int comparableConfidencePairCount;

  final double? avgConfidenceBefore;
  final double? avgConfidenceAfter;

  /// Measured change (after - before), averaged only over comparable
  /// pairs. Null when comparableConfidencePairCount == 0.
  final double? avgConfidenceChange;

  /// Self-reported: % of survey respondents who rated learning 4-5/5.
  final double? reportedLearningPercent;

  /// Self-reported: % of survey respondents who said "Yes" to application.
  final double? reportedApplicationPercent;

  /// Self-reported: % who said "Yes" or "Maybe" to application.
  final double? reportedApplicationOrMaybePercent;

  double get attendanceRate => registeredCount == 0 ? 0 : (attendedCount / registeredCount) * 100;
}

/// Result of a `syncSessionAttendance` Cloud Function call — reflects
/// exactly what the backend actually did, never a client-side guess.
class ZoomSyncResult {
  ZoomSyncResult({
    required this.registeredCount,
    required this.matchedCount,
    required this.qualifiedCount,
    required this.unmatchedRegistrantCount,
    required this.unmatchedZoomParticipants,
  });

  final int registeredCount;
  final int matchedCount;
  final int qualifiedCount;
  final int unmatchedRegistrantCount;
  final List<Map<String, dynamic>> unmatchedZoomParticipants;

  factory ZoomSyncResult.fromCallableResponse(Map<String, dynamic> data) {
    return ZoomSyncResult(
      registeredCount: (data['registeredCount'] as num?)?.toInt() ?? 0,
      matchedCount: (data['matchedCount'] as num?)?.toInt() ?? 0,
      qualifiedCount: (data['qualifiedCount'] as num?)?.toInt() ?? 0,
      unmatchedRegistrantCount: (data['unmatchedRegistrantCount'] as num?)?.toInt() ?? 0,
      unmatchedZoomParticipants: (data['unmatchedZoomParticipants'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
    );
  }
}
