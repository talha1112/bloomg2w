import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 32),
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: actions,
      ),
      body: SafeArea(
        child: ListView(
          padding: padding,
          children: children,
        ),
      ),
    );
  }
}
