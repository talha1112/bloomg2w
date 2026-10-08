import 'package:flutter/material.dart';

import '../../../models/speaker_application.dart';
import '../../../services/speaker_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/bloom_network_image.dart';
import '../../../widgets/common/status_pill.dart';
import 'admin_speaker_detail_screen.dart';

class AdminSpeakerApplicationsScreen extends StatefulWidget {
  const AdminSpeakerApplicationsScreen({super.key});

  @override
  State<AdminSpeakerApplicationsScreen> createState() => _AdminSpeakerApplicationsScreenState();
}

class _AdminSpeakerApplicationsScreenState extends State<AdminSpeakerApplicationsScreen> {
  SpeakerStatus? _filter = SpeakerStatus.pending;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Speaker Applications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<SpeakerApplication>>(
          stream: SpeakerService.instance.watchAllApplications(),
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
                      _filterChip('New/Pending', SpeakerStatus.pending, all),
                      const SizedBox(width: 8),
                      _filterChip('Approved', SpeakerStatus.approved, all),
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

  Widget _filterChip(String label, SpeakerStatus? status, List<SpeakerApplication> all) {
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

  final SpeakerApplication application;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (application.status) {
      case SpeakerStatus.approved:
        statusColor = AppColors.sage;
        break;
      case SpeakerStatus.changesRequested:
        statusColor = AppColors.amber;
        break;
      case SpeakerStatus.declined:
        statusColor = AppColors.coral;
        break;
      case SpeakerStatus.pending:
        statusColor = AppColors.adminGoldDeep;
        break;
    }

    return BloomCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminSpeakerDetailScreen(uid: application.uid))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.royal.withValues(alpha: 0.08),
            backgroundImage: application.photoUrl != null ? bloomNetworkImage(application.photoUrl!) : null,
            child: application.photoUrl == null ? const Icon(Icons.person, color: AppColors.royal) : null,
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
                Text(application.profession, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                Text(application.speakingTopic, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
                if (application.status == SpeakerStatus.approved) ...[
                  const SizedBox(height: 4),
                  StatusPill(application.published ? 'Published to Bureau' : 'Not Published', color: application.published ? AppColors.sage : AppColors.inkSoft),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
        ],
      ),
    );
  }
}
