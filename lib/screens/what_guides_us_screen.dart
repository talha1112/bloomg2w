import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';

class WhatGuidesUsScreen extends StatelessWidget {
  const WhatGuidesUsScreen({super.key});

  static const _learnMoreUrl = 'https://projectbloomgirls2women.org/who-we-are/';

  static const _coreSolutions = [
    ('Life Skills', 'Empowering girls and women with practical abilities for everyday challenges that transform lives and generations.'),
    ('Education & Training', 'Supporting lifelong learning, growth, and empowerment for girls and women.'),
    ('Personal Development', 'Strengthening mind, body, and confidence while cultivating purpose and resilience.'),
  ];

  static const _guidingPrinciples = [
    'Follow Rules',
    'Be Self-Motivated',
    'Have Self Love & Self Esteem',
    'Positive Growth Mindset & Good Physical Health',
    'Maintain Positive Academic Standing',
    'Be Coachable',
    'Give and Take Feedback',
    'Respect Others',
    "Keep Going & Don't Give Up",
    'Be Inventive',
    'Participate in Fundraising & Volunteering',
    'Be a Lifelong Learner & Valued Citizen',
  ];

  static const _growthAreas = [
    'Personal Development',
    'Education and Training',
    'Emotional Intelligence',
    'Career Planning',
    'Entrepreneurship',
    'Role Modeling',
    'Domestic Violence, Sexual Abuse & Harassment Awareness',
    'Technology Awareness',
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
      title: 'What Guides Us',
      children: [
        BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Our Movement', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.royalDeep)),
              const SizedBox(height: 6),
              const Text(
                'We are a movement of growth, healing, and empowerment. We nurture the hearts and minds of girls, women, and mothers — helping them rise in confidence, walk in strength, and live with purpose. We believe that when women support one another, we don\'t just grow — we flourish.',
                style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.55),
              ),
            ],
          ),
        ),
        const SectionHeader('The Quote That Guides Us'),
        BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '"We don\'t choose where we begin, but we do choose how we grow and live."',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14.5, color: AppColors.royal, height: 1.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Text(
                'While circumstances of origin are beyond our control, we shape ourselves through intentional choices. This principle builds resilience, encourages rising above limitations, strengthens confidence, and supports purposeful empowerment.',
                style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.5),
              ),
            ],
          ),
        ),
        const SectionHeader('Our Core Solutions'),
        ..._coreSolutions.map(
          (s) => BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.royalDeep)),
                const SizedBox(height: 4),
                Text(s.$2, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.45)),
              ],
            ),
          ),
        ),
        const SectionHeader('Guiding Principles'),
        BloomCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _guidingPrinciples
                .map((p) => Chip(
                      label: Text(p, style: const TextStyle(fontSize: 11.5)),
                      backgroundColor: AppColors.royal.withValues(alpha: 0.06),
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
        ),
        const SectionHeader('Key Growth Areas'),
        BloomCard(
          child: Column(
            children: _growthAreas
                .map((g) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_right, size: 18, color: AppColors.teal),
                          const SizedBox(width: 4),
                          Expanded(child: Text(g, style: const TextStyle(fontSize: 13, color: AppColors.ink))),
                        ],
                      ),
                    ))
                .toList(),
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
