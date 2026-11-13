// test/backup_archive_test.dart
//
// Unit tests για τα pure helpers του backup zip (χωρίς Isar/plugin).
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:super_note/services/backup_archive.dart';

void main() {
  group('isBackupZip', () {
    test('zip true (case-insensitive), isar false', () {
      expect(BackupArchive.isBackupZip('/a/b.zip'), true);
      expect(BackupArchive.isBackupZip('/a/B.ZIP'), true);
      expect(BackupArchive.isBackupZip('/a/b.isar'), false);
      expect(BackupArchive.isBackupZip('/a/b'), false);
    });
  });

  group('isAllowedEntry (C7)', () {
    test('επιτρεπτά: DB + επίπεδα attachments', () {
      expect(BackupArchive.isAllowedEntry('super_note_db.isar'), true);
      expect(BackupArchive.isAllowedEntry('attachments/a.png'), true);
      expect(BackupArchive.isAllowedEntry('attachments/a b.png'), true);
    });

    test('μη επιτρεπτά: traversal / nested / άγνωστα', () {
      expect(BackupArchive.isAllowedEntry('../evil.txt'), false);
      expect(BackupArchive.isAllowedEntry('attachments/../evil.txt'), false);
      expect(BackupArchive.isAllowedEntry('attachments/sub/b.png'), false);
      expect(BackupArchive.isAllowedEntry('attachments\\win.png'), false);
      expect(BackupArchive.isAllowedEntry('attachments/'), false);
      expect(BackupArchive.isAllowedEntry('attachments/..'), false);
      expect(BackupArchive.isAllowedEntry('other.bin'), false);
      expect(BackupArchive.isAllowedEntry(''), false);
    });
  });

  group('extractBackupZip allowlist', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('snb_arch_');
    });

    tearDown(() async {
      try {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      } catch (_) {}
    });

    test('γράφει μόνο DB + επίπεδα attachments', () async {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes(
            'super_note_db.isar', utf8.encode('db-bytes')))
        ..addFile(
            ArchiveFile.bytes('attachments/a.txt', utf8.encode('a')))
        ..addFile(ArchiveFile.bytes(
            'attachments/nested/b.txt', utf8.encode('nested')))
        ..addFile(ArchiveFile.bytes('../evil.txt', utf8.encode('evil')));

      final zipPath = p.join(tmp.path, 'in.zip');
      await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

      final outDir = p.join(tmp.path, 'out');
      await Directory(outDir).create();
      final names = await BackupArchive.extractBackupZip(zipPath, outDir);

      expect(names, contains('super_note_db.isar'));
      expect(names, contains('attachments/a.txt'));
      expect(
          File(p.join(outDir, 'super_note_db.isar')).existsSync(), true);
      expect(File(p.join(outDir, 'attachments', 'a.txt')).existsSync(), true);
      expect(File(p.join(outDir, 'attachments', 'nested', 'b.txt')).existsSync(),
          false);
      expect(File(p.join(outDir, '..', 'evil.txt')).existsSync(), false);
    });
  });

  group('rebasePath', () {
    test('basename στο νέο dir', () {
      final out = BackupArchive.rebasePath(
          '/old/docs/attachments/123_photo.jpg', '/new/docs/attachments');
      expect(out, p.join('/new/docs/attachments', '123_photo.jpg'));
    });

    test('cross-device absolute path ξαναγράφεται', () {
      final out = BackupArchive.rebasePath(
          r'C:\Users\X\attachments\a.png', '/data/data/app/attachments');
      expect(out?.endsWith('a.png'), true);
      expect(out?.contains('data'), true);
    });

    test('κενό basename → null', () {
      expect(BackupArchive.rebasePath('', '/new'), isNull);
    });
  });
}
