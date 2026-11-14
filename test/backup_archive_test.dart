// test/backup_archive_test.dart
//
// Unit tests για τα pure helpers του backup zip (χωρίς Isar/plugin).
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:super_note/services/backup/backup_progress.dart';
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

  // S-307 (Δ3/Δ4): δημιουργία + εξαγωγή streaming, πρόοδος, ακύρωση.
  group('create + extract streaming (S-307)', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('snb_arch_stream_');
    });

    tearDown(() async {
      try {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      } catch (_) {}
    });

    Future<Directory> makeAttachments() async {
      final dir = Directory(p.join(tmp.path, 'attachments'));
      await dir.create();
      await File(p.join(dir.path, 'a.bin'))
          .writeAsBytes(List<int>.generate(3000, (i) => i % 251));
      await File(p.join(dir.path, 'b.bin'))
          .writeAsBytes(List<int>.generate(1500, (i) => (i * 5) % 256));
      return dir;
    }

    test('db + συνημμένα → round-trip μέσω extract', () async {
      final dbPath = p.join(tmp.path, 'super_note_db.isar');
      final dbBytes = List<int>.generate(20000, (i) => (i * 7) % 256);
      await File(dbPath).writeAsBytes(dbBytes);
      final attDir = await makeAttachments();
      final zipPath = p.join(tmp.path, 'out.zip');

      final progress = <int>[];
      final size = await BackupArchive.createBackupZip(
        dbPath: dbPath,
        attachmentsDir: attDir,
        destZipPath: zipPath,
        onProgress: (prog) {
          if (prog.phase == BackupPhase.zip) progress.add(prog.done);
        },
      );
      expect(size, greaterThan(0));
      expect(progress, isNotEmpty);
      expect(progress.last, 20000 + 3000 + 1500);

      final outDir = p.join(tmp.path, 'out');
      await Directory(outDir).create();
      final names = await BackupArchive.extractBackupZip(zipPath, outDir);
      expect(names, contains('super_note_db.isar'));
      expect(names, contains('attachments/a.bin'));
      expect(names, contains('attachments/b.bin'));

      expect(await File(p.join(outDir, 'super_note_db.isar')).readAsBytes(),
          dbBytes);
      expect(
          await File(p.join(outDir, 'attachments', 'a.bin')).length(), 3000);
      expect(
          await File(p.join(outDir, 'attachments', 'b.bin')).length(), 1500);
    });

    test('extractBackupZipDbOnly γράφει μόνο τη βάση', () async {
      final dbPath = p.join(tmp.path, 'super_note_db.isar');
      await File(dbPath).writeAsBytes(List<int>.filled(4000, 3));
      final attDir = await makeAttachments();
      final zipPath = p.join(tmp.path, 'dbonly.zip');
      await BackupArchive.createBackupZip(
        dbPath: dbPath,
        attachmentsDir: attDir,
        destZipPath: zipPath,
      );

      final outDir = p.join(tmp.path, 'dbonly');
      await Directory(outDir).create();
      final names =
          await BackupArchive.extractBackupZipDbOnly(zipPath, outDir);
      expect(names, contains('attachments/a.bin'));
      expect(File(p.join(outDir, 'super_note_db.isar')).existsSync(), true);
      expect(File(p.join(outDir, 'attachments', 'a.bin')).existsSync(), false);
    });

    test('μεγάλο zip (3MB) → streaming extract χωρίς απώλεια', () async {
      final dbPath = p.join(tmp.path, 'super_note_db.isar');
      final big = List<int>.generate(3 * 1024 * 1024, (i) => (i * 31) % 256);
      await File(dbPath).writeAsBytes(big);
      final attDir = await makeAttachments();
      final zipPath = p.join(tmp.path, 'big.zip');
      await BackupArchive.createBackupZip(
        dbPath: dbPath,
        attachmentsDir: attDir,
        destZipPath: zipPath,
      );

      final outDir = p.join(tmp.path, 'big_out');
      await Directory(outDir).create();
      await BackupArchive.extractBackupZip(zipPath, outDir);
      final extracted = await File(p.join(outDir, 'super_note_db.isar')).length();
      expect(extracted, big.length);
    });

    test('ακύρωση → BackupCancelledException', () async {
      final dbPath = p.join(tmp.path, 'super_note_db.isar');
      await File(dbPath).writeAsBytes(List<int>.filled(1000, 1));
      final attDir = await makeAttachments();
      await expectLater(
        BackupArchive.createBackupZip(
          dbPath: dbPath,
          attachmentsDir: attDir,
          destZipPath: p.join(tmp.path, 'cancelled.zip'),
          isCancelled: () => true,
        ),
        throwsA(isA<BackupCancelledException>()),
      );
    });

    test('estimateSourceBytes = db + συνημμένα', () async {
      final dbPath = p.join(tmp.path, 'super_note_db.isar');
      await File(dbPath).writeAsBytes(List<int>.filled(1234, 0));
      final attDir = await makeAttachments();
      final total = await BackupArchive.estimateSourceBytes(
        dbPath: dbPath,
        attachmentsDir: attDir,
      );
      expect(total, 1234 + 3000 + 1500);
    });

    test('estimateSourceBytes χωρίς attachments dir → μόνο db', () async {
      final dbPath = p.join(tmp.path, 'super_note_db.isar');
      await File(dbPath).writeAsBytes(List<int>.filled(500, 0));
      final total = await BackupArchive.estimateSourceBytes(
        dbPath: dbPath,
        attachmentsDir: Directory(p.join(tmp.path, 'missing')),
      );
      expect(total, 500);
    });
  });
}
