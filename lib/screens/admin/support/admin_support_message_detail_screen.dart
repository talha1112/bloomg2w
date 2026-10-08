import 'package:flutter/material.dart';

import '../../../models/support_message.dart';
import '../../../services/support_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/section_header.dart';
import '../../../widgets/common/status_pill.dart';

class AdminSupportMessageDetailScreen extends StatefulWidget {
  const AdminSupportMessageDetailScreen({super.key, required this.message});

  final SupportMessage message;

  @override
  State<AdminSupportMessageDetailScreen> createState() => _AdminSupportMessageDetailScreenState();
}

class _AdminSupportMessageDetailScreenState extends State<AdminSupportMessageDetailScreen> {
  bool _working = false;

  Future<void> _toggleResolved(SupportMessage message) async {
    setState(() => _working = true);
    try {
      final next = message.status == SupportMessageStatus.open ? SupportMessageStatus.resolved : SupportMessageStatus.open;
      await SupportService.instance.setStatus(id: message.id, status: next);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(backgroundColor: AppColors.royalDeep, foregroundColor: Colors.white, title: const Text('Message Detail', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      body: SafeArea(
        child: StreamBuilder<List<SupportMessage>>(
          stream: SupportService.instance.watchAllMessages(),
          initialData: [widget.message],
          builder: (context, snapshot) {
            final message = (snapshot.data ?? const []).firstWhere(
              (m) => m.id == widget.message.id,
              orElse: () => widget.message,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(
                  children: [
                    Expanded(child: Text(message.subject.isNotEmpty ? message.subject : message.type.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.royalDeep))),
                    StatusPill(message.status.label, color: message.status == SupportMessageStatus.open ? AppColors.adminGoldDeep : AppColors.sage),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message.category.isNotEmpty ? message.category : message.type.label, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                const SectionHeader('From'),
                BloomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.userName.isNotEmpty ? message.userName : '(No name on file)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(message.userEmail, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                      const SizedBox(height: 6),
                      Text(_formatDate(message.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
                const SectionHeader('Message'),
                BloomCard(child: Text(message.message, style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.5))),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _working ? null : () => _toggleResolved(message),
                    style: FilledButton.styleFrom(
                      backgroundColor: message.status == SupportMessageStatus.open ? AppColors.sage : AppColors.inkSoft,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      message.status == SupportMessageStatus.open ? 'MARK AS RESOLVED' : 'REOPEN',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
