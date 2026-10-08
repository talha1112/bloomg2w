import 'package:flutter/material.dart';

import '../models/bloom_session.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/status_pill.dart';
import 'my_bloom_journey_screen.dart';
import 'sessions/session_detail_screen.dart';

class EventsZoomScreen extends StatelessWidget {
  const EventsZoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Events & Zoom Center',
      children: [
        BloomCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyBloomJourneyScreen())),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_outlined, color: AppColors.royalDeep, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('My Bloom Journey — badges, history & rewards', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkSoft),
            ],
          ),
        ),
        const SectionHeader('Upcoming Bloom Sessions'),
        StreamBuilder<List<BloomSession>>(
          stream: SessionService.instance.watchUpcomingPublishedSessions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: AppColors.royal)));
            }
            // `date` is a calendar day (time of day lives in the separate
            // startTime string), so compare whole days: a session stays
            // listed for its entire day, which is exactly when participants
            // need it to check in and join.
            final now = DateTime.now();
            final startOfToday = DateTime(now.year, now.month, now.day);
            final sessions = (snapshot.data ?? []).where((s) => !DateTime(s.date.year, s.date.month, s.date.day).isBefore(startOfToday)).toList();
            if (sessions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No upcoming sessions scheduled yet — check back soon!', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
              );
            }
            return Column(children: sessions.map((s) => _SessionCard(session: s)).toList());
          },
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final BloomSession session;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.royal, width: 1.5)),
            child: Column(
              children: [
                Text(_formatDate(session.date).split(' ').first.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.royalDeep)),
                Text(session.date.day.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.royalDeep)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const StatusPill('Zoom Meeting', color: AppColors.cornflower, icon: Icons.videocam_outlined),
                    if (session.guestSpeakerNameSnapshot != null) ...[
                      const SizedBox(width: 6),
                      StatusPill(session.guestSpeakerNameSnapshot!, color: AppColors.rose, icon: Icons.mic_outlined),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: AppColors.inkSoft),
                    const SizedBox(width: 4),
                    Text(session.startTime, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: session))),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.royal), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                    child: const Text('View Details', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
