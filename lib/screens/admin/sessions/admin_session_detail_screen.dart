import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/bloom_session.dart';
import '../../../models/session_registration.dart';
import '../../../models/speaker_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/session_service.dart';
import '../../../services/speaker_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/bloom_network_image.dart';
import '../../../widgets/common/section_header.dart';
import '../../../widgets/common/status_pill.dart';
import 'admin_session_form_screen.dart';

class AdminSessionDetailScreen extends StatefulWidget {
  const AdminSessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<AdminSessionDetailScreen> createState() => _AdminSessionDetailScreenState();
}

class _AdminSessionDetailScreenState extends State<AdminSessionDetailScreen> {
  bool _working = false;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _joinZoom(String link) async {
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Zoom link set for this session.')));
      return;
    }
    final launched = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open the Zoom link.")));
    }
  }

  Future<void> _sendReminder(BloomSession session) async {
    setState(() => _working = true);
    try {
      await SessionService.instance.sendReminderNow(session.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder sent to all registrants.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't send the reminder — please try again.")));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _notifySessionStarting(BloomSession session) async {
    setState(() => _working = true);
    try {
      await SessionService.instance.sendSessionStartingNow(session.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registrants notified the session is starting.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't send the notification — please try again.")));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _syncAttendance(BloomSession session) async {
    if (session.zoomMeetingId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set a Zoom Meeting ID on this session before syncing attendance.')));
      return;
    }
    setState(() => _working = true);
    try {
      final result = await SessionService.instance.syncAttendanceFromZoom(session.id);
      if (!mounted) return;
      final message = result.unmatchedRegistrantCount > 0
          ? 'Synced: ${result.qualifiedCount}/${result.matchedCount} qualified. ${result.unmatchedRegistrantCount} registrant(s) could not be matched — review manually.'
          : 'Synced: ${result.qualifiedCount}/${result.matchedCount} registrants qualified.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Zoom sync failed: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancelSession(BloomSession session) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Session?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('All registrants will be notified this session was cancelled.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep Session')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Cancel Session', style: TextStyle(color: AppColors.coral))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _working = true);
    try {
      await SessionService.instance.cancelSession(session.id, session.title, reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session cancelled and registrants notified.')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(backgroundColor: AppColors.royalDeep, foregroundColor: Colors.white, title: const Text('Session Detail', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
      body: SafeArea(
        child: StreamBuilder<List<BloomSession>>(
          stream: SessionService.instance.watchAllSessions(),
          builder: (context, snapshot) {
            final matches = (snapshot.data ?? []).where((s) => s.id == widget.sessionId);
            final session = matches.isEmpty ? null : matches.first;
            if (session == null) {
              return const Center(child: CircularProgressIndicator(color: AppColors.royal));
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(
                  children: [
                    Expanded(child: Text(session.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.royalDeep))),
                    StatusPill(session.status.label, color: session.status == SessionStatus.cancelled ? AppColors.coral : AppColors.sage),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${_formatDate(session.date)} · ${session.startTime} – ${session.endTime}', style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                const SectionHeader('Details'),
                BloomCard(
                  child: Column(
                    children: [
                      _row('Program', session.program.isEmpty ? '—' : session.program),
                      const Divider(height: 18),
                      _row('Audience', session.ageGroup.isEmpty ? '—' : session.ageGroup),
                      const Divider(height: 18),
                      _row('Min. Attendance', '${session.minAttendancePercent}%'),
                      if (session.registrationDeadline != null) ...[
                        const Divider(height: 18),
                        _row('Registration Deadline', _formatDate(session.registrationDeadline!)),
                      ],
                    ],
                  ),
                ),
                if (session.description.isNotEmpty) ...[
                  const SectionHeader('Description'),
                  BloomCard(child: Text(session.description, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.5))),
                ],
                if (session.guestSpeakerUid != null) ...[
                  const SectionHeader('Guest Speaker'),
                  FutureBuilder<SpeakerProfile?>(
                    future: SpeakerService.instance.fetchPublishedSpeaker(session.guestSpeakerUid!),
                    builder: (context, speakerSnapshot) {
                      final speaker = speakerSnapshot.data;
                      return BloomCard(
                        child: Row(
                          children: [
                            CircleAvatar(radius: 26, backgroundColor: AppColors.rose.withValues(alpha: 0.14), backgroundImage: speaker?.photoUrl != null ? bloomNetworkImage(speaker!.photoUrl!) : null, child: speaker?.photoUrl == null ? const Icon(Icons.mic_outlined, color: AppColors.rose, size: 22) : null),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(session.guestSpeakerNameSnapshot ?? speaker?.fullName ?? 'Unknown Speaker', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  if (speaker != null) Text(speaker.speakingTopic, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                const SectionHeader('Zoom Meeting'),
                BloomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (session.zoomMeetingId.isNotEmpty) _row('Meeting ID', session.zoomMeetingId),
                      if (session.zoomPasscode.isNotEmpty) ...[const SizedBox(height: 8), _row('Passcode', session.zoomPasscode)],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _joinZoom(session.zoomMeetingLink),
                          icon: const Icon(Icons.videocam, size: 18),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.sage, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          label: const Text('JOIN / START ZOOM SESSION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader('Manage Session'),
                if (session.status == SessionStatus.published) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : () => _sendReminder(session),
                          icon: const Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.adminGoldDeep),
                          label: const Text('Send Reminder Now', style: TextStyle(color: AppColors.adminGoldDeep, fontWeight: FontWeight.w700, fontSize: 12)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.adminGoldDeep), padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : () => _notifySessionStarting(session),
                          icon: const Icon(Icons.videocam_outlined, size: 16, color: AppColors.sage),
                          label: const Text('Notify: Starting', style: TextStyle(color: AppColors.sage, fontWeight: FontWeight.w700, fontSize: 12)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.sage), padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminSessionFormScreen(existing: session))),
                        icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.royal),
                        label: const Text('Edit / Reschedule', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w700, fontSize: 12)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.royal), padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (session.status != SessionStatus.cancelled)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : () => _cancelSession(session),
                          icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.coral),
                          label: const Text('Cancel Session', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700, fontSize: 12)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.coral), padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                  ],
                ),
                const SectionHeader('Zoom Attendance Sync'),
                BloomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pulls the authoritative attendance report from Zoom and matches registrants by their Bloom account email. Manual entry below remains available for exceptions.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _working ? null : () => _syncAttendance(session),
                          icon: const Icon(Icons.sync, size: 17),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.adminGoldDeep, padding: const EdgeInsets.symmetric(vertical: 12)),
                          label: Text(_working ? 'Syncing…' : 'Sync Attendance from Zoom', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ),
                      ),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: SessionService.instance.watchSyncLogForSession(session.id),
                        builder: (context, logSnapshot) {
                          final logs = logSnapshot.data ?? [];
                          if (logs.isEmpty) return const SizedBox.shrink();
                          final latest = logs.first;
                          final status = latest['status'] as String? ?? 'unknown';
                          final startedAt = (latest['startedAt'] is Timestamp) ? (latest['startedAt'] as Timestamp).toDate() : null;
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                Icon(status == 'success' ? Icons.check_circle_outline : Icons.error_outline, size: 15, color: status == 'success' ? AppColors.sage : AppColors.coral),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    status == 'success'
                                        ? 'Last synced ${startedAt != null ? _formatDate(startedAt) : ''} · ${latest['qualifiedCount'] ?? 0}/${latest['matchedCount'] ?? 0} qualified'
                                        : 'Last sync failed: ${latest['errorMessage'] ?? 'unknown error'}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SectionHeader('Impact Metrics'),
                FutureBuilder<({int registered, int attended, int completed})>(
                  future: SessionService.instance.fetchSessionImpactMetrics(session.id),
                  builder: (context, metricsSnapshot) {
                    final metrics = metricsSnapshot.data;
                    return BloomCard(
                      child: Row(
                        children: [
                          Expanded(child: _metricTile('${metrics?.registered ?? '—'}', 'Registered', AppColors.royal)),
                          Expanded(child: _metricTile('${metrics?.attended ?? '—'}', 'Attended', AppColors.sage)),
                          Expanded(child: _metricTile('${metrics?.completed ?? '—'}', 'Completed', AppColors.amber)),
                        ],
                      ),
                    );
                  },
                ),
                const SectionHeader('Registered Participants & Attendance'),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('The check/cancel icons below are a manual override for exceptions — attendance recorded this way is audit-logged with your admin account.', style: TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.3)),
                ),
                StreamBuilder<List<SessionRegistration>>(
                  stream: SessionService.instance.watchRegistrationsForSession(session.id),
                  builder: (context, regSnapshot) {
                    final registrations = regSnapshot.data ?? [];
                    if (registrations.isEmpty) {
                      return const BloomCard(child: Text('No one has registered yet.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
                    }
                    return Column(children: registrations.map((r) => _RegistrantTile(registration: r)).toList());
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _metricTile(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _RegistrantTile extends StatefulWidget {
  const _RegistrantTile({required this.registration});

  final SessionRegistration registration;

  @override
  State<_RegistrantTile> createState() => _RegistrantTileState();
}

class _RegistrantTileState extends State<_RegistrantTile> {
  bool _working = false;

  Future<void> _toggleAttendance(bool attended) async {
    final adminUid = AuthService.instance.currentUser?.uid;
    if (adminUid == null) return;
    setState(() => _working = true);
    try {
      await SessionService.instance.recordAttendance(registrationId: widget.registration.id, attended: attended, correctedByUid: adminUid);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Color get _statusColor {
    switch (widget.registration.status) {
      case RegistrationStatus.attended:
      case RegistrationStatus.completed:
        return AppColors.sage;
      case RegistrationStatus.missed:
      case RegistrationStatus.cancelled:
        return AppColors.coral;
      default:
        return AppColors.adminGoldDeep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.registration;
    return BloomCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.participantName.isEmpty ? '(No name)' : r.participantName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    StatusPill(r.status.label, color: _statusColor),
                    if (r.attendanceSource != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        r.attendanceSource == 'zoom_import'
                            ? 'Zoom${r.attendancePercent != null ? ' · ${r.attendancePercent!.toStringAsFixed(0)}%' : ''}'
                            : 'Manual override',
                        style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (r.status != RegistrationStatus.cancelled)
            Row(
              children: [
                IconButton(
                  onPressed: _working ? null : () => _toggleAttendance(true),
                  icon: const Icon(Icons.check_circle_outline),
                  color: AppColors.sage,
                  tooltip: 'Manual override: Mark Attended',
                ),
                IconButton(
                  onPressed: _working ? null : () => _toggleAttendance(false),
                  icon: const Icon(Icons.cancel_outlined),
                  color: AppColors.coral,
                  tooltip: 'Manual override: Mark Missed',
                ),
              ],
            ),
        ],
      ),
    );
  }
}
