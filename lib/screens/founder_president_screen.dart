import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';

class FounderPresidentScreen extends StatelessWidget {
  const FounderPresidentScreen({super.key});

  static const _learnMoreUrl = 'https://projectbloomgirls2women.org/president-2/';

  static const _degrees = [
    "Associate Degree in Applied Science (A.A.S.)",
    "Bachelor's Degree in Business Administration (B.B.A.)",
    "Two Master's Degrees (M.A. and M.S.A.)",
    "Post-Master's Educational Specialization (Ed.S.)",
    'PhD in Organizational Studies',
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
      title: 'Founder & President',
      children: [
        Center(
          child: Column(
            children: [
              const CircleAvatar(radius: 44, backgroundColor: AppColors.royal, backgroundImage: AssetImage('assets/images/founder_president.png')),
              const SizedBox(height: 12),
              const Text('Dr. Vicki Golden, PhD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.royalDeep)),
              const Text('Founder & President, Bloom G2W', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
            ],
          ),
        ),
        const SectionHeader('A Message From Dr. Golden'),
        const BloomCard(
          child: Text(
            '"Our dreams are powered by a higher source. Shift your mindset — see beyond where you are, become who you\'re called to be, and never give up."',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14, color: AppColors.royal, height: 1.5, fontWeight: FontWeight.w600),
          ),
        ),
        BloomCard(
          child: const Text(
            'Dr. Golden has faced significant challenges and adversity that tested her resilience and determination. She found strength and clarity through purpose and passion. Through active coaching, she mentors and empowers young women to rise with purpose, guiding girls into confident, capable leaders while inviting them to grow and bloom into their fullest potential.',
            style: TextStyle(fontSize: 13, color: AppColors.ink, height: 1.55),
          ),
        ),
        const SectionHeader('Her Story: A Purpose Close to Her Heart'),
        const BloomCard(
          child: Text(
            "Dr. Golden's mission is deeply personal. For over 30 years, she attended college both full-time and part-time while raising four daughters as a single mother — working full-time, attending classes at night, and managing her home and children while overcoming life's many challenges. These experiences taught her strength, resilience, the value of guidance and encouragement, and the importance of having someone who stands with you. She wants to be the support she once needed, believing no woman or girl should struggle alone.",
            style: TextStyle(fontSize: 13, color: AppColors.ink, height: 1.55),
          ),
        ),
        const SectionHeader('From a GED to a PhD'),
        BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'At age 16, Dr. Golden left school with a fourth-grade reading level. She married young, then made the pivotal decision to change her life. She earned her GED and continued her education at night while raising four children as a single mother. Over 25 years, she earned six college degrees:',
                style: TextStyle(fontSize: 13, color: AppColors.ink, height: 1.55),
              ),
              const SizedBox(height: 10),
              ..._degrees.map(
                (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 15, color: AppColors.sage),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d, style: const TextStyle(fontSize: 12.5, color: AppColors.ink))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Her journey demonstrates that faith, perseverance, and purpose can rewrite any story.',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.inkSoft, height: 1.5),
              ),
            ],
          ),
        ),
        const SectionHeader('Expertise & Impact'),
        BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _ImpactItem(title: 'Education & Training Expert', body: 'Executive leader, Chief Learning Officer, and professor with 20+ years of experience empowering girls and women through strategic education and training.'),
              SizedBox(height: 12),
              _ImpactItem(title: 'Transformational Fundraising Leader', body: 'Drives strategic fundraising, secures sustainable funding, and builds strong partnerships to expand opportunity and create lasting impact.'),
              SizedBox(height: 12),
              _ImpactItem(title: 'Supporting Positive Change', body: 'Builds hope and insight where struggle has lived unseen, giving voice, support, and direction to those often overlooked.'),
              SizedBox(height: 12),
              _ImpactItem(title: 'Community Growth & Engagement', body: 'Advocates for girls and women by creating spaces for growth, voice, and opportunity through community involvement and giving back.'),
            ],
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

class _ImpactItem extends StatelessWidget {
  const _ImpactItem({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep)),
        const SizedBox(height: 3),
        Text(body, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.45)),
      ],
    );
  }
}
