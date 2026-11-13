// test/share_attachments_test.dart
//
// E39 — Collect: φίλτρα ύπαρξης, όρια D1, μετατροπή σε XFile.
// Χρησιμοποιεί πραγματικά temp αρχεία (Directory.systemTemp).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/models/attachment.dart';
import 'package:super_note/services/share/share_attachments.dart';
import 'package:super_note/services/share/share_models.dart';

void main() {
  late Directory tmp;
  late Directory attachmentsDir;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sn_share_test_');
    // S-18: τα fixtures ζουν μέσα στο επιτρεπτό root (docs/attachments).
    attachmentsDir =
        Directory('${tmp.path}${Platform.pathSeparator}attachments')
          ..createSync(recursive: true);
    AttachmentPathGuard.configure(appDataDir: tmp.path);
  });

  tearDown(() {
    AttachmentPathGuard.reset();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Attachment att({
    required String path,
    String name = 'file.txt',
    String mime = 'text/plain',
    int size = 0,
  }) =>
      Attachment()
        ..itemId = 1
        ..fileName = name
        ..localPath = path
        ..mimeType = mime
        ..fileSize = size;

  /// Γράφει [bytes] bytes μέσα στο attachments root και επιστρέφει το path.
  String write(String name, int bytes) {
    final file = File('${attachmentsDir.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(List<int>.filled(bytes, 65));
    return file.path;
  }

  group('collect', () {
    test('αρχείο που δεν υπάρχει → skipped', () {
      final res = ShareAttachments.collect([
        att(
            path:
                '${attachmentsDir.path}${Platform.pathSeparator}missing.bin'),
      ]);
      expect(res.files, isEmpty);
      expect(res.skipped, 1);
    });

    test('fileSize 0 → μέγεθος από το δίσκο', () {
      final path = write('a.bin', 10);
      final res = ShareAttachments.collect([att(path: path, size: 0)]);
      expect(res.files.single.sizeBytes, 10);
      expect(res.skipped, 0);
    });

    test('fileSize > 0 → δεν διαβάζει το δίσκο για μέγεθος', () {
      final path = write('a.bin', 10);
      final res = ShareAttachments.collect([att(path: path, size: 9999)]);
      expect(res.files.single.sizeBytes, 9999);
    });

    test('κενό fileName → displayName από basename', () {
      final path = write('photo.png', 4);
      final res = ShareAttachments.collect([att(path: path, name: '')]);
      expect(res.files.single.displayName, 'photo.png');
    });

    test('maxFiles → κόβει τα επιπλέον', () {
      final res = ShareAttachments.collect(
        [
          att(path: write('1.bin', 1)),
          att(path: write('2.bin', 1)),
          att(path: write('3.bin', 1)),
        ],
        maxFiles: 2,
      );
      expect(res.files.length, 2);
      expect(res.skipped, 1);
    });

    test('maxTotalBytes → παραλείπει ό,τι ξεπερνά το όριο', () {
      final res = ShareAttachments.collect(
        [
          att(path: write('small.bin', 10), size: 10),
          att(path: write('big.bin', 10), size: 100),
        ],
        maxTotalBytes: 50,
      );
      expect(res.files.single.sizeBytes, 10);
      expect(res.skipped, 1);
    });

    test('διατηρεί τη σειρά φόρτωσης', () {
      final res = ShareAttachments.collect([
        att(path: write('b.bin', 1), name: 'b'),
        att(path: write('a.bin', 1), name: 'a'),
      ]);
      expect(res.files.map((f) => f.displayName).toList(), ['b', 'a']);
    });

    // ── S-18: containment guard ──────────────────────────────
    test('εκτός attachments root → skipped', () {
      final outside = File('${tmp.path}${Platform.pathSeparator}outside.bin')
        ..writeAsBytesSync(List<int>.filled(4, 65));
      final res = ShareAttachments.collect([att(path: outside.path)]);
      expect(res.files, isEmpty);
      expect(res.skipped, 1);
    });

    test('traversal .. → skipped', () {
      final path =
          '${attachmentsDir.path}${Platform.pathSeparator}..${Platform.pathSeparator}secret.bin';
      File('${tmp.path}${Platform.pathSeparator}secret.bin')
          .writeAsBytesSync(List<int>.filled(4, 65));
      final res = ShareAttachments.collect([att(path: path)]);
      expect(res.files, isEmpty);
      expect(res.skipped, 1);
    });

    test('root unset → όλα skipped (fail-closed)', () {
      final path = write('a.bin', 4);
      AttachmentPathGuard.reset();
      final res = ShareAttachments.collect([att(path: path)]);
      expect(res.files, isEmpty);
      expect(res.skipped, 1);
    });

    test('μίξη με όρια D1: νόμιμο περνά, εκτός root απορρίπτεται', () {
      final outside = File('${tmp.path}${Platform.pathSeparator}outside.bin')
        ..writeAsBytesSync(List<int>.filled(4, 65));
      final res = ShareAttachments.collect(
        [
          att(path: write('ok.bin', 4), name: 'ok.bin'),
          att(path: outside.path, name: 'outside.bin'),
        ],
        maxFiles: 2,
      );
      expect(res.files.single.displayName, 'ok.bin');
      expect(res.skipped, 1);
    });
  });

  group('toXFiles', () {
    test('κενό mimeType → null (το plugin κάνει lookup από την επέκταση)', () {
      final x = ShareAttachments.toXFiles(const [
        ShareFile(path: '/a/b.txt', displayName: 'b.txt', mimeType: ''),
      ]).single;
      expect(x.path, '/a/b.txt');
      expect(x.mimeType, isNull);
    });

    test('γνωστό mimeType → περνά αυτούσιο', () {
      final x = ShareAttachments.toXFiles(const [
        ShareFile(path: '/a/b.png', displayName: 'b.png', mimeType: 'image/png'),
      ]).single;
      expect(x.mimeType, 'image/png');
    });

    test('null mimeType → null', () {
      final x = ShareAttachments.toXFiles(const [
        ShareFile(path: '/a/b.bin', displayName: 'b.bin'),
      ]).single;
      expect(x.mimeType, isNull);
    });
  });

  group('platformSupportsFiles', () {
    testWidgets('Linux → false', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        expect(ShareAttachments.platformSupportsFiles, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Windows → true', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        expect(ShareAttachments.platformSupportsFiles, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
