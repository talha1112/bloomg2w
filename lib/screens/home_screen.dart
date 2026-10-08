import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/dashboard_tile.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/badge_celebration.dart';
import '../widgets/dashboard_tile_card.dart';
import '../widgets/hero_banner_card.dart';
import '../widgets/legacy_role_reconciliation_banner.dart';
import '../widgets/quote_footer_card.dart';
import '../widgets/upcoming_event_card.dart';
import 'about_screen.dart';
import 'community_partners_screen.dart';
import 'contact_support_screen.dart';
import 'events_zoom_screen.dart';
import 'founder_president_screen.dart';
import 'learning_center_screen.dart';
import 'membership_registration_screen.dart';
import 'notifications_screen.dart';
import 'parent_portal_screen.dart';
import 'profile_settings_screen.dart';
import 'rewards_screen.dart';
import 'signature_programs_screen.dart';
import 'speaker/speaker_bureau_screen.dart';
import 'what_guides_us_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  late final _tiles = [
    DashboardTile(
      icon: Icons.favorite_border,
      title: 'My Profile',
      subtitle: 'View & update your profile',
      color: AppColors.royal,
      builder: (_) => const ProfileSettingsScreen(),
    ),
    DashboardTile(
      icon: Icons.groups_outlined,
      title: 'Membership',
      subtitle: 'Join, manage & renew',
      color: AppColors.royal,
      builder: (_) => const MembershipRegistrationScreen(),
    ),
    DashboardTile(
      icon: Icons.family_restroom,
      title: 'Parent Portal',
      subtitle: 'Resources & support',
      color: AppColors.amber,
      builder: (_) => const ParentPortalScreen(),
    ),
    DashboardTile(
      icon: Icons.spa_outlined,
      title: 'About Bloom G2W',
      subtitle: 'Our story & mission',
      color: AppColors.violet,
      builder: (_) => const AboutScreen(),
    ),
    DashboardTile(
      icon: Icons.local_florist_outlined,
      title: 'Signature Programs',
      subtitle: 'Explore our 9 core programs',
      color: AppColors.rose,
      builder: (_) => const SignatureProgramsScreen(),
    ),
    DashboardTile(
      icon: Icons.record_voice_over_outlined,
      title: 'Founder & President',
      subtitle: 'Meet our Founder & President',
      color: AppColors.cornflower,
      builder: (_) => const FounderPresidentScreen(),
    ),
    DashboardTile(
      icon: Icons.explore_outlined,
      title: 'What Guides Us',
      subtitle: 'Mission, vision & core values',
      color: AppColors.teal,
      builder: (_) => const WhatGuidesUsScreen(),
    ),
    DashboardTile(
      icon: Icons.campaign_outlined,
      title: 'Guest Speakers Bureau',
      subtitle: 'Browse speaker profiles & request speakers',
      color: AppColors.amber,
      builder: (_) => const SpeakerBureauScreen(),
    ),
    DashboardTile(
      icon: Icons.card_giftcard_outlined,
      title: 'Rewards',
      subtitle: 'Earn points & redeem rewards',
      color: AppColors.sage,
      builder: (_) => const RewardsScreen(),
    ),
    DashboardTile(
      icon: Icons.handshake_outlined,
      title: 'Community Partners',
      subtitle: 'Support, discounts & gift cards',
      color: AppColors.rose,
      builder: (_) => const CommunityPartnersScreen(),
    ),
    DashboardTile(
      icon: Icons.event_note_outlined,
      title: 'Events & Zoom',
      subtitle: 'Register for events & workshops',
      color: AppColors.teal,
      builder: (_) => const EventsZoomScreen(),
    ),
    DashboardTile(
      icon: Icons.school_outlined,
      title: 'Courses',
      subtitle: 'Explore courses & workshops',
      color: AppColors.cornflower,
      builder: (_) => const LearningCenterScreen(),
      comingSoon: true,
    ),
    DashboardTile(
      icon: Icons.support_agent_outlined,
      title: 'Contact & Support',
      subtitle: 'FAQs, feedback & help',
      color: AppColors.coral,
      builder: (_) => const ContactSupportScreen(),
    ),
  ];

  // Every destination except Home (index 0) pushes a separate full-screen
  // page rather than swapping content in place — so once that page is
  // popped (back button, swipe-back, etc.), this HomeScreen instance is
  // still the one underneath and must show Home as active again. Resetting
  // _navIndex to 0 in the push's `then` (instead of leaving it at whatever
  // was tapped) is what fixes the stale "wrong icon highlighted" state
  // after returning from Profile/Events/Rewards.
  void _open(WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute(builder: builder)).then((_) {
      if (mounted) setState(() => _navIndex = 0);
    });
  }

  void _onNavTap(int i) {
    if (i == 0) {
      setState(() => _navIndex = 0);
      return;
    }
    setState(() => _navIndex = i);
    switch (i) {
      case 1:
        _open((_) => const EventsZoomScreen());
        break;
      case 2:
        setState(() => _navIndex = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Courses is coming soon!')),
        );
        break;
      case 3:
        _open((_) => const RewardsScreen());
        break;
      case 4:
        _open((_) => const ProfileSettingsScreen());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = _buildScaffold(context);
    final uid = AuthService.instance.currentUser?.uid;
    return uid == null ? scaffold : BadgeCelebrationListener(uid: uid, child: scaffold);
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        elevation: 0,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Colors.white,
            ),
            children: [
              TextSpan(text: 'Bloom'),
              TextSpan(text: 'G2', style: TextStyle(color: AppColors.gold)),
              TextSpan(text: 'W'),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) {
              final uid = AuthService.instance.currentUser?.uid;
              return StreamBuilder<List<AppNotification>>(
                stream: uid == null ? const Stream.empty() : NotificationService.instance.watchForUser(uid),
                builder: (context, snapshot) {
                  final unread = (snapshot.data ?? []).where((n) => !n.read).length;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: AppColors.gold),
                        onPressed: () => _open((_) => const NotificationsScreen()),
                      ),
                      if (unread > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                color: AppColors.royalDeep,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const LegacyRoleReconciliationBanner(),
            const HeroBannerCard(),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final uid = AuthService.instance.currentUser?.uid;
                return StreamBuilder<UserProfile?>(
                  stream: uid == null ? const Stream.empty() : UserService.instance.watchUserProfile(uid),
                  builder: (context, snapshot) {
                    // A Girl (minor) has no child of her own to manage —
                    // Parent Portal is a Guardian-only concept, and showing
                    // it here would be confusing/misleading for her. Every
                    // other role sees the full tile set as before.
                    final isMinor = snapshot.data?.role == AppRole.minor;
                    final tiles = isMinor ? _tiles.where((t) => t.title != 'Parent Portal').toList() : _tiles;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tiles.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.98,
                      ),
                      itemBuilder: (context, i) => DashboardTileCard(tile: tiles[i]),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const UpcomingEventCard(),
            const SizedBox(height: 20),
            const QuoteFooterCard(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: AppColors.royalDeep,
        indicatorColor: AppColors.gold.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.gold : Colors.white70,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.home, color: AppColors.gold),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.event, color: AppColors.gold),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.menu_book, color: AppColors.gold),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.card_giftcard, color: AppColors.gold),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: Colors.white70),
            selectedIcon: Icon(Icons.person, color: AppColors.gold),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
