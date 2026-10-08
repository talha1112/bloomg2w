import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class BloomProgressBar extends StatelessWidget {
  const BloomProgressBar({super.key, required this.value, this.color = AppColors.royal});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: color.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}
