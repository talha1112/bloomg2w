import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/speaker_application.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/speaker_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_network_image.dart';
import '../login_screen.dart';
import 'speaker_application_submitted_screen.dart';

/// The Guest Speaker application form — STEP 1 of the Guest Speaker
/// Sign-Up flow. Requires the user to be signed in first; if not, sends
/// them to Login (per spec: "require them to log in or create an account
/// before submitting an application").
class SpeakerApplicationFormScreen extends StatefulWidget {
  const SpeakerApplicationFormScreen({super.key});

  @override
  State<SpeakerApplicationFormScreen> createState() => _SpeakerApplicationFormScreenState();
}

class _SpeakerApplicationFormScreenState extends State<SpeakerApplicationFormScreen> {
  // Personal information
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityStateCtrl = TextEditingController();
  final _professionalTitleCtrl = TextEditingController();
  final _professionCtrl = TextEditingController();
  final _organizationCtrl = TextEditingController();
  final _yearsExperienceCtrl = TextEditingController();
  final _linkedInCtrl = TextEditingController();

  // Credentials & experience
  final _educationCtrl = TextEditingController();
  final _certificationsCtrl = TextEditingController();
  final _professionalExperienceCtrl = TextEditingController();
  final _volunteerExperienceCtrl = TextEditingController();
  final _previousSpeakingCtrl = TextEditingController();

  // Speaking information
  final _speakingTopicCtrl = TextEditingController();
  final _presentationTitleCtrl = TextEditingController();
  final _presentationDescriptionCtrl = TextEditingController();
  final Set<String> _targetAudiences = {};

  // Expertise
  final Set<String> _expertiseAreas = {};
  final _otherExpertiseCtrl = TextEditingController();

  // Availability
  SpeakerAvailability _availability = SpeakerAvailability.either;
  final _availableDaysTimesCtrl = TextEditingController();

  // Additional
  final _whySpeakCtrl = TextEditingController();
  final _additionalInfoCtrl = TextEditingController();

  Uint8List? _pickedPhotoBytes;
  String? _photoUrl;
  bool _uploadingPhoto = false;
  bool _submitting = false;
  String? _error;

  bool get _canSubmit =>
      _fullNameCtrl.text.trim().isNotEmpty &&
      _photoUrl != null &&
      _emailCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _professionCtrl.text.trim().isNotEmpty &&
      _speakingTopicCtrl.text.trim().isNotEmpty &&
      _presentationDescriptionCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    _fullNameCtrl.text = user?.displayName ?? '';
    _emailCtrl.text = user?.email ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _fullNameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _cityStateCtrl,
      _professionalTitleCtrl,
      _professionCtrl,
      _organizationCtrl,
      _yearsExperienceCtrl,
      _linkedInCtrl,
      _educationCtrl,
      _certificationsCtrl,
      _professionalExperienceCtrl,
      _volunteerExperienceCtrl,
      _previousSpeakingCtrl,
      _speakingTopicCtrl,
      _presentationTitleCtrl,
      _presentationDescriptionCtrl,
      _otherExpertiseCtrl,
      _availableDaysTimesCtrl,
      _whySpeakCtrl,
      _additionalInfoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _pickedPhotoBytes = bytes;
      _uploadingPhoto = true;
    });
    try {
      final url = await StorageService.instance.uploadProfilePhoto(uid: uid, file: picked, kind: ImageUploadKind.speakerPhoto);
      await UserService.instance.updatePhotoUrl(uid: uid, photoUrl: url);
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't upload photo: $e");
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await SpeakerService.instance.submitApplication(
        SpeakerApplication(
          uid: uid,
          fullName: _fullNameCtrl.text.trim(),
          photoUrl: _photoUrl,
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          cityState: _cityStateCtrl.text.trim(),
          professionalTitle: _professionalTitleCtrl.text.trim(),
          profession: _professionCtrl.text.trim(),
          organization: _organizationCtrl.text.trim(),
          yearsExperience: _yearsExperienceCtrl.text.trim(),
          linkedInUrl: _linkedInCtrl.text.trim(),
          education: _educationCtrl.text.trim(),
          certifications: _certificationsCtrl.text.trim(),
          professionalExperience: _professionalExperienceCtrl.text.trim(),
          volunteerExperience: _volunteerExperienceCtrl.text.trim(),
          previousSpeakingExperience: _previousSpeakingCtrl.text.trim(),
          speakingTopic: _speakingTopicCtrl.text.trim(),
          presentationTitle: _presentationTitleCtrl.text.trim(),
          presentationDescription: _presentationDescriptionCtrl.text.trim(),
          targetAudiences: _targetAudiences.toList(),
          expertiseAreas: _expertiseAreas.toList(),
          otherExpertiseDetail: _otherExpertiseCtrl.text.trim(),
          availability: _availability,
          availableDaysTimes: _availableDaysTimesCtrl.text.trim(),
          whySpeak: _whySpeakCtrl.text.trim(),
          additionalInfo: _additionalInfoCtrl.text.trim(),
          status: SpeakerStatus.pending,
          published: false,
          createdAt: DateTime.now(),
        ),
      );

      // Ensure this account is tagged with the guestSpeaker role so it
      // routes to the Guest Speaker Dashboard on future logins.
      await UserService.instance.updateRoleIfSelf(uid: uid, role: AppRole.guestSpeaker);

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SpeakerApplicationSubmittedScreen()));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong submitting your application: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? photoImage;
    if (_photoUrl != null) {
      photoImage = bloomNetworkImage(_photoUrl!);
    } else if (_pickedPhotoBytes != null) {
      photoImage = MemoryImage(_pickedPhotoBytes!);
    }

    final signedIn = AuthService.instance.currentUser != null;
    if (!signedIn) {
      return _SignInRequiredView(
        onSignedIn: () => setState(() {
          _fullNameCtrl.text = AuthService.instance.currentUser?.displayName ?? '';
          _emailCtrl.text = AuthService.instance.currentUser?.email ?? '';
        }),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.royalDeep,
        foregroundColor: Colors.white,
        title: const Text('🎤 Guest Speaker Sign-Up', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5)),
              ),
            ],
            _sectionLabel('Personal Information'),
            Center(
              child: GestureDetector(
                onTap: _uploadingPhoto ? null : _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: AppColors.royal.withValues(alpha: 0.08),
                      backgroundImage: photoImage,
                      child: photoImage == null ? const Icon(Icons.camera_alt_outlined, color: AppColors.royal, size: 30) : null,
                    ),
                    if (_uploadingPhoto)
                      const Positioned.fill(
                        child: CircleAvatar(backgroundColor: Colors.black38, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                      ),
                  ],
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _uploadingPhoto ? null : _pickPhoto,
                child: Text(_photoUrl == null ? 'Add Profile Photo *' : 'Change Photo', style: const TextStyle(color: AppColors.royal, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
            ),
            const SizedBox(height: 8),
            _field(_fullNameCtrl, 'Full Name *'),
            const SizedBox(height: 12),
            _field(_emailCtrl, 'Email Address *', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_phoneCtrl, 'Phone Number *', keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _field(_cityStateCtrl, 'City/State'),
            const SizedBox(height: 12),
            _field(_professionalTitleCtrl, 'Professional Title'),
            const SizedBox(height: 12),
            _field(_professionCtrl, 'Profession/Occupation *'),
            const SizedBox(height: 12),
            _field(_organizationCtrl, 'Organization/Company'),
            const SizedBox(height: 12),
            _field(_yearsExperienceCtrl, 'Years of Professional Experience', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _field(_linkedInCtrl, 'LinkedIn or Professional Website (optional)', keyboardType: TextInputType.url),
            const SizedBox(height: 24),
            _sectionLabel('Credentials & Experience'),
            _field(_educationCtrl, 'Degrees/Education', maxLines: 2),
            const SizedBox(height: 12),
            _field(_certificationsCtrl, 'Certifications/Credentials', maxLines: 2),
            const SizedBox(height: 12),
            _field(_professionalExperienceCtrl, 'Professional Experience', maxLines: 3),
            const SizedBox(height: 12),
            _field(_volunteerExperienceCtrl, 'Community/Volunteer Experience', maxLines: 3),
            const SizedBox(height: 12),
            _field(_previousSpeakingCtrl, 'Previous Speaking Experience', maxLines: 3),
            const SizedBox(height: 24),
            _sectionLabel('Speaking Information'),
            _field(_speakingTopicCtrl, 'Presentation/Speaking Topic *'),
            const SizedBox(height: 12),
            _field(_presentationTitleCtrl, 'Short Presentation Title'),
            const SizedBox(height: 12),
            _field(_presentationDescriptionCtrl, 'Brief Description of Presentation *', maxLines: 3),
            const SizedBox(height: 14),
            const Text('Who is this presentation best for?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.royalDeep)),
            const SizedBox(height: 8),
            _chipWrap(kSpeakerAudienceOptions, _targetAudiences),
            const SizedBox(height: 24),
            _sectionLabel('Areas of Expertise'),
            const Text('Select all that apply.', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            _chipWrap(kSpeakerExpertiseOptions, _expertiseAreas),
            if (_expertiseAreas.contains('Other')) ...[
              const SizedBox(height: 12),
              _field(_otherExpertiseCtrl, 'Please explain'),
            ],
            const SizedBox(height: 24),
            _sectionLabel('Availability'),
            _availabilityPicker(),
            const SizedBox(height: 12),
            _field(_availableDaysTimesCtrl, 'General Days/Times Available'),
            const SizedBox(height: 24),
            _sectionLabel('Additional Information'),
            const Text('Why would you like to speak with Project Bloom Girls 2 Women?', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            _field(_whySpeakCtrl, 'Your response', maxLines: 3),
            const SizedBox(height: 12),
            _field(_additionalInfoCtrl, 'Additional Information You Would Like Us to Know', maxLines: 3),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSubmit && !_submitting ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.royal,
                  disabledBackgroundColor: AppColors.royal.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_submitting ? 'Submitting…' : 'SUBMIT SPEAKER APPLICATION →', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.royalDeep)),
    );
  }

  Widget _availabilityPicker() {
    return Row(
      children: SpeakerAvailability.values.map((a) {
        final selected = _availability == a;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _availability = a),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.royal : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? AppColors.royal : Colors.black.withValues(alpha: 0.08)),
                ),
                child: Text(a.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.ink)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _chipWrap(List<String> options, Set<String> selectedSet) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = selectedSet.contains(opt);
        return FilterChip(
          label: Text(opt, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.royal, fontWeight: FontWeight.w600)),
          selected: selected,
          onSelected: (v) => setState(() {
            if (v) {
              selectedSet.add(opt);
            } else {
              selectedSet.remove(opt);
            }
          }),
          selectedColor: AppColors.royal,
          backgroundColor: AppColors.royal.withValues(alpha: 0.06),
          checkmarkColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: BorderSide.none),
        );
      }).toList(),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
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

class _SignInRequiredView extends StatelessWidget {
  const _SignInRequiredView({required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(backgroundColor: AppColors.royalDeep, foregroundColor: Colors.white, title: const Text('Guest Speaker Sign-Up')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic_external_on_outlined, color: AppColors.royal, size: 48),
              const SizedBox(height: 16),
              const Text('Log In or Create an Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.royalDeep), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'You need to be signed in before submitting a Guest Speaker application.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                    onSignedIn();
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.royal, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Log In / Sign Up', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
