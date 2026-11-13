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

  // ─────────────────────────────────────────────────────────────────
  // E50: πολλαπλοί φάκελοι (support + legacy cache) + adopt
  // ─────────────────────────────────────────────────────────────────

  group('E50 multi-dir', () {
    late Directory support;
    late Directory legacy;

    setUp(() async {
      support = Directory(p.join(tmp.path, 'support'));
      legacy = Directory(p.join(tmp.path, 'legacy'));
      await support.create();
      await legacy.create();
    });

    Future<File> put(Directory dir, String name, {String body = 'x'}) async {
      final f = File(p.join(dir.path, name));
      await f.writeAsString(body);
      return f;
    }

    test('listIn: merged, dedupe κατά basename (support κερδίζει)', () async {
      await put(support, 'auto_2026-01-01T10-00-00.snb');
      await put(support, 'auto_2026-01-03T10-00-00.snb');
      await put(legacy, 'auto_2026-01-01T10-00-00.snb'); // ίδιο όνομα
      await put(legacy, 'auto_2026-01-02T10-00-00.snb');
      await put(legacy, 'notes.txt');

      final list =
          await BackupRotation.listIn(<Directory>[support, legacy]);

      expect(list.length, 3);
      expect(list.map(p.basename).toList(), <String>[
        'auto_2026-01-03T10-00-00.snb',
        'auto_2026-01-02T10-00-00.snb',
        'auto_2026-01-01T10-00-00.snb',
      ]);
      // Το dedupe κρατά το αντίγραφο του support dir (πρώτο στη σειρά).
      expect(list.last, p.join(support.path, 'auto_2026-01-01T10-00-00.snb'));
    });

    test('listIn: ανύπαρκτοι φάκελοι → κενή λίστα (ποτέ throw)', () async {
      final a = Directory(p.join(tmp.path, 'nope1'));
      final b = Directory(p.join(tmp.path, 'nope2'));
      expect(await BackupRotation.listIn(<Directory>[a, b]), isEmpty);
    });

    test('rotateIn: όριο συνολικά, ποτέ μη-auto αρχεία', () async {
      for (var day = 1; day <= 4; day++) {
        await put(support, 'auto_2026-03-0${day}T10-00-00.snb');
      }
      for (var day = 5; day <= 7; day++) {
        await put(legacy, 'auto_2026-03-0${day}T10-00-00.snb');
      }
      await put(legacy, 'legacy_2025.zip');

      final deleted =
          await BackupRotation.rotateIn(<Directory>[support, legacy], max: 3);
      final remaining =
          await BackupRotation.listIn(<Directory>[support, legacy]);

      expect(deleted, 4);
      expect(remaining.length, 3);
      expect(remaining.map(p.basename).toList(), <String>[
        'auto_2026-03-07T10-00-00.snb',
        'auto_2026-03-06T10-00-00.snb',
        'auto_2026-03-05T10-00-00.snb',
      ]);
      expect(File(p.join(legacy.path, 'legacy_2025.zip')).existsSync(), true);
    });

    test('sweepPartialsIn: σβήνει .partial/.tmp σε όλους τους φακέλους',
        () async {
      await put(support, 'auto_1.snb.partial');
      await put(support, 'auto_1.snb');
      await put(legacy, 'auto_2.tmp');
      await put(legacy, 'auto_2.snb');

      final deleted =
          await BackupRotation.sweepPartialsIn(<Directory>[support, legacy]);

      expect(deleted, 2);
      expect(File(p.join(support.path, 'auto_1.snb')).existsSync(), true);
      expect(File(p.join(legacy.path, 'auto_2.snb')).existsSync(), true);
    });

    test('totalBytes: άθροισμα + skip λείποντος αρχείου', () async {
      await put(support, 'auto_1.snb', body: '12345');
      await put(support, 'auto_2.snb', body: '123');

      final bytes = await BackupRotation.totalBytes(<String>[
        p.join(support.path, 'auto_1.snb'),
        p.join(support.path, 'auto_2.snb'),
        p.join(support.path, 'missing.snb'),
      ]);

      expect(bytes, 8);
      expect(await BackupRotation.totalBytes(const <String>[]), 0);
    });

    test('adoptLegacy: μετακινεί μόνο auto_* και είναι idempotent', () async {
      await put(legacy, 'auto_2026-04-01T10-00-00.snb');
      await put(legacy, 'auto_2026-04-02T10-00-00.zip');
      await put(legacy, 'notes.txt');

      final r1 =
          await BackupRotation.adoptLegacy(target: support, legacy: legacy);

      expect(r1.moved, 2);
      expect(r1.failed, 0);
      expect(File(p.join(support.path, 'auto_2026-04-01T10-00-00.snb'))
          .existsSync(), true);
      expect(File(p.join(support.path, 'auto_2026-04-02T10-00-00.zip'))
          .existsSync(), true);
      // Ξένο αρχείο μένει εκεί που ήταν (ο φάκελος δεν είναι άδειος).
      expect(File(p.join(legacy.path, 'notes.txt')).existsSync(), true);
      expect(legacy.existsSync(), true);

      final r2 =
          await BackupRotation.adoptLegacy(target: support, legacy: legacy);

      expect(r2.moved, 0);
      expect(r2.skipped, 0);
      expect(r2.failed, 0);
    });

    test('adoptLegacy: άδειος legacy φάκελος διαγράφεται', () async {
      await put(legacy, 'auto_2026-04-03T10-00-00.snb');

      await BackupRotation.adoptLegacy(target: support, legacy: legacy);

      expect(legacy.existsSync(), false);
    });

    test('adoptLegacy: διπλότυπο ίδιου μεγέθους → ένα αντίγραφο', () async {
      await put(legacy, 'auto_2026-05-01T10-00-00.snb', body: 'abc');
      await put(support, 'auto_2026-05-01T10-00-00.snb', body: 'abc');

      final r =
          await BackupRotation.adoptLegacy(target: support, legacy: legacy);

      expect(r.moved, 0);
      expect(r.skipped, 1);
      expect(File(p.join(legacy.path, 'auto_2026-05-01T10-00-00.snb'))
          .existsSync(), false);
      expect(File(p.join(support.path, 'auto_2026-05-01T10-00-00.snb'))
          .existsSync(), true);
    });

    test('adoptLegacy: ίδιο όνομα, διαφορετικό μέγεθος → μένουν και τα δύο',
        () async {
      await put(legacy, 'auto_2026-05-02T10-00-00.snb', body: 'abc');
      await put(support, 'auto_2026-05-02T10-00-00.snb', body: 'abcdef');

      final r =
          await BackupRotation.adoptLegacy(target: support, legacy: legacy);

      expect(r.moved, 0);
      expect(r.skipped, 1);
      // Καμία απώλεια: το legacy παραμένει (ορατό από το dual-read).
      expect(File(p.join(legacy.path, 'auto_2026-05-02T10-00-00.snb'))
          .existsSync(), true);
      expect(File(p.join(support.path, 'auto_2026-05-02T10-00-00.snb'))
          .existsSync(), true);
    });

    test('adoptLegacy: ανύπαρκτος legacy → 0/0/0', () async {
      final missing = Directory(p.join(tmp.path, 'missing_legacy'));
      final r =
          await BackupRotation.adoptLegacy(target: support, legacy: missing);
      expect(r.moved, 0);
      expect(r.skipped, 0);
      expect(r.failed, 0);
    });

    test('list(dir) παραμένει αμετάβλητο (wrapper συμβατότητας)', () async {
      await put(support, 'auto_2026-01-01T10-00-00.snb');
      await put(support, 'auto_2026-01-02T10-00-00.snb');
      await put(support, 'notes.txt');

      final list = await BackupRotation.list(support);

      expect(list.length, 2);
      expect(p.basename(list.first), 'auto_2026-01-02T10-00-00.snb');
    });
  });
}
