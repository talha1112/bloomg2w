import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/registration_data.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/wizard_scaffold.dart';
import '../speaker/speaker_application_form_screen.dart';
import 'partner/partner_profile_screen.dart';
import 'profile_information_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _resending = false;
  String? _message;

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final user = AuthService.instance.currentUser;
      await user?.reload();
      final verified = AuthService.instance.currentUser?.emailVerified ?? false;
      if (!mounted) return;
      if (verified) {
        final userType = context.read<RegistrationData>().userType;
        Widget destination;
        if (userType == BloomUserType.communityPartner) {
          destination = const PartnerProfileScreen();
        } else if (userType == BloomUserType.guestSpeaker) {
          destination = const SpeakerApplicationFormScreen();
        } else {
          destination = const ProfileInformationScreen();
        }
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
      } else {
        setState(() => _message = "Not verified yet — click the link in your email, then try again.");
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _message = null;
    });
    try {
      await AuthService.instance.currentUser?.sendEmailVerification();
      if (mounted) setState(() => _message = 'Verification email sent again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<RegistrationData>().email;
    return WizardScaffold(
      step: 2,
      totalSteps: 8,
      footer: WizardPrimaryButton(
        label: _checking ? 'Checking…' : "I've Verified My Email",
        enabled: !_checking,
        onPressed: _checkVerified,
      ),
      children: [
        const Text('Verify Your Email', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.royalDeep)),
        const SizedBox(height: 6),
        Text(
          email.isEmpty
              ? "We've sent you a verification link. Open your email and click it to continue."
              : "We've sent a verification link to $email. Open your email and click it to continue.",
          style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.4),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black.withValues(alpha: 0.08))),
          child: const Column(
            children: [
              Icon(Icons.mark_email_read_outlined, color: AppColors.royal, size: 40),
              SizedBox(height: 10),
              Text('Check your inbox (and spam folder)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep), textAlign: TextAlign.center),
            ],
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 16),
          Text(_message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        ],
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: _resending ? null : _resend,
            child: Text(_resending ? 'Sending…' : 'Resend Link', style: const TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
