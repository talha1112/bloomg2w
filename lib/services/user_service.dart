import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/user_profile.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'bloomg2w-db',
  );

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1');

  CollectionReference get _usersRef => _db.collection('users');

  /// Creates the Firestore profile doc for a newly signed-up user.
  /// [role] may only be 'member', 'partner', or 'guardian' here — never
  /// 'admin' and never 'minor' (a Girl's doc is created atomically together
  /// with her guardian invite code by [completeMinorSignup] instead, since
  /// that requires a server-side transaction a plain client write can't
  /// safely do). [dateOfBirth] is required by the security rules whenever
  /// [role] is 'member' or 'guardian' — see [UserProfile.toCreateMap].
  Future<void> createUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    required String memberType,
    AppRole role = AppRole.member,
    DateTime? dateOfBirth,
    String? photoUrl,
  }) {
    final profile = UserProfile(
      uid: uid,
      firstName: firstName,
      lastName: lastName,
      email: email,
      role: role,
      memberType: memberType,
      createdAt: DateTime.now(),
      photoUrl: photoUrl,
      dateOfBirth: dateOfBirth,
    );
    return _usersRef.doc(uid).set(profile.toCreateMap(selfRole: role, dateOfBirth: dateOfBirth));
  }

  /// Creates a Girl's (minor's) Firestore profile doc AND generates her
  /// guardian invite code, atomically, via the `completeMinorSignup` Cloud
  /// Function — this can't be done as a plain client write because
  /// reserving a globally-unique invite code requires a server-side
  /// transaction. Returns the freshly-generated invite code so it can be
  /// shown to her immediately on the waiting screen.
  Future<String> completeMinorSignup({
    required String firstName,
    required String lastName,
    required String email,
    required String memberType,
    required DateTime dateOfBirth,
  }) async {
    final callable = _functions.httpsCallable('completeMinorSignup');
    final result = await callable.call<Map<String, dynamic>>({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'memberType': memberType,
      'dateOfBirth': dateOfBirth.millisecondsSinceEpoch,
    });
    return result.data['inviteCode'] as String;
  }

  /// Links the signed-in Guardian to a Girl's account via her invite code.
  /// Reusable/non-expiring — redeeming the same code twice is a harmless
  /// no-op, not an error. Only a caller whose own role is already
  /// 'guardian' may call this; see `redeemInviteCode` in
  /// functions/src/guardianLinking.ts.
  Future<void> redeemInviteCode(String code) async {
    final callable = _functions.httpsCallable('redeemInviteCode');
    await callable.call<Map<String, dynamic>>({'code': code});
  }

  Future<UserProfile?> fetchUserProfile(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  Stream<UserProfile?> watchUserProfile(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    });
  }

  Stream<List<UserProfile>> watchAllUsers() {
    return _usersRef.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(UserProfile.fromFirestore).toList(),
        );
  }

  /// Self-service role change — per the security rules, the only
  /// transition a user may make on their own doc is member -> guestSpeaker
  /// (applying to the Speaker Bureau). Any other transition is rejected
  /// by Firestore itself, regardless of what's passed here.
  Future<void> updateRoleIfSelf({required String uid, required AppRole role}) {
    return _usersRef.doc(uid).update({'role': role.value});
  }

  /// Updates the signed-in user's own profile photo URL in Firestore —
  /// this is the field every other screen (Admin's user list/detail, etc.)
  /// actually reads, so uploads must be persisted here, not just to
  /// Firebase Auth's separate photoURL.
  Future<void> updatePhotoUrl({required String uid, required String photoUrl}) {
    return _usersRef.doc(uid).update({'photoUrl': photoUrl});
  }

  /// Lets a signed-in user record their own date of birth after the fact —
  /// used by the legacy-account reconciliation prompt for users who
  /// registered before dateOfBirth was collected at sign-up. Permitted by
  /// the security rules' self-update path (dateOfBirth isn't in the
  /// immutable field set) and does NOT change role, so an existing
  /// unrestricted 'member' account stays exactly as unrestricted as
  /// before — this only records the birthday for future reference.
  Future<void> updateDateOfBirth({required String uid, required DateTime dateOfBirth}) {
    return _usersRef.doc(uid).update({'dateOfBirth': Timestamp.fromDate(dateOfBirth)});
  }

  /// Permanently deletes the SIGNED-IN user's own account — their Firestore
  /// profile and every doc they own, their Storage photo, any guardian/
  /// minor link they're part of, and their Firebase Auth account itself.
  /// Routed through the `deleteOwnAccount` Cloud Function (Admin SDK) since
  /// deleting a Firebase Auth account client-side requires a recent
  /// re-authentication this app has no UI for — the server-side call has
  /// no such requirement. See functions/src/accountDeletion.ts for exactly
  /// what is deleted vs. anonymized vs. left alone.
  ///
  /// The caller's Firebase Auth session is already invalid server-side by
  /// the time this returns; the caller is responsible for signing out
  /// locally and navigating away (the client SDK still has a cached user
  /// object until that happens).
  Future<void> deleteOwnAccount() async {
    final callable = _functions.httpsCallable('deleteOwnAccount');
    await callable.call<Map<String, dynamic>>();
  }
}
