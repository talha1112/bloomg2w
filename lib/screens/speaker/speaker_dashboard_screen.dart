import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bloom_session.dart';
import '../../models/speaker_application.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../services/speaker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/status_pill.dart';
import '../login_screen.dart';

/// The dedicated dashboard for accounts with role == guestSpeaker.
/// Shows their application status and — once approved & published —
/// confirms their visibility in the Bureau. Applicants never see other
/// applicants' info here; this is their own status only.
class SpeakerDashboardScreen extends StatelessWidget {
  const SpeakerDashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Guest Speaker', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          IconButton(icon: const Icon(Icons.logout, size: 20), tooltip: 'Sign Out', onPressed: () => _signOut(context)),
        ],
      ),
      body: SafeArea(
        child: uid == null
            ? const Center(child: Text('Not signed in.'))
            : StreamBuilder<SpeakerApplication?>(
                stream: SpeakerService.instance.watchApplication(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.royal));
                  }
                  final application = snapshot.data;
                  if (application == null) {
                    return const Center(child: Text('No application found.', style: TextStyle(color: AppColors.inkSoft)));
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.royalDeep, Color(0xFF0C1440)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.adminGold.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic_external_on_outlined, color: AppColors.adminGold, size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(application.fullName.isNotEmpty ? application.fullName : 'Your Application', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  _statusPillFor(application),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (application.status == SpeakerStatus.approved) ...[
                        const SectionHeader('My Sessions'),
                        StreamBuilder<List<BloomSession>>(
                          stream: SessionService.instance.watchSessionsForSpeaker(uid),
                          builder: (context, sessionSnapshot) {
                            final sessions = (sessionSnapshot.data ?? []).where((s) => s.status != SessionStatus.cancelled).toList();
                            if (sessions.isEmpty) {
                              return const BloomCard(child: Text('No sessions assigned to you yet.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
                            }
                            return Column(children: sessions.map((s) => _SpeakerSessionTile(session: s)).toList());
                          },
                        ),
                      ],
                      const SectionHeader('Application Status'),
                      BloomCard(child: _statusMessage(application)),
                      if (application.status == SpeakerStatus.approved && application.published) ...[
                        const SectionHeader("You're Live in the Bureau! 🎉"),
                        const BloomCard(
                          child: Text(
                            'Members can now browse your speaker profile and express interest in your presentation.',
                            style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.4),
                          ),
                        ),
                      ],
                      const SectionHeader('Your Speaking Topic'),
                      BloomCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(application.speakingTopic, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            const SizedBox(height: 6),
                            Text(application.presentationDescription, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.4)),
                          ],
                        ),
                      ),
                      if (application.adminNotes.isNotEmpty) ...[
                        const SectionHeader('Notes From Project Bloom'),
                        BloomCard(child: Text(application.adminNotes, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.4))),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _statusPillFor(SpeakerApplication application) {
    Color color;
    switch (application.status) {
      case SpeakerStatus.approved:
        color = AppColors.sage;
        break;
      case SpeakerStatus.changesRequested:
        color = AppColors.amber;
        break;
      case SpeakerStatus.declined:
        color = AppColors.coral;
        break;
      case SpeakerStatus.pending:
        color = AppColors.adminGold;
        break;
    }
    return StatusPill(application.status.label, color: color);
  }

  Widget _statusMessage(SpeakerApplication application) {
    late String message;
    switch (application.status) {
      case SpeakerStatus.pending:
        message = 'Your application is under review. You\'ll be notified once Project Bloom has made a decision.';
        break;
      case SpeakerStatus.approved:
        message = application.published
            ? 'Congratulations — your profile is approved and published to the Guest Speakers Bureau!'
            : 'Your application has been approved! Project Bloom will publish your profile to the Bureau soon.';
        break;
      case SpeakerStatus.changesRequested:
        message = 'Project Bloom has requested a few changes to your application. See the notes below.';
        break;
      case SpeakerStatus.declined:
        message = 'Your application was not approved at this time. Thank you for your interest in Project Bloom.';
        break;
    }
    return Text(message, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5));
  }
}

class _SpeakerSessionTile extends StatefulWidget {
  const _SpeakerSessionTile({required this.session});

  final BloomSession session;

  @override
  State<_SpeakerSessionTile> createState() => _SpeakerSessionTileState();
}

class _SpeakerSessionTileState extends State<_SpeakerSessionTile> {
  bool _starting = false;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _startMeeting() async {
    setState(() => _starting = true);
    try {
      final hostInfo = await SessionService.instance.fetchZoomHostInfo(widget.session.id);
      final startUrl = hostInfo?.startUrl;
      if (startUrl == null || startUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Zoom meeting has been created for this session yet — check with your Project Bloom admin.')));
        }
        return;
      }
      final launched = await launchUrl(Uri.parse(startUrl), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open Zoom.")));
      }
    } catch (e) {
      // Before an admin creates the meeting, the host-link doc doesn't
      // exist and the security rules deny the read — same outcome for the
      // speaker as "no meeting yet".
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Zoom meeting has been created for this session yet — check with your Project Bloom admin.')));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(session.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.royalDeep)),
          const SizedBox(height: 4),
          Text('${_formatDate(session.date)} · ${session.startTime}', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _starting ? null : _startMeeting,
              icon: const Icon(Icons.videocam, size: 17),
              style: FilledButton.styleFrom(backgroundColor: AppColors.sage, padding: const EdgeInsets.symmetric(vertical: 12)),
              label: Text(_starting ? 'Opening…' : 'Start Meeting', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}
