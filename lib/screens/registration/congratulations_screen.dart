import 'package:flutter/material.dart';

import '../../services/role_router.dart';
import '../../theme/app_theme.dart';

class CongratulationsScreen extends StatelessWidget {
  const CongratulationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.royalDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                child: const Center(child: Text('🌸', style: TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 28),
              const Text(
                'Congratulations!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white),
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                  children: [
                    TextSpan(text: 'Welcome to Bloom'),
                    TextSpan(text: 'G2', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
                    TextSpan(text: 'W!'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your journey to bloom starts now.',
                style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.75)),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // Routes through RoleRouter rather than hardcoding
                  // HomeScreen — a freshly-registered Girl (minor) without
                  // a linked guardian yet must land on the waiting screen,
                  // not the normal app shell. RoleRouter is the single
                  // chokepoint that already applies this check for Login
                  // and session-restore; this is the one other entry point
                  // into the signed-in app and must apply the same rule.
                  onPressed: () => RoleRouter.routeSignedInUser(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.royalDeep,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Explore the App', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
