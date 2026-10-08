import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/signature_program.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';

/// 🌸 Our Signature Programs — each "Learn More" opens the corresponding
/// page on the Project Bloom Girls 2 Women website in the device browser.
class SignatureProgramsScreen extends StatelessWidget {
  const SignatureProgramsScreen({super.key});

  Future<void> _openProgram(BuildContext context, SignatureProgram program) async {
    final uri = Uri.parse(program.url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't open ${program.title}. Please try again later.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Our Signature Programs',
      children: [
        const Text(
          '🌸 Explore the programs Project Bloom Girls 2 Women offers to help girls and women bloom into their purpose.',
          style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.5),
        ),
        const SizedBox(height: 16),
        ...kSignaturePrograms.map((program) => _ProgramCard(program: program, onLearnMore: () => _openProgram(context, program))),
      ],
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program, required this.onLearnMore});

  final SignatureProgram program;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: program.color, shape: BoxShape.circle),
            child: Icon(program.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.royalDeep)),
                const SizedBox(height: 4),
                Text(program.description, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.4)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: onLearnMore,
                  child: Text('Learn More →', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: program.color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
