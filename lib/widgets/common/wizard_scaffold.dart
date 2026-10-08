import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.children,
    this.footer,
    this.showBack = true,
  });

  final int step;
  final int totalSteps;
  final List<Widget> children;
  final Widget? footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        foregroundColor: AppColors.royalDeep,
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Row(
          children: List.generate(totalSteps, (i) {
            final active = i <= step;
            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: active ? AppColors.royal : AppColors.royal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: children,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

class WizardPrimaryButton extends StatelessWidget {
  const WizardPrimaryButton({super.key, required this.label, required this.onPressed, this.enabled = true});

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.royal,
          disabledBackgroundColor: AppColors.royal.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Colors.white)),
      ),
    );
  }
}
