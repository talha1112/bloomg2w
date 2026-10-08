import 'package:flutter/material.dart';

import '../../../models/membership_application.dart';
import '../../../services/membership_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/section_header.dart';
import '../../../widgets/common/status_pill.dart';

class AdminMembershipDetailScreen extends StatefulWidget {
  const AdminMembershipDetailScreen({super.key, required this.application});

  final MembershipApplication application;

  @override
  State<AdminMembershipDetailScreen> createState() => _AdminMembershipDetailScreenState();
}

class _AdminMembershipDetailScreenState extends State<AdminMembershipDetailScreen> {
  bool _working = false;

  Future<void> _setStatus(MembershipStatus status) async {
    setState(() => _working = true);
    try {
      await MembershipService.instance.setStatus(id: widget.application.id, status: status);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Color _statusColor(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.approved:
        return AppColors.sage;
      case MembershipStatus.declined:
        return AppColors.coral;
      case MembershipStatus.pending:
        return AppColors.adminGoldDeep;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(backgroundColor: AppColors.royalDeep, foregroundColor: Colors.white, title: const Text('Membership Application', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      body: SafeArea(
        child: StreamBuilder<List<MembershipApplication>>(
          stream: MembershipService.instance.watchAllApplications(),
          initialData: [widget.application],
          builder: (context, snapshot) {
            final application = (snapshot.data ?? const []).firstWhere(
              (a) => a.id == widget.application.id,
              orElse: () => widget.application,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(
                  children: [
                    Expanded(child: Text(application.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.royalDeep))),
                    StatusPill(application.status.label, color: _statusColor(application.status)),
                  ],
                ),
                Text(application.type.label, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                const SectionHeader('Member Profile'),
                BloomCard(
                  child: Column(
                    children: [
                      _row('Email', application.email),
                      const Divider(height: 18),
                      _row('Phone', application.phone.isEmpty ? '—' : application.phone),
                      const Divider(height: 18),
                      _row('Date of Birth', application.dateOfBirth.isEmpty ? '—' : application.dateOfBirth),
                      const Divider(height: 18),
                      _row('Submitted', _formatDate(application.createdAt)),
                    ],
                  ),
                ),
                if (application.type == MembershipType.girls) ...[
                  const SectionHeader('Parent / Guardian'),
                  BloomCard(
                    child: Column(
                      children: [
                        _row('Name', application.parentName.isEmpty ? '—' : application.parentName),
                        const Divider(height: 18),
                        _row('Email', application.parentEmail.isEmpty ? '—' : application.parentEmail),
                        const Divider(height: 18),
                        _row('Phone', application.parentPhone.isEmpty ? '—' : application.parentPhone),
                        const Divider(height: 18),
                        _row('Consent Given', application.parentConsent ? 'Yes' : 'No'),
                      ],
                    ),
                  ),
                ],
                if (application.interests.isNotEmpty) ...[
                  const SectionHeader('Interests'),
                  BloomCard(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: application.interests.map((i) => Chip(label: Text(i, style: const TextStyle(fontSize: 11.5)), backgroundColor: AppColors.royal.withValues(alpha: 0.06), side: BorderSide.none)).toList(),
                    ),
                  ),
                ],
                if (application.membershipQuestion.isNotEmpty) ...[
                  const SectionHeader('What They Hope to Gain'),
                  BloomCard(child: Text(application.membershipQuestion, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5))),
                ],
                const SectionHeader('Terms Accepted'),
                BloomCard(
                  child: Row(
                    children: [
                      Icon(application.acceptedTerms ? Icons.check_circle : Icons.cancel, color: application.acceptedTerms ? AppColors.sage : AppColors.coral, size: 18),
                      const SizedBox(width: 8),
                      Text(application.acceptedTerms ? 'Accepted Terms & Conditions' : 'Did not accept terms', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (application.status == MembershipStatus.pending) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _working ? null : () => _setStatus(MembershipStatus.approved),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.sage, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _working ? null : () => _setStatus(MembershipStatus.declined),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.coral), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('DECLINE', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.coral)),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
      ],
    );
  }
}
