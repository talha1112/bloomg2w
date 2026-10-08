import 'package:flutter/material.dart';

import '../../../models/speaker_application.dart';
import '../../../services/speaker_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/bloom_network_image.dart';
import '../../../widgets/common/section_header.dart';
import '../../../widgets/common/status_pill.dart';

class AdminSpeakerDetailScreen extends StatefulWidget {
  const AdminSpeakerDetailScreen({super.key, required this.uid});

  final String uid;

  @override
  State<AdminSpeakerDetailScreen> createState() => _AdminSpeakerDetailScreenState();
}

class _AdminSpeakerDetailScreenState extends State<AdminSpeakerDetailScreen> {
  bool _working = false;

  Future<void> _setStatus(SpeakerStatus status, {String? notes}) async {
    setState(() => _working = true);
    try {
      await SpeakerService.instance.setStatus(uid: widget.uid, status: status, adminNotes: notes ?? '');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _requestChanges() async {
    final controller = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request Changes'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'What should the applicant update?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()), child: const Text('Send')),
        ],
      ),
    );
    if (notes != null) await _setStatus(SpeakerStatus.changesRequested, notes: notes);
  }

  Future<void> _togglePublished(bool value) async {
    setState(() => _working = true);
    try {
      await SpeakerService.instance.setPublished(uid: widget.uid, published: value);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(backgroundColor: AppColors.royalDeep, foregroundColor: Colors.white, title: const Text('Speaker Application', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      body: SafeArea(
        child: FutureBuilder<SpeakerApplication?>(
          future: SpeakerService.instance.fetchApplication(widget.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.royal));
            }
            final app = snapshot.data;
            if (app == null) return const Center(child: Text('Application not found.'));

            return StreamBuilder<SpeakerApplication?>(
              stream: SpeakerService.instance.watchApplication(widget.uid),
              initialData: app,
              builder: (context, liveSnapshot) {
                final application = liveSnapshot.data ?? app;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.royal.withValues(alpha: 0.08),
                        backgroundImage: application.photoUrl != null ? bloomNetworkImage(application.photoUrl!) : null,
                        child: application.photoUrl == null ? const Icon(Icons.person, color: AppColors.royal, size: 40) : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: Text(application.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.royalDeep))),
                    Center(child: Text(application.profession, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft))),
                    const SizedBox(height: 10),
                    Center(child: _statusPill(application)),
                    const SectionHeader('Contact (admin only)'),
                    BloomCard(
                      child: Column(
                        children: [
                          _row('Email', application.email),
                          const Divider(height: 18),
                          _row('Phone', application.phone),
                          if (application.cityState.isNotEmpty) ...[const Divider(height: 18), _row('City/State', application.cityState)],
                        ],
                      ),
                    ),
                    const SectionHeader('Credentials & Experience'),
                    BloomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (application.organization.isNotEmpty) _labeled('Organization', application.organization),
                          if (application.yearsExperience.isNotEmpty) _labeled('Years of Experience', application.yearsExperience),
                          if (application.education.isNotEmpty) _labeled('Education', application.education),
                          if (application.certifications.isNotEmpty) _labeled('Certifications', application.certifications),
                          if (application.professionalExperience.isNotEmpty) _labeled('Professional Experience', application.professionalExperience),
                          if (application.volunteerExperience.isNotEmpty) _labeled('Volunteer Experience', application.volunteerExperience),
                          if (application.previousSpeakingExperience.isNotEmpty) _labeled('Previous Speaking Experience', application.previousSpeakingExperience),
                        ],
                      ),
                    ),
                    const SectionHeader('Proposed Topic'),
                    BloomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _labeled('Speaking Topic', application.speakingTopic),
                          if (application.presentationTitle.isNotEmpty) _labeled('Presentation Title', application.presentationTitle),
                          _labeled('Description', application.presentationDescription),
                          if (application.targetAudiences.isNotEmpty) _labeled('Target Audience', application.targetAudiences.join(', ')),
                          _labeled('Availability', application.availability.label),
                        ],
                      ),
                    ),
                    if (application.expertiseAreas.isNotEmpty) ...[
                      const SectionHeader('Areas of Expertise'),
                      BloomCard(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: application.expertiseAreas.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 11.5)), backgroundColor: AppColors.royal.withValues(alpha: 0.06), side: BorderSide.none)).toList(),
                        ),
                      ),
                    ],
                    if (application.whySpeak.isNotEmpty) ...[
                      const SectionHeader('Why They Want to Speak'),
                      BloomCard(child: Text(application.whySpeak, style: const TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.4))),
                    ],
                    const SectionHeader('Date Submitted'),
                    BloomCard(child: Text(_formatDate(application.createdAt), style: const TextStyle(fontSize: 12.5, color: AppColors.ink))),
                    if (application.status == SpeakerStatus.approved) ...[
                      const SectionHeader('Bureau Visibility'),
                      BloomCard(
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Publish to Bureau', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  Text('Members can see this speaker when ON', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                                ],
                              ),
                            ),
                            Switch(value: application.published, onChanged: _working ? null : _togglePublished, activeThumbColor: AppColors.sage),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (application.status == SpeakerStatus.pending || application.status == SpeakerStatus.changesRequested) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _working ? null : () => _setStatus(SpeakerStatus.approved),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.sage, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _working ? null : _requestChanges,
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.amber), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('REQUEST CHANGES', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.amber)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _working ? null : () => _setStatus(SpeakerStatus.declined),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.coral), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('DECLINE', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.coral)),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _statusPill(SpeakerApplication application) {
    Color color;
    switch (application.status) {
      case SpeakerStatus.approved:
        color = AppColors.sage;
        break;
      case SpeakerStatus.changesRequested:
        color = AppColors.amber;
        break;
      case SpeakerStatus.declined:
        color = AppColors.coral;
        break;
      case SpeakerStatus.pending:
        color = AppColors.adminGoldDeep;
        break;
    }
    return StatusPill(application.status.label, color: color);
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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

  Widget _labeled(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4)),
        ],
      ),
    );
  }
}
