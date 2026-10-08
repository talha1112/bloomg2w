import 'package:flutter/material.dart';

import '../models/bloom_session.dart';
import '../screens/events_zoom_screen.dart';
import '../screens/sessions/session_detail_screen.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

/// Shows the next real, published, upcoming Bloom session on the Home
/// screen — never fabricated data. If none exists, shows an honest empty
/// state instead of inventing an event.
class UpcomingEventCard extends StatelessWidget {
  const UpcomingEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BloomSession>>(
      stream: SessionService.instance.watchUpcomingPublishedSessions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _shell(
            context,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(color: AppColors.royal)),
            ),
          );
        }

        // A session's `date` is a calendar day only (time of day lives in
        // the separate startTime string) — compare whole days so today's
        // session is still shown, matching Events & Zoom's own logic.
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final sessions = (snapshot.data ?? []).where((s) => !DateTime(s.date.year, s.date.month, s.date.day).isBefore(startOfToday)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        if (sessions.isEmpty) {
          return _shell(
            context,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No upcoming sessions scheduled yet — check back soon!', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
            ),
          );
        }

        final next = sessions.first;
        return _shell(
          context,
          onTapDetails: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: next))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.royal, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(_monthAbbrev(next.date.month), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.royalDeep)),
                    Text('${next.date.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.royalDeep)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 64,
                  height: 64,
                  color: AppColors.royalDeep,
                  child: const Icon(Icons.videocam_outlined, color: AppColors.gold, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(next.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.royalDeep)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.cornflower.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Zoom Meeting', style: TextStyle(fontSize: 10.5, color: AppColors.cornflower, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    if (next.startTime.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: AppColors.inkSoft),
                          const SizedBox(width: 4),
                          Text(next.startTime, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                        ],
                      ),
                    if (next.topic.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(next.topic, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _monthAbbrev(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }

  Widget _shell(BuildContext context, {required Widget child, VoidCallback? onTapDetails}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Upcoming Events', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.royalDeep)),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EventsZoomScreen())),
                child: const Row(
                  children: [
                    Text('View All', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w600, fontSize: 13)),
                    Icon(Icons.chevron_right, size: 16, color: AppColors.royal),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
