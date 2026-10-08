import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'speaker_dashboard_screen.dart';

/// Shown immediately after a Guest Speaker application is submitted.
/// Per spec: submitting does NOT publish the speaker to the Bureau.
class SpeakerApplicationSubmittedScreen extends StatelessWidget {
  const SpeakerApplicationSubmittedScreen({super.key});

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
                child: const Center(child: Text('🎤', style: TextStyle(fontSize: 38))),
              ),
              const SizedBox(height: 24),
              const Text(
                'Thank you for your interest in becoming a\nProject Bloom Guest Speaker!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 14),
              Text(
                'Your profile has been submitted for review. You will be notified after your application has been reviewed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.82), height: 1.5),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SpeakerDashboardScreen()),
                    (route) => false,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.royalDeep,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('View Application Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
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
