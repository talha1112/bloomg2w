import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/donation.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import 'donation_confirmation_screen.dart';

/// Community Partner financial contribution — collects amount/purpose,
/// then hands off to createDonationCheckout (server-side validated) and
/// opens Stripe-hosted Checkout. This screen never collects card details
/// and never marks a donation paid; only the stripeWebhook Cloud
/// Function does that.
class PartnerDonationScreen extends StatefulWidget {
  const PartnerDonationScreen({super.key});

  @override
  State<PartnerDonationScreen> createState() => _PartnerDonationScreenState();
}

class _PartnerDonationScreenState extends State<PartnerDonationScreen> {
  static const _presetAmounts = [2500, 5000, 10000, 25000]; // cents
  int? _selectedAmountCents;
  final _customAmountCtrl = TextEditingController();
  bool _useCustom = false;
  String _purpose = kDonationPurposes.first;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _customAmountCtrl.dispose();
    super.dispose();
  }

  int? get _resolvedAmountCents {
    if (_useCustom) {
      final dollars = double.tryParse(_customAmountCtrl.text.trim());
      if (dollars == null || dollars <= 0) return null;
      return (dollars * 100).round();
    }
    return _selectedAmountCents;
  }

  Future<void> _continue() async {
    final amountCents = _resolvedAmountCents;
    if (amountCents == null || amountCents < 100) {
      setState(() => _error = 'Enter a valid amount of at least \$1.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await PartnerService.instance.createDonationCheckout(amountCents: amountCents, purpose: _purpose);
      final launched = await launchUrl(Uri.parse(result.checkoutUrl), mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception("Couldn't open the Stripe checkout page.");
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DonationConfirmationScreen(donationId: result.donationId)),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start checkout: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Support Project Bloom', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Your contribution helps provide rewards, workshops, learning opportunities, and resources for Bloom participants.',
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 20),
            const Text('Choose an amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._presetAmounts.map((cents) => _amountChip('\$${cents ~/ 100}', selected: !_useCustom && _selectedAmountCents == cents, onTap: () => setState(() {
                      _useCustom = false;
                      _selectedAmountCents = cents;
                    }))),
                _amountChip('Custom', selected: _useCustom, onTap: () => setState(() => _useCustom = true)),
              ],
            ),
            if (_useCustom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customAmountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Custom Amount (\$)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ],
            const SizedBox(height: 22),
            const Text('Purpose', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kDonationPurposes.map((p) => _amountChip(p, selected: _purpose == p, onTap: () => setState(() => _purpose = p))).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _continue,
                style: FilledButton.styleFrom(backgroundColor: AppColors.royal, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(_submitting ? 'Starting checkout…' : 'Continue to Payment', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            const BloomCard(
              child: Text(
                'You will be redirected to Stripe\'s secure checkout page to complete your payment. Bloom G2W never sees or stores your card details.',
                style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountChip(String label, {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.royal : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.royal : Colors.black.withValues(alpha: 0.1)),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.inkSoft)),
      ),
    );
  }
}
