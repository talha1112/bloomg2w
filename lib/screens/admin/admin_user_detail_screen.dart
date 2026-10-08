import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import '../../widgets/common/bloom_network_image.dart';
import '../../widgets/common/role_style.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_pill.dart';

class AdminUserDetailScreen extends StatelessWidget {
  const AdminUserDetailScreen({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final style = RoleStyle.forRole(user.role);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('User Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.royalDeep, Color(0xFF0C1440)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.adminGold.withValues(alpha: 0.35)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: style.color.withValues(alpha: 0.22),
                    backgroundImage: user.photoUrl != null ? bloomNetworkImage(user.photoUrl!) : null,
                    child: user.photoUrl == null ? Icon(style.icon, color: Colors.white, size: 32) : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.fullName.isEmpty ? '(No name)' : user.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(user.email, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.75))),
                  const SizedBox(height: 10),
                  StatusPill(
                    user.role.label,
                    color: style.color,
                    icon: style.icon,
                  ),
                ],
              ),
            ),
            const SectionHeader('Account Information'),
            BloomCard(
              child: Column(
                children: [
                  _infoRow('User ID', user.uid),
                  const Divider(height: 20),
                  _infoRow('Full Name', user.fullName.isEmpty ? '—' : user.fullName),
                  const Divider(height: 20),
                  _infoRow('Email', user.email),
                  const Divider(height: 20),
                  _infoRow('Role', user.role.label),
                  const Divider(height: 20),
                  _infoRow('Member Type', user.memberType.isEmpty ? '—' : user.memberType),
                  const Divider(height: 20),
                  _infoRow('Date of Birth', user.dateOfBirth == null ? '— (not on file)' : _formatDate(user.dateOfBirth!)),
                  const Divider(height: 20),
                  _infoRow('Joined', _formatDate(user.createdAt)),
                ],
              ),
            ),
            if (user.role == AppRole.minor) ...[
              const SectionHeader('Linked Guardians'),
              BloomCard(
                child: user.guardianUids.isEmpty
                    ? const Text('⚠ No guardian linked yet', style: TextStyle(fontSize: 13, color: AppColors.coral, fontWeight: FontWeight.w700))
                    : _LinkedProfilesList(uids: user.guardianUids),
              ),
            ],
            if (user.role == AppRole.guardian) ...[
              const SectionHeader('Linked Children'),
              BloomCard(
                child: user.linkedChildUids.isEmpty
                    ? const Text('No children linked yet.', style: TextStyle(fontSize: 13, color: AppColors.inkSoft))
                    : _LinkedProfilesList(uids: user.linkedChildUids),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
        ),
      ],
    );
  }
}

/// Resolves a list of uids (a minor's guardianUids, or a guardian's
/// linkedChildUids) to display names — admin-only screen, so a plain
/// one-shot fetch per uid is fine (small lists, capped at
/// MAX_GUARDIANS_PER_MINOR server-side).
class _LinkedProfilesList extends StatelessWidget {
  const _LinkedProfilesList({required this.uids});

  final List<String> uids;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: uids.map((uid) {
        return FutureBuilder<UserProfile?>(
          future: UserService.instance.fetchUserProfile(uid),
          builder: (context, snapshot) {
            final name = snapshot.data?.fullName;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                name != null && name.isNotEmpty ? name : (snapshot.connectionState == ConnectionState.waiting ? 'Loading…' : uid),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
