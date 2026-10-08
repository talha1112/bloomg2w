import 'package:flutter/material.dart';

import '../models/bloom_reward.dart';
import '../models/public_partner_profile.dart';
import '../services/partner_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/bloom_network_image.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/status_pill.dart';

/// Member-facing view. Admin-only fields (contact person, email, phone,
/// address, donation records) are intentionally not rendered here —
/// see AdminDashboardScreen > "Approve community partners" / partner management.
class CommunityPartnersScreen extends StatefulWidget {
  const CommunityPartnersScreen({super.key});

  @override
  State<CommunityPartnersScreen> createState() => _CommunityPartnersScreenState();
}

class _CommunityPartnersScreenState extends State<CommunityPartnersScreen> {
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Community Partners',
      children: [
        StreamBuilder<List<PublicPartnerProfile>>(
          stream: PartnerService.instance.watchPublicPartnerDirectory(),
          builder: (context, partnerSnapshot) {
            if (partnerSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.royal)),
              );
            }

            final partners = partnerSnapshot.data ?? [];
            if (partners.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No Community Partners yet — check back soon!',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final categories = <String>{for (final p in partners) ...p.supportTypes}.toList()..sort();
            final filtered = _categoryFilter == null ? partners : partners.where((p) => p.supportTypes.contains(_categoryFilter)).toList();

            return StreamBuilder<List<BloomReward>>(
              stream: PartnerService.instance.watchMarketplaceRewards(),
              builder: (context, rewardSnapshot) {
                final rewards = rewardSnapshot.data ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categories.isNotEmpty) ...[
                      const SectionHeader('Ways They Support Us'),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _categoryChip('All', null),
                            ...categories.map((c) => _categoryChip(c, c)),
                          ],
                        ),
                      ),
                    ],
                    const SectionHeader('Business Directory'),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No partners match that filter.', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                      )
                    else
                      ...filtered.map((p) => _PartnerCard(partner: p, rewards: rewards.where((r) => r.partnerUid == p.uid).toList())),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _categoryChip(String label, String? value) {
    final selected = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.royal)),
        selected: selected,
        onSelected: (_) => setState(() => _categoryFilter = value),
        selectedColor: AppColors.royal,
        backgroundColor: AppColors.royal.withValues(alpha: 0.06),
        side: BorderSide.none,
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner, required this.rewards});

  final PublicPartnerProfile partner;
  final List<BloomReward> rewards;

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.royal, width: 1.5),
              image: partner.logoUrl != null ? DecorationImage(image: bloomNetworkImage(partner.logoUrl!), fit: BoxFit.cover) : null,
            ),
            child: partner.logoUrl == null ? const Icon(Icons.storefront, color: AppColors.royalDeep, size: 20) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.businessName.isEmpty ? '(Unnamed Business)' : partner.businessName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                if (partner.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(partner.description, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft, height: 1.3)),
                ],
                if (rewards.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: rewards.map((r) => StatusPill(r.name, color: AppColors.amber, icon: Icons.qr_code_2)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
