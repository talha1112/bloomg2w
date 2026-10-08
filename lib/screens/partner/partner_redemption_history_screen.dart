import 'package:flutter/material.dart';

import '../../models/bloom_reward.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/status_pill.dart';

/// A Community Partner's own reward redemption history — never shows
/// unrelated partners' data, since watchRedemptionsForPartner queries by
/// the caller's own uid and Firestore rules scope reads the same way.
class PartnerRedemptionHistoryScreen extends StatelessWidget {
  const PartnerRedemptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return PageScaffold(
      title: 'Redemption History',
      children: [
        if (uid == null)
          const BloomCard(child: Text('Not signed in.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
        else
          StreamBuilder<List<RewardRedemption>>(
            stream: PartnerService.instance.watchRedemptionsForPartner(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: AppColors.royal)));
              }
              final redemptions = snapshot.data ?? [];
              if (redemptions.isEmpty) {
                return const BloomCard(child: Text('No redemptions yet.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
              }
              return Column(children: redemptions.map((r) => _RedemptionRow(redemption: r)).toList());
            },
          ),
      ],
    );
  }
}

class _RedemptionRow extends StatelessWidget {
  const _RedemptionRow({required this.redemption});

  final RewardRedemption redemption;

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final used = redemption.status == RedemptionStatus.used;
    return BloomCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(redemption.rewardName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(
                  used ? 'Redeemed ${_formatDate(redemption.usedAt)}' : 'Issued ${_formatDate(redemption.createdAt)}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          StatusPill(used ? 'Redeemed' : 'Issued', color: used ? AppColors.sage : AppColors.amber),
        ],
      ),
    );
  }
}
