import 'package:flutter/material.dart';

import '../models/bloom_reward.dart';
import '../models/session_badge.dart';
import '../models/session_registration.dart';
import '../services/auth_service.dart';
import '../services/partner_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/progress_bar.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/status_pill.dart';
import 'rewards_screen.dart';

/// A participant's real, Firestore-backed progress overview — sessions
/// attended, badges earned, registration history, and reward status. Every
/// number here is a live query result, never invented.
class MyBloomJourneyScreen extends StatelessWidget {
  const MyBloomJourneyScreen({super.key});

  /// Simple, encouraging milestone ladder — badge counts to celebrate.
  /// Not a client-configurable admin setting (that's reward badgeCost,
  /// which IS admin-configured); this is purely a motivational display.
  static const List<int> _milestones = [1, 5, 10, 25];

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return PageScaffold(
      title: 'My Bloom Journey',
      children: [
        if (uid == null)
          const BloomCard(child: Text('Log in to see your journey.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
        else ...[
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
                  final unspent = badges.where((b) => !b.isSpent).length;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _statTile('$attendedCount', 'Sessions Attended', AppColors.sage)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('${badges.length}', 'Badges Earned', AppColors.amber)),
                          const SizedBox(width: 10),
                          Expanded(child: _statTile('$completedCount', 'Completed', AppColors.royal)),
                        ],
                      ),
                      const SectionHeader('Next Milestone'),
                      _milestoneCard(badges.length),
                      const SectionHeader('My Badges'),
                      if (badges.isEmpty)
                        const BloomCard(child: Text('Attend a session and complete its exit survey to earn your first badge!', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
                      else
                        SizedBox(
                          height: 96,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: badges.map((b) => _BadgeTile(badge: b)).toList(),
                          ),
                        ),
                      const SectionHeader('Rewards'),
                      BloomCard(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardsScreen())),
                        child: Row(
                          children: [
                            const Icon(Icons.card_giftcard, color: AppColors.royal, size: 22),
                            const SizedBox(width: 12),
                            Expanded(child: Text('$unspent unspent badge${unspent == 1 ? '' : 's'} — browse the Rewards Marketplace', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                            const Icon(Icons.chevron_right, color: AppColors.inkSoft),
                          ],
                        ),
                      ),
                      StreamBuilder<List<RewardRedemption>>(
                        stream: PartnerService.instance.watchRedemptionsForParticipant(uid),
                        builder: (context, redemptionSnapshot) {
                          final redemptions = redemptionSnapshot.data ?? [];
                          if (redemptions.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: BloomCard(
                              child: Column(
                                children: [
                                  for (var i = 0; i < redemptions.length; i++) ...[
                                    if (i > 0) const Divider(height: 20),
                                    _redemptionRow(redemptions[i]),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SectionHeader('Registration History'),
                      if (registrations.isEmpty)
                        const BloomCard(child: Text('No sessions yet — check out Events & Zoom to get started!', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
                      else
                        BloomCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < registrations.length; i++) ...[
                                if (i > 0) const Divider(height: 20),
                                _historyRow(registrations[i]),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _milestoneCard(int badgeCount) {
    final next = _milestones.firstWhere((m) => m > badgeCount, orElse: () => _milestones.last);
    final previous = _milestones.lastWhere((m) => m <= badgeCount, orElse: () => 0);
    final isMaxed = badgeCount >= _milestones.last;
    final progress = isMaxed ? 1.0 : (badgeCount - previous) / (next - previous);

    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMaxed ? 'You\'ve reached the top milestone — amazing work! 🌸' : '$badgeCount of $next badges toward your next milestone',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          BloomProgressBar(value: progress.clamp(0.0, 1.0)),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label, Color color) {
    return BloomCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _historyRow(SessionRegistration r) {
    Color color;
    switch (r.status) {
      case RegistrationStatus.attended:
      case RegistrationStatus.completed:
        color = AppColors.sage;
        break;
      case RegistrationStatus.missed:
      case RegistrationStatus.cancelled:
        color = AppColors.coral;
        break;
      default:
        color = AppColors.royal;
    }
    return Row(
      children: [
        Icon(r.attended ? Icons.check_circle : Icons.circle_outlined, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(r.participantName, style: const TextStyle(fontSize: 13))),
        StatusPill(r.status.label, color: color),
      ],
    );
  }

  Widget _redemptionRow(RewardRedemption r) {
    final used = r.status == RedemptionStatus.used;
    return Row(
      children: [
        Icon(used ? Icons.check_circle : Icons.pending_outlined, color: used ? AppColors.sage : AppColors.amber, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(r.rewardName, style: const TextStyle(fontSize: 13))),
        StatusPill(used ? 'Used' : 'Pending', color: used ? AppColors.sage : AppColors.amber),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final SessionBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: badge.isSpent ? Colors.white.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, color: badge.isSpent ? AppColors.inkSoft : AppColors.amber, size: 24),
          const SizedBox(height: 6),
          Text(badge.sessionTitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badge.isSpent ? AppColors.inkSoft : AppColors.royalDeep, height: 1.2)),
        ],
      ),
    );
  }
}
