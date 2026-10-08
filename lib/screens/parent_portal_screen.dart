import 'package:flutter/material.dart';

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
import 'login_screen.dart';

/// Real, Firestore-backed guardian overview: shows each linked child's
/// actual upcoming sessions, attendance, and badges — read-only, sourced
/// the same way MemberDashboardScreen sources a member's own data, just
/// parameterized by each linked child's uid instead of the caller's own.
/// No fabricated permissions, emergency contacts, or "Register a Child"
/// button — those don't correspond to any real feature today.
class ParentPortalScreen extends StatefulWidget {
  const ParentPortalScreen({super.key});

  @override
  State<ParentPortalScreen> createState() => _ParentPortalScreenState();
}

class _ParentPortalScreenState extends State<ParentPortalScreen> {
  final _codeCtrl = TextEditingController();
  bool _linking = false;
  String? _linkError;
  String? _linkSuccess;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeemCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _linking = true;
      _linkError = null;
      _linkSuccess = null;
    });

    try {
      await UserService.instance.redeemInviteCode(code);
      if (mounted) {
        setState(() => _linkSuccess = 'Linked! Your child\'s account now appears below.');
        _codeCtrl.clear();
      }
    } catch (e) {
      if (mounted) setState(() => _linkError = "That code didn't work — double-check it and try again.");
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

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
    final uid = AuthService.instance.currentUser?.uid;

    return PageScaffold(
      title: 'Parent / Guardian Portal',
      // RoleRouter sends a Guardian straight here as their "home" — unlike
      // HomeScreen, this screen has no AppDrawer, so without this action a
      // guardian would have no way to sign out at all.
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Sign Out',
          onPressed: () => _signOut(context),
        ),
      ],
      children: [
        if (uid == null)
          const BloomCard(child: Text('Log in to see your Parent Portal.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
        else
          StreamBuilder<UserProfile?>(
            stream: UserService.instance.watchUserProfile(uid),
            builder: (context, profileSnapshot) {
              final childUids = profileSnapshot.data?.linkedChildUids ?? const [];

              return Column(
                children: [
                  const SectionHeader('Link a Child'),
                  BloomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ask your daughter for her invite code to see her sessions, attendance, and badges here.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _codeCtrl,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: 'Invite code',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _linking ? null : _redeemCode,
                              style: FilledButton.styleFrom(backgroundColor: AppColors.royal, foregroundColor: Colors.white),
                              child: Text(_linking ? 'Linking…' : 'Link'),
                            ),
                          ],
                        ),
                        if (_linkError != null) ...[
                          const SizedBox(height: 8),
                          Text(_linkError!, style: const TextStyle(color: AppColors.coral, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                        if (_linkSuccess != null) ...[
                          const SizedBox(height: 8),
                          Text(_linkSuccess!, style: const TextStyle(color: AppColors.sage, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                  const SectionHeader('My Children'),
                  if (childUids.isEmpty)
                    const BloomCard(child: Text('No linked children yet — enter an invite code above to get started.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
                  else
                    ...childUids.map((childUid) => _ChildCard(childUid: childUid)),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.childUid});

  final String childUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: UserService.instance.watchUserProfile(childUid),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        if (profile == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.royal.withValues(alpha: 0.1),
                      backgroundImage: profile.photoUrl != null ? bloomNetworkImage(profile.photoUrl!) : null,
                      child: profile.photoUrl == null ? const Icon(Icons.person, color: AppColors.royalDeep) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(profile.fullName.isNotEmpty ? profile.fullName : 'Your child', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<SessionRegistration>>(
                  stream: SessionService.instance.watchRegistrationsForUser(childUid),
                  builder: (context, regSnapshot) {
                    final registrations = regSnapshot.data ?? [];
                    final attendedCount = registrations.where((r) => r.attended).length;
                    final completedCount = registrations.where((r) => r.completionMet).length;

                    return StreamBuilder<List<SessionBadge>>(
                      stream: SessionService.instance.watchBadgesForUser(childUid),
                      builder: (context, badgeSnapshot) {
                        final badges = badgeSnapshot.data ?? [];
                        return Row(
                          children: [
                            Expanded(child: _statTile('${badges.length}', 'Badges')),
                            Expanded(child: _statTile('$attendedCount', 'Attended')),
                            Expanded(child: _statTile('$completedCount', 'Completed')),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statTile(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.royal)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
