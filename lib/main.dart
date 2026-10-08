import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/registration_data.dart';
import 'screens/partner/donation_confirmation_screen.dart';
import 'screens/registration/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/role_router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BloomG2WApp());
}

class BloomG2WApp extends StatelessWidget {
  const BloomG2WApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegistrationData(),
      child: MaterialApp(
        title: 'Bloom G2W',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

/// If a session is already signed in, routes straight to that user's
/// dashboard by role; otherwise shows Welcome. Replaces the old splash
/// screen's "already logged in?" check now that there's no splash delay.
///
/// Also handles the web-only Stripe Checkout redirect: this app has no
/// URL-based router (pure Navigator.push in-memory navigation), so the
/// browser landing on /donation-success or /donation-cancelled after
/// Stripe would otherwise just show the normal home/login screen with no
/// indication a payment was just attempted. Reading Uri.base once at
/// startup and, if it matches, pushing DonationConfirmationScreen on top
/// of the normal auth-gated destination closes that gap without
/// introducing a full routing system for a single redirect case.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    final uri = Uri.base;
    final isDonationRedirect = uri.path.endsWith('/donation-success') || uri.path.endsWith('/donation-cancelled');
    final donationId = isDonationRedirect ? uri.queryParameters['donationId'] : null;
    final checkoutCancelled = uri.path.endsWith('/donation-cancelled');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // RoleRouter replaces the whole stack (removing this AuthGate route),
      // so grab the navigator first rather than relying on this widget
      // still being mounted afterwards.
      final navigator = Navigator.of(context);
      if (AuthService.instance.currentUser != null) {
        await RoleRouter.routeSignedInUser(context);
      }
      if (donationId != null) {
        navigator.push(MaterialPageRoute(builder: (_) => DonationConfirmationScreen(donationId: donationId, checkoutCancelled: checkoutCancelled)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const WelcomeScreen();
  }
}
