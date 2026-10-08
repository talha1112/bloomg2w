import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/partner_profile.dart';
import '../../../models/registration_data.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/wizard_scaffold.dart';
import 'partner_create_reward_screen.dart';

/// STEP 2 — Tell Us How You Want to Help.
class PartnerSupportTypeScreen extends StatefulWidget {
  const PartnerSupportTypeScreen({super.key});

  @override
  State<PartnerSupportTypeScreen> createState() => _PartnerSupportTypeScreenState();
}

class _PartnerSupportTypeScreenState extends State<PartnerSupportTypeScreen> {
  final Set<String> _selected = {};
  final _contributionCtrl = TextEditingController();

  bool get _canContinue => _selected.isNotEmpty;

  @override
  void dispose() {
    _contributionCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    final data = context.read<RegistrationData>();
    data.update(() {
      data.partnerSupportTypes = _selected.toList();
      data.partnerContributionDetails = _contributionCtrl.text.trim();
    });
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerCreateRewardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return WizardScaffold(
      step: 4,
      totalSteps: 7,
      footer: WizardPrimaryButton(label: 'Continue', enabled: _canContinue, onPressed: _continue),
      children: [
        const Text('How Would You Like to Help?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.royalDeep)),
        const SizedBox(height: 6),
        const Text(
          'Select all the ways you\'d like to support Project Bloom Girls 2 Women.',
          style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 20),
        ...kPartnerSupportOptions.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SupportOptionTile(
              label: option,
              selected: _selected.contains(option),
              onTap: () => setState(() {
                if (_selected.contains(option)) {
                  _selected.remove(option);
                } else {
                  _selected.add(option);
                }
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Tell us about your contribution', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep)),
        const SizedBox(height: 10),
        TextField(
          controller: _contributionCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe what you\'d like to offer…',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.royal, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _SupportOptionTile extends StatelessWidget {
  const _SupportOptionTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.royal : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.royal : Colors.black.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Colors.white : AppColors.inkSoft.withValues(alpha: 0.5), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: selected ? Colors.white : AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
