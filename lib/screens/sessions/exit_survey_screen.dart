import 'package:flutter/material.dart';

import '../../models/bloom_session.dart';
import '../../models/session_survey.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_card.dart';

/// Post-session exit survey — 5 questions per program requirements:
/// learning, confidence, application, most-valuable-learning, future
/// support interest. Submitting this is the only trigger for badge award
/// and impact-metrics inclusion — the admin never manually awards a badge
/// or calculates outcomes (spec section 8).
class ExitSurveyScreen extends StatefulWidget {
  const ExitSurveyScreen({super.key, required this.session});

  final BloomSession session;

  @override
  State<ExitSurveyScreen> createState() => _ExitSurveyScreenState();
}

class _ExitSurveyScreenState extends State<ExitSurveyScreen> {
  int _learningRating = 0;
  int _confidenceAfter = 0;
  ApplicationLikelihood? _applicationLikelihood;
  final _mostValuableCtrl = TextEditingController();
  FutureSupportInterest? _futureSupportInterest;
  bool _working = false;

  bool get _canSubmit => _learningRating > 0 && _confidenceAfter > 0 && _applicationLikelihood != null && _futureSupportInterest != null;

  @override
  void dispose() {
    _mostValuableCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = AuthService.instance.currentUser;
    if (user == null || !_canSubmit) return;

    setState(() => _working = true);
    try {
      await SessionService.instance.submitExitSurvey(
        sessionId: widget.session.id,
        uid: user.uid,
        sessionTitle: widget.session.title,
        program: widget.session.program,
        learningRating: _learningRating,
        confidenceAfter: _confidenceAfter,
        applicationLikelihood: _applicationLikelihood!,
        mostValuableLearning: _mostValuableCtrl.text.trim(),
        futureSupportInterest: _futureSupportInterest!,
      );
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Thank You! 🌸'),
            content: const Text('Your feedback has been submitted. Check My Badges for anything you\'ve earned!'),
            actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't submit your survey — please try again.")));
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
        title: const Text('Exit Survey', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(widget.session.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.royalDeep)),
            const SizedBox(height: 4),
            const Text('Tell us how this session went for you.', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 20),
            _ratingCard('I learned something new today.', _learningRating, (v) => setState(() => _learningRating = v)),
            const SizedBox(height: 14),
            _ratingCard('I feel more confident about today\'s topic after participating.', _confidenceAfter, (v) => setState(() => _confidenceAfter = v)),
            const SizedBox(height: 14),
            _choiceCard(
              'I can use something I learned today in my school, work, home, or everyday life.',
              ApplicationLikelihood.values,
              (v) => v.label,
              _applicationLikelihood,
              (v) => setState(() => _applicationLikelihood = v),
            ),
            const SizedBox(height: 14),
            BloomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What was the most valuable thing you learned today?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mostValuableCtrl,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(hintText: 'Share your thoughts (optional)...', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _choiceCard(
              'Would you be interested in future support or programming like this?',
              FutureSupportInterest.values,
              (v) => v.label,
              _futureSupportInterest,
              (v) => setState(() => _futureSupportInterest = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_working || !_canSubmit) ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.royal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(_working ? 'Submitting…' : 'SUBMIT SURVEY', style: const TextStyle(fontWeight: FontWeight.w800)),
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

  Widget _choiceCard<T>(String question, List<T> options, String Function(T) labelFor, T? selected, ValueChanged<T> onChanged) {
    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((o) {
              final isSelected = o == selected;
              return GestureDetector(
                onTap: () => onChanged(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.royal : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: isSelected ? AppColors.royal : Colors.black.withValues(alpha: 0.1)),
                  ),
                  child: Text(labelFor(o), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.inkSoft)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
