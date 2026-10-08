import 'package:flutter/material.dart';

import '../../models/bloom_session.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';

/// Pre-session check-in — a short, encouraging 3-question pulse taken
/// before a session starts (knowledge, confidence, learning goal).
/// Submitting this also flips the registration's checkedIn/status flags,
/// unlocking the Join Session button.
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key, required this.session});

  final BloomSession session;

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  int _knowledgeBefore = 0;
  int _confidenceBefore = 0;
  final _goalCtrl = TextEditingController();
  bool _working = false;

  bool get _canSubmit => _knowledgeBefore > 0 && _confidenceBefore > 0;

  @override
  void dispose() {
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = AuthService.instance.currentUser;
    if (user == null || !_canSubmit) return;

    setState(() => _working = true);
    try {
      await SessionService.instance.submitCheckin(
        sessionId: widget.session.id,
        uid: user.uid,
        knowledgeBefore: _knowledgeBefore,
        confidenceBefore: _confidenceBefore,
        learningGoal: _goalCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't submit your check-in — please try again.")));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('Pre-Session Check-In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(widget.session.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.royalDeep)),
            const SizedBox(height: 4),
            const Text('Just a couple quick questions before we get started!', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 20),
            _ratingCard('How much do you know about today\'s topic?', _knowledgeBefore, (v) => setState(() => _knowledgeBefore = v)),
            const SizedBox(height: 14),
            _ratingCard('How confident are you about using what you will learn today?', _confidenceBefore, (v) => setState(() => _confidenceBefore = v)),
            const SizedBox(height: 14),
            BloomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What do you hope to learn today? (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _goalCtrl,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(hintText: 'Share what you\'re hoping to get out of this session...', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_working || !_canSubmit) ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.royal, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(_working ? 'Submitting…' : "I'm Ready — Check In!", style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingCard(String question, int value, ValueChanged<int> onChanged) {
    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final starValue = i + 1;
              return IconButton(
                onPressed: () => onChanged(starValue),
                icon: Icon(
                  starValue <= value ? Icons.star : Icons.star_border,
                  color: AppColors.amber,
                  size: 30,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
