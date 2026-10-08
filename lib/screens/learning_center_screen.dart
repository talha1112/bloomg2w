import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/progress_bar.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/status_pill.dart';

class LearningCenterScreen extends StatelessWidget {
  const LearningCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Learning Center',
      children: [
        const SectionHeader('In Progress'),
        BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Confidence 101', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  StatusPill('4 videos', color: AppColors.cornflower, icon: Icons.play_circle_outline),
                ],
              ),
              const SizedBox(height: 10),
              const BloomProgressBar(value: 0.72),
              const SizedBox(height: 6),
              const Text('72% complete · Quiz pending', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
            ],
          ),
        ),
        const SectionHeader('Completed'),
        BloomCard(
          child: Row(
            children: [
              const Icon(Icons.workspace_premium, color: AppColors.amber, size: 26),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financial Literacy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('Certificate earned · Badge unlocked', style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              StatusPill('Done', color: AppColors.sage, icon: Icons.check),
            ],
          ),
        ),
        const SectionHeader('Explore Courses'),
        _courseTile('Leadership Lab', '6 videos · 1 quiz', AppColors.violet, Icons.groups_2_outlined),
        _courseTile('STEM for Girls', '8 videos · 2 quizzes', AppColors.teal, Icons.science_outlined),
        _courseTile('Public Speaking Basics', '5 videos · 1 quiz', AppColors.rose, Icons.record_voice_over_outlined),
        const SectionHeader('Learning Resources'),
        BloomCard(
          child: Column(
            children: [
              _resourceRow(Icons.picture_as_pdf_outlined, 'Bloom Workbook (PDF)'),
              const Divider(height: 20),
              _resourceRow(Icons.article_outlined, 'Parent Guide: Supporting Growth'),
              const Divider(height: 20),
              _resourceRow(Icons.ondemand_video_outlined, 'Video Library'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _courseTile(String title, String subtitle, Color color, IconData icon) {
    return BloomCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkSoft),
        ],
      ),
    );
  }

  Widget _resourceRow(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.royal, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
        const Icon(Icons.download_outlined, size: 18, color: AppColors.inkSoft),
      ],
    );
  }
}
