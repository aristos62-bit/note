// lib/core/utils/image_utils.dart
//
// SPoT για image resize/thumbnail guards.
// Χωρίς νέα dependency: image_picker maxWidth + ResizeImage/cacheWidth.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'debug_config.dart';

class ImageUtils {
  ImageUtils._();

  static const int avatarCacheSize = 256;
  static const int listThumbCacheWidth = 80;
  static const int maxGalleryBytes = 2 * 1024 * 1024;

  /// Avatar provider από base64 με downscale. Null αν άκυρο.
  static ImageProvider? avatarProvider(String? base64,
      {int size = avatarCacheSize}) {
    if (base64 == null || base64.isEmpty) return null;
    try {
      final bytes = base64Decode(base64);
      if (bytes.length > maxGalleryBytes * 4) {
        DebugConfig.warning(
            'ImageUtils.avatar: oversize photo ${bytes.length} bytes, showing downscaled');
      }
      return ResizeImage(MemoryImage(bytes),
          width: size, height: size, policy: ResizeImagePolicy.fit);
    } catch (e, stack) {
      DebugConfig.error('ImageUtils.avatarProvider', e, stack);
      return null;
    }
  }

  /// Thumbnail για File attachments στη λίστα (πραγματικό decode-resize).
  static Widget fileThumb(String path,
      {double size = 40, int cacheWidth = listThumbCacheWidth}) {
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (c, e, s) {
        DebugConfig.warning('ImageUtils.fileThumb failed for $path ($e)');
        return const Icon(Icons.insert_drive_file_outlined, size: 24);
      },
    );
  }

  /// Guard μεγέθους gallery bytes. Επιστρέφει true αν ΟΚ.
  static bool checkMaxBytes(List<int> bytes, {int max = maxGalleryBytes}) {
    if (bytes.length > max) {
      DebugConfig.warning(
          'ImageUtils.checkMaxBytes: ${bytes.length} > $max bytes');
      return false;
    }
    return true;
  }
}
