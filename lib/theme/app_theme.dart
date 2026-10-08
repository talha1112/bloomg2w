import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const royalDeep = Color(0xFF101C52);
  static const royal = Color(0xFF1A2E7A);
  static const royalLight = Color(0xFF2A3F9E);
  static const gold = Color(0xFFFFFFFF);
  static const goldDeep = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFAF7F0);
  static const paper = Color(0xFFF4F2EA);
  static const ink = Color(0xFF14162A);
  static const inkSoft = Color(0xFF5B5E7E);

  static const sage = Color(0xFF2FA35C);
  static const rose = Color(0xFFC94F7A);
  static const coral = Color(0xFFD1573F);
  static const teal = Color(0xFF1F8FA0);
  static const amber = Color(0xFFE8942C);
  static const violet = Color(0xFF5C3F9E);
  static const cornflower = Color(0xFF2D6FDB);

  /// Real gold accent, reserved for the Admin side (Navy + Gold + White).
  /// Distinct from [gold]/[goldDeep] above, which were changed to white
  /// for the member-facing app per prior direction.
  static const adminGold = Color(0xFFD4AF37);
  static const adminGoldDeep = Color(0xFFB8912C);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.royal,
        primary: AppColors.royal,
        secondary: AppColors.gold,
        surface: AppColors.cream,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.paper,
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
    );
  }
}
