import 'package:flutter/material.dart';

import '../../../models/partner_profile.dart';
import '../../../services/partner_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/page_scaffold.dart';
import '../../../widgets/common/status_pill.dart';
import 'admin_partner_detail_screen.dart';

/// Admin — Community Partner management. Lists every partner with a
/// status filter; tapping one opens the detail/approval screen.
class AdminPartnersScreen extends StatefulWidget {
  const AdminPartnersScreen({super.key});

  @override
  State<AdminPartnersScreen> createState() => _AdminPartnersScreenState();
}

class _AdminPartnersScreenState extends State<AdminPartnersScreen> {
  PartnerStatus? _filter;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Community Partners',
      children: [
        StreamBuilder<List<PartnerProfile>>(
          stream: PartnerService.instance.watchAllPartners(),
          builder: (context, snapshot) {
            final partners = snapshot.data ?? [];
            final counts = {for (final s in PartnerStatus.values) s: partners.where((p) => p.status == s).length};

            final filtered = _filter == null ? partners : partners.where((p) => p.status == _filter).toList();

            return Column(
              children: [
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip('All', partners.length, _filter == null, () => setState(() => _filter = null)),
                      const SizedBox(width: 8),
                      ...PartnerStatus.values.map((s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _filterChip(s.label, counts[s] ?? 0, _filter == s, () => setState(() => _filter = s)),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No partners in this view.', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                  )
                else
                  ...filtered.map((p) => _PartnerTile(partner: p)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _filterChip(String label, int count, bool selected, VoidCallback onTap) {
    return ActionChip(
      label: Text('$label ($count)', style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: selected ? AppColors.royal.withValues(alpha: 0.14) : Colors.white,
      labelStyle: TextStyle(color: selected ? AppColors.royal : AppColors.inkSoft, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
    );
  }
}

class _PartnerTile extends StatelessWidget {
  const _PartnerTile({required this.partner});

  final PartnerProfile partner;

  Color get _statusColor {
    switch (partner.status) {
      case PartnerStatus.approved:
        return AppColors.sage;
      case PartnerStatus.pending:
        return AppColors.amber;
      case PartnerStatus.rejected:
        return AppColors.coral;
      case PartnerStatus.suspended:
        return AppColors.inkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminPartnerDetailScreen(partnerUid: partner.uid))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partner.businessName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(partner.contactPerson, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          StatusPill(partner.status.label, color: _statusColor),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}
