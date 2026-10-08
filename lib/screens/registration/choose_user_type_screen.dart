import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/registration_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/wizard_scaffold.dart';
import 'create_account_screen.dart';

class ChooseUserTypeScreen extends StatefulWidget {
  const ChooseUserTypeScreen({super.key});

  @override
  State<ChooseUserTypeScreen> createState() => _ChooseUserTypeScreenState();
}

class _ChooseUserTypeScreenState extends State<ChooseUserTypeScreen> {
  BloomUserType? _selected;

  @override
  Widget build(BuildContext context) {
    return WizardScaffold(
      step: 0,
      totalSteps: 8,
      footer: WizardPrimaryButton(
        label: 'Continue',
        enabled: _selected != null,
        onPressed: () {
          context.read<RegistrationData>().setUserType(_selected!);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateAccountScreen()));
        },
      ),
      children: [
        const Text('Choose Who You Are', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.royalDeep)),
        const SizedBox(height: 6),
        const Text('This determines what content you\'ll see.', style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
        const SizedBox(height: 24),
        ...BloomUserType.values.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TypeButton(
              type: t,
              selected: _selected == t,
              onTap: () => setState(() => _selected = t),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.type, required this.selected, required this.onTap});

  final BloomUserType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.royal : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.royal : Colors.black.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(type.icon, color: selected ? Colors.white : Colors.black, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                type.label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: selected ? Colors.white : AppColors.royalDeep),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.chevron_right,
              color: selected ? Colors.white : Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}
