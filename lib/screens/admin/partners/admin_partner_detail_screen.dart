import 'package:flutter/material.dart';

import '../../../models/bloom_reward.dart';
import '../../../models/donation.dart';
import '../../../models/partner_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/partner_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/bloom_network_image.dart';
import '../../../widgets/common/section_header.dart';
import '../../../widgets/common/status_pill.dart';

/// Admin — full detail view of one Community Partner: business info,
/// approve/reject/suspend actions, their proposed rewards, donation
/// history, and redemption history. Never exposes another partner's
/// data (this screen is scoped to one partnerUid, fetched by the
/// caller's own admin-gated read).
class AdminPartnerDetailScreen extends StatefulWidget {
  const AdminPartnerDetailScreen({super.key, required this.partnerUid});

  final String partnerUid;

  @override
  State<AdminPartnerDetailScreen> createState() => _AdminPartnerDetailScreenState();
}

class _AdminPartnerDetailScreenState extends State<AdminPartnerDetailScreen> {
  bool _working = false;

  Future<void> _setStatus(PartnerStatus status) async {
    final adminUid = AuthService.instance.currentUser?.uid;
    if (adminUid == null) return;

    if (status == PartnerStatus.rejected || status == PartnerStatus.suspended) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(status == PartnerStatus.rejected ? 'Reject Partner?' : 'Suspend Partner?'),
          content: Text(status == PartnerStatus.rejected
              ? 'This partner will not be published to the directory and their rewards will remain hidden.'
              : 'This partner will be removed from the public directory. Their existing rewards remain but no longer appear in the marketplace once re-reviewed.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(status == PartnerStatus.rejected ? 'Reject' : 'Suspend', style: const TextStyle(color: AppColors.coral))),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _working = true);
    try {
      if (status == PartnerStatus.approved) {
        await PartnerService.instance.approvePartner(partnerUid: widget.partnerUid, adminUid: adminUid);
      } else {
        await PartnerService.instance.setPartnerStatus(partnerUid: widget.partnerUid, status: status, adminUid: adminUid);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Partner status set to ${status.label}.')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(backgroundColor: AppColors.royalDeep, foregroundColor: Colors.white, title: const Text('Partner Detail', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      body: SafeArea(
        child: StreamBuilder<PartnerProfile?>(
          stream: PartnerService.instance.watchPartnerProfile(widget.partnerUid),
          builder: (context, snapshot) {
            final partner = snapshot.data;
            if (partner == null) {
              return const Center(child: CircularProgressIndicator(color: AppColors.royal));
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 28, backgroundColor: AppColors.royal.withValues(alpha: 0.1), backgroundImage: partner.logoUrl != null ? bloomNetworkImage(partner.logoUrl!) : null, child: partner.logoUrl == null ? const Icon(Icons.storefront_outlined, color: AppColors.royal, size: 24) : null),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(partner.businessName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.royalDeep)),
                          const SizedBox(height: 4),
                          _statusPill(partner.status),
                        ],
                      ),
                    ),
                  ],
                ),
                const SectionHeader('Contact Information'),
                BloomCard(
                  child: Column(
                    children: [
                      _row('Contact', partner.contactPerson),
                      const Divider(height: 18),
                      _row('Email', partner.email),
                      const Divider(height: 18),
                      _row('Phone', partner.phone.isEmpty ? '—' : partner.phone),
                      const Divider(height: 18),
                      _row('Website', partner.website.isEmpty ? '—' : partner.website),
                    ],
                  ),
                ),
                const SectionHeader('How They Support'),
                BloomCard(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: partner.supportTypes.map((t) => Chip(label: Text(t, style: const TextStyle(fontSize: 11)))).toList(),
                  ),
                ),
                const SectionHeader('Business Description'),
                BloomCard(child: Text(partner.description.isEmpty ? 'No description provided.' : partner.description, style: const TextStyle(fontSize: 13, height: 1.5))),
                const SectionHeader('Contribution Details'),
                BloomCard(child: Text(partner.contributionDetails.isEmpty ? 'No contribution details provided.' : partner.contributionDetails, style: const TextStyle(fontSize: 13, height: 1.5))),
                const SectionHeader('Manage Partner'),
                Row(
                  children: [
                    if (partner.status != PartnerStatus.approved)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : () => _setStatus(PartnerStatus.approved),
                          icon: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.sage),
                          label: const Text('Approve', style: TextStyle(color: AppColors.sage, fontWeight: FontWeight.w700, fontSize: 12)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.sage), padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    if (partner.status != PartnerStatus.rejected) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : () => _setStatus(PartnerStatus.rejected),
                          icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.coral),
                          label: const Text('Reject', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700, fontSize: 12)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.coral), padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                    if (partner.status == PartnerStatus.approved) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : () => _setStatus(PartnerStatus.suspended),
                          icon: const Icon(Icons.pause_circle_outline, size: 16, color: AppColors.inkSoft),
                          label: const Text('Suspend', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w700, fontSize: 12)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.inkSoft), padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SectionHeader('Rewards Proposed'),
                StreamBuilder<List<BloomReward>>(
                  stream: PartnerService.instance.watchPartnerRewards(widget.partnerUid),
                  builder: (context, rewardSnapshot) {
                    final rewards = rewardSnapshot.data ?? [];
                    if (rewards.isEmpty) {
                      return const BloomCard(child: Text('No rewards proposed yet.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
                    }
                    return Column(children: rewards.map((r) => _AdminRewardTile(reward: r)).toList());
                  },
                ),
                const SectionHeader('Donation History'),
                StreamBuilder<List<Donation>>(
                  stream: PartnerService.instance.watchDonationsForPartner(widget.partnerUid),
                  builder: (context, donationSnapshot) {
                    final donations = donationSnapshot.data ?? [];
                    if (donations.isEmpty) {
                      return const BloomCard(child: Text('No donations yet.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
                    }
                    return BloomCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < donations.length; i++) ...[
                            if (i > 0) const Divider(height: 20),
                            _donationRow(donations[i]),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusPill(PartnerStatus status) {
    Color color;
    switch (status) {
      case PartnerStatus.approved:
        color = AppColors.sage;
        break;
      case PartnerStatus.pending:
        color = AppColors.amber;
        break;
      case PartnerStatus.rejected:
        color = AppColors.coral;
        break;
      case PartnerStatus.suspended:
        color = AppColors.inkSoft;
        break;
    }
    return StatusPill(status.label, color: color);
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
      ],
    );
  }

  Widget _donationRow(Donation d) {
    return Row(
      children: [
        Expanded(child: Text(d.purpose, style: const TextStyle(fontSize: 12.5))),
        Text('\$${d.amountDollars.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        StatusPill(d.status.label, color: d.status == DonationStatus.paid ? AppColors.sage : AppColors.inkSoft),
      ],
    );
  }
}

class _AdminRewardTile extends StatelessWidget {
  const _AdminRewardTile({required this.reward});

  final BloomReward reward;

  Future<void> _review(BuildContext context, RewardStatus status) async {
    String reviewNotes = '';
    if (status == RewardStatus.rejected) {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject Reward?'),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason (shown to partner)')),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Reject', style: TextStyle(color: AppColors.coral))),
          ],
        ),
      );
      if (confirmed != true) return;
      reviewNotes = controller.text.trim();
    }
    await PartnerService.instance.setRewardStatus(rewardId: reward.id, status: status, reviewNotes: reviewNotes);
  }

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text('\$${reward.value.toStringAsFixed(0)} · ${reward.quantityAvailable} available · ${reward.badgeCost} badge${reward.badgeCost == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
          ),
          if (reward.status == RewardStatus.pending) ...[
            IconButton(icon: const Icon(Icons.check_circle_outline, color: AppColors.sage), onPressed: () => _review(context, RewardStatus.approved)),
            IconButton(icon: const Icon(Icons.cancel_outlined, color: AppColors.coral), onPressed: () => _review(context, RewardStatus.rejected)),
          ] else
            StatusPill(reward.status.label, color: reward.status == RewardStatus.approved ? AppColors.sage : AppColors.inkSoft),
        ],
      ),
    );
  }
}
