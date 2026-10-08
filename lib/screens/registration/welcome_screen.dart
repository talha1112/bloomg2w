import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/registration_data.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import 'choose_user_type_screen.dart';

/// The app's first-impression screen, rebuilt as real Flutter widgets
/// (not a static background image) so it stays crisp at any resolution
/// and themeable — text content and layout hierarchy follow the original
/// brand welcome graphic: gold wave header, BloomG2W wordmark, tagline,
/// the Project Bloom circular emblem, title/subheading, a spotlighted
/// body paragraph with a script "bloom" accent, an italic footer quote,
/// then the Join Now / Log In controls pinned to the bottom.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.royalDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Lower zone: deep royal gradient with a soft radial glow behind
          // the body paragraph, echoing the original artwork's starlit-water
          // background.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.white,
                    AppColors.royalLight,
                    AppColors.royalDeep,
                  ],
                  stops: const [0.0, 0.3, 0.42, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                    child: Column(
                      children: [
                        const SizedBox(height: 18),
                        _GoldWave(),
                        const SizedBox(height: 18),
                        _Wordmark(),
                        const SizedBox(height: 10),
                        _Tagline(),
                        const SizedBox(height: 22),
                        Image.asset(
                          'assets/images/project_bloom_emblem.png',
                          width: 190,
                          height: 190,
                        ),
                        const SizedBox(height: 18),
                        // White, not navy — this text sits far enough down
                        // the screen that it falls on the dark-blue part of
                        // the background gradient, where navy text was
                        // nearly invisible (the same navy as the background
                        // itself). White keeps it legible regardless of
                        // scroll position or screen height.
                        Text(
                          'Welcome to BloomG2W',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Building a Nation of Bloomers—\none Girl and one Woman at a time.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 36),
                        _SpotlightBody(),
                        const SizedBox(height: 18),
                        _FooterQuote(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            context.read<RegistrationData>().reset();
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChooseUserTypeScreen()));
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.royalDeep,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Join Now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 13.5, color: Colors.white),
                            children: [
                              TextSpan(text: 'Already a Member? '),
                              TextSpan(text: 'Log In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin sweeping gold ribbon across the top, approximating the original
/// artwork's two-stroke wave with a CustomPaint curve.
class _GoldWave extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      width: double.infinity,
      child: CustomPaint(painter: _WavePainter()),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = AppColors.adminGold
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final paint2 = Paint()
      ..color = AppColors.adminGoldDeep
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path1 = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.5, -size.height * 0.4, size.width, size.height * 0.55);
    final path2 = Path()
      ..moveTo(0, size.height * 0.95)
      ..quadraticBezierTo(size.width * 0.5, -size.height * 0.1, size.width, size.height * 0.8);

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "BloomG2W" wordmark, matching the original's two-tone navy/gold styling
/// and the small sparkle accent above the "o" where a dot would sit.
class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 40, height: 1);
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        RichText(
          text: TextSpan(
            style: style,
            children: [
              TextSpan(text: 'Bloom', style: style.copyWith(color: AppColors.royalDeep)),
              TextSpan(text: 'G2', style: style.copyWith(color: AppColors.adminGold)),
              TextSpan(text: 'W', style: style.copyWith(color: AppColors.royalDeep)),
            ],
          ),
        ),
        const Positioned(
          top: -14,
          child: Icon(Icons.auto_awesome, color: AppColors.adminGold, size: 16),
        ),
      ],
    );
  }
}

/// "BLOOM. | BELIEVE. | BECOME." — bold caps, wide tracking, alternating
/// navy/gold to match the original.
class _Tagline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.4);
    return RichText(
      text: TextSpan(
        style: style.copyWith(color: AppColors.royalDeep),
        children: [
          const TextSpan(text: 'BLOOM. '),
          TextSpan(text: '|  ', style: style.copyWith(color: AppColors.adminGold)),
          TextSpan(text: 'BELIEVE. ', style: style.copyWith(color: AppColors.adminGold)),
          const TextSpan(text: '|  '),
          const TextSpan(text: 'BECOME.'),
        ],
      ),
    );
  }
}

/// The spotlighted body paragraph on the dark zone, with "bloom" rendered
/// in a script accent font as in the original artwork.
class _SpotlightBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final serif = GoogleFonts.lora(fontSize: 16, color: Colors.white, height: 1.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: serif,
          children: [
            const TextSpan(text: 'Inspired by the lotus, we rise from the mud of life, learn, grow, and '),
            TextSpan(
              text: 'bloom',
              style: GoogleFonts.sacramento(fontSize: 26, color: AppColors.adminGold, height: 1),
            ),
            const TextSpan(text: ' into our best selves—living with purpose.'),
          ],
        ),
      ),
    );
  }
}

/// Italic footer quote, with "bloom" bolded within the italic line as in
/// the original.
class _FooterQuote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.loraTextTheme().bodyMedium!.copyWith(
          fontStyle: FontStyle.italic,
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 13,
          height: 1.5,
        );
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Life is like a flower, you may '),
          TextSpan(text: 'bloom', style: base.copyWith(fontWeight: FontWeight.w700)),
          const TextSpan(text: ' early, you may '),
          TextSpan(text: 'bloom', style: base.copyWith(fontWeight: FontWeight.w700)),
          const TextSpan(text: ' later, just don’t forget to '),
          TextSpan(text: 'bloom', style: base.copyWith(fontWeight: FontWeight.w700)),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
