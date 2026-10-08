import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuoteFooterCard extends StatelessWidget {
  const QuoteFooterCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.royalDeep,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.5, fontFamily: 'Georgia'),
                children: [
                  const TextSpan(text: '“Life is like a flower,\nyou may bloom '),
                  TextSpan(text: 'early', style: TextStyle(color: AppColors.gold, fontStyle: FontStyle.italic)),
                  const TextSpan(text: ',\nyou may bloom '),
                  TextSpan(text: 'late', style: TextStyle(color: AppColors.gold, fontStyle: FontStyle.italic)),
                  const TextSpan(text: ',\njust don\'t forget to '),
                  TextSpan(text: 'bloom.', style: TextStyle(color: AppColors.gold, fontStyle: FontStyle.italic)),
                  const TextSpan(text: '”'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Icon(Icons.spa, color: AppColors.gold, size: 40),
              const SizedBox(height: 4),
              Text(
                'The Lotus',
                style: TextStyle(color: AppColors.gold, fontStyle: FontStyle.italic, fontSize: 12, fontFamily: 'Georgia'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
