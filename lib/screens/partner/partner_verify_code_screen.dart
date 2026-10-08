import 'package:flutter/material.dart';

import '../../models/bloom_reward.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';

/// STEP 5 — Redeem the Reward.
/// The Community Partner verifies a participant's one-time redemption
/// code before providing the product, service, gift card, or reward.
/// Marking used goes through the markRedemptionUsed Cloud Function, which
/// atomically ensures a code can only ever be used once.
class PartnerVerifyCodeScreen extends StatefulWidget {
  const PartnerVerifyCodeScreen({super.key});

  @override
  State<PartnerVerifyCodeScreen> createState() => _PartnerVerifyCodeScreenState();
}

class _PartnerVerifyCodeScreenState extends State<PartnerVerifyCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _checking = false;
  bool _marking = false;
  RewardRedemption? _found;
  String? _message;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || _codeCtrl.text.trim().isEmpty) return;

    setState(() {
      _checking = true;
      _found = null;
      _message = null;
    });

    try {
      final redemption = await PartnerService.instance.findRedemptionByCode(partnerUid: uid, code: _codeCtrl.text);
      if (redemption == null) {
        setState(() => _message = 'No reward found for that code.');
      } else if (redemption.status == RedemptionStatus.used) {
        setState(() {
          _found = redemption;
          _message = 'This code has already been redeemed — do not provide the reward again.';
        });
      } else {
        setState(() => _found = redemption);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _markRedeemed() async {
    final redemption = _found;
    if (redemption == null) return;

    setState(() => _marking = true);
    try {
      await PartnerService.instance.markRedemptionUsed(redemption.code);
      if (mounted) setState(() => _message = 'REDEEMED ✓ — this code can no longer be used.');
      await _verify();
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not mark redeemed: $e');
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final redemption = _found;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Verify Redemption Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Ask the participant for their reward code and enter it below to verify before providing the reward.',
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Redemption Code',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.royal, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _checking ? null : _verify,
                style: FilledButton.styleFrom(backgroundColor: AppColors.royal, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(_checking ? 'Checking…' : 'Verify Code', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
            ],
            if (redemption != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: redemption.status == RedemptionStatus.used ? AppColors.sage : AppColors.adminGold, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(redemption.rewardName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.royalDeep)),
                    const SizedBox(height: 4),
                    Text('${redemption.badgeCost} badge${redemption.badgeCost == 1 ? '' : 's'} spent', style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                    const SizedBox(height: 12),
                    if (redemption.status == RedemptionStatus.used)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.sage, size: 18),
                          SizedBox(width: 6),
                          Text('REDEEMED ✓', style: TextStyle(color: AppColors.sage, fontWeight: FontWeight.w800)),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _marking ? null : _markRedeemed,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.sage, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: Text(_marking ? 'Marking…' : 'Mark as Redeemed ✓', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
