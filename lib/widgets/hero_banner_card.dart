import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HeroBannerCard extends StatelessWidget {
  const HeroBannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          SizedBox(
            height: 300,
            width: double.infinity,
            child: Image.asset('assets/images/hero_banner.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.royalDeep.withValues(alpha: 0.88),
                    AppColors.royalDeep.withValues(alpha: 0.15),
                  ],
                  stops: const [0.42, 0.95],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome to',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                      height: 1.02,
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(text: 'Bloom\n'),
                      TextSpan(text: 'G2', style: TextStyle(color: AppColors.gold)),
                      TextSpan(text: 'W'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bloom. Believe. Become.',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Empowering girls and women to grow with confidence,\nlead with purpose, and bloom into their brightest future.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            bottom: 12,
            child: Text(
              '✦ SEEDING A NATION OF BLOOMERS ✦',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
