import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'common/bloom_card.dart';

/// Shown only to a PRE-EXISTING member-role account registered before the
/// Girl/Woman/Parent role split existed (memberType 'girl' or 'parent',
/// but role is still the old 'member', and no dateOfBirth on file). These
/// users keep full, unrestricted access regardless of whether they act on
/// this — per the explicit no-bulk-migration decision, nobody already
/// signed up is ever retroactively locked out. This is an invitation to
/// opt into the new experience (guardian linking for parents, age-gated
/// account for girls), not a gate.
///
/// Dismissible for the current session only (plain in-memory flag, not
/// persisted) — it can resurface on next login until the user completes
/// the confirmation flow below.
class LegacyRoleReconciliationBanner extends StatefulWidget {
  const LegacyRoleReconciliationBanner({super.key});

  @override
  State<LegacyRoleReconciliationBanner> createState() => _LegacyRoleReconciliationBannerState();
}

class _LegacyRoleReconciliationBannerState extends State<LegacyRoleReconciliationBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (_dismissed || uid == null) return const SizedBox.shrink();

    return StreamBuilder<UserProfile?>(
      stream: UserService.instance.watchUserProfile(uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final needsReconciliation = profile != null &&
            profile.role == AppRole.member &&
            (profile.memberType == 'girl' || profile.memberType == 'parent') &&
            profile.dateOfBirth == null;

        if (!needsReconciliation) return const SizedBox.shrink();

        final isParent = profile.memberType == 'parent';
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BloomCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.royal, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Finish Setting Up Your Account', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep)),
                      const SizedBox(height: 4),
                      Text(
                        isParent
                            ? "Confirm your birthday and link your child's account to unlock the new Parent Portal."
                            : "Confirm your birthday to finish setting up your account.",
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _confirmBirthday(context, uid, isParent),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Confirm Now', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700, fontSize: 12.5)),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: () => setState(() => _dismissed = true),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Not Now', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700, fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmBirthday(BuildContext context, String uid, bool isParent) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 90),
      lastDate: now,
    );
    if (picked == null || !context.mounted) return;

    try {
      // A self-update may freely set dateOfBirth going forward (it's not
      // in the rules' immutable set) — this does NOT change role, so an
      // existing 'girl'/memberType 'member' stays exactly as unrestricted
      // as before; this only records her birthday for future reference.
      await UserService.instance.updateDateOfBirth(uid: uid, dateOfBirth: picked);
      if (context.mounted) setState(() => _dismissed = true);
    } catch (_) {
      // Best-effort — leave the banner up so she can retry.
    }
  }
}
