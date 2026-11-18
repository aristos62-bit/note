// test/cache_cleanup_test.dart
//
// S-19: SPoT καθαρισμού temp αντιγράφων (share_plus / pickers / backup).
// Έμφαση στο fail-closed: ποτέ διαγραφή εκτός temp, ποτέ exception.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:super_note/core/core.dart';

void main() {
  late Directory tmp;
  late String root;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sn_cache_cleanup_');
    root = p.normalize(tmp.path);
    CacheCleanup.tempRootProvider = () async => tmp;
  });

  tearDown(() {
    CacheCleanup.reset();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('isWithinTemp (λεξικός έλεγχος)', () {
    test('sharePlusDirName = share_plus (SPoT)', () {
      expect(CacheCleanup.sharePlusDirName, 'share_plus');
    });

    test('αρχείο εντός root → true', () {
      expect(CacheCleanup.isWithinTemp(p.join(root, 'a.txt'), root), isTrue);
    });

    test('υποφάκελος εντός root → true', () {
      expect(
        CacheCleanup.isWithinTemp(p.join(root, 'sub', 'a.txt'), root),
        isTrue,
      );
    });

    test('το ίδιο το root → false (ποτέ διαγραφή όλου του temp)', () {
      expect(CacheCleanup.isWithinTemp(root, root), isFalse);
    });

    test('sibling temp2 → false', () {
      final sibling = p.join(p.dirname(root), '${p.basename(root)}_2', 'a.txt');
      expect(CacheCleanup.isWithinTemp(sibling, root), isFalse);
    });

    test('relative path → false', () {
      expect(CacheCleanup.isWithinTemp(p.join('sub', 'a.txt'), root), isFalse);
    });

    test('null / κενό → false', () {
      expect(CacheCleanup.isWithinTemp(null, root), isFalse);
      expect(CacheCleanup.isWithinTemp('', root), isFalse);
    });
  });

  group('tempRootPath', () {
    test('μη απόλυτο root → null (fail-closed)', () async {
      CacheCleanup.tempRootProvider =
          () async => Directory(p.join('relative', 'tmp'));
      expect(await CacheCleanup.tempRootPath(), isNull);
    });

    test('provider που πετά → null, χωρίς exception', () async {
      CacheCleanup.tempRootProvider =
          () async => throw const FileSystemException('boom');
      expect(await CacheCleanup.tempRootPath(), isNull);
      expect(await CacheCleanup.deleteTempFile(p.join(root, 'a.txt')), isFalse);
    });
  });

  group('deleteTempFile', () {
    test('εντός temp → διαγράφεται + άδειος γονικός σβήνεται', () async {
      final dir = Directory(p.join(root, 'file_picker', '123'))
        ..createSync(recursive: true);
      final file = File(p.join(dir.path, 'a.txt'))..writeAsStringSync('x');

      expect(await CacheCleanup.deleteTempFile(file.path), isTrue);
      expect(file.existsSync(), isFalse);
      expect(dir.existsSync(), isFalse);
    });

    test('γονικός με άλλα αρχεία → μένει', () async {
      final dir = Directory(p.join(root, 'file_picker', '123'))
        ..createSync(recursive: true);
      final file = File(p.join(dir.path, 'a.txt'))..writeAsStringSync('x');
      final other = File(p.join(dir.path, 'b.txt'))..writeAsStringSync('y');

      expect(await CacheCleanup.deleteTempFile(file.path), isTrue);
      expect(other.existsSync(), isTrue);
      expect(dir.existsSync(), isTrue);
    });

    test('αρχείο απευθείας στο root → διαγράφεται, root μένει', () async {
      final file = File(p.join(root, 'a.txt'))..writeAsStringSync('x');

      expect(await CacheCleanup.deleteTempFile(file.path), isTrue);
      expect(file.existsSync(), isFalse);
      expect(tmp.existsSync(), isTrue);
    });

    test('εκτός temp → false και το αρχείο μένει', () async {
      final outside = Directory.systemTemp.createTempSync('sn_outside_');
      addTearDown(() => outside.deleteSync(recursive: true));
      final file = File(p.join(outside.path, 'user.txt'))
        ..writeAsStringSync('x');

      expect(await CacheCleanup.deleteTempFile(file.path), isFalse);
      expect(file.existsSync(), isTrue);
    });

    test('ανύπαρκτο αρχείο → false, χωρίς exception', () async {
      expect(
        await CacheCleanup.deleteTempFile(p.join(root, 'missing.txt')),
        isFalse,
      );
    });

    test('null path → false', () async {
      expect(await CacheCleanup.deleteTempFile(null), isFalse);
    });
  });

  group('deleteTempDir', () {
    test('recursive διαγραφή εντός temp → true', () async {
      final dir = Directory(p.join(root, '_backup_share_1'))
        ..createSync(recursive: true);
      File(p.join(dir.path, 'a.snb')).writeAsStringSync('x');

      expect(await CacheCleanup.deleteTempDir(dir.path), isTrue);
      expect(dir.existsSync(), isFalse);
    });

    test('το ίδιο το temp root → false', () async {
      expect(await CacheCleanup.deleteTempDir(root), isFalse);
      expect(tmp.existsSync(), isTrue);
    });

    test('ανύπαρκτος φάκελος → false', () async {
      expect(
        await CacheCleanup.deleteTempDir(p.join(root, 'nope')),
        isFalse,
      );
    });
  });

  group('deletePickedFile (platform gate)', () {
    test('desktop → δεν διαγράφει (αρχική διαδρομή χρήστη)', () async {
      CacheCleanup.pickerCopiesToTempProvider = () => false;
      final file = File(p.join(root, 'picked.pdf'))..writeAsStringSync('x');

      expect(await CacheCleanup.deletePickedFile(file.path), isFalse);
      expect(file.existsSync(), isTrue);
    });

    test('mobile → διαγράφει το temp αντίγραφο', () async {
      CacheCleanup.pickerCopiesToTempProvider = () => true;
      final file = File(p.join(root, 'picked.pdf'))..writeAsStringSync('x');

      expect(await CacheCleanup.deletePickedFile(file.path), isTrue);
      expect(file.existsSync(), isFalse);
    });

    test('mobile αλλά εκτός temp → δεν διαγράφει', () async {
      CacheCleanup.pickerCopiesToTempProvider = () => true;
      final outside = Directory.systemTemp.createTempSync('sn_outside2_');
      addTearDown(() => outside.deleteSync(recursive: true));
      final file = File(p.join(outside.path, 'user.pdf'))
        ..writeAsStringSync('x');

      expect(await CacheCleanup.deletePickedFile(file.path), isFalse);
      expect(file.existsSync(), isTrue);
    });
  });

  group('scheduling', () {
    test('scheduleTempDir → διαγράφει μετά το delay', () async {
      final dir = Directory(p.join(root, '_backup_share_2'))
        ..createSync(recursive: true);
      CacheCleanup.scheduleTempDir(
        dir.path,
        delay: const Duration(milliseconds: 10),
      );

      expect(dir.existsSync(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(dir.existsSync(), isFalse);
    });

    test('scheduleTempDir με null → no-op', () async {
      CacheCleanup.scheduleTempDir(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    test('scheduleSharePlusCleanup → διαγράφει το share_plus', () async {
      final dir = Directory(p.join(root, CacheCleanup.sharePlusDirName))
        ..createSync(recursive: true);
      File(p.join(dir.path, 'a.txt')).writeAsStringSync('x');

      CacheCleanup.scheduleSharePlusCleanup(
        delay: const Duration(milliseconds: 10),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(dir.existsSync(), isFalse);
    });

    test('generation: παλιό timer δεν σβήνει νεότερα αντίγραφα', () async {
      final dir = Directory(p.join(root, CacheCleanup.sharePlusDirName))
        ..createSync(recursive: true);
      File(p.join(dir.path, 'a.txt')).writeAsStringSync('a');

      CacheCleanup.scheduleSharePlusCleanup(
        delay: const Duration(milliseconds: 80),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      File(p.join(dir.path, 'b.txt')).writeAsStringSync('b');
      CacheCleanup.scheduleSharePlusCleanup(
        delay: const Duration(milliseconds: 150),
      );

      // t≈120ms: το παλιό timer έληξε αλλά είναι stale → δεν σβήνει τίποτα.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(dir.existsSync(), isTrue);
      expect(File(p.join(dir.path, 'b.txt')).existsSync(), isTrue);

      // t≈220ms: το νεότερο timer καθαρίζει.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(dir.existsSync(), isFalse);
    });
  });
}
