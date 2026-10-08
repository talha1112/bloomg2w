import 'package:cloud_firestore/cloud_firestore.dart';

enum SessionStatus { draft, published, cancelled, completed }

extension SessionStatusX on SessionStatus {
  String get value => name;

  static SessionStatus fromValue(String? value) {
    return SessionStatus.values.firstWhere(
      (s) => s.value == value?.trim(),
      orElse: () => SessionStatus.draft,
    );
  }

  String get label {
    switch (this) {
      case SessionStatus.draft:
        return 'Draft';
      case SessionStatus.published:
        return 'Published';
      case SessionStatus.cancelled:
        return 'Cancelled';
      case SessionStatus.completed:
        return 'Completed';
    }
  }
}

/// A scheduled Bloom G2W Zoom session — created and managed by an admin.
/// [guestSpeakerUid], when set, points at an existing `speaker_profiles/{uid}`
/// doc rather than duplicating speaker data here (per program direction to
/// reuse the existing speaker collection).
class BloomSession {
  BloomSession({
    required this.id,
    required this.title,
    required this.topic,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.zoomMeetingLink,
    required this.zoomMeetingId,
    required this.zoomPasscode,
    required this.minAttendancePercent,
    required this.program,
    required this.ageGroup,
    required this.status,
    required this.createdAt,
    this.registrationDeadline,
    this.guestSpeakerUid,
    this.guestSpeakerNameSnapshot,
    this.cancellationReason,
  });

  final String id;
  final String title;
  final String topic;
  final String description;
  final DateTime date;
  final String startTime; // free-form "6:00 PM" — kept simple for admin entry
  final String endTime;
  final String zoomMeetingLink;
  final String zoomMeetingId;
  final String zoomPasscode;
  final int minAttendancePercent;
  final String program;
  final String ageGroup; // e.g. "Girls" or "Adult Women"
  final SessionStatus status;
  final DateTime createdAt;
  final DateTime? registrationDeadline;
  final String? guestSpeakerUid;
  final String? guestSpeakerNameSnapshot;
  final String? cancellationReason;

  factory BloomSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BloomSession(
      id: doc.id,
      title: data['title'] as String? ?? '',
      topic: data['topic'] as String? ?? '',
      description: data['description'] as String? ?? '',
      date: data['date'] is Timestamp ? calendarDateFromTimestamp(data['date'] as Timestamp) : DateTime.now(),
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      zoomMeetingLink: data['zoomMeetingLink'] as String? ?? '',
      zoomMeetingId: data['zoomMeetingId'] as String? ?? '',
      zoomPasscode: data['zoomPasscode'] as String? ?? '',
      minAttendancePercent: (data['minAttendancePercent'] as num?)?.toInt() ?? 80,
      program: data['program'] as String? ?? '',
      ageGroup: data['ageGroup'] as String? ?? '',
      status: SessionStatusX.fromValue(data['status'] as String?),
      registrationDeadline: data['registrationDeadline'] is Timestamp ? calendarDateFromTimestamp(data['registrationDeadline'] as Timestamp) : null,
      guestSpeakerUid: data['guestSpeakerUid'] as String?,
      guestSpeakerNameSnapshot: data['guestSpeakerNameSnapshot'] as String?,
      cancellationReason: data['cancellationReason'] as String?,
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'topic': topic,
      'description': description,
      'date': timestampFromCalendarDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'zoomMeetingLink': zoomMeetingLink,
      'zoomMeetingId': zoomMeetingId,
      'zoomPasscode': zoomPasscode,
      'minAttendancePercent': minAttendancePercent,
      'program': program,
      'ageGroup': ageGroup,
      'status': status.value,
      'registrationDeadline': registrationDeadline != null ? timestampFromCalendarDate(registrationDeadline!) : null,
      'guestSpeakerUid': guestSpeakerUid,
      'guestSpeakerNameSnapshot': guestSpeakerNameSnapshot,
      'cancellationReason': cancellationReason,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// Zoom's host-only start link, created by the createZoomMeetingForSession
/// Cloud Function on behalf of the assigned speaker's Zoom user account.
/// Lives at bloom_sessions/{id}/private/zoomHost — a subcollection only the
/// admin and the assigned speaker may read, since Firestore rules cannot
/// redact individual fields within a shared document. Regular participants
/// use BloomSession.zoomMeetingLink (the join URL) instead.
class SessionZoomHost {
  SessionZoomHost({required this.startUrl, required this.hostEmail});

  final String startUrl;
  final String hostEmail;

  factory SessionZoomHost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SessionZoomHost(
      startUrl: data['startUrl'] as String? ?? '',
      hostEmail: data['hostEmail'] as String? ?? '',
    );
  }
}

const kBloomSessionPrograms = [
  'Women Blooming Club',
  'Girls Mentorship Circle',
  'Leadership Lab',
  'Financial Literacy',
  'AI & Digital Skills',
  'Career Readiness',
  'Guest Speaker Series',
];

const kBloomSessionAgeGroups = ['Girls', 'Adult Women', 'All Ages'];

/// Session dates are calendar days, not instants — the time of day lives in
/// the separate startTime/endTime strings. They're stored as midnight UTC of
/// that day and read back by UTC components, so every viewer (and the
/// createZoomMeetingForSession Cloud Function, which reads UTC components)
/// sees the same day regardless of their own timezone. Storing local
/// midnight instead shifts the day for anyone in a different timezone than
/// the admin who created the session.
Timestamp timestampFromCalendarDate(DateTime date) => Timestamp.fromDate(DateTime.utc(date.year, date.month, date.day));

DateTime calendarDateFromTimestamp(Timestamp ts) {
  final utc = ts.toDate().toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}
