import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/registration_data.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/wizard_scaffold.dart';
import 'verify_email_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  static const _privacyPolicyUrl = 'https://bloomg2w.web.app/privacy-policy';

  Future<void> _openPrivacyPolicy() async {
    final launched = await launchUrl(Uri.parse(_privacyPolicyUrl), mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open the link. Please try again later.")));
    }
  }

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _agreed = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _errorText;

  bool get _canContinue =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().isNotEmpty &&
      _passwordCtrl.text.isNotEmpty &&
      _passwordCtrl.text == _confirmCtrl.text &&
      _agreed;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final data = context.read<RegistrationData>();

      // Community Partner and Guest Speaker accounts still create their
      // Firestore profile doc here, right after the Firebase Auth account —
      // they aren't age-gated. Girl/Woman/Parent accounts defer profile
      // creation until the Profile Information step (next), because their
      // role assignment and server-side age validation both depend on the
      // date of birth collected there — see ProfileInformationScreen.
      final credential = await AuthService.instance.signUp(
        email: email,
        password: password,
        displayName: '$firstName $lastName'.trim(),
      );
      await credential.user?.sendEmailVerification();

      final uid = credential.user?.uid;
      if (uid != null) {
        if (data.userType == BloomUserType.communityPartner) {
          await UserService.instance.createUserProfile(
            uid: uid,
            firstName: firstName,
            lastName: lastName,
            email: email,
            memberType: data.userType?.name ?? '',
            role: AppRole.partner,
          );
        } else if (data.userType == BloomUserType.guestSpeaker) {
          await UserService.instance.createUserProfile(
            uid: uid,
            firstName: firstName,
            lastName: lastName,
            email: email,
            memberType: data.userType?.name ?? '',
            role: AppRole.guestSpeaker,
          );
        }
      }

      if (!mounted) return;
      data.update(() {
        data.firstName = firstName;
        data.lastName = lastName;
        data.email = email;
        data.password = password;
        data.confirmPassword = _confirmCtrl.text;
        data.agreedToPrivacyPolicy = _agreed;
      });
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VerifyEmailScreen()));
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = AuthService.messageForCode(e.code));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WizardScaffold(
      step: 1,
      totalSteps: 8,
      footer: WizardPrimaryButton(
        label: _submitting ? 'Creating Account…' : 'Continue',
        enabled: _canContinue && !_submitting,
        onPressed: _continue,
      ),
      children: [
        const Text('Create Your Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.royalDeep)),
        const SizedBox(height: 6),
        const Text('Just the essentials to get you started.', style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(_errorText!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(height: 24),
        _field(_firstNameCtrl, 'First Name'),
        const SizedBox(height: 14),
        _field(_lastNameCtrl, 'Last Name'),
        const SizedBox(height: 14),
        _field(_emailCtrl, 'Email Address', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _field(
          _passwordCtrl,
          'Password',
          obscure: _obscure,
          suffix: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppColors.inkSoft),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: 14),
        _field(
          _confirmCtrl,
          'Confirm Password',
          obscure: _obscureConfirm,
          suffix: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppColors.inkSoft),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.royal,
          title: Text.rich(
            TextSpan(
              text: 'I agree to the ',
              style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
              children: [
                TextSpan(
                  text: 'Privacy Policy',
                  style: const TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700),
                  recognizer: TapGestureRecognizer()..onTap = _openPrivacyPolicy,
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool obscure = false, TextInputType? keyboardType, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.royal, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
