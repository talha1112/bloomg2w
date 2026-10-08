import 'package:flutter/material.dart';

import '../models/membership_application.dart';
import '../services/auth_service.dart';
import '../services/membership_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';

class MembershipRegistrationScreen extends StatefulWidget {
  const MembershipRegistrationScreen({super.key});

  @override
  State<MembershipRegistrationScreen> createState() => _MembershipRegistrationScreenState();
}

class _MembershipRegistrationScreenState extends State<MembershipRegistrationScreen> {
  MembershipType _type = MembershipType.girls;
  bool _parentConsent = false;
  bool _acceptedTerms = false;
  bool _submitting = false;

  final _parentNameCtrl = TextEditingController();
  final _parentEmailCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _questionCtrl = TextEditingController();

  final _interests = <String, bool>{
    'Leadership': true,
    'Arts & Creativity': false,
    'STEM': false,
    'Faith & Purpose': true,
    'Financial Literacy': false,
    'Community Service': false,
  };

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    _fullNameCtrl.text = user?.displayName ?? '';
    _emailCtrl.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _parentNameCtrl.dispose();
    _parentEmailCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _fullNameCtrl.dispose();
    _dobCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _questionCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (!_acceptedTerms || _fullNameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) return false;
    if (_type == MembershipType.girls && !_parentConsent) return false;
    return true;
  }

  Future<void> _submit() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      await MembershipService.instance.submitApplication(
        MembershipApplication(
          id: '',
          uid: uid,
          type: _type,
          fullName: _fullNameCtrl.text.trim(),
          dateOfBirth: _dobCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          parentName: _parentNameCtrl.text.trim(),
          parentEmail: _parentEmailCtrl.text.trim(),
          parentPhone: _parentPhoneCtrl.text.trim(),
          parentConsent: _parentConsent,
          interests: _interests.entries.where((e) => e.value).map((e) => e.key).toList(),
          membershipQuestion: _questionCtrl.text.trim(),
          acceptedTerms: _acceptedTerms,
          status: MembershipStatus.pending,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome! Your membership application has been submitted for review.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong submitting your application: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Membership Registration',
      children: [
        const SectionHeader('Membership Type'),
        Row(
          children: [
            Expanded(
              child: _TypeCard(
                title: 'Girls Membership',
                subtitle: 'Ages 8–17',
                icon: Icons.emoji_people_outlined,
                selected: _type == MembershipType.girls,
                onTap: () => setState(() => _type = MembershipType.girls),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TypeCard(
                title: "Women's Membership",
                subtitle: '18+',
                icon: Icons.woman_outlined,
                selected: _type == MembershipType.women,
                onTap: () => setState(() => _type = MembershipType.women),
              ),
            ),
          ],
        ),
        if (_type == MembershipType.girls) ...[
          const SectionHeader('Parent / Guardian Registration'),
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _textField(_parentNameCtrl, 'Parent / Guardian full name'),
                const SizedBox(height: 10),
                _textField(_parentEmailCtrl, 'Parent / Guardian email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _textField(_parentPhoneCtrl, 'Parent / Guardian phone', keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _parentConsent,
                  onChanged: (v) => setState(() => _parentConsent = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.royal,
                  title: const Text('I give consent for my child to participate in Bloom G2W activities.', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ),
        ],
        const SectionHeader('Member Profile'),
        BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _textField(_fullNameCtrl, 'Full name'),
              const SizedBox(height: 10),
              _textField(_dobCtrl, 'Date of birth (MM/DD/YYYY)'),
              const SizedBox(height: 10),
              _textField(_emailCtrl, 'Email address', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _textField(_phoneCtrl, 'Phone number', keyboardType: TextInputType.phone),
            ],
          ),
        ),
        const SectionHeader('Interests'),
        BloomCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests.keys.map((k) {
              final selected = _interests[k]!;
              return FilterChip(
                label: Text(k, style: TextStyle(fontSize: 12.5, color: selected ? Colors.white : AppColors.royal, fontWeight: FontWeight.w600)),
                selected: selected,
                onSelected: (v) => setState(() => _interests[k] = v),
                selectedColor: AppColors.royal,
                backgroundColor: AppColors.royal.withValues(alpha: 0.06),
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: BorderSide.none),
              );
            }).toList(),
          ),
        ),
        const SectionHeader('Membership Questions'),
        BloomCard(
          child: _textField(_questionCtrl, 'What do you hope to gain from Bloom G2W?', maxLines: 3),
        ),
        BloomCard(
          child: CheckboxListTile(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.royal,
            title: const Text.rich(
              TextSpan(
                text: 'I agree to the ',
                style: TextStyle(fontSize: 12.5, color: AppColors.ink),
                children: [
                  TextSpan(text: 'Terms and Conditions', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700)),
                  TextSpan(text: ' of Bloom G2W.'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.royal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.royal.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _canSubmit && !_submitting ? _submit : null,
            child: Text(_submitting ? 'Submitting…' : 'Join the Bloom Movement', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _textField(TextEditingController controller, String label, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.paper,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.royal : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.royal : Colors.black.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.gold : AppColors.royal, size: 26),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? Colors.white : AppColors.royalDeep)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11.5, color: selected ? Colors.white70 : AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
