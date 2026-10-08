import 'package:flutter/material.dart';

import '../../../models/support_message.dart';
import '../../../services/support_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/status_pill.dart';
import 'admin_support_message_detail_screen.dart';

class AdminSupportMessagesScreen extends StatefulWidget {
  const AdminSupportMessagesScreen({super.key});

  @override
  State<AdminSupportMessagesScreen> createState() => _AdminSupportMessagesScreenState();
}

class _AdminSupportMessagesScreenState extends State<AdminSupportMessagesScreen> {
  SupportMessageStatus? _statusFilter = SupportMessageStatus.open;
  SupportMessageType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Contact & Support', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<SupportMessage>>(
          stream: SupportService.instance.watchAllMessages(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.royal));
            }
            final all = snapshot.data ?? [];
            final filtered = all.where((m) {
              final statusMatch = _statusFilter == null || m.status == _statusFilter;
              final typeMatch = _typeFilter == null || m.type == _typeFilter;
              return statusMatch && typeMatch;
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _statusChip('Open', SupportMessageStatus.open, all),
                      const SizedBox(width: 8),
                      _statusChip('Resolved', SupportMessageStatus.resolved, all),
                      const SizedBox(width: 8),
                      _statusChip('All', null, all),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _typeChip('All Types', null),
                        const SizedBox(width: 8),
                        _typeChip('Contact', SupportMessageType.contact),
                        const SizedBox(width: 8),
                        _typeChip('Problems', SupportMessageType.reportProblem),
                        const SizedBox(width: 8),
                        _typeChip('Feedback', SupportMessageType.feedback),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No messages here.', style: TextStyle(color: AppColors.inkSoft)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _MessageTile(message: filtered[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusChip(String label, SupportMessageStatus? status, List<SupportMessage> all) {
    final selected = _statusFilter == status;
    final count = status == null ? all.length : all.where((m) => m.status == status).length;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = status),
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

  Widget _typeChip(String label, SupportMessageType? type) {
    final selected = _typeFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _typeFilter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.adminGold.withValues(alpha: 0.18) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.adminGoldDeep : Colors.black.withValues(alpha: 0.08)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected ? AppColors.adminGoldDeep : AppColors.inkSoft)),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final SupportMessage message;

  IconData get _icon {
    switch (message.type) {
      case SupportMessageType.contact:
        return Icons.mail_outline;
      case SupportMessageType.reportProblem:
        return Icons.report_gmailerrorred_outlined;
      case SupportMessageType.feedback:
        return Icons.feedback_outlined;
    }
  }

  Color get _iconColor {
    switch (message.type) {
      case SupportMessageType.contact:
        return AppColors.royal;
      case SupportMessageType.reportProblem:
        return AppColors.coral;
      case SupportMessageType.feedback:
        return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminSupportMessageDetailScreen(message: message))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: _iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(_icon, color: _iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.subject.isNotEmpty ? message.subject : message.type.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                    StatusPill(message.status.label, color: message.status == SupportMessageStatus.open ? AppColors.adminGoldDeep : AppColors.sage),
                  ],
                ),
                const SizedBox(height: 3),
                Text(message.userName.isNotEmpty ? message.userName : message.userEmail, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                const SizedBox(height: 4),
                Text(message.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
