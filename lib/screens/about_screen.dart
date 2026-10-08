import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _learnMoreUrl = 'https://projectbloomgirls2women.org/about-us/';

  static const _coreOfferings = [
    'Virtual learning and skill-building opportunities',
    'Coaching and leadership sessions via Zoom',
    'Training, resources, incentives, and networking',
    'Community rewards through partnerships',
    'Whole-person development, wellness, and empowerment',
  ];

  Future<void> _learnMore(BuildContext context) async {
    final launched = await launchUrl(Uri.parse(_learnMoreUrl), mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open the link. Please try again later.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'About Bloom G2W',
      children: [
        BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Our Vision', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.royalDeep)),
              const SizedBox(height: 6),
              const Text(
                'We aspire to inspire ALL girls and women — across every background, race, and ethnicity — to emerge as powerful change-makers who achieve success and uplift others. Our vision centers on four commitments: empowering all girls and women, rising together as leaders, supporting success and growth, and lifting others to thrive.',
                style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.55),
              ),
              const SizedBox(height: 16),
              const Text('Our Mission', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.royalDeep)),
              const SizedBox(height: 6),
              const Text(
                'Blooming: From Girlhood to Womanhood. We empower girls ages 8–17 to develop into confident women, while supporting women ages 18–70+ through life\'s transitions — guiding every participant toward discovering her purpose through our B.M.E. framework: Body, Mind, and inner Energy.',
                style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.55),
              ),
            ],
          ),
        ),
        const SectionHeader('What We Offer'),
        BloomCard(
          child: Column(
            children: _coreOfferings
                .map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: AppColors.sage),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p, style: const TextStyle(fontSize: 13.5, color: AppColors.ink))),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        const SectionHeader('Why the Lotus'),
        const BloomCard(
          child: Text(
            'The lotus flower represents our core values — strength, resilience, purity, and success — reflecting how beauty and growth emerge from adversity. Our virtual platform lets girls and women connect locally and globally, receive meaningful support, and grow together in a safe, guided environment.',
            style: TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.55),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.royal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _learnMore(context),
            child: const Text('Learn More', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
