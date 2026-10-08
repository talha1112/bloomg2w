import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/bloom_reward.dart';
import '../models/session_badge.dart';
import '../services/auth_service.dart';
import '../services/partner_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/status_pill.dart';

/// Real, Firestore-backed Rewards Marketplace. Unspent badge count gates
/// eligibility; redemption itself always goes through the redeemReward
/// Cloud Function (atomic badge deduction + unique code) — this screen
/// never deducts a badge or mints a code client-side.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return PageScaffold(
      title: 'Rewards',
      children: [
        if (uid == null)
          const BloomCard(child: Text('Log in to see your rewards.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
        else ...[
          StreamBuilder<List<SessionBadge>>(
            stream: SessionService.instance.watchBadgesForUser(uid),
            builder: (context, badgeSnapshot) {
              final badges = badgeSnapshot.data ?? [];
              final unspent = badges.where((b) => !b.isSpent).length;
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.royalDeep, AppColors.royal]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: AppColors.gold, size: 30),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$unspent', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
                        const Text('Unspent Badges', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SectionHeader('Available Rewards'),
          StreamBuilder<List<SessionBadge>>(
            stream: SessionService.instance.watchBadgesForUser(uid),
            builder: (context, badgeSnapshot) {
              final unspentBadges = (badgeSnapshot.data ?? []).where((b) => !b.isSpent).length;
              return StreamBuilder<List<BloomReward>>(
                stream: PartnerService.instance.watchMarketplaceRewards(),
                builder: (context, rewardSnapshot) {
                  if (rewardSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: AppColors.royal)));
                  }
                  final rewards = (rewardSnapshot.data ?? []).where((r) => r.isAvailable).toList();
                  if (rewards.isEmpty) {
                    return const BloomCard(child: Text('No rewards available right now — check back soon!', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
                  }
                  return Column(children: rewards.map((r) => _RewardTile(reward: r, unspentBadges: unspentBadges)).toList());
                },
              );
            },
          ),
          const SectionHeader('My Redemptions'),
          StreamBuilder<List<RewardRedemption>>(
            stream: PartnerService.instance.watchRedemptionsForParticipant(uid),
            builder: (context, snapshot) {
              final redemptions = snapshot.data ?? [];
              if (redemptions.isEmpty) {
                return const BloomCard(child: Text('No redemptions yet.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
              }
              return Column(children: redemptions.map((r) => _RedemptionTile(redemption: r)).toList());
            },
          ),
        ],
      ],
    );
  }
}

/// Shows a participant's redemption code both as text and as a QR code
/// (encoding the code itself) that a Community Partner can scan if they
/// have their own QR-capable verification tooling — the built-in partner
/// verification screen accepts manual code entry either way, so QR here
/// is a convenience for the participant, not a requirement for partners.
Future<void> showRedemptionCodeDialog(BuildContext context, {required String partnerName, required String code}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Your Reward Code 🎉'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Show this to $partnerName to claim your reward:', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          QrImageView(data: code, size: 160, backgroundColor: Colors.white),
          const SizedBox(height: 16),
          Text(code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 3, color: AppColors.royalDeep)),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
    ),
  );
}

class _RewardTile extends StatefulWidget {
  const _RewardTile({required this.reward, required this.unspentBadges});

  final BloomReward reward;
  final int unspentBadges;

  @override
  State<_RewardTile> createState() => _RewardTileState();
}

class _RewardTileState extends State<_RewardTile> {
  bool _redeeming = false;

  Future<void> _redeem() async {
    setState(() => _redeeming = true);
    try {
      final code = await PartnerService.instance.redeemReward(widget.reward.id);
      if (mounted) {
        await showRedemptionCodeDialog(context, partnerName: widget.reward.partnerName, code: code);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not redeem: $e')));
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.reward;
    final canAfford = widget.unspentBadges >= reward.badgeCost;
    return BloomCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.royal, shape: BoxShape.circle),
            child: const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text('${reward.badgeCost} badge${reward.badgeCost == 1 ? '' : 's'} · ${reward.partnerName}', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          canAfford
              ? FilledButton(
                  onPressed: _redeeming ? null : _redeem,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.royal, padding: const EdgeInsets.symmetric(horizontal: 14)),
                  child: Text(_redeeming ? '…' : 'Redeem', style: const TextStyle(fontSize: 11.5)),
                )
              : StatusPill('Locked', color: AppColors.inkSoft, icon: Icons.lock_outline),
        ],
      ),
    );
  }
}

class _RedemptionTile extends StatelessWidget {
  const _RedemptionTile({required this.redemption});

  final RewardRedemption redemption;

  @override
  Widget build(BuildContext context) {
    final used = redemption.status == RedemptionStatus.used;
    return BloomCard(
      onTap: used ? null : () => showRedemptionCodeDialog(context, partnerName: redemption.partnerName, code: redemption.code),
      child: Row(
        children: [
          Icon(used ? Icons.check_circle : Icons.pending_outlined, color: used ? AppColors.sage : AppColors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(redemption.rewardName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                Text('Code: ${redemption.code}', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
          ),
          StatusPill(used ? 'Used' : 'Pending', color: used ? AppColors.sage : AppColors.amber),
        ],
      ),
    );
  }
}
