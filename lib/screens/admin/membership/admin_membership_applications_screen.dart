import 'package:flutter/material.dart';

import '../../../models/membership_application.dart';
import '../../../services/membership_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/status_pill.dart';
import 'admin_membership_detail_screen.dart';

class AdminMembershipApplicationsScreen extends StatefulWidget {
  const AdminMembershipApplicationsScreen({super.key});

  @override
  State<AdminMembershipApplicationsScreen> createState() => _AdminMembershipApplicationsScreenState();
}

class _AdminMembershipApplicationsScreenState extends State<AdminMembershipApplicationsScreen> {
  MembershipStatus? _filter = MembershipStatus.pending;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Membership Applications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<MembershipApplication>>(
          stream: MembershipService.instance.watchAllApplications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.royal));
            }
            final all = snapshot.data ?? [];
            final filtered = _filter == null ? all : all.where((a) => a.status == _filter).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _filterChip('Pending', MembershipStatus.pending, all),
                      const SizedBox(width: 8),
                      _filterChip('Approved', MembershipStatus.approved, all),
                      const SizedBox(width: 8),
                      _filterChip('All', null, all),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No applications here.', style: TextStyle(color: AppColors.inkSoft)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _ApplicationTile(application: filtered[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, MembershipStatus? status, List<MembershipApplication> all) {
    final selected = _filter == status;
    final count = status == null ? all.length : all.where((a) => a.status == status).length;
    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.royal : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.royal : Colors.black.withValues(alpha: 0.1)),
        ),
        child: Text('$label ($count)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.inkSoft)),
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application});

  final MembershipApplication application;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (application.status) {
      case MembershipStatus.approved:
        statusColor = AppColors.sage;
        break;
      case MembershipStatus.declined:
        statusColor = AppColors.coral;
        break;
      case MembershipStatus.pending:
        statusColor = AppColors.adminGoldDeep;
        break;
    }

    return BloomCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminMembershipDetailScreen(application: application))),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (application.type == MembershipType.girls ? AppColors.violet : AppColors.cornflower).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              application.type == MembershipType.girls ? Icons.emoji_people_outlined : Icons.woman_outlined,
              color: application.type == MembershipType.girls ? AppColors.violet : AppColors.cornflower,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(application.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                    StatusPill(application.status.label, color: statusColor),
                  ],
                ),
                const SizedBox(height: 2),
                Text(application.type.label, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                Text(application.email, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
        ],
      ),
    );
  }
}
