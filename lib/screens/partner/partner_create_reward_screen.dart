import 'package:flutter/material.dart';

import '../../models/bloom_reward.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../theme/app_theme.dart';

/// Lets an already-onboarded Community Partner create an additional
/// Bloom Reward from their dashboard (distinct from the one-time reward
/// created during registration).
class PartnerCreateRewardScreen extends StatefulWidget {
  const PartnerCreateRewardScreen({super.key});

  @override
  State<PartnerCreateRewardScreen> createState() => _PartnerCreateRewardScreenState();
}

class _PartnerCreateRewardScreenState extends State<PartnerCreateRewardScreen> {
  final _nameCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _badgeCostCtrl = TextEditingController(text: '1');
  final _descriptionCtrl = TextEditingController();
  final _restrictionsCtrl = TextEditingController();
  DateTime? _expiration;
  bool _saving = false;
  String? _error;

  bool get _canSave =>
      _nameCtrl.text.trim().isNotEmpty &&
      _valueCtrl.text.trim().isNotEmpty &&
      _quantityCtrl.text.trim().isNotEmpty &&
      _badgeCostCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _quantityCtrl.dispose();
    _badgeCostCtrl.dispose();
    _descriptionCtrl.dispose();
    _restrictionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiration() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 90)), firstDate: now, lastDate: DateTime(now.year + 5));
    if (picked != null) setState(() => _expiration = picked);
  }

  Future<void> _save() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = await PartnerService.instance.fetchPartnerProfile(uid);
      final quantity = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
      await PartnerService.instance.createReward(
        BloomReward(
          id: '',
          partnerUid: uid,
          partnerName: profile?.businessName ?? '',
          name: _nameCtrl.text.trim(),
          value: double.tryParse(_valueCtrl.text.trim()) ?? 0,
          quantityAvailable: quantity,
          remainingQuantity: quantity,
          badgeCost: int.tryParse(_badgeCostCtrl.text.trim()) ?? 1,
          description: _descriptionCtrl.text.trim(),
          expirationDate: _expiration,
          restrictions: _restrictionsCtrl.text.trim().isEmpty ? null : _restrictionsCtrl.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save reward: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Create a Bloom Reward', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5)),
              ),
            ],
            _field(_nameCtrl, 'Reward Name', hint: 'e.g. \$25 Bloom Achievement Gift Card'),
            const SizedBox(height: 14),
            _field(_valueCtrl, 'Reward Value (\$)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 14),
            _field(_quantityCtrl, 'Number of Rewards Available', keyboardType: TextInputType.number),
            const SizedBox(height: 14),
            _field(_badgeCostCtrl, 'Badges Required to Redeem', hint: 'e.g. 3', keyboardType: TextInputType.number),
            const SizedBox(height: 14),
            _field(_descriptionCtrl, 'Description (optional)', maxLines: 3),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickExpiration,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Expiration Date (if applicable)',
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.inkSoft),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                child: Text(
                  _expiration == null ? 'No expiration' : '${_expiration!.month}/${_expiration!.day}/${_expiration!.year}',
                  style: TextStyle(fontSize: 14, color: _expiration == null ? AppColors.inkSoft : AppColors.ink),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _field(_restrictionsCtrl, 'Special Restrictions (optional)', maxLines: 3),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave && !_saving ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.royal,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_saving ? 'Saving…' : 'Create Reward', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {String? hint, int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.royal, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
