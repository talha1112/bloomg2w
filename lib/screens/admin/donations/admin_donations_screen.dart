import 'package:flutter/material.dart';

import '../../../models/donation.dart';
import '../../../services/partner_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/page_scaffold.dart';
import '../../../widgets/common/status_pill.dart';

/// Admin — Community Partner financial contributions. Every status shown
/// here is exactly what stripeWebhook last wrote; nothing here is
/// editable, since donation status is a trusted, server-confirmed fact.
class AdminDonationsScreen extends StatefulWidget {
  const AdminDonationsScreen({super.key});

  @override
  State<AdminDonationsScreen> createState() => _AdminDonationsScreenState();
}

class _AdminDonationsScreenState extends State<AdminDonationsScreen> {
  DonationStatus? _filter;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Donations',
      children: [
        StreamBuilder<List<Donation>>(
          stream: PartnerService.instance.watchAllDonations(),
          builder: (context, snapshot) {
            final donations = snapshot.data ?? [];
            // Failed, cancelled, and refunded attempts never became (or no
            // longer are) money received, so they're excluded — "Total" is
            // paid plus still-pending contributions.
            final total = donations.where((d) => d.status == DonationStatus.paid || d.status == DonationStatus.pending).fold(0, (sum, d) => sum + d.amount);
            final paid = donations.where((d) => d.status == DonationStatus.paid).fold(0, (sum, d) => sum + d.amount);
            final pending = donations.where((d) => d.status == DonationStatus.pending).fold(0, (sum, d) => sum + d.amount);

            final filtered = _filter == null ? donations : donations.where((d) => d.status == _filter).toList();

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _statTile('\$${(total / 100).toStringAsFixed(0)}', 'Total Contributions', AppColors.royal)),
                    const SizedBox(width: 10),
                    Expanded(child: _statTile('\$${(paid / 100).toStringAsFixed(0)}', 'Paid', AppColors.sage)),
                    const SizedBox(width: 10),
                    Expanded(child: _statTile('\$${(pending / 100).toStringAsFixed(0)}', 'Pending', AppColors.amber)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip('All', _filter == null, () => setState(() => _filter = null)),
                      const SizedBox(width: 8),
                      ...DonationStatus.values.map((s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _filterChip(s.label, _filter == s, () => setState(() => _filter = s)),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No donations in this view.', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)))
                else
                  ...filtered.map((d) => _DonationTile(donation: d, formatDate: _formatDate)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _statTile(String value, String label, Color color) {
    return BloomCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: selected ? AppColors.royal.withValues(alpha: 0.14) : Colors.white,
      labelStyle: TextStyle(color: selected ? AppColors.royal : AppColors.inkSoft, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
    );
  }
}

class _DonationTile extends StatelessWidget {
  const _DonationTile({required this.donation, required this.formatDate});

  final Donation donation;
  final String Function(DateTime) formatDate;

  Color get _statusColor {
    switch (donation.status) {
      case DonationStatus.paid:
        return AppColors.sage;
      case DonationStatus.pending:
        return AppColors.amber;
      case DonationStatus.failed:
      case DonationStatus.cancelled:
        return AppColors.coral;
      case DonationStatus.refunded:
        return AppColors.inkSoft;
    }
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
                Text(donation.partnerName.isEmpty ? '(Unknown Partner)' : donation.partnerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text('${donation.purpose} · ${formatDate(donation.createdAt)}', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                if (donation.stripePaymentIntentId != null) ...[
                  const SizedBox(height: 2),
                  Text('Stripe: ${donation.stripePaymentIntentId}', style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${donation.amountDollars.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.royalDeep)),
              const SizedBox(height: 4),
              StatusPill(donation.status.label, color: _statusColor),
            ],
          ),
        ],
      ),
    );
  }
}
