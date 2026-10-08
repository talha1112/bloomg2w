import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/role_router.dart';
import '../theme/app_theme.dart';
import 'registration/welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      final credential = await AuthService.instance.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      await RoleRouter.routeSignedInUser(context, uidOverride: credential.user?.uid);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = AuthService.messageForCode(e.code));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = 'Enter your email above first, then tap "Forgot Password?" again.');
      return;
    }
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = AuthService.messageForCode(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: AppColors.royal, shape: BoxShape.circle),
                  child: const Center(child: Text('🌸', style: TextStyle(fontSize: 28))),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Welcome Back', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.royalDeep)),
              const SizedBox(height: 6),
              const Text('Log in to continue blooming.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
              const SizedBox(height: 36),
              _field(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: const Text('Forgot Password?', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w600, fontSize: 12.5)),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(_errorText!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _login,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.royal,
                  disabledBackgroundColor: AppColors.royal.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_submitting ? 'Logging in…' : 'Login', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WelcomeScreen())),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                      children: [
                        TextSpan(text: "Don't have an account? "),
                        TextSpan(text: 'Join Now', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool obscure = false, TextInputType? keyboardType, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.royal, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
