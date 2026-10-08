import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Shown to a signed-in Girl (role 'minor') who has zero linked guardians
/// yet. She cannot use any app feature until a parent/guardian links to
/// her account via the invite code shown here — reached as the single
/// routing outcome for AppRole.minor + no guardianUids, from both
/// RoleRouter (Login / session-restore) and the end of the signup wizard
/// (CongratulationsScreen), so there is exactly one place this gate lives.
///
/// Live-updates via a Firestore stream on her own profile doc: the instant
/// a guardian redeems her code (guardianUids becomes non-empty), this
/// screen auto-navigates to HomeScreen with no restart or manual refresh
/// needed, matching the real-time-first pattern used throughout this app.
class WaitingForGuardianScreen extends StatelessWidget {
  const WaitingForGuardianScreen({super.key, required this.uid, required this.initialInviteCode});

  final String uid;

  /// The invite code as known at routing time (from RegistrationData right
  /// after signup, or from the profile just fetched by RoleRouter) — shown
  /// immediately without waiting for the first stream event, then kept in
  /// sync by the StreamBuilder below in case it's ever regenerated.
  final String? initialInviteCode;

  Future<void> _signOut(BuildContext context) async {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.royalDeep,
      body: SafeArea(
        child: StreamBuilder<UserProfile?>(
          stream: UserService.instance.watchUserProfile(uid),
          initialData: null,
          builder: (context, snapshot) {
            final profile = snapshot.data;

            // The instant a guardian links, move on to the real app —
            // scheduled after the current frame so it's safe to navigate
            // from inside a StreamBuilder's builder callback.
            if (profile != null && profile.guardianUids.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              });
            }

            final code = profile?.inviteCode ?? initialInviteCode;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    child: const Center(child: Text('🌸', style: TextStyle(fontSize: 34))),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Almost there!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ask your parent or guardian to enter this code in their Bloom G2W app to finish setting up your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85), height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  if (code == null)
                    const CircularProgressIndicator(color: AppColors.gold)
                  else
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gold, width: 2),
                        ),
                        child: Column(
                          children: [
                            Text(
                              code,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: 6, color: AppColors.royalDeep),
                            ),
                            const SizedBox(height: 6),
                            const Text('Tap to copy', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'This screen will update automatically once you\'re linked.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.65)),
                  ),
                  const Spacer(flex: 4),
                  TextButton(
                    onPressed: () => _signOut(context),
                    child: Text('Sign Out', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
