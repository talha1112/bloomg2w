import 'package:flutter/material.dart';

class DashboardTile {
  const DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.builder,
    this.comingSoon = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final WidgetBuilder builder;
  final bool comingSoon;
}
