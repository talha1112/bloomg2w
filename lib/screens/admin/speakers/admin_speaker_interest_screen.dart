import 'package:flutter/material.dart';

import '../../../models/speaker_interest.dart';
import '../../../services/speaker_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';

/// Admin — Speaker Interest Tracking. Groups every speaker_interests
/// record by speaker so admins can see who to prioritize scheduling.
class AdminSpeakerInterestScreen extends StatelessWidget {
  const AdminSpeakerInterestScreen({super.key});

  Future<void> _scheduleSpeaker(BuildContext context, String speakerUid, String speakerName) async {
    final toNotify = await SpeakerService.instance.fetchUnnotifiedScheduleRequests(speakerUid);
    for (final interest in toNotify) {
      await SpeakerService.instance.markInterestNotified(interest.id);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            toNotify.isEmpty
                ? '$speakerName marked as scheduled.'
                : '$speakerName marked as scheduled — ${toNotify.length} member${toNotify.length == 1 ? '' : 's'} notified.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Speaker Interest Tracking', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: StreamBuilder<List<SpeakerInterest>>(
          stream: SpeakerService.instance.watchAllInterests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.royal));
            }
            final interests = snapshot.data ?? [];
            if (interests.isEmpty) {
              return const Center(child: Text('No interest submitted yet.', style: TextStyle(color: AppColors.inkSoft)));
            }

            final bySpeaker = <String, List<SpeakerInterest>>{};
            for (final interest in interests) {
              bySpeaker.putIfAbsent(interest.speakerUid, () => []).add(interest);
            }
            final entries = bySpeaker.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final speakerInterests = entries[i].value;
                final speakerUid = entries[i].key;
                final speakerName = speakerInterests.first.speakerName;

                final audienceCounts = <String, int>{};
                for (final interest in speakerInterests) {
                  audienceCounts.update(interest.audienceGroup.isEmpty ? 'Unspecified' : interest.audienceGroup, (v) => v + 1, ifAbsent: () => 1);
                }
                final scheduleRequests = speakerInterests.where((i) => i.interestType == InterestType.scheduleRequest).length;
                final topAudience = audienceCounts.isEmpty ? '—' : (audienceCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;

                return BloomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(speakerName.isEmpty ? 'Unnamed Speaker' : speakerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.royalDeep)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.favorite, color: AppColors.coral, size: 16),
                          const SizedBox(width: 4),
                          Text('${speakerInterests.length} Members Interested', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Audience showing interest: $topAudience', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                      if (scheduleRequests > 0) ...[
                        const SizedBox(height: 4),
                        Text('$scheduleRequests requested Project Bloom schedule this speaker', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _scheduleSpeaker(context, speakerUid, speakerName),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                          child: const Text('Schedule Speaker →', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
