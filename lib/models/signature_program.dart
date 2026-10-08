import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SignatureProgram {
  const SignatureProgram({
    required this.title,
    required this.description,
    required this.url,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final String url;
  final IconData icon;
  final Color color;
}

const kSignaturePrograms = [
  SignatureProgram(
    title: 'Women Empowerment',
    description: 'Helping women build confidence, purpose, leadership, and independence.',
    url: 'https://projectbloomgirls2women.org/women-empowerment/',
    icon: Icons.emoji_events_outlined,
    color: AppColors.royal,
  ),
  SignatureProgram(
    title: "Girls' Education & Coaching",
    description: 'Helping girls grow confident, capable, resilient, and future-ready.',
    url: 'https://projectbloomgirls2women.org/girls-education-coaching/',
    icon: Icons.school_outlined,
    color: AppColors.violet,
  ),
  SignatureProgram(
    title: 'Single Moms Raising',
    description: 'Supporting single mothers as they strengthen families and futures.',
    url: 'https://projectbloomgirls2women.org/girls-education-coaching/',
    icon: Icons.family_restroom,
    color: AppColors.amber,
  ),
  SignatureProgram(
    title: 'Hidden Heroes',
    description: "Celebrating courageous girls and women overcoming life's challenges.",
    url: 'https://projectbloomgirls2women.org/hidden-heroes/',
    icon: Icons.star_outline,
    color: AppColors.coral,
  ),
  SignatureProgram(
    title: 'Protect & Empower',
    description: 'Promoting safety, awareness, prevention, advocacy, and personal empowerment.',
    url: 'https://projectbloomgirls2women.org/sexual-violence-trafficking-abuse/',
    icon: Icons.shield_outlined,
    color: AppColors.teal,
  ),
  SignatureProgram(
    title: 'Skill Building',
    description: 'Building practical skills for careers, technology, and financial success.',
    url: 'https://projectbloomgirls2women.org/career-readiness-entrepreneurship/',
    icon: Icons.build_outlined,
    color: AppColors.cornflower,
  ),
  SignatureProgram(
    title: 'Women Veterans',
    description: 'Supporting women veterans as they transition, connect, and thrive.',
    url: 'https://projectbloomgirls2women.org/women-veterans-community-service/',
    icon: Icons.military_tech_outlined,
    color: AppColors.sage,
  ),
  SignatureProgram(
    title: 'Emotional Intelligence Mastery',
    description: 'Building self-awareness, confidence, resilience, communication, and healthy relationships.',
    url: 'https://projectbloomgirls2women.org/emotional-intelligence-new/',
    icon: Icons.psychology_outlined,
    color: AppColors.rose,
  ),
  SignatureProgram(
    title: 'Community Social Responsibility',
    description: 'Connecting community partners to create meaningful, lasting positive impact.',
    url: 'https://projectbloomgirls2women.org/social-responsibility-giving-back/',
    icon: Icons.handshake_outlined,
    color: AppColors.royalDeep,
  ),
];
