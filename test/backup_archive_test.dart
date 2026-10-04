// test/backup_archive_test.dart
//
// Unit tests για τα pure helpers του backup zip (χωρίς Isar/plugin).
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
