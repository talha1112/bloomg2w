import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.registrationConfirmed:
        return Icons.check_circle_outline;
      case AppNotificationType.sessionReminder:
        return Icons.access_time;
      case AppNotificationType.sessionStarting:
        return Icons.videocam_outlined;
      case AppNotificationType.sessionUpdated:
        return Icons.edit_calendar_outlined;
      case AppNotificationType.sessionCancelled:
        return Icons.event_busy_outlined;
      case AppNotificationType.general:
        return Icons.campaign_outlined;
    }
  }

  Color _colorFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.registrationConfirmed:
        return AppColors.sage;
      case AppNotificationType.sessionReminder:
        return AppColors.rose;
      case AppNotificationType.sessionStarting:
        return AppColors.cornflower;
      case AppNotificationType.sessionUpdated:
        return AppColors.amber;
      case AppNotificationType.sessionCancelled:
        return AppColors.coral;
      case AppNotificationType.general:
        return AppColors.violet;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return PageScaffold(
      title: 'Notifications',
      actions: [
        if (uid != null)
          TextButton(
            onPressed: () => NotificationService.instance.markAllReadForUser(uid),
            child: const Text('Mark all read', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
      ],
      children: [
        const SectionHeader('Recent'),
        if (uid == null)
          const BloomCard(child: Text('Log in to see your notifications.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
        else
          StreamBuilder<List<AppNotification>>(
            stream: NotificationService.instance.watchForUser(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: AppColors.royal)));
              }
              final notifications = snapshot.data ?? [];
              if (notifications.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No notifications yet.', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                );
              }
              return Column(
                children: notifications.map((n) {
                  final color = _colorFor(n.type);
                  return BloomCard(
                    onTap: n.read ? null : () => NotificationService.instance.markRead(n.id),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: Icon(_iconFor(n.type), color: color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                                  if (!n.read) Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.royal, shape: BoxShape.circle)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(n.body, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.3)),
                              const SizedBox(height: 4),
                              Text(_timeAgo(n.createdAt), style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}
