import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/bloom_reward.dart';
import '../../../models/partner_profile.dart';
import '../../../models/registration_data.dart';
import '../../../services/auth_service.dart';
import '../../../services/partner_service.dart';
import '../../../theme/app_theme.dart';
import '../../home_screen.dart';
import '../../partner/partner_dashboard_screen.dart';

/// Writes the partner profile, updates the user's role to 'partner', and
/// creates their first Bloom Reward — then shows the STEP 6 thank-you
/// message from the Community Partner Program spec.
class PartnerRegistrationComplete extends StatefulWidget {
  const PartnerRegistrationComplete({super.key});

  @override
  State<PartnerRegistrationComplete> createState() => _PartnerRegistrationCompleteState();
}

class _PartnerRegistrationCompleteState extends State<PartnerRegistrationComplete> {
  bool _saving = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _save());
  }

  Future<void> _save() async {
    final data = context.read<RegistrationData>();
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _saving = false;
        _error = 'You need to be signed in to finish this step.';
      });
      return;
    }

    try {
      await PartnerService.instance.createPartnerProfile(
        PartnerProfile(
          uid: uid,
          businessName: data.partnerBusinessName,
          contactPerson: data.partnerContactPerson,
          email: data.email,
          phone: data.phoneNumber,
          website: data.partnerWebsite,
          description: data.partnerDescription,
          supportTypes: data.partnerSupportTypes,
          contributionDetails: data.partnerContributionDetails,
          logoUrl: data.partnerLogoUrl,
          createdAt: DateTime.now(),
        ),
      );

      if (data.rewardName.isNotEmpty) {
        await PartnerService.instance.createReward(
          BloomReward(
            id: '',
            partnerUid: uid,
            partnerName: data.partnerBusinessName,
            name: data.rewardName,
            value: data.rewardValue,
            quantityAvailable: data.rewardQuantity,
            remainingQuantity: data.rewardQuantity,
            badgeCost: data.rewardBadgeCost,
            expirationDate: data.rewardExpiration,
            restrictions: data.rewardRestrictions.isEmpty ? null : data.rewardRestrictions,
            createdAt: DateTime.now(),
          ),
        );
      }

      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Something went wrong saving your partner profile: $e";
        });
      }
    }
  }

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
              if (_saving) ...[
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Setting Up Your Partner Profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'Saving your business details and reward offer. This only takes a few seconds — please don’t close this screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, height: 1.5),
                ),
              ] else if (_error != null) ...[
                const Icon(Icons.error_outline, color: AppColors.coral, size: 48),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
              ] else ...[
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  child: const Center(child: Text('❤️', style: TextStyle(fontSize: 38))),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Thank you for being a\nProject Bloom Girls 2 Women\nCommunity Partner!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white, height: 1.35),
                ),
                const SizedBox(height: 14),
                Text(
                  'Your generosity helps us encourage girls and women to participate, learn, achieve goals, build confidence, and continue blooming.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8), height: 1.5),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Together, we are Building a Nation of Bloomers —\nOne Girl and One Woman at a Time.™',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppColors.gold, height: 1.5),
                ),
                const SizedBox(height: 10),
                const Text('🌸 Bloom. Believe. Become.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'Your application is under review. A Project Bloom admin will approve your profile before it appears publicly and before your rewards go live.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
              const Spacer(flex: 4),
              if (!_saving)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => _error != null ? const HomeScreen() : const PartnerDashboardScreen()),
                      (route) => false,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.royalDeep,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Go to My Partner Dashboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
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
