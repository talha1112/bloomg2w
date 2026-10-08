import 'package:cloud_firestore/cloud_firestore.dart';

enum InterestType { attend, scheduleRequest, topicInterest, notifyWhenScheduled }

extension InterestTypeX on InterestType {
  String get value => name;

  static InterestType fromValue(String? value) {
    return InterestType.values.firstWhere(
      (t) => t.value == value?.trim(),
      orElse: () => InterestType.topicInterest,
    );
  }

  String get label {
    switch (this) {
      case InterestType.attend:
        return "I would like to attend this speaker's presentation.";
      case InterestType.scheduleRequest:
        return 'I would like Project Bloom to schedule this speaker.';
      case InterestType.topicInterest:
        return 'I am interested in this topic.';
      case InterestType.notifyWhenScheduled:
        return 'Please notify me when this speaker is scheduled.';
    }
  }
}

/// A single member's expressed interest in a Guest Speaker.
/// Never enables direct member-to-speaker contact — Project Bloom
/// administration coordinates all communication and scheduling.
class SpeakerInterest {
  SpeakerInterest({
    required this.id,
    required this.speakerUid,
    required this.speakerName,
    required this.memberUid,
    required this.interestType,
    required this.audienceGroup,
    required this.createdAt,
    this.notified = false,
  });

  final String id;
  final String speakerUid;
  final String speakerName;
  final String memberUid;
  final InterestType interestType;
  final String audienceGroup;
  final DateTime createdAt;
  final bool notified;

  factory SpeakerInterest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SpeakerInterest(
      id: doc.id,
      speakerUid: data['speakerUid'] as String? ?? '',
      speakerName: data['speakerName'] as String? ?? '',
      memberUid: data['memberUid'] as String? ?? '',
      interestType: InterestTypeX.fromValue(data['interestType'] as String?),
      audienceGroup: data['audienceGroup'] as String? ?? '',
      notified: data['notified'] as bool? ?? false,
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'speakerUid': speakerUid,
      'speakerName': speakerName,
      'memberUid': memberUid,
      'interestType': interestType.value,
      'audienceGroup': audienceGroup,
      'notified': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
