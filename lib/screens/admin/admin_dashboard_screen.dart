import 'package:flutter/material.dart';

import '../../models/bloom_reward.dart';
import '../../models/bloom_session.dart';
import '../../models/membership_application.dart';
import '../../models/partner_profile.dart';
import '../../models/speaker_application.dart';
import '../../models/support_message.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/membership_service.dart';
import '../../services/partner_service.dart';
import '../../services/session_service.dart';
import '../../services/speaker_service.dart';
import '../../services/support_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_pill.dart';
import '../login_screen.dart';
import 'admin_users_screen.dart';
import 'donations/admin_donations_screen.dart';
import 'impact/admin_impact_dashboard_screen.dart';
import 'membership/admin_membership_applications_screen.dart';
import 'partners/admin_partners_screen.dart';
import 'sessions/admin_sessions_screen.dart';
import 'speakers/admin_speaker_applications_screen.dart';
import 'speakers/admin_speaker_interest_screen.dart';
import 'support/admin_support_messages_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Administrator Dashboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign Out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.royalDeep, Color(0xFF0C1440)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.adminGold.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, color: AppColors.adminGold, size: 30),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Manage the entire Bloom G2W application — users, approvals, content, rewards & reporting.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SectionHeader('People'),
            BloomCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: AppColors.adminGold.withValues(alpha: 0.16), shape: BoxShape.circle),
                    child: const Icon(Icons.people_alt_outlined, color: AppColors.adminGoldDeep, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All Users', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        SizedBox(height: 2),
                        Text('View every account and its role', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
                ],
              ),
            ),
            const SectionHeader('Bloom Sessions'),
            StreamBuilder<List<BloomSession>>(
              stream: SessionService.instance.watchAllSessions(),
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? [];
                final now = DateTime.now();
                final startOfToday = DateTime(now.year, now.month, now.day);
                final upcomingPublished = sessions.where((s) => s.status == SessionStatus.published && !DateTime(s.date.year, s.date.month, s.date.day).isBefore(startOfToday)).length;
                return BloomCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminSessionsScreen())),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: AppColors.royal.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.videocam_outlined, color: AppColors.royal, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create & Manage Sessions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            SizedBox(height: 2),
                            Text('Schedule Zoom sessions, assign speakers & track attendance', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                      if (upcomingPublished > 0) StatusPill('$upcomingPublished upcoming', color: AppColors.sage),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
                    ],
                  ),
                );
              },
            ),
            BloomCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminImpactDashboardScreen())),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: AppColors.sage.withValues(alpha: 0.16), shape: BoxShape.circle),
                    child: const Icon(Icons.insights_outlined, color: AppColors.sage, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Impact Dashboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        SizedBox(height: 2),
                        Text('Filter by program, age group & date — export reports', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
                ],
              ),
            ),
            const SectionHeader('Guest Speakers'),
            StreamBuilder<List<SpeakerApplication>>(
              stream: SpeakerService.instance.watchAllApplications(),
              builder: (context, snapshot) {
                final applications = snapshot.data ?? [];
                final pendingCount = applications.where((a) => a.status == SpeakerStatus.pending).length;
                return Column(
                  children: [
                    BloomCard(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminSpeakerApplicationsScreen())),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: AppColors.adminGold.withValues(alpha: 0.16), shape: BoxShape.circle),
                            child: const Icon(Icons.mic_outlined, color: AppColors.adminGoldDeep, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Speaker Applications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                          if (pendingCount > 0) StatusPill('$pendingCount pending', color: AppColors.adminGoldDeep),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
                        ],
                      ),
                    ),
                    BloomCard(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminSpeakerInterestScreen())),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.14), shape: BoxShape.circle),
                            child: const Icon(Icons.favorite_outline, color: AppColors.coral, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('Speaker Interest Tracking', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                          const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SectionHeader('Contact & Support'),
            StreamBuilder<List<SupportMessage>>(
              stream: SupportService.instance.watchAllMessages(),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                final openCount = messages.where((m) => m.status == SupportMessageStatus.open).length;
                return BloomCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminSupportMessagesScreen())),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: AppColors.royal.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.support_agent_outlined, color: AppColors.royal, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Support Messages', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            SizedBox(height: 2),
                            Text('Contact forms, problem reports & feedback', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                      if (openCount > 0) StatusPill('$openCount open', color: AppColors.adminGoldDeep),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
                    ],
                  ),
                );
              },
            ),
            const SectionHeader('Membership'),
            StreamBuilder<List<MembershipApplication>>(
              stream: MembershipService.instance.watchAllApplications(),
              builder: (context, snapshot) {
                final applications = snapshot.data ?? [];
                final pendingCount = applications.where((a) => a.status == MembershipStatus.pending).length;
                return BloomCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminMembershipApplicationsScreen())),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: AppColors.adminGold.withValues(alpha: 0.16), shape: BoxShape.circle),
                        child: const Icon(Icons.groups_outlined, color: AppColors.adminGoldDeep, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Membership Applications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            SizedBox(height: 2),
                            Text('Girls & Women\'s membership submissions', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                      if (pendingCount > 0) StatusPill('$pendingCount pending', color: AppColors.adminGoldDeep),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
                    ],
                  ),
                );
              },
            ),
            StreamBuilder<List<PartnerProfile>>(
              stream: PartnerService.instance.watchAllPartners(),
              builder: (context, snapshot) {
                final partners = snapshot.data ?? [];
                final pendingCount = partners.where((p) => p.status == PartnerStatus.pending).length;
                return BloomCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPartnersScreen())),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: AppColors.royal.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.handshake_outlined, color: AppColors.royal, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Community Partners', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            SizedBox(height: 2),
                            Text('Approve partners & review proposed rewards', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                      if (pendingCount > 0) StatusPill('$pendingCount pending', color: AppColors.adminGoldDeep),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
                    ],
                  ),
                );
              },
            ),
            BloomCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDonationsScreen())),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: AppColors.sage.withValues(alpha: 0.16), shape: BoxShape.circle),
                    child: const Icon(Icons.volunteer_activism_outlined, color: AppColors.sage, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Donations', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        SizedBox(height: 2),
                        Text('Community Partner financial contributions', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
                ],
              ),
            ),
            const SectionHeader('Quick Stats'),
            StreamBuilder<List<UserProfile>>(
              stream: UserService.instance.watchAllUsers(),
              builder: (context, userSnapshot) {
                final users = userSnapshot.data ?? [];
                final totalMembers = users.where((u) => u.role == AppRole.member).length;

                return StreamBuilder<List<PartnerProfile>>(
                  stream: PartnerService.instance.watchAllPartners(),
                  builder: (context, partnerSnapshot) {
                    final activePartners = (partnerSnapshot.data ?? []).where((p) => p.status == PartnerStatus.approved).length;

                    return StreamBuilder<List<RewardRedemption>>(
                      stream: PartnerService.instance.watchAllRedemptions(),
                      builder: (context, rewardSnapshot) {
                        final redemptions = (rewardSnapshot.data ?? []).where((r) => r.status == RedemptionStatus.used).length;

                        return Row(
                          children: [
                            Expanded(child: _statTile('$totalMembers', 'Total Members')),
                            const SizedBox(width: 10),
                            Expanded(child: _statTile('$activePartners', 'Active Partners')),
                            const SizedBox(width: 10),
                            Expanded(child: _statTile('$redemptions', 'QR Redemptions')),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return BloomCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.royal)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
