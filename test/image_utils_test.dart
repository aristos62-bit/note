// test/image_utils_test.dart
//
// ImageUtils SPoT (Φ4a βήμα 13): guard + avatar + thumb.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/image_utils.dart';

// 1px PNG base64 (έγκυρο, μικρό).
const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  test('checkMaxBytes under/over/exact', () {
    expect(ImageUtils.checkMaxBytes(List.filled(100, 0)), isTrue);
    expect(
      ImageUtils.checkMaxBytes(
          List.filled(ImageUtils.maxGalleryBytes + 1, 0)),
      isFalse,
    );
    expect(
      ImageUtils.checkMaxBytes(
          List.filled(ImageUtils.maxGalleryBytes, 0)),
      isTrue,
    );
  });

  test('avatarProvider null/empty/invalid → null', () {
    expect(ImageUtils.avatarProvider(null), isNull);
    expect(ImageUtils.avatarProvider(''), isNull);
    expect(ImageUtils.avatarProvider('not-base64!!'), isNull);
  });

  test('avatarProvider valid → ResizeImage', () {
    final p = ImageUtils.avatarProvider(_tinyPngBase64);
    expect(p, isNotNull);
    expect(p, isA<ResizeImage>());
  });

  test('fileThumb returns Image with error fallback', () {
    final w = ImageUtils.fileThumb('/no/such/file_xyz.jpg');
    expect(w, isA<Image>());
    final img = w as Image;
    expect(img.width, 40);
    expect(img.height, 40);
    expect(img.fit, BoxFit.cover);
    expect(img.errorBuilder, isNotNull);
  });

  test('tiny png decodes (sanity)', () {
    expect(base64Decode(_tinyPngBase64), isNotEmpty);
  });
}
