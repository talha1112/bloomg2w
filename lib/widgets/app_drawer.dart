import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/member_dashboard_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _signOut(BuildContext context) async {
    Navigator.of(context).pop();
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.royalDeep,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white),
                        children: [
                          TextSpan(text: 'Bloom'),
                          TextSpan(text: 'G2', style: TextStyle(color: AppColors.gold)),
                          TextSpan(text: 'W'),
                        ],
                      ),
                    ),
                  ),
                  _tile(context, Icons.dashboard_customize_outlined, 'Member Dashboard', const MemberDashboardScreen()),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.coral),
              title: const Text('Sign Out', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700, fontSize: 14)),
              onTap: () => _signOut(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, Widget screen, {bool highlight = false}) {
    return ListTile(
      leading: Icon(icon, color: highlight ? AppColors.gold : Colors.white70),
      title: Text(label, style: TextStyle(color: highlight ? AppColors.gold : Colors.white, fontWeight: highlight ? FontWeight.w700 : FontWeight.w500, fontSize: 14)),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      },
    );
  }
}
