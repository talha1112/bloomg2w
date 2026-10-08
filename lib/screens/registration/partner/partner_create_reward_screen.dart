import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/registration_data.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/wizard_scaffold.dart';
import 'partner_registration_complete.dart';

/// STEP 3 — Create a Bloom Reward.
class PartnerCreateRewardScreen extends StatefulWidget {
  const PartnerCreateRewardScreen({super.key});

  @override
  State<PartnerCreateRewardScreen> createState() => _PartnerCreateRewardScreenState();
}

class _PartnerCreateRewardScreenState extends State<PartnerCreateRewardScreen> {
  final _rewardNameCtrl = TextEditingController();
  final _rewardValueCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _badgeCostCtrl = TextEditingController(text: '1');
  final _restrictionsCtrl = TextEditingController();
  DateTime? _expirationDate;

  bool get _canContinue =>
      _rewardNameCtrl.text.trim().isNotEmpty &&
      _rewardValueCtrl.text.trim().isNotEmpty &&
      _quantityCtrl.text.trim().isNotEmpty &&
      _badgeCostCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _rewardNameCtrl.dispose();
    _rewardValueCtrl.dispose();
    _quantityCtrl.dispose();
    _badgeCostCtrl.dispose();
    _restrictionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiration() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _expirationDate = picked);
  }

  void _continue() {
    final data = context.read<RegistrationData>();
    data.update(() {
      data.rewardName = _rewardNameCtrl.text.trim();
      data.rewardValue = double.tryParse(_rewardValueCtrl.text.trim()) ?? 0;
      data.rewardQuantity = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
      data.rewardBadgeCost = int.tryParse(_badgeCostCtrl.text.trim()) ?? 1;
      data.rewardExpiration = _expirationDate;
      data.rewardRestrictions = _restrictionsCtrl.text.trim();
    });
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerRegistrationComplete()));
  }

  @override
  Widget build(BuildContext context) {
    return WizardScaffold(
      step: 5,
      totalSteps: 7,
      footer: WizardPrimaryButton(label: 'Continue', enabled: _canContinue, onPressed: _continue),
      children: [
        const Text('🌸🏅 Create a Bloom Reward', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.royalDeep)),
        const SizedBox(height: 6),
        const Text(
          'Select the reward you\'d like to provide to our Bloomers.',
          style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 24),
        _field(_rewardNameCtrl, 'Reward Name', hint: 'e.g. \$25 Bloom Achievement Gift Card'),
        const SizedBox(height: 14),
        _field(_rewardValueCtrl, 'Reward Value (\$)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 14),
        _field(_quantityCtrl, 'Number of Rewards Available', keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        _field(_badgeCostCtrl, 'Badges Required to Redeem', hint: 'e.g. 3', keyboardType: TextInputType.number),
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
              _expirationDate == null ? 'No expiration' : '${_expirationDate!.month}/${_expirationDate!.day}/${_expirationDate!.year}',
              style: TextStyle(fontSize: 14, color: _expirationDate == null ? AppColors.inkSoft : AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _field(_restrictionsCtrl, 'Special Restrictions (optional)', maxLines: 3),
      ],
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
