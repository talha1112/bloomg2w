import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';

/// Consistent color + icon for each [AppRole], used anywhere a user's role
/// needs to be visually distinguished (All Users list, user detail, etc.).
class RoleStyle {
  const RoleStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  factory RoleStyle.forRole(AppRole role) {
    switch (role) {
      case AppRole.admin:
        return const RoleStyle(color: AppColors.adminGoldDeep, icon: Icons.verified_user_outlined);
      case AppRole.partner:
        return const RoleStyle(color: AppColors.violet, icon: Icons.handshake_outlined);
      case AppRole.guestSpeaker:
        return const RoleStyle(color: AppColors.rose, icon: Icons.mic_outlined);
      case AppRole.member:
        return const RoleStyle(color: AppColors.teal, icon: Icons.person_outline);
      case AppRole.minor:
        return const RoleStyle(color: AppColors.coral, icon: Icons.emoji_people_outlined);
      case AppRole.guardian:
        return const RoleStyle(color: AppColors.sage, icon: Icons.family_restroom_outlined);
    }
  }
}
