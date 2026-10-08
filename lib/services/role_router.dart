import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/home_screen.dart';
import '../screens/parent_portal_screen.dart';
import '../screens/partner/partner_dashboard_screen.dart';
import '../screens/speaker/speaker_dashboard_screen.dart';
import '../screens/waiting_for_guardian_screen.dart';
import 'auth_service.dart';
import 'user_service.dart';

/// Routes a signed-in user to the correct home screen based on their
/// Firestore role, replacing the entire navigation stack.
///
/// Centralized here so Login and Splash (session restore) always apply
/// the exact same role check instead of duplicating — and risking
/// diverging — the logic.
class RoleRouter {
  RoleRouter._();

  /// [uidOverride] should be passed by callers that already have a fresh
  /// uid on hand (e.g. straight from a UserCredential right after sign-in).
  /// [AuthService.currentUser] can lag behind by a frame right after
  /// signIn() resolves, so relying on it alone at that moment can read null.
  static Future<void> routeSignedInUser(BuildContext context, {String? uidOverride}) async {
    final uid = uidOverride ?? AuthService.instance.currentUser?.uid;

    UserProfile? profile;
    try {
      profile = uid == null ? null : await UserService.instance.fetchUserProfile(uid);
    } catch (_) {
      // Fall through as a non-admin if the profile can't be fetched.
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => _screenForRole(profile)),
      (route) => false,
    );
  }

  static Widget _screenForRole(UserProfile? profile) {
    switch (profile?.role) {
      case AppRole.admin:
        return const AdminDashboardScreen();
      case AppRole.partner:
        return const PartnerDashboardScreen();
      case AppRole.guestSpeaker:
        return const SpeakerDashboardScreen();
      case AppRole.guardian:
        // A guardian's "home" is the Parent Portal itself — they don't
        // participate in sessions themselves.
        return const ParentPortalScreen();
      case AppRole.minor:
        // Hard-blocked until at least one guardian has linked to her —
        // see WaitingForGuardianScreen's doc comment. profile is non-null
        // here since role came from it.
        if (profile!.guardianUids.isEmpty) {
          return WaitingForGuardianScreen(uid: profile.uid, initialInviteCode: profile.inviteCode);
        }
        return const HomeScreen();
      case AppRole.member:
      case null:
        return const HomeScreen();
    }
  }
}
