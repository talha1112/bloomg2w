import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/registration_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/wizard_scaffold.dart';
import 'congratulations_screen.dart';

class NotificationsOptInScreen extends StatelessWidget {
  const NotificationsOptInScreen({super.key});

  void _choose(BuildContext context, bool wantsReminders) {
    final data = context.read<RegistrationData>();
    data.update(() => data.wantsReminders = wantsReminders);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CongratulationsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return WizardScaffold(
      step: 5,
      totalSteps: 8,
      children: [
        const SizedBox(height: 20),
        const Text('Stay in the Loop', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.royalDeep)),
        const SizedBox(height: 6),
        const Text('Would you like reminders about events, courses & rewards?', style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.4)),
        const SizedBox(height: 28),
        _OptionCard(
          emoji: '🔔',
          title: 'Yes, notify me',
          subtitle: 'Get reminders for events, Zoom sessions & courses',
          color: AppColors.royal,
          onTap: () => _choose(context, true),
        ),
        const SizedBox(height: 14),
        _OptionCard(
          emoji: '🔕',
          title: 'Not Now',
          subtitle: 'You can turn this on later in Settings',
          color: AppColors.inkSoft,
          onTap: () => _choose(context, false),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.emoji, required this.title, required this.subtitle, required this.color, required this.onTap});

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.royalDeep)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
