import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/registration_data.dart';
import '../../../services/auth_service.dart';
import '../../../services/storage_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/common/bloom_network_image.dart';
import '../../../widgets/common/wizard_scaffold.dart';
import 'partner_support_type_screen.dart';

/// STEP 1 — Create a Community Partner Profile.
class PartnerProfileScreen extends StatefulWidget {
  const PartnerProfileScreen({super.key});

  @override
  State<PartnerProfileScreen> createState() => _PartnerProfileScreenState();
}

class _PartnerProfileScreenState extends State<PartnerProfileScreen> {
  final _businessNameCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  Uint8List? _pickedLogoBytes;
  String? _logoUrl;
  bool _uploadingLogo = false;

  bool get _canContinue => _businessNameCtrl.text.trim().isNotEmpty && _contactPersonCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _contactPersonCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _pickedLogoBytes = bytes;
      _uploadingLogo = true;
    });
    try {
      final url = await StorageService.instance.uploadProfilePhoto(uid: uid, file: picked, kind: ImageUploadKind.partnerLogo);
      if (mounted) setState(() => _logoUrl = url);
    } catch (_) {
      // Logo is optional — silently continue without it if upload fails.
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  void _continue() {
    final data = context.read<RegistrationData>();
    data.update(() {
      data.partnerBusinessName = _businessNameCtrl.text.trim();
      data.partnerContactPerson = _contactPersonCtrl.text.trim();
      data.phoneNumber = _phoneCtrl.text.trim();
      data.partnerWebsite = _websiteCtrl.text.trim();
      data.partnerDescription = _descriptionCtrl.text.trim();
      data.partnerLogoUrl = _logoUrl;
    });
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartnerSupportTypeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? logoImage;
    if (_logoUrl != null) {
      logoImage = bloomNetworkImage(_logoUrl!);
    } else if (_pickedLogoBytes != null) {
      logoImage = MemoryImage(_pickedLogoBytes!);
    }

    return WizardScaffold(
      step: 3,
      totalSteps: 7,
      footer: WizardPrimaryButton(label: 'Continue', enabled: _canContinue, onPressed: _continue),
      children: [
        const Text('🌸 Community Partner Profile', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.royalDeep)),
        const SizedBox(height: 6),
        const Text(
          'Tell us about your business or organization.',
          style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: _uploadingLogo ? null : _pickLogo,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.royal.withValues(alpha: 0.08),
                  backgroundImage: logoImage,
                  child: logoImage == null ? const Icon(Icons.storefront_outlined, color: AppColors.royal, size: 34) : null,
                ),
                if (_uploadingLogo)
                  const Positioned.fill(
                    child: CircleAvatar(backgroundColor: Colors.black38, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.royal, width: 1.5)),
                    child: const Icon(Icons.camera_alt, color: AppColors.royalDeep, size: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _uploadingLogo ? null : _pickLogo,
            child: Text(_logoUrl == null ? 'Add Business Logo (optional)' : 'Change Logo', style: const TextStyle(color: AppColors.royal, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
        ),
        const SizedBox(height: 12),
        _field(_businessNameCtrl, 'Business/Organization Name'),
        const SizedBox(height: 14),
        _field(_contactPersonCtrl, 'Contact Person'),
        const SizedBox(height: 14),
        _field(_phoneCtrl, 'Phone', keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _field(_websiteCtrl, 'Website/Social Media', keyboardType: TextInputType.url),
        const SizedBox(height: 14),
        _field(_descriptionCtrl, 'Brief Business Description', maxLines: 3),
      ],
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
