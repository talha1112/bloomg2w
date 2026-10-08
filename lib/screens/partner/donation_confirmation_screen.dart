import 'package:flutter/material.dart';

import '../../models/donation.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import 'partner_dashboard_screen.dart';

/// Shown immediately after handing off to Stripe Checkout. Deliberately
/// does NOT claim success — it reads the donation's real status live from
/// Firestore, which only the stripeWebhook Cloud Function ever updates
/// once Stripe confirms the payment. Returning to the app proves nothing
/// on its own; a "pending" status here is expected and correct until the
/// webhook fires (usually within seconds).
class DonationConfirmationScreen extends StatelessWidget {
  const DonationConfirmationScreen({super.key, required this.donationId, this.checkoutCancelled = false});

  final String donationId;

  /// True when Stripe redirected to the cancel URL. The donation stays
  /// 'pending' until Stripe expires the session (hours later), so without
  /// this the screen would spin on "Confirming…" for a payment the partner
  /// deliberately abandoned.
  final bool checkoutCancelled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Contribution Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: StreamBuilder<Donation?>(
          stream: PartnerService.instance.watchDonation(donationId),
          builder: (context, snapshot) {
            final donation = snapshot.data;
            // A cancelled checkout leaves the record 'pending' until Stripe
            // expires the session; present it as cancelled rather than as an
            // endless "confirming" spinner. A real payment always wins: once
            // the webhook marks it paid, 'paid' is shown regardless.
            final status = (checkoutCancelled && (donation == null || donation.status == DonationStatus.pending)) ? DonationStatus.cancelled : donation?.status;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 24),
                Center(child: _statusIcon(status)),
                const SizedBox(height: 20),
                Text(_statusHeadline(status), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.royalDeep)),
                const SizedBox(height: 8),
                Text(_statusMessage(status), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.5)),
                if (status == DonationStatus.pending || status == null) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'If you closed or cancelled the Stripe payment page, no charge was made — you can safely go back to your dashboard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft, height: 1.4),
                  ),
                ],
                if (donation != null) ...[
                  const SizedBox(height: 20),
                  BloomCard(
                    child: Column(
                      children: [
                        _row('Amount', '\$${donation.amountDollars.toStringAsFixed(2)}'),
                        const Divider(height: 20),
                        _row('Purpose', donation.purpose),
                        const Divider(height: 20),
                        _row('Status', (status ?? donation.status).label),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const PartnerDashboardScreen()),
                      (route) => false,
                    ),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.royal, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Back to Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusIcon(DonationStatus? status) {
    switch (status) {
      case DonationStatus.paid:
        return const Icon(Icons.check_circle, color: AppColors.sage, size: 64);
      case DonationStatus.failed:
      case DonationStatus.cancelled:
        return const Icon(Icons.cancel_outlined, color: AppColors.coral, size: 64);
      default:
        return const SizedBox(width: 64, height: 64, child: CircularProgressIndicator(color: AppColors.royal, strokeWidth: 3));
    }
  }

  String _statusHeadline(DonationStatus? status) {
    switch (status) {
      case DonationStatus.paid:
        return 'Thank You! 🌸';
      case DonationStatus.failed:
        return 'Payment Failed';
      case DonationStatus.cancelled:
        return 'Checkout Cancelled';
      default:
        return 'Confirming Your Payment…';
    }
  }

  String _statusMessage(DonationStatus? status) {
    switch (status) {
      case DonationStatus.paid:
        return 'Your contribution has been received and confirmed. Thank you for supporting Project Bloom Girls 2 Women!';
      case DonationStatus.failed:
        return 'Stripe reported this payment did not complete. No charge was made. You can try again from your dashboard.';
      case DonationStatus.cancelled:
        return 'The checkout was cancelled before payment. No charge was made.';
      default:
        return 'We\'re waiting for Stripe to confirm your payment — this usually takes just a few seconds. This page will update automatically.';
    }
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
}
