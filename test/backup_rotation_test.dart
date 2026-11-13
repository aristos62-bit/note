// test/backup_rotation_test.dart
//
// S-02: rotation / listing / partial sweep των αυτόματων αντιγράφων.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:super_note/services/backup/backup_rotation.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('snb_rot_');
  });

  tearDown(() async {
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<File> touch(String name) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsString('x');
    return f;
  }

  test('isBackupFile: .snb/.zip case-insensitive, τίποτα άλλο', () {
    expect(BackupRotation.isBackupFile('/a/auto_1.snb'), isTrue);
    expect(BackupRotation.isBackupFile('/a/AUTO_1.SNB'), isTrue);
    expect(BackupRotation.isBackupFile('/a/old.zip'), isTrue);
    expect(BackupRotation.isBackupFile('/a/notes.txt'), isFalse);
    expect(BackupRotation.isBackupFile('/a/auto_1.snb.partial'), isFalse);
  });

  test('isAutoBackupFile: μόνο auto_*.<snb|zip>', () {
    expect(BackupRotation.isAutoBackupFile('/a/auto_2026-01-01T00-00-00.snb'),
        isTrue);
    expect(BackupRotation.isAutoBackupFile('/a/auto_2026-01-01T00-00-00.zip'),
        isTrue);
    expect(BackupRotation.isAutoBackupFile('/a/legacy.zip'), isFalse);
    expect(BackupRotation.isAutoBackupFile('/a/auto_1.txt'), isFalse);
    expect(BackupRotation.isAutoBackupFile('/a/auto_1.snb.partial'), isFalse);
  });

  test('list: νεότερα πρώτα, αγνοεί μη-backup αρχεία', () async {
    await touch('auto_2026-01-01T10-00-00.snb');
    await touch('auto_2026-01-03T10-00-00.snb');
    await touch('auto_2026-01-02T10-00-00.snb');
    await touch('auto_2026-01-04T10-00-00.zip');
    await touch('notes.txt');
    await touch('legacy_2025.zip');

    final list = await BackupRotation.list(tmp);
    expect(list.length, 4);
    expect(p.basename(list.first), 'auto_2026-01-04T10-00-00.zip');
    expect(p.basename(list.last), 'auto_2026-01-01T10-00-00.snb');
    expect(list.any((path) => path.endsWith('legacy_2025.zip')), false);
  });

  test('rotate: κρατά τα max νεότερα (αγνοεί ξένα αρχεία)', () async {
    for (var day = 1; day <= 6; day++) {
      await touch('auto_2026-02-0${day}T10-00-00.snb');
    }
    await touch('legacy_2025.zip');

    final deleted = await BackupRotation.rotate(tmp, max: 3);
    final remaining = await BackupRotation.list(tmp);

    expect(deleted, 3); // 6 auto backups → κρατά 3
    expect(remaining.length, 3);
    expect(p.basename(remaining.first), 'auto_2026-02-06T10-00-00.snb');
    expect(p.basename(remaining.last), 'auto_2026-02-04T10-00-00.snb');
    // Το rotation ΔΕΝ αγγίζει αρχεία εκτός του `auto_` pattern.
    expect(File(p.join(tmp.path, 'legacy_2025.zip')).existsSync(), true);
  });

  test('rotate: max < 1 δεν διαγράφει τίποτα', () async {
    await touch('auto_a.snb');
    expect(await BackupRotation.rotate(tmp, max: 0), 0);
    expect((await BackupRotation.list(tmp)).length, 1);
  });

  test('sweepPartials: σβήνει μόνο .partial/.tmp', () async {
    await touch('auto_1.snb.partial');
    await touch('auto_1.tmp');
    await touch('auto_1.snb');

    final deleted = await BackupRotation.sweepPartials(tmp);
    final left = await tmp.list().map((e) => p.basename(e.path)).toList();

    expect(deleted, 2);
    expect(left, <String>['auto_1.snb']);
  });

  test('list σε ανύπαρκτο φάκελο → κενή λίστα', () async {
    final missing = Directory(p.join(tmp.path, 'missing'));
    expect(await BackupRotation.list(missing), isEmpty);
  });
}
