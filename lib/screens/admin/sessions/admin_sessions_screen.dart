import 'package:flutter/material.dart';

import '../../../models/bloom_session.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/status_pill.dart';
import 'admin_session_detail_screen.dart';
import 'admin_session_form_screen.dart';

class AdminSessionsScreen extends StatefulWidget {
  const AdminSessionsScreen({super.key});

  @override
  State<AdminSessionsScreen> createState() => _AdminSessionsScreenState();
}

class _AdminSessionsScreenState extends State<AdminSessionsScreen> {
  SessionStatus? _filter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Bloom Sessions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminSessionFormScreen())),
        backgroundColor: AppColors.royal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Session', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<BloomSession>>(
          stream: SessionService.instance.watchAllSessions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.royal));
            }
            final all = snapshot.data ?? [];
            final filtered = _filter == null ? all : all.where((s) => s.status == _filter).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _filterChip('All', null, all),
                        const SizedBox(width: 8),
                        _filterChip('Draft', SessionStatus.draft, all),
                        const SizedBox(width: 8),
                        _filterChip('Published', SessionStatus.published, all),
                        const SizedBox(width: 8),
                        _filterChip('Cancelled', SessionStatus.cancelled, all),
                        const SizedBox(width: 8),
                        _filterChip('Completed', SessionStatus.completed, all),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No sessions yet — tap "New Session" to create one.', style: TextStyle(color: AppColors.inkSoft), textAlign: TextAlign.center))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _SessionTile(session: filtered[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, SessionStatus? status, List<BloomSession> all) {
    final selected = _filter == status;
    final count = status == null ? all.length : all.where((s) => s.status == status).length;
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final BloomSession session;

  Color get _statusColor {
    switch (session.status) {
      case SessionStatus.draft:
        return AppColors.inkSoft;
      case SessionStatus.published:
        return AppColors.sage;
      case SessionStatus.cancelled:
        return AppColors.coral;
      case SessionStatus.completed:
        return AppColors.cornflower;
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminSessionDetailScreen(sessionId: session.id))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.royal.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.videocam_outlined, color: AppColors.royal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(session.title.isEmpty ? '(Untitled Session)' : session.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                    StatusPill(session.status.label, color: _statusColor),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${_formatDate(session.date)} · ${session.startTime}', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                if (session.guestSpeakerNameSnapshot != null) ...[
                  const SizedBox(height: 3),
                  Text('🎤 ${session.guestSpeakerNameSnapshot}', style: const TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
