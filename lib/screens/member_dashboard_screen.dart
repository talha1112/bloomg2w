import 'package:flutter/material.dart';

import '../models/bloom_session.dart';
import '../models/session_badge.dart';
import '../models/session_registration.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/bloom_network_image.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';
import 'sessions/session_detail_screen.dart';

/// Real, Firestore-backed member overview. Every value shown here comes
/// from an actual query — no fabricated points, hours, or events. Where a
/// metric isn't implemented (e.g. reward points), it is left out entirely
/// rather than faked.
class MemberDashboardScreen extends StatelessWidget {
  const MemberDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return PageScaffold(
      title: 'Member Dashboard',
      children: [
        if (uid == null)
          const BloomCard(child: Text('Log in to see your dashboard.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
        else
          StreamBuilder<UserProfile?>(
            stream: UserService.instance.watchUserProfile(uid),
            builder: (context, profileSnapshot) {
              final profile = profileSnapshot.data;
              return Column(
                children: [
                  BloomCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white,
                          backgroundImage: profile?.photoUrl != null ? bloomNetworkImage(profile!.photoUrl!) : null,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.royal, width: 1.5)),
                            child: profile?.photoUrl == null ? const Icon(Icons.person, color: AppColors.royalDeep, size: 26) : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile != null && profile.fullName.isNotEmpty ? 'Welcome back, ${profile.firstName} 👋' : 'Welcome back 👋',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.royalDeep),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile?.memberType.isNotEmpty == true ? '${_memberTypeLabel(profile!.memberType)} · Bloom Circle' : 'Bloom Circle',
                                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<List<SessionRegistration>>(
                    stream: SessionService.instance.watchRegistrationsForUser(uid),
                    builder: (context, regSnapshot) {
                      final registrations = regSnapshot.data ?? [];
                      final attendedCount = registrations.where((r) => r.attended).length;
                      final completedCount = registrations.where((r) => r.completionMet).length;

                      return StreamBuilder<List<SessionBadge>>(
                        stream: SessionService.instance.watchBadgesForUser(uid),
                        builder: (context, badgeSnapshot) {
                          final badges = badgeSnapshot.data ?? [];
                          return Row(
                            children: [
                              Expanded(child: _statTile('${badges.length}', 'Badges Earned', AppColors.violet)),
                              const SizedBox(width: 10),
                              Expanded(child: _statTile('$attendedCount', 'Sessions Attended', AppColors.sage)),
                              const SizedBox(width: 10),
                              Expanded(child: _statTile('$completedCount', 'Completed', AppColors.royal)),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SectionHeader('Upcoming Sessions'),
                  StreamBuilder<List<BloomSession>>(
                    stream: SessionService.instance.watchUpcomingPublishedSessions(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(color: AppColors.royal)));
                      }
                      final now = DateTime.now();
                      final startOfToday = DateTime(now.year, now.month, now.day);
                      final sessions = (snapshot.data ?? []).where((s) => !DateTime(s.date.year, s.date.month, s.date.day).isBefore(startOfToday)).toList()
                        ..sort((a, b) => a.date.compareTo(b.date));
                      if (sessions.isEmpty) {
                        return const BloomCard(child: Text('No upcoming sessions scheduled yet — check back soon!', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
                      }
                      final next = sessions.first;
                      return BloomCard(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(session: next))),
                        child: Row(
                          children: [
                            const Icon(Icons.event_available_outlined, color: AppColors.teal),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(next.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text('${_formatDate(next.date)} · ${next.startTime}', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.inkSoft),
                          ],
                        ),
                      );
                    },
                  ),
                  const SectionHeader('My Badges'),
                  StreamBuilder<List<SessionBadge>>(
                    stream: SessionService.instance.watchBadgesForUser(uid),
                    builder: (context, snapshot) {
                      final badges = snapshot.data ?? [];
                      if (badges.isEmpty) {
                        return const BloomCard(child: Text('Attend a session and complete its exit survey to earn your first badge!', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
                      }
                      return SizedBox(
                        height: 96,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: badges.map((b) => _badge(b)).toList(),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  String _memberTypeLabel(String memberType) {
    switch (memberType.toLowerCase()) {
      case 'girl':
        return 'Girls Member';
      case 'woman':
        return 'Women\'s Member';
      case 'parent':
        return 'Parent/Guardian';
      default:
        return 'Member';
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  Widget _statTile(String value, String label, Color color) {
    return BloomCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _badge(SessionBadge badge) {
    return Container(
      width: 84,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withValues(alpha: 0.05))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, color: AppColors.amber, size: 24),
          const SizedBox(height: 6),
          Text(badge.sessionTitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.royalDeep, height: 1.2)),
        ],
      ),
    );
  }
}
