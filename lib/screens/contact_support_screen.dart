import 'package:flutter/material.dart';

import '../models/support_message.dart';
import '../services/auth_service.dart';
import '../services/support_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  String _category = 'FAQ';

  static const _categories = ['FAQ', 'Technical', 'Membership'];

  static const _faqs = [
    ('How do I register my child for Bloom G2W?', 'Go to Membership Registration, select Girls Membership, and complete the parent/guardian consent section.'),
    ('How do I join a Zoom event?', 'From Events & Zoom Center, tap "Join Zoom" on any event you\'re registered for.'),
    ('How do I redeem a reward?', 'Visit Rewards, select an available reward, and show the QR code to the Community Partner.'),
  ];

  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitContactForm() async {
    if (_messageCtrl.text.trim().isEmpty) return;
    await _submit(
      type: SupportMessageType.contact,
      category: '$_category Support',
      subject: _subjectCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
    );
    if (mounted) {
      _subjectCtrl.clear();
      _messageCtrl.clear();
    }
  }

  Future<void> _submit({
    required SupportMessageType type,
    required String category,
    required String subject,
    required String message,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      await SupportService.instance.submitMessage(
        SupportMessage(
          id: '',
          uid: user.uid,
          userName: user.displayName ?? '',
          userEmail: user.email ?? '',
          type: type,
          category: category,
          subject: subject,
          message: message,
          status: SupportMessageStatus.open,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you — your message has been sent to Bloom G2W support.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong sending your message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showQuickSubmitSheet({required SupportMessageType type, required String title, required String hint}) async {
    final controller = TextEditingController();
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.royalDeep)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: AppColors.paper,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(controller.text.trim()),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.royal, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (message != null && message.isNotEmpty) {
      await _submit(type: type, category: type.label, subject: title, message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Contact & Support',
      children: [
        const SectionHeader('How can we help?'),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _categories
                .map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _category == c ? Colors.white : AppColors.royal)),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                        selectedColor: AppColors.royal,
                        backgroundColor: AppColors.royal.withValues(alpha: 0.06),
                        side: BorderSide.none,
                      ),
                    ))
                .toList(),
          ),
        ),
        if (_category == 'FAQ') ...[
          const SectionHeader('Frequently Asked Questions'),
          ..._faqs.map(
            (f) => BloomCard(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                expandedAlignment: Alignment.centerLeft,
                children: [Text(f.$2, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.5))],
              ),
            ),
          ),
        ] else ...[
          const SectionHeader('Contact Form'),
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category: $_category Support', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.royal)),
                const SizedBox(height: 12),
                _field(_subjectCtrl, 'Subject'),
                const SizedBox(height: 10),
                _field(_messageCtrl, 'Describe your issue…', maxLines: 4),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submitContactForm,
              style: FilledButton.styleFrom(backgroundColor: AppColors.royal, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(_submitting ? 'Sending…' : 'Send Message', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
        const SectionHeader('Other Options'),
        BloomCard(
          onTap: () => _showQuickSubmitSheet(
            type: SupportMessageType.reportProblem,
            title: 'Report a Problem',
            hint: 'What went wrong?',
          ),
          child: const Row(
            children: [
              Icon(Icons.report_gmailerrorred_outlined, color: AppColors.coral),
              SizedBox(width: 10),
              Expanded(child: Text('Report a Problem', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
              Icon(Icons.chevron_right, color: AppColors.inkSoft),
            ],
          ),
        ),
        BloomCard(
          onTap: () => _showQuickSubmitSheet(
            type: SupportMessageType.feedback,
            title: 'Send Feedback',
            hint: 'Tell us what you think…',
          ),
          child: const Row(
            children: [
              Icon(Icons.feedback_outlined, color: AppColors.amber),
              SizedBox(width: 10),
              Expanded(child: Text('Send Feedback', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
              Icon(Icons.chevron_right, color: AppColors.inkSoft),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.paper,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
