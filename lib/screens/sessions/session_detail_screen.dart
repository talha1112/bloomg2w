import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bloom_session.dart';
import '../../models/session_registration.dart';
import '../../models/speaker_profile.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/speaker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import '../../widgets/common/bloom_network_image.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_pill.dart';
import 'checkin_screen.dart';
import 'exit_survey_screen.dart';

/// Participant-facing session detail — session info, guest speaker, and
/// the register/check-in/join flow. Attendance status is always
/// admin-recorded; a participant can never mark themself attended.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.session});

  final BloomSession session;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _working = false;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _register() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() => _working = true);
    try {
      await SessionService.instance.registerForSession(
        sessionId: widget.session.id,
        uid: user.uid,
        participantName: user.displayName ?? user.email ?? 'Bloom Member',
        sessionTitle: widget.session.title,
      );
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("You're Registered! 🌸"),
            content: Text("You're registered for this Bloom session — ${widget.session.title}."),
            actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't register — registration may have closed or the session is no longer available.")),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _joinZoom() async {
    final link = widget.session.zoomMeetingLink;
    if (link.isEmpty) return;
    final launched = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open the Zoom link.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    final session = widget.session;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(backgroundColor: AppColors.royalDeep, foregroundColor: Colors.white, title: const Text('Session Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(session.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppColors.royalDeep)),
            if (session.topic.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(session.topic, style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.royal),
                const SizedBox(width: 6),
                Text(_formatDate(session.date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 14),
                const Icon(Icons.access_time, size: 15, color: AppColors.royal),
                const SizedBox(width: 6),
                Text(session.startTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            if (session.registrationDeadline != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.event_busy_outlined, size: 15, color: AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Text('Registration closes ${_formatDate(session.registrationDeadline!)}', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                ],
              ),
            ],
            if (session.guestSpeakerUid != null) ...[
              const SectionHeader('🎤 Guest Speaker'),
              FutureBuilder<SpeakerProfile?>(
                future: SpeakerService.instance.fetchPublishedSpeaker(session.guestSpeakerUid!),
                builder: (context, snapshot) {
                  final speaker = snapshot.data;
                  return BloomCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.rose.withValues(alpha: 0.14),
                          backgroundImage: speaker?.photoUrl != null ? bloomNetworkImage(speaker!.photoUrl!) : null,
                          child: speaker?.photoUrl == null ? const Icon(Icons.mic_outlined, color: AppColors.rose, size: 26) : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(session.guestSpeakerNameSnapshot ?? speaker?.fullName ?? 'Guest Speaker', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.royalDeep)),
                              if (speaker != null) ...[
                                const SizedBox(height: 2),
                                Text(speaker.speakingTopic, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SectionHeader('About This Session'),
            BloomCard(child: Text(session.description.isEmpty ? 'No description provided.' : session.description, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5))),
            const SectionHeader('Registration'),
            uid == null
                ? const BloomCard(child: Text('Log in to register.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
                : StreamBuilder<SessionRegistration?>(
                    stream: SessionService.instance.watchRegistration(sessionId: session.id, uid: uid),
                    builder: (context, snapshot) {
                      final registration = snapshot.data;
                      return _RegistrationPanel(
                        session: session,
                        registration: registration,
                        working: _working,
                        onRegister: _register,
                        onJoin: _joinZoom,
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationPanel extends StatelessWidget {
  const _RegistrationPanel({
    required this.session,
    required this.registration,
    required this.working,
    required this.onRegister,
    required this.onJoin,
  });

  final BloomSession session;
  final SessionRegistration? registration;
  final bool working;
  final VoidCallback onRegister;
  final VoidCallback onJoin;

  /// Registration stays open through the END of the deadline day in the
  /// participant's own timezone (the deadline is a calendar day).
  bool get _registrationClosed {
    final deadline = session.registrationDeadline;
    if (deadline == null) return false;
    return DateTime.now().isAfter(DateTime(deadline.year, deadline.month, deadline.day + 1));
  }

  @override
  Widget build(BuildContext context) {
    if (registration == null) {
      if (_registrationClosed) {
        return const BloomCard(
          child: Text('Registration for this session has closed.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        );
      }
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: working ? null : onRegister,
          style: FilledButton.styleFrom(backgroundColor: AppColors.royal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(working ? 'Registering…' : 'REGISTER FOR SESSION', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      );
    }

    Color statusColor;
    switch (registration!.status) {
      case RegistrationStatus.attended:
      case RegistrationStatus.completed:
        statusColor = AppColors.sage;
        break;
      case RegistrationStatus.missed:
      case RegistrationStatus.cancelled:
        statusColor = AppColors.coral;
        break;
      default:
        statusColor = AppColors.royal;
    }

    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(registration!.status.label, color: statusColor),
          const SizedBox(height: 12),
          if (registration!.status == RegistrationStatus.registered && !registration!.checkedIn)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: working ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CheckinScreen(session: session))),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.royal), padding: const EdgeInsets.symmetric(vertical: 13)),
                child: const Text('Pre-Session Check-In', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700)),
              ),
            ),
          if (registration!.checkedIn || registration!.status == RegistrationStatus.joinAvailable) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.videocam, size: 18),
                style: FilledButton.styleFrom(backgroundColor: AppColors.sage, padding: const EdgeInsets.symmetric(vertical: 13)),
                label: const Text('Continue to Zoom', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
          if (registration!.attended && !registration!.surveyCompleted) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExitSurveyScreen(session: session))),
                icon: const Icon(Icons.rate_review_outlined, size: 18, color: AppColors.royal),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.royal), padding: const EdgeInsets.symmetric(vertical: 13)),
                label: const Text('Complete Exit Survey', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
