import 'package:flutter/material.dart';

import '../models/session_badge.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

/// Watches for newly-earned, not-yet-celebrated badges for [uid] and shows
/// a one-time encouraging celebration dialog for each — marking it seen
/// immediately after so the same badge is never celebrated twice, even
/// across app restarts (celebrationSeen lives in Firestore, not local
/// state). Wrap a screen's body with this to opt it into celebrations.
class BadgeCelebrationListener extends StatefulWidget {
  const BadgeCelebrationListener({super.key, required this.uid, required this.child});

  final String uid;
  final Widget child;

  @override
  State<BadgeCelebrationListener> createState() => _BadgeCelebrationListenerState();
}

class _BadgeCelebrationListenerState extends State<BadgeCelebrationListener> {
  bool _dialogShowing = false;
  final Set<String> _handled = {};

  Future<void> _celebrate(SessionBadge badge) async {
    if (_dialogShowing || _handled.contains(badge.id) || !mounted) return;
    _handled.add(badge.id);
    _dialogShowing = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Column(
          children: const [
            Icon(Icons.emoji_events, color: AppColors.amber, size: 48),
            SizedBox(height: 10),
            Text('New Badge Earned! 🌸', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.royalDeep)),
          ],
        ),
        content: Text(
          'Congratulations on completing "${badge.sessionTitle}"! Keep blooming — every session brings you closer to your next milestone.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.royal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text('Yay!', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );

    await SessionService.instance.markBadgeCelebrationSeen(badge.id);
    _dialogShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SessionBadge>>(
      stream: SessionService.instance.watchUncelebratedBadges(widget.uid),
      builder: (context, snapshot) {
        final uncelebrated = snapshot.data ?? [];
        if (uncelebrated.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate(uncelebrated.first));
        }
        return widget.child;
      },
    );
  }
}
