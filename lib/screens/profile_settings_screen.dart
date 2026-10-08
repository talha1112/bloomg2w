import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/session_badge.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/bloom_card.dart';
import '../widgets/common/bloom_network_image.dart';
import '../widgets/common/page_scaffold.dart';
import '../widgets/common/section_header.dart';
import 'login_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  Uint8List? _pickedPhotoBytes;
  String? _photoUrl;
  bool _uploading = false;
  String? _error;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingPhoto();
  }

  Future<void> _loadExistingPhoto() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    // Firestore is the source of truth every other screen reads from;
    // fall back to Firebase Auth's photoURL only if that's unset.
    final profile = await UserService.instance.fetchUserProfile(uid);
    final url = profile?.photoUrl ?? AuthService.instance.currentUser?.photoURL;
    if (mounted && url != null) setState(() => _photoUrl = url);
  }

  String _memberTypeLabel(String memberType) {
    switch (memberType.toLowerCase()) {
      case 'girl':
        return 'Girls Membership (8–17)';
      case 'woman':
        return "Women's Membership";
      case 'parent':
        return 'Parent/Guardian';
      default:
        return 'Member';
    }
  }

  String _formatMemberSince(DateTime date) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _changePhoto() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _pickedPhotoBytes = bytes;
      _uploading = true;
      _error = null;
    });

    try {
      final url = await StorageService.instance.uploadProfilePhoto(uid: uid, file: picked);
      // Persist to both: Firestore (what the rest of the app reads —
      // Admin's user list/detail, etc.) and Firebase Auth (used as a
      // fallback and by any Auth-driven UI).
      await UserService.instance.updatePhotoUrl(uid: uid, photoUrl: url);
      await AuthService.instance.currentUser?.updatePhotoURL(url);
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't upload photo — try again.");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'This permanently deletes your account, profile, photos, session history, badges, and any guardian/child link. This cannot be undone.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete Account', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await UserService.instance.deleteOwnAccount();
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = "Couldn't delete your account — try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final uid = user?.uid;
    final name = (user?.displayName?.trim().isNotEmpty ?? false) ? user!.displayName! : 'Bloom Member';

    ImageProvider? avatarImage;
    if (_photoUrl != null) {
      avatarImage = bloomNetworkImage(_photoUrl!);
    } else if (_pickedPhotoBytes != null) {
      avatarImage = MemoryImage(_pickedPhotoBytes!);
    }

    return PageScaffold(
      title: 'Profile & Settings',
      children: [
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _uploading ? null : _changePhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.royal.withValues(alpha: 0.1),
                      backgroundImage: avatarImage,
                      child: avatarImage == null ? const Icon(Icons.person, color: AppColors.royalDeep, size: 40) : null,
                    ),
                    if (_uploading)
                      const Positioned.fill(
                        child: CircleAvatar(backgroundColor: Colors.black38, child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.royal, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.royalDeep)),
              Text(user?.email ?? '', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.coral)),
              ],
            ],
          ),
        ),
        const SectionHeader('Membership Information'),
        if (uid == null)
          const BloomCard(child: Text('Log in to see your membership details.', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)))
        else
          StreamBuilder<UserProfile?>(
            stream: UserService.instance.watchUserProfile(uid),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              return BloomCard(
                child: Column(
                  children: [
                    _infoRow('Membership Type', profile != null ? _memberTypeLabel(profile.memberType) : '—'),
                    const Divider(height: 20),
                    _infoRow('Member Since', profile != null ? _formatMemberSince(profile.createdAt) : '—'),
                    const Divider(height: 20),
                    _infoRow('Status', 'Active'),
                  ],
                ),
              );
            },
          ),
        const SectionHeader('My Badges'),
        if (uid == null)
          const SizedBox.shrink()
        else
          StreamBuilder<List<SessionBadge>>(
            stream: SessionService.instance.watchBadgesForUser(uid),
            builder: (context, snapshot) {
              final badges = snapshot.data ?? [];
              if (badges.isEmpty) {
                return const BloomCard(child: Text('Attend a session and complete its exit survey to earn your first badge!', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)));
              }
              return SizedBox(
                height: 88,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: badges.map((b) => _badge(b.sessionTitle)).toList(),
                ),
              );
            },
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout, size: 18, color: AppColors.coral),
          label: const Text('Sign Out', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.coral),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size.fromHeight(0),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _deleting ? null : _confirmDeleteAccount,
          icon: _deleting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral))
              : const Icon(Icons.delete_outline, size: 18, color: AppColors.coral),
          label: Text(_deleting ? 'Deleting…' : 'Delete Account', style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ],
    );
  }

  Widget _badge(String sessionTitle) {
    return Container(
      width: 84,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withValues(alpha: 0.05))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, color: AppColors.amber, size: 22),
          const SizedBox(height: 6),
          Text(sessionTitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.royalDeep, height: 1.2)),
        ],
      ),
    );
  }
}
