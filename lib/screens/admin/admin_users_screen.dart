import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import '../../widgets/common/bloom_network_image.dart';
import '../../widgets/common/role_style.dart';
import '../../widgets/common/status_pill.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _query = '';
  AppRole? _roleFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('All Users', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<UserProfile>>(
          stream: UserService.instance.watchAllUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Failed to load users.', style: TextStyle(color: AppColors.inkSoft)));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.royal));
            }

            final all = snapshot.data ?? [];
            final filtered = all.where((u) {
              final matchesQuery = _query.isEmpty ||
                  u.fullName.toLowerCase().contains(_query.toLowerCase()) ||
                  u.email.toLowerCase().contains(_query.toLowerCase());
              final matchesRole = _roleFilter == null || u.role == _roleFilter;
              return matchesQuery && matchesRole;
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search name or email…',
                      prefixIcon: const Icon(Icons.search, color: AppColors.inkSoft, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.adminGold, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _roleChip('All', null),
                        const SizedBox(width: 8),
                        _roleChip('Members', AppRole.member),
                        const SizedBox(width: 8),
                        _roleChip('Admins', AppRole.admin),
                        const SizedBox(width: 8),
                        _roleChip('Partners', AppRole.partner),
                        const SizedBox(width: 8),
                        _roleChip('Guest Speakers', AppRole.guestSpeaker),
                        const SizedBox(width: 8),
                        _roleChip('Minors', AppRole.minor),
                        const SizedBox(width: 8),
                        _roleChip('Guardians', AppRole.guardian),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('${filtered.length} of ${all.length}', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No users found.', style: TextStyle(color: AppColors.inkSoft)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _UserTile(user: filtered[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _roleChip(String label, AppRole? role) {
    final selected = _roleFilter == role;
    return GestureDetector(
      onTap: () => setState(() => _roleFilter = role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.royal : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.royal : Colors.black.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.inkSoft),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final style = RoleStyle.forRole(user.role);
    return BloomCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminUserDetailScreen(user: user))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: style.color.withValues(alpha: 0.14),
            backgroundImage: user.photoUrl != null ? bloomNetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null ? Icon(style.icon, color: style.color, size: 20) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty ? '(No name)' : user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep),
                ),
                const SizedBox(height: 2),
                Text(user.email, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                if (user.memberType.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(user.memberType, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
                ],
                if (user.role == AppRole.minor && user.guardianUids.isEmpty) ...[
                  const SizedBox(height: 4),
                  const Text('⚠ Unlinked — no guardian yet', style: TextStyle(fontSize: 10.5, color: AppColors.coral, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          StatusPill(
            user.role.label,
            color: style.color,
            icon: user.role == AppRole.admin ? Icons.verified_user_outlined : null,
          ),
        ],
      ),
    );
  }
}
