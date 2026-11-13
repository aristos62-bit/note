// test/share_content_builder_test.dart
//
// E39 — Render: textForMode, canOfferFiles, build (σύνθεση bundle).
// Το `build` χρησιμοποιεί πραγματικά temp αρχεία για το collect.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/models/attachment.dart';
import 'package:super_note/models/item.dart';
import 'package:super_note/services/share/share_content_builder.dart';
import 'package:super_note/services/share/share_loader.dart';
import 'package:super_note/services/share/share_models.dart';

Item _item({String? title = 'Δοκιμή', ItemType type = ItemType.note}) => Item()
  ..workspaceId = 1
  ..type = type
  ..title = title;

ShareBundle _bundle(
  List<ShareFile> files, {
  String text = '**Τίτλος**\n',
}) =>
    ShareBundle(item: _item(), text: text, files: files);

void main() {
  group('textForMode', () {
    test('textOnly → αναλλοίωτο κείμενο', () {
      final bundle = _bundle(const [
        ShareFile(path: '/a/b.txt', displayName: 'b.txt', sizeBytes: 100),
      ]);
      expect(
        ShareContentBuilder.textForMode(bundle, ShareMode.textOnly),
        bundle.text,
      );
    });

    test('textAndFiles χωρίς αρχεία → αναλλοίωτο', () {
      final bundle = _bundle(const <ShareFile>[]);
      expect(
        ShareContentBuilder.textForMode(bundle, ShareMode.textAndFiles),
        bundle.text,
      );
    });

    test('textAndFiles → λίστα 📎 στο τέλος', () {
      final bundle = _bundle(const [
        ShareFile(path: '/a/b.txt', displayName: 'b.txt', sizeBytes: 1536),
      ]);
      final out =
          ShareContentBuilder.textForMode(bundle, ShareMode.textAndFiles);
      expect(out, startsWith(bundle.text));
      expect(out, contains('📎 Συνημμένα: 1 συνημμένο'));
      expect(out, contains('  • b.txt (1.5KB)'));
      expect(out, endsWith('  • b.txt (1.5KB)'));
    });

    test('truncation στο όριο maxTextChars', () {
      final long = 'a' * (ShareLimits.maxTextChars + 500);
      final bundle = _bundle(
        const [ShareFile(path: '/a/b.txt', displayName: 'b.txt')],
        text: long,
      );
      final out =
          ShareContentBuilder.textForMode(bundle, ShareMode.textAndFiles);
      expect(out.length, ShareLimits.maxTextChars);
      expect(out, endsWith('...'));
    });
  });

  group('canOfferFiles', () {
    testWidgets('Windows + αρχεία → true', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final bundle = _bundle(
          const [ShareFile(path: '/a/b.txt', displayName: 'b.txt')],
        );
        expect(ShareContentBuilder.canOfferFiles(bundle), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Linux + αρχεία → false', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final bundle = _bundle(
          const [ShareFile(path: '/a/b.txt', displayName: 'b.txt')],
        );
        expect(ShareContentBuilder.canOfferFiles(bundle), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('χωρίς αρχεία → false', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        expect(
          ShareContentBuilder.canOfferFiles(_bundle(const <ShareFile>[])),
          isFalse,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('build', () {
    test('note χωρίς αρχεία → κείμενο από ShareText, χωρίς files', () {
      final item = _item(title: 'Σημείωση');
      final bundle = ShareContentBuilder.build(ShareData(item: item));

      expect(bundle.item, same(item));
      expect(bundle.text, contains('**Σημείωση**'));
      expect(bundle.files, isEmpty);
      expect(bundle.skippedFiles, 0);
    });

    test('συνημμένο που λείπει από το δίσκο → skippedFiles', () {
      final missing = Attachment()
        ..itemId = 1
        ..fileName = 'x.txt'
        ..localPath = '/definitely/missing/x.txt'
        ..mimeType = 'text/plain'
        ..fileSize = 5;

      final bundle = ShareContentBuilder.build(
        ShareData(item: _item(), attachments: [missing]),
      );

      expect(bundle.files, isEmpty);
      expect(bundle.skippedFiles, 1);
      expect(bundle.hasFiles, isFalse);
    });

    test('υπαρκτό συνημμένο → files + 📎 στο textAndFiles', () {
      final dir = Directory.systemTemp.createTempSync('sn_share_build_');
      // S-18: το fixture πρέπει να ζει μέσα στο επιτρεπτό root.
      AttachmentPathGuard.configure(appDataDir: dir.path);
      addTearDown(() {
        AttachmentPathGuard.reset();
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      final attachmentsDir =
          Directory('${dir.path}${Platform.pathSeparator}attachments')
            ..createSync(recursive: true);
      final path =
          '${attachmentsDir.path}${Platform.pathSeparator}έκθεση.pdf';
      File(path).writeAsBytesSync([1, 2, 3, 4]);

      final att = Attachment()
        ..itemId = 1
        ..fileName = 'έκθεση.pdf'
        ..localPath = path
        ..mimeType = 'application/pdf'
        ..fileSize = 0;

      final bundle = ShareContentBuilder.build(
        ShareData(item: _item(), attachments: [att]),
      );

      expect(bundle.hasFiles, isTrue);
      expect(bundle.files.single.sizeBytes, 4);
      expect(bundle.totalBytes, 4);

      final out =
          ShareContentBuilder.textForMode(bundle, ShareMode.textAndFiles);
      expect(out, contains('📎 Συνημμένα: 1 συνημμένο'));
      expect(out, contains('  • έκθεση.pdf (4B)'));
    });
  });
}
