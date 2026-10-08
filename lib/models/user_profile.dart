import 'package:cloud_firestore/cloud_firestore.dart';

enum AppRole { member, admin, partner, guestSpeaker, minor, guardian }

extension AppRoleX on AppRole {
  String get value => name;

  static AppRole fromValue(String? value) {
    final normalized = value?.trim();
    return AppRole.values.firstWhere(
      (r) => r.value == normalized,
      orElse: () => AppRole.member,
    );
  }

  String get label {
    switch (this) {
      case AppRole.member:
        return 'Member';
      case AppRole.admin:
        return 'Admin';
      case AppRole.partner:
        return 'Community Partner';
      case AppRole.guestSpeaker:
        return 'Guest Speaker';
      case AppRole.minor:
        return 'Girl (Minor)';
      case AppRole.guardian:
        return 'Parent/Guardian';
    }
  }
}

/// The member "type" chosen during registration (girl, woman, parent, etc.)
/// This is distinct from [AppRole], which controls admin access.
class UserProfile {
  UserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.memberType,
    required this.createdAt,
    this.photoUrl,
    this.dateOfBirth,
    this.guardianUids = const [],
    this.linkedChildUids = const [],
    this.inviteCode,
  });

  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final AppRole role;
  final String memberType;
  final DateTime createdAt;
  final String? photoUrl;

  /// Only ever set for self-created 'minor'/'member'/'guardian' docs going
  /// forward; absent (null) on legacy docs created before this field
  /// existed — never assume non-null.
  final DateTime? dateOfBirth;

  /// A 'minor' doc's linked guardian uids. Only ever written by the
  /// redeemInviteCode Cloud Function (Admin SDK) — never by any client
  /// write, including this user's own. Empty on every doc that isn't a
  /// linked minor.
  final List<String> guardianUids;

  /// A 'guardian' doc's linked minor (child) uids. Same write restriction
  /// as [guardianUids].
  final List<String> linkedChildUids;

  /// Set only on a 'minor' doc, by the invite-code-generation Cloud
  /// Function at account-creation time. Null for every other role.
  final String? inviteCode;

  String get fullName => '$firstName $lastName'.trim();

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: doc.id,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: AppRoleX.fromValue(data['role'] as String?),
      memberType: data['memberType'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      dateOfBirth: data['dateOfBirth'] is Timestamp
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      guardianUids: (data['guardianUids'] as List?)?.whereType<String>().toList() ?? const [],
      linkedChildUids: (data['linkedChildUids'] as List?)?.whereType<String>().toList() ?? const [],
      inviteCode: data['inviteCode'] as String?,
    );
  }

  /// [selfRole] is the role a user may assign themselves at sign-up —
  /// 'member', 'partner', 'guestSpeaker', 'minor', or 'guardian'. Never
  /// 'admin'; that must be granted out-of-band (Firebase Console / an
  /// existing admin).
  ///
  /// [dateOfBirth] is required by the security rules for 'minor'/'member'/
  /// 'guardian' self-signups (age is enforced server-side against the
  /// chosen role) — pass it whenever [selfRole] is one of those.
  /// guardianUids/linkedChildUids/inviteCode are deliberately never
  /// included here: they can only ever be empty/absent at self-create time,
  /// matching what the security rules require.
  Map<String, dynamic> toCreateMap({AppRole selfRole = AppRole.member, DateTime? dateOfBirth}) {
    final role = selfRole == AppRole.admin ? AppRole.member : selfRole;
    final map = {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': role.value,
      'memberType': memberType,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (dateOfBirth != null) {
      map['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
    }
    return map;
  }
}
