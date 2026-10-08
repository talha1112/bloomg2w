import 'package:flutter/material.dart';

import '../../models/speaker_profile.dart';
import '../../services/speaker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import '../../widgets/common/bloom_network_image.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/section_header.dart';
import 'speaker_profile_detail_screen.dart';

/// 🎙️ Guest Speakers Bureau — only approved AND published speakers
/// (from speaker_profiles, which contains no PII) appear here.
class SpeakerBureauScreen extends StatefulWidget {
  const SpeakerBureauScreen({super.key});

  @override
  State<SpeakerBureauScreen> createState() => _SpeakerBureauScreenState();
}

class _SpeakerBureauScreenState extends State<SpeakerBureauScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Guest Speakers Bureau',
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search by topic (confidence, career, STEM…)',
            prefixIcon: const Icon(Icons.search, color: AppColors.inkSoft),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SectionHeader('Browse Speakers'),
        StreamBuilder<List<SpeakerProfile>>(
          stream: SpeakerService.instance.watchPublishedSpeakers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: AppColors.royal)));
            }
            final speakers = snapshot.data ?? [];
            final filtered = _query.isEmpty
                ? speakers
                : speakers.where((s) {
                    final q = _query.toLowerCase();
                    return s.fullName.toLowerCase().contains(q) ||
                        s.speakingTopic.toLowerCase().contains(q) ||
                        s.expertiseAreas.any((e) => e.toLowerCase().contains(q));
                  }).toList();

            if (filtered.isEmpty) {
              return const BloomCard(child: Text('No speakers found.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
            }

            return Column(children: filtered.map((s) => _SpeakerCard(speaker: s)).toList());
          },
        ),
      ],
    );
  }
}

class _SpeakerCard extends StatelessWidget {
  const _SpeakerCard({required this.speaker});

  final SpeakerProfile speaker;

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SpeakerProfileDetailScreen(speaker: speaker))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.royal.withValues(alpha: 0.08),
            backgroundImage: speaker.photoUrl != null ? bloomNetworkImage(speaker.photoUrl!) : null,
            child: speaker.photoUrl == null ? const Icon(Icons.person, color: AppColors.royal) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(speaker.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.royalDeep)),
                const SizedBox(height: 2),
                Text(
                  speaker.professionalTitle.isNotEmpty ? speaker.professionalTitle : speaker.profession,
                  style: const TextStyle(fontSize: 12, color: AppColors.ink),
                ),
                if (speaker.yearsExperience.isNotEmpty) Text('${speaker.yearsExperience} yrs experience', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                const SizedBox(height: 6),
                Text(speaker.speakingTopic, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.royal)),
                if (speaker.expertiseAreas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: speaker.expertiseAreas.take(3).map((e) => Chip(
                          label: Text(e, style: const TextStyle(fontSize: 10.5)),
                          backgroundColor: AppColors.royal.withValues(alpha: 0.06),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                  ),
                ],
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('VIEW PROFILE →', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.royal)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
