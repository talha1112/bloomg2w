import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Which image namespace an upload belongs to — each has its own Storage
/// path so a member's profile photo, a speaker's headshot, and a partner's
/// logo can never collide or overwrite one another (they previously all
/// shared `profile_photos/{uid}.jpg`).
enum ImageUploadKind { profilePhoto, speakerPhoto, partnerLogo }

extension ImageUploadKindX on ImageUploadKind {
  String get folder {
    switch (this) {
      case ImageUploadKind.profilePhoto:
        return 'profile_photos';
      case ImageUploadKind.speakerPhoto:
        return 'speaker_photos';
      case ImageUploadKind.partnerLogo:
        return 'partner_logos';
    }
  }
}

/// Thin wrapper around Firebase Storage for user-uploaded images.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads an image for [uid] under the given [kind]'s namespace and
  /// returns its public download URL.
  Future<String> uploadProfilePhoto({
    required String uid,
    required XFile file,
    ImageUploadKind kind = ImageUploadKind.profilePhoto,
  }) async {
    final ref = _storage.ref('${kind.folder}/$uid.jpg');
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(File(file.path));
    }
    return ref.getDownloadURL();
  }
}
