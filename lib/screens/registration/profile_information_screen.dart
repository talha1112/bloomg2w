import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/registration_data.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/bloom_network_image.dart';
import '../../widgets/common/wizard_scaffold.dart';
import 'additional_information_screen.dart';

class ProfileInformationScreen extends StatefulWidget {
  const ProfileInformationScreen({super.key});

  @override
  State<ProfileInformationScreen> createState() => _ProfileInformationScreenState();
}

class _ProfileInformationScreenState extends State<ProfileInformationScreen> {
  DateTime? _birthday;
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();

  Uint8List? _pickedPhotoBytes;
  String? _uploadedPhotoUrl;
  bool _uploadingPhoto = false;
  String? _photoError;

  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 15),
      firstDate: DateTime(now.year - 90),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthday = picked);
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
      _photoError = null;
    });

    try {
      final url = await StorageService.instance.uploadProfilePhoto(uid: uid, file: picked);
      // NOTE: the Firestore profile doc does not exist yet at this point in
      // the wizard for Girl/Woman/Parent accounts (it's created at the end
      // of _continue() below, once date of birth is known) — so the photo
      // URL is stashed on RegistrationData and written to Firestore as
      // part of that same profile-creation call, not here via a separate
      // update() that would fail with not-found.
      if (!mounted) return;
      setState(() => _uploadedPhotoUrl = url);
      final data = context.read<RegistrationData>();
      data.update(() {
        data.profilePhotoPath = picked.path;
        data.profilePhotoUrl = url;
      });
    } catch (e) {
      if (mounted) setState(() => _photoError = "Couldn't upload photo: $e");
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  int _ageInYears(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _continue() async {
    final data = context.read<RegistrationData>();

    if (_birthday == null) {
      setState(() => _submitError = 'Please select your birthday to continue.');
      return;
    }

    // Client-side age-vs-role check is a UX convenience only — the real
    // security boundary is enforced server-side (Cloud Function for Girl,
    // Firestore rules for Woman/Parent) regardless of what happens here.
    final age = _ageInYears(_birthday!);
    final userType = data.userType;
    if (userType == BloomUserType.girl && (age < 8 || age >= 18)) {
      setState(() => _submitError = 'A Girl account requires a birthday between 8 and 17 years old.');
      return;
    }
    if ((userType == BloomUserType.woman || userType == BloomUserType.parent) && age < 18) {
      setState(() => _submitError = 'This account type requires you to be 18 or older.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) {
        throw StateError('Not signed in.');
      }

      if (userType == BloomUserType.girl) {
        // Atomically creates her profile doc AND her guardian invite code —
        // see completeMinorSignup in functions/src/guardianLinking.ts.
        final inviteCode = await UserService.instance.completeMinorSignup(
          firstName: data.firstName,
          lastName: data.lastName,
          email: data.email,
          memberType: BloomUserType.girl.name,
          dateOfBirth: _birthday!,
        );
        data.update(() => data.inviteCode = inviteCode);
      } else {
        final role = userType == BloomUserType.parent ? AppRole.guardian : AppRole.member;
        await UserService.instance.createUserProfile(
          uid: uid,
          firstName: data.firstName,
          lastName: data.lastName,
          email: data.email,
          memberType: userType?.name ?? '',
          role: role,
          dateOfBirth: _birthday,
          photoUrl: _uploadedPhotoUrl,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _submitError = "Couldn't finish setting up your account: $e");
      return;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }

    data.update(() {
      data.birthday = _birthday;
      data.phoneNumber = _phoneCtrl.text.trim();
      data.city = _cityCtrl.text.trim();
      data.state = _stateCtrl.text.trim();
    });
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdditionalInformationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (_uploadedPhotoUrl != null) {
      avatarImage = bloomNetworkImage(_uploadedPhotoUrl!);
    } else if (_pickedPhotoBytes != null) {
      avatarImage = MemoryImage(_pickedPhotoBytes!);
    }

    return WizardScaffold(
      step: 3,
      totalSteps: 8,
      footer: WizardPrimaryButton(
        label: _submitting ? 'Setting Up…' : 'Continue',
        enabled: !_submitting,
        onPressed: _continue,
      ),
      children: [
        const Text('Profile Information', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.royalDeep)),
        const SizedBox(height: 6),
        const Text('Just the essentials — everything else can wait.', style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
        if (_submitError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.coral.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(_submitError!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: _uploadingPhoto ? null : _pickPhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.royal.withValues(alpha: 0.1),
                  backgroundImage: avatarImage,
                  child: avatarImage == null ? const Icon(Icons.person, color: AppColors.royal, size: 40) : null,
                ),
                if (_uploadingPhoto)
                  const Positioned.fill(
                    child: CircleAvatar(backgroundColor: Colors.black38, child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.royal, width: 1.5)),
                    child: const Icon(Icons.camera_alt, color: AppColors.royalDeep, size: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _uploadingPhoto ? null : _pickPhoto,
            child: Text(
              avatarImage == null ? 'Add Profile Photo (optional)' : 'Change Photo',
              style: const TextStyle(color: AppColors.royal, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ),
        if (_photoError != null)
          Center(child: Text(_photoError!, style: const TextStyle(color: AppColors.coral, fontSize: 12))),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickBirthday,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Birthday',
              filled: true,
              fillColor: Colors.white,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.inkSoft),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            child: Text(
              _birthday == null ? 'Select date' : '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}',
              style: TextStyle(fontSize: 14, color: _birthday == null ? AppColors.inkSoft : AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _field(_phoneCtrl, 'Phone Number', keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _field(_cityCtrl, 'City'),
        const SizedBox(height: 14),
        _field(_stateCtrl, 'State'),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
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
