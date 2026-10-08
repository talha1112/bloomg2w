import 'package:flutter/material.dart';

import '../../../models/bloom_session.dart';
import '../../../models/speaker_profile.dart';
import '../../../services/session_service.dart';
import '../../../services/speaker_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_card.dart';
import '../../../widgets/common/bloom_network_image.dart';
import '../../../widgets/common/section_header.dart';

/// Admin — Create or edit a Bloom Session. Pass [existing] to edit.
class AdminSessionFormScreen extends StatefulWidget {
  const AdminSessionFormScreen({super.key, this.existing});

  final BloomSession? existing;

  @override
  State<AdminSessionFormScreen> createState() => _AdminSessionFormScreenState();
}

class _AdminSessionFormScreenState extends State<AdminSessionFormScreen> {
  final _titleCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl = TextEditingController();
  final _zoomLinkCtrl = TextEditingController();
  final _zoomIdCtrl = TextEditingController();
  final _zoomPasscodeCtrl = TextEditingController();
  final _minAttendanceCtrl = TextEditingController(text: '80');

  DateTime? _date;
  DateTime? _registrationDeadline;
  String? _program;
  String? _ageGroup;
  String? _guestSpeakerUid;
  String? _guestSpeakerName;
  bool _saving = false;
  String? _error;

  /// The session doc ID once it exists — set from [widget.existing] when
  /// editing, or assigned after the first save when creating a new session.
  String? _sessionId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.existing?.id;
    final s = widget.existing;
    if (s != null) {
      _titleCtrl.text = s.title;
      _topicCtrl.text = s.topic;
      _descriptionCtrl.text = s.description;
      _startTimeCtrl.text = s.startTime;
      _endTimeCtrl.text = s.endTime;
      _zoomLinkCtrl.text = s.zoomMeetingLink;
      _zoomIdCtrl.text = s.zoomMeetingId;
      _zoomPasscodeCtrl.text = s.zoomPasscode;
      _minAttendanceCtrl.text = s.minAttendancePercent.toString();
      _date = s.date;
      _registrationDeadline = s.registrationDeadline;
      _program = s.program.isEmpty ? null : s.program;
      _ageGroup = s.ageGroup.isEmpty ? null : s.ageGroup;
      _guestSpeakerUid = s.guestSpeakerUid;
      _guestSpeakerName = s.guestSpeakerNameSnapshot;
    }
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _topicCtrl, _descriptionCtrl, _startTimeCtrl, _endTimeCtrl, _zoomLinkCtrl, _zoomIdCtrl, _zoomPasscodeCtrl, _minAttendanceCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSave => _titleCtrl.text.trim().isNotEmpty && _date != null && _program != null && _ageGroup != null && _startTimeCtrl.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _date ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: DateTime(now.year + 2));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickRegistrationDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _registrationDeadline ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: DateTime(now.year + 2));
    if (picked != null) setState(() => _registrationDeadline = picked);
  }

  Future<void> _pickGuestSpeaker() async {
    final speakers = await SpeakerService.instance.watchPublishedSpeakers().first;
    if (!mounted) return;
    if (speakers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No published speakers available yet.')));
      return;
    }
    final selected = await showModalBottomSheet<SpeakerProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign Guest Speaker', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.royalDeep)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.close, color: AppColors.inkSoft),
                    title: const Text('No Guest Speaker', style: TextStyle(fontSize: 13.5)),
                    onTap: () => Navigator.of(sheetContext).pop(),
                  ),
                  ...speakers.map(
                    (s) => ListTile(
                      leading: CircleAvatar(backgroundColor: AppColors.royal.withValues(alpha: 0.1), backgroundImage: s.photoUrl != null ? bloomNetworkImage(s.photoUrl!) : null, child: s.photoUrl == null ? const Icon(Icons.person, color: AppColors.royal, size: 18) : null),
                      title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      subtitle: Text(s.speakingTopic, style: const TextStyle(fontSize: 11.5)),
                      onTap: () => Navigator.of(sheetContext).pop(s),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _guestSpeakerUid = selected.uid;
        _guestSpeakerName = selected.fullName;
      });
    } else {
      setState(() {
        _guestSpeakerUid = null;
        _guestSpeakerName = null;
      });
    }
  }

  BloomSession _buildSession({required SessionStatus status}) {
    return BloomSession(
      id: _sessionId ?? '',
      title: _titleCtrl.text.trim(),
      topic: _topicCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      date: _date!,
      startTime: _startTimeCtrl.text.trim(),
      endTime: _endTimeCtrl.text.trim(),
      zoomMeetingLink: _zoomLinkCtrl.text.trim(),
      zoomMeetingId: _zoomIdCtrl.text.trim(),
      zoomPasscode: _zoomPasscodeCtrl.text.trim(),
      minAttendancePercent: int.tryParse(_minAttendanceCtrl.text.trim()) ?? 80,
      program: _program ?? '',
      ageGroup: _ageGroup ?? '',
      status: status,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      registrationDeadline: _registrationDeadline,
      guestSpeakerUid: _guestSpeakerUid,
      guestSpeakerNameSnapshot: _guestSpeakerName,
    );
  }

  Future<void> _save({required SessionStatus status}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final session = _buildSession(status: status);

      if (_sessionId != null) {
        await SessionService.instance.updateSession(_sessionId!, session, previous: widget.existing);
      } else {
        await SessionService.instance.createSession(session);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save session: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Edit Session' : 'Create Session', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5)),
              ),
            ],
            const SectionHeader('Session Details'),
            BloomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(_titleCtrl, 'Session Title *'),
                  const SizedBox(height: 10),
                  _field(_topicCtrl, 'Topic'),
                  const SizedBox(height: 10),
                  _field(_descriptionCtrl, 'Description', maxLines: 4),
                ],
              ),
            ),
            const SectionHeader('Date & Time'),
            BloomCard(
              child: Column(
                children: [
                  _pickerRow(icon: Icons.calendar_today_outlined, label: 'Date *', value: _date == null ? 'Select date' : _formatDate(_date!), onTap: _pickDate),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(child: _field(_startTimeCtrl, 'Start Time (e.g. 6:00 PM)')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_endTimeCtrl, 'End Time')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _pickerRow(icon: Icons.event_busy_outlined, label: 'Registration Deadline', value: _registrationDeadline == null ? 'None' : _formatDate(_registrationDeadline!), onTap: _pickRegistrationDeadline),
                ],
              ),
            ),
            const SectionHeader('Zoom Meeting'),
            BloomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the Zoom meeting details for this session manually.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _field(_zoomLinkCtrl, 'Zoom Meeting Link', keyboardType: TextInputType.url),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _field(_zoomIdCtrl, 'Meeting ID')),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_zoomPasscodeCtrl, 'Passcode')),
                    ],
                  ),
                ],
              ),
            ),
            const SectionHeader('Program & Audience'),
            BloomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Program *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.royalDeep)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kBloomSessionPrograms.map((p) => _choiceChip(p, _program == p, () => setState(() => _program = p))).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Age Group / Audience *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.royalDeep)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kBloomSessionAgeGroups.map((a) => _choiceChip(a, _ageGroup == a, () => setState(() => _ageGroup = a))).toList(),
                  ),
                  const SizedBox(height: 14),
                  _field(_minAttendanceCtrl, 'Minimum Attendance % (required to pass)', keyboardType: TextInputType.number),
                ],
              ),
            ),
            const SectionHeader('Guest Speaker'),
            BloomCard(
              onTap: _pickGuestSpeaker,
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: AppColors.rose.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: const Icon(Icons.mic_outlined, color: AppColors.rose, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _guestSpeakerName ?? 'Tap to assign a guest speaker (optional)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _guestSpeakerName == null ? AppColors.inkSoft : AppColors.ink),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.inkSoft, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _canSave && !_saving ? () => _save(status: SessionStatus.draft) : null,
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.royal), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Save as Draft', style: TextStyle(color: AppColors.royal, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _canSave && !_saving ? () => _save(status: SessionStatus.published) : null,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.royal, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(_saving ? 'Saving…' : 'Publish', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.royal : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.royal : Colors.black.withValues(alpha: 0.1)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.inkSoft)),
      ),
    );
  }

  Widget _pickerRow({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.royal),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.royalDeep)),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.paper,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
