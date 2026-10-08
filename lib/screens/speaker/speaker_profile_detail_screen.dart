import 'package:flutter/material.dart';

import '../../models/speaker_interest.dart';
import '../../models/speaker_profile.dart';
import '../../services/auth_service.dart';
import '../../services/speaker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import '../../widgets/common/bloom_network_image.dart';
import '../../widgets/common/section_header.dart';

/// Full speaker profile — never shows email, phone, or address, and
/// never enables direct member-to-speaker contact. All engagement goes
/// through the "I'm Interested" flow, coordinated by Project Bloom.
class SpeakerProfileDetailScreen extends StatelessWidget {
  const SpeakerProfileDetailScreen({super.key, required this.speaker});

  final SpeakerProfile speaker;

  Future<void> _expressInterest(BuildContext context) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    final result = await showModalBottomSheet<_InterestSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InterestSheet(speaker: speaker),
    );
    if (result == null) return;

    await SpeakerService.instance.submitInterest(
      SpeakerInterest(
        id: '',
        speakerUid: speaker.uid,
        speakerName: speaker.fullName,
        memberUid: uid,
        interestType: result.interestType,
        audienceGroup: result.audienceGroup,
        createdAt: DateTime.now(),
      ),
    );

    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: const Text('Thank you! Your interest has been submitted to Project Bloom.', style: TextStyle(fontSize: 13.5)),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(backgroundColor: AppColors.royalDeep, foregroundColor: Colors.white, title: const Text('Speaker Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.royal.withValues(alpha: 0.08),
                backgroundImage: speaker.photoUrl != null ? bloomNetworkImage(speaker.photoUrl!) : null,
                child: speaker.photoUrl == null ? const Icon(Icons.person, color: AppColors.royal, size: 44) : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(speaker.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.royalDeep))),
            if (speaker.professionalTitle.isNotEmpty || speaker.profession.isNotEmpty)
              Center(child: Text(speaker.professionalTitle.isNotEmpty ? speaker.professionalTitle : speaker.profession, style: const TextStyle(fontSize: 13.5, color: AppColors.ink))),
            if (speaker.organization.isNotEmpty) Center(child: Text(speaker.organization, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft))),
            if (speaker.yearsExperience.isNotEmpty) Center(child: Text('${speaker.yearsExperience} years of experience', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft))),
            if (speaker.professionalExperience.isNotEmpty) ...[
              const SectionHeader('Professional Experience'),
              BloomCard(child: Text(speaker.professionalExperience, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5))),
            ],
            const SectionHeader('🎤 Speaking Topics'),
            BloomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(speaker.speakingTopic, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.royal)),
                  if (speaker.presentationTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(speaker.presentationTitle, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
            const SectionHeader('About This Presentation'),
            BloomCard(child: Text(speaker.presentationDescription, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5))),
            if (speaker.targetAudiences.isNotEmpty) ...[
              const SectionHeader('Best For'),
              BloomCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: speaker.targetAudiences.map((a) => Chip(label: Text(a, style: const TextStyle(fontSize: 11.5)), backgroundColor: AppColors.teal.withValues(alpha: 0.1), side: BorderSide.none)).toList(),
                ),
              ),
            ],
            if (speaker.expertiseAreas.isNotEmpty) ...[
              const SectionHeader('Areas of Expertise'),
              BloomCard(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: speaker.expertiseAreas.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 11.5)), backgroundColor: AppColors.royal.withValues(alpha: 0.06), side: BorderSide.none)).toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _expressInterest(context),
                icon: const Icon(Icons.favorite, size: 18),
                style: FilledButton.styleFrom(backgroundColor: AppColors.coral, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                label: const Text("I'M INTERESTED IN THIS SPEAKER", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestSelection {
  _InterestSelection(this.interestType, this.audienceGroup);
  final InterestType interestType;
  final String audienceGroup;
}

class _InterestSheet extends StatefulWidget {
  const _InterestSheet({required this.speaker});
  final SpeakerProfile speaker;

  @override
  State<_InterestSheet> createState() => _InterestSheetState();
}

class _InterestSheetState extends State<_InterestSheet> {
  InterestType? _selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What are you interested in?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.royalDeep)),
            const SizedBox(height: 14),
            RadioGroup<InterestType>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              child: Column(
                children: InterestType.values.map(
                  (type) => RadioListTile<InterestType>(
                    value: type,
                    activeColor: AppColors.royal,
                    contentPadding: EdgeInsets.zero,
                    title: Text(type.label, style: const TextStyle(fontSize: 13)),
                  ),
                ).toList(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.of(context).pop(
                          _InterestSelection(_selected!, widget.speaker.targetAudiences.isNotEmpty ? widget.speaker.targetAudiences.first : ''),
                        ),
                style: FilledButton.styleFrom(backgroundColor: AppColors.royal, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('SUBMIT INTEREST', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
