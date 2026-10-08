import 'package:flutter/material.dart';

import '../../models/bloom_reward.dart';
import '../../models/partner_profile.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import '../../widgets/common/bloom_network_image.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_pill.dart';
import '../login_screen.dart';
import 'partner_create_reward_screen.dart';
import 'partner_donation_screen.dart';
import 'partner_redemption_history_screen.dart';
import 'partner_verify_code_screen.dart';

class PartnerDashboardScreen extends StatelessWidget {
  const PartnerDashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Community Partner', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sign Out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: uid == null
            ? const Center(child: Text('Not signed in.'))
            : StreamBuilder<PartnerProfile?>(
                stream: PartnerService.instance.watchPartnerProfile(uid),
                builder: (context, profileSnapshot) {
                  final profile = profileSnapshot.data;
                  final isApproved = profile?.status == PartnerStatus.approved;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (profile != null && profile.status != PartnerStatus.approved) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: (profile.status == PartnerStatus.rejected ? AppColors.coral : AppColors.amber).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                profile.status == PartnerStatus.rejected ? Icons.cancel_outlined : Icons.hourglass_empty,
                                color: profile.status == PartnerStatus.rejected ? AppColors.coral : AppColors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  profile.status == PartnerStatus.rejected
                                      ? 'Your application was not approved. Contact Project Bloom for details.'
                                      : profile.status == PartnerStatus.suspended
                                          ? 'Your partner account is currently suspended.'
                                          : 'Your application is pending admin review. You can prepare rewards below, but nothing will be public until approved.',
                                  style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.royalDeep, Color(0xFF0C1440)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.adminGold.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              backgroundImage: profile?.logoUrl != null ? bloomNetworkImage(profile!.logoUrl!) : null,
                              child: profile?.logoUrl == null ? const Icon(Icons.storefront_outlined, color: AppColors.adminGold, size: 24) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile?.businessName.isNotEmpty == true ? profile!.businessName : 'Your Business',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Thank you for supporting Project Bloom G2W ❤️', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SectionHeader('Quick Actions'),
                      Row(
                        children: [
                          Expanded(
                            child: _actionCard(
                              context,
                              icon: Icons.add_card_outlined,
                              label: 'Create Reward',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerCreateRewardScreen())),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionCard(
                              context,
                              icon: Icons.qr_code_scanner_outlined,
                              label: 'Verify Code',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerVerifyCodeScreen())),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _actionCard(
                              context,
                              icon: Icons.volunteer_activism_outlined,
                              label: 'Financial Contribution',
                              onTap: isApproved ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerDonationScreen())) : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionCard(
                              context,
                              icon: Icons.history,
                              label: 'Redemption History',
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerRedemptionHistoryScreen())),
                            ),
                          ),
                        ],
                      ),
                      const SectionHeader('My Rewards'),
                      StreamBuilder<List<BloomReward>>(
                        stream: PartnerService.instance.watchPartnerRewards(uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator(color: AppColors.royal)),
                            );
                          }
                          final rewards = snapshot.data ?? [];
                          if (rewards.isEmpty) {
                            return const BloomCard(
                              child: Text('No rewards yet — create your first Bloom Reward above.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                            );
                          }
                          return Column(children: rewards.map((r) => _RewardTile(reward: r)).toList());
                        },
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _actionCard(BuildContext context, {required IconData icon, required String label, VoidCallback? onTap}) {
    final disabled = onTap == null;
    return BloomCard(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: disabled ? AppColors.inkSoft : AppColors.royal, shape: BoxShape.circle),
            child: Icon(icon, color: disabled ? Colors.white70 : AppColors.adminGold, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: disabled ? AppColors.inkSoft : AppColors.royalDeep)),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.reward});

  final BloomReward reward;

  @override
  Widget build(BuildContext context) {
    final isAvailable = reward.isAvailable;
    return BloomCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: (isAvailable ? AppColors.adminGold : AppColors.inkSoft).withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(Icons.card_giftcard, color: isAvailable ? AppColors.adminGoldDeep : AppColors.inkSoft, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  '\$${reward.value.toStringAsFixed(0)} · ${reward.remainingQuantity}/${reward.quantityAvailable} left · ${reward.badgeCost} badge${reward.badgeCost == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                ),
                if (reward.status == RewardStatus.rejected && reward.reviewNotes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Admin note: ${reward.reviewNotes}', style: const TextStyle(fontSize: 10.5, color: AppColors.coral)),
                ],
              ],
            ),
          ),
          StatusPill(
            _statusLabel(reward),
            color: isAvailable
                ? AppColors.sage
                : (reward.status == RewardStatus.rejected ? AppColors.coral : AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  String _statusLabel(BloomReward reward) {
    if (reward.status != RewardStatus.approved) return reward.status.label;
    if (!reward.active) return 'Paused';
    if (reward.remainingQuantity <= 0) return 'Out of Stock';
    return 'Active';
  }
}
