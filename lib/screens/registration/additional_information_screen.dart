import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/registration_data.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/wizard_scaffold.dart';
import 'notifications_optin_screen.dart';

class AdditionalInformationScreen extends StatefulWidget {
  const AdditionalInformationScreen({super.key});

  @override
  State<AdditionalInformationScreen> createState() => _AdditionalInformationScreenState();
}

class _AdditionalInformationScreenState extends State<AdditionalInformationScreen> {
  // Girls
  final _schoolCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  static const _girlInterestOptions = ['Leadership', 'STEM', 'Technology', 'Arts', 'Sports', 'Career Exploration'];

  // Women
  final _occupationCtrl = TextEditingController();
  bool _isBusinessOwner = false;
  static const _womenInterestOptions = ['Leadership', 'Career', 'Entrepreneurship', 'AI', 'Health', 'Finance'];

  // Parents
  final _childNameCtrl = TextEditingController();
  final _childAgeCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();
  final _guardianInviteCodeCtrl = TextEditingController();
  bool _linkingGuardianCode = false;
  String? _guardianCodeError;

  // Guest speakers
  final _professionCtrl = TextEditingController();
  final _organizationCtrl = TextEditingController();
  final _speakingTopicsCtrl = TextEditingController();
  final _availabilityCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _schoolCtrl,
      _gradeCtrl,
      _occupationCtrl,
      _childNameCtrl,
      _childAgeCtrl,
      _emergencyContactCtrl,
      _guardianInviteCodeCtrl,
      _professionCtrl,
      _organizationCtrl,
      _speakingTopicsCtrl,
      _availabilityCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _continue() async {
    final data = context.read<RegistrationData>();
    final userType = data.userType;

    // A guardian entering an invite code here is entirely optional —
    // linking has no expiry, so she can always do it later from Parent
    // Portal instead. An invalid code here must not block finishing
    // signup; just surface the error and let her retry or move on.
    final code = _guardianInviteCodeCtrl.text.trim();
    if (userType == BloomUserType.parent && code.isNotEmpty) {
      setState(() {
        _linkingGuardianCode = true;
        _guardianCodeError = null;
      });
      try {
        await UserService.instance.redeemInviteCode(code);
      } catch (e) {
        if (mounted) {
          setState(() => _guardianCodeError = "That code didn't work — you can try again later from Parent Portal.");
        }
      } finally {
        if (mounted) setState(() => _linkingGuardianCode = false);
      }
    }

    if (!mounted) return;
    data.update(() {
      data.school = _schoolCtrl.text.trim();
      data.grade = _gradeCtrl.text.trim();
      data.occupation = _occupationCtrl.text.trim();
      data.isBusinessOwner = _isBusinessOwner;
      data.childName = _childNameCtrl.text.trim();
      data.childAge = _childAgeCtrl.text.trim();
      data.emergencyContact = _emergencyContactCtrl.text.trim();
      data.guardianInviteCodeInput = code;
      data.profession = _professionCtrl.text.trim();
      data.organization = _organizationCtrl.text.trim();
      data.speakingTopics = _speakingTopicsCtrl.text.trim();
      data.availability = _availabilityCtrl.text.trim();
    });
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsOptInScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<RegistrationData>();
    final userType = data.userType;

    return WizardScaffold(
      step: 4,
      totalSteps: 8,
      footer: WizardPrimaryButton(
        label: _linkingGuardianCode ? 'Linking…' : 'Continue',
        enabled: !_linkingGuardianCode,
        onPressed: _continue,
      ),
      children: [
        const Text('Additional Information', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.royalDeep)),
        const SizedBox(height: 6),
        Text(
          'A few details specific to ${userType?.label ?? 'your account'}.',
          style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 24),
        if (userType == BloomUserType.girl) ..._girlsFields(data),
        if (userType == BloomUserType.woman) ..._womenFields(data),
        if (userType == BloomUserType.parent) ..._parentFields(),
        if (userType == BloomUserType.guestSpeaker) ..._speakerFields(),
      ],
    );
  }

  List<Widget> _girlsFields(RegistrationData data) {
    return [
      _field(_schoolCtrl, 'School'),
      const SizedBox(height: 14),
      _field(_gradeCtrl, 'Grade'),
      const SizedBox(height: 18),
      const Text('Interests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep)),
      const SizedBox(height: 10),
      _interestChips(_girlInterestOptions, data.girlInterests, AppColors.violet),
    ];
  }

  List<Widget> _womenFields(RegistrationData data) {
    return [
      _field(_occupationCtrl, 'Occupation'),
      const SizedBox(height: 10),
      StatefulBuilder(
        builder: (context, setLocal) => CheckboxListTile(
          value: _isBusinessOwner,
          onChanged: (v) => setLocal(() => _isBusinessOwner = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.royal,
          title: const Text('Business Owner?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 12),
      const Text('Professional Interests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep)),
      const SizedBox(height: 10),
      _interestChips(_womenInterestOptions, data.womenInterests, AppColors.cornflower),
    ];
  }

  List<Widget> _parentFields() {
    return [
      _field(_childNameCtrl, "Child's Name"),
      const SizedBox(height: 14),
      _field(_childAgeCtrl, "Child's Age", keyboardType: TextInputType.number),
      const SizedBox(height: 14),
      _field(_emergencyContactCtrl, 'Emergency Contact', keyboardType: TextInputType.phone),
      const SizedBox(height: 18),
      const Text('Link to Your Child (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep)),
      const SizedBox(height: 4),
      const Text(
        "If your daughter already has a Bloom G2W account, enter her invite code to see her sessions and badges. You can also do this later from Parent Portal.",
        style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft, height: 1.4),
      ),
      const SizedBox(height: 10),
      _field(_guardianInviteCodeCtrl, "Child's Invite Code"),
      if (_guardianCodeError != null) ...[
        const SizedBox(height: 6),
        Text(_guardianCodeError!, style: const TextStyle(color: AppColors.coral, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ],
    ];
  }

  List<Widget> _speakerFields() {
    return [
      _field(_professionCtrl, 'Profession'),
      const SizedBox(height: 14),
      _field(_organizationCtrl, 'Organization'),
      const SizedBox(height: 14),
      _field(_speakingTopicsCtrl, 'Topics You Can Speak On', maxLines: 3),
      const SizedBox(height: 14),
      _field(_availabilityCtrl, 'Availability'),
    ];
  }

  Widget _interestChips(List<String> options, Set<String> selectedSet, Color color) {
    return StatefulBuilder(
      builder: (context, setLocal) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final selected = selectedSet.contains(opt);
          return FilterChip(
            label: Text(opt, style: TextStyle(fontSize: 12.5, color: selected ? Colors.white : color, fontWeight: FontWeight.w600)),
            selected: selected,
            onSelected: (v) => setLocal(() {
              if (v) {
                selectedSet.add(opt);
              } else {
                selectedSet.remove(opt);
              }
            }),
            selectedColor: color,
            backgroundColor: color.withValues(alpha: 0.08),
            checkmarkColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: BorderSide.none),
          );
        }).toList(),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.royal, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
