import 'package:cloud_firestore/cloud_firestore.dart';

/// Per spec section 6 — participant-visible session status. Attendance
/// must be admin-recorded (from Zoom's attendance report), never
/// self-reported by the participant.
enum RegistrationStatus {
  registered,
  checkInAvailable,
  joinAvailable,
  attended,
  completed,
  cancelled,
  missed,
}

extension RegistrationStatusX on RegistrationStatus {
  String get value => name;

  static RegistrationStatus fromValue(String? value) {
    return RegistrationStatus.values.firstWhere(
      (s) => s.value == value?.trim(),
      orElse: () => RegistrationStatus.registered,
    );
  }

  String get label {
    switch (this) {
      case RegistrationStatus.registered:
        return 'Registered';
      case RegistrationStatus.checkInAvailable:
        return 'Check-In Available';
      case RegistrationStatus.joinAvailable:
        return 'Join Session';
      case RegistrationStatus.attended:
        return 'Attended';
      case RegistrationStatus.completed:
        return 'Completed';
      case RegistrationStatus.cancelled:
        return 'Cancelled';
      case RegistrationStatus.missed:
        return 'Missed';
    }
  }
}

/// One registration record per participant/session (spec section 7).
/// A participant may only have one active registration per session —
/// enforced by using `${sessionId}_${uid}` as the document ID.
class SessionRegistration {
  SessionRegistration({
    required this.id,
    required this.sessionId,
    required this.participantUid,
    required this.participantName,
    required this.registeredAt,
    required this.status,
    this.notified = false,
    this.checkedIn = false,
    this.attended = false,
    this.surveyCompleted = false,
    this.completionMet = false,
    this.attendanceSource,
    this.attendancePercent,
    this.attendanceMatchMethod,
  });

  final String id;
  final String sessionId;
  final String participantUid;
  final String participantName;
  final DateTime registeredAt;
  final RegistrationStatus status;
  final bool notified;
  final bool checkedIn;
  final bool attended;
  final bool surveyCompleted;
  final bool completionMet;

  /// 'zoom_import' | 'manual' | null (never recorded yet).
  final String? attendanceSource;
  final double? attendancePercent;

  /// 'email' | 'name' | 'unmatched' | null — only set by a Zoom import.
  final String? attendanceMatchMethod;

  static String idFor({required String sessionId, required String uid}) => '${sessionId}_$uid';

  factory SessionRegistration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SessionRegistration(
      id: doc.id,
      sessionId: data['sessionId'] as String? ?? '',
      participantUid: data['participantUid'] as String? ?? '',
      participantName: data['participantName'] as String? ?? '',
      registeredAt: data['registeredAt'] is Timestamp ? (data['registeredAt'] as Timestamp).toDate() : DateTime.now(),
      status: RegistrationStatusX.fromValue(data['status'] as String?),
      notified: data['notified'] as bool? ?? false,
      checkedIn: data['checkedIn'] as bool? ?? false,
      attended: data['attended'] as bool? ?? false,
      surveyCompleted: data['surveyCompleted'] as bool? ?? false,
      completionMet: data['completionMet'] as bool? ?? false,
      attendanceSource: data['attendanceSource'] as String?,
      attendancePercent: (data['attendancePercent'] as num?)?.toDouble(),
      attendanceMatchMethod: data['attendanceMatchMethod'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'sessionId': sessionId,
      'participantUid': participantUid,
      'participantName': participantName,
      'registeredAt': FieldValue.serverTimestamp(),
      'status': RegistrationStatus.registered.value,
      'notified': false,
      'checkedIn': false,
      'attended': false,
      'surveyCompleted': false,
      'completionMet': false,
    };
  }
}
