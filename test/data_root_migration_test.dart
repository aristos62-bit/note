// test/data_root_migration_test.dart
//
// S-01: crash-safe μετανάστευση βάσης + συνημμένων από το legacy root
// (Documents στα Windows) στη νέα ρίζα δεδομένων.
//
// Εδώ ελέγχονται τα πραγματικά file operations σε temp dirs:
//  • fresh / existing / resumed / migrated / abortedLegacy
//  • commit point (rename) και D3′ (legacy DB → .migration_safety)
//  • rollback μετά από invalid migrated DB (Δ2)
//  • rebasePath (pure)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:super_note/core/core.dart';
import 'package:super_note/services/services.dart';

void main() {
  late Directory tmp;
  late String root;
  late String legacy;

  String legacyDb() => AppPaths.dbFileIn(legacy);
  String newDb() => AppPaths.dbFileIn(root);
  String legacyAtt() => AppPaths.attachmentsIn(legacy);
  String newAtt() => AppPaths.attachmentsIn(root);

  void writeLegacyDb([String data = 'DB-CONTENT']) {
    File(legacyDb()).writeAsStringSync(data);
  }

  void writeLegacyAttachments(List<String> names) {
    final dir = Directory(legacyAtt())..createSync(recursive: true);
    for (final n in names) {
      File(p.join(dir.path, n)).writeAsStringSync('file:$n');
    }
  }

  List<String> namesIn(String dir) {
    final d = Directory(dir);
    if (!d.existsSync()) return <String>[];
    return d.listSync().whereType<File>().map((f) => p.basename(f.path)).toList()
      ..sort();
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sn_s01_');
    root = p.join(tmp.path, 'SuperNoteData');
    legacy = p.join(tmp.path, 'Documents');
    Directory(legacy).createSync(recursive: true);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('ensure', () {
    test('fresh: καμία βάση πουθενά → fresh, χωρίς legacy cleanup', () async {
      final plan =
          await DataRootMigration.ensure(root: root, legacyRoot: legacy);

      expect(plan.state, DataRootState.fresh);
      expect(plan.activeRoot, root);
      expect(plan.legacyRoot, isNull);
      expect(plan.needsCleanup, isFalse);
      expect(Directory(root).existsSync(), isTrue);
    });

    test('non-Windows / ίδια ρίζα → fresh (no-op)', () async {
      final plan = await DataRootMigration.ensure(
        root: legacy,
        legacyRoot: legacy,
      );
      expect(plan.state, DataRootState.fresh);
      expect(plan.activeRoot, legacy);
      expect(plan.legacyRoot, isNull);
    });

    test('existing: υπάρχει ήδη βάση στη νέα ρίζα', () async {
      Directory(root).createSync(recursive: true);
      File(newDb()).writeAsStringSync('NEW');
      writeLegacyDb();

      final plan =
          await DataRootMigration.ensure(root: root, legacyRoot: legacy);

      // Το legacy DB υπάρχει ακόμη → resumed (χρειάζεται cleanup).
      expect(plan.state, DataRootState.resumed);
      expect(plan.activeRoot, root);
      expect(plan.needsCleanup, isTrue);
      expect(File(newDb()).readAsStringSync(), 'NEW');
    });

    test('existing: χωρίς legacy → existing', () async {
      Directory(root).createSync(recursive: true);
      File(newDb()).writeAsStringSync('NEW');

      final plan =
          await DataRootMigration.ensure(root: root, legacyRoot: legacy);

      expect(plan.state, DataRootState.existing);
      expect(plan.activeRoot, root);
      expect(plan.needsCleanup, isFalse);
    });

    test('migrated: DB + συνημμένα μεταφέρονται, legacy μένει ακέραιο',
        () async {
      writeLegacyDb('DBDATA');
      writeLegacyAttachments(['a.png', 'b.png']);
      File('${legacyDb()}-lck').writeAsStringSync('lock');

      final plan =
          await DataRootMigration.ensure(root: root, legacyRoot: legacy);

      expect(plan.state, DataRootState.migrated);
      expect(plan.activeRoot, root);
      expect(plan.legacyRoot, legacy);
      expect(plan.migratedThisRun, isTrue);

      expect(File(newDb()).readAsStringSync(), 'DBDATA');
      expect(namesIn(newAtt()), ['a.png', 'b.png']);

      // D3′: τίποτα δεν διαγράφεται πριν το commit point.
      expect(File(legacyDb()).existsSync(), isTrue);
      expect(File('${legacyDb()}-lck').existsSync(), isTrue);

      // Το staging καθαρίζεται μετά το commit.
      expect(Directory(AppPaths.stagingIn(root)).existsSync(), isFalse);
    });

    test('abortedLegacy: αποτυχία rename → rollback, δεδομένα ακέραια',
        () async {
      writeLegacyDb('DBDATA');
      writeLegacyAttachments(['a.png']);
      // Εμπόδιο: φάκελος με το όνομα του τελικού αρχείου.
      Directory(root).createSync(recursive: true);
      Directory(newDb()).createSync();

      final plan =
          await DataRootMigration.ensure(root: root, legacyRoot: legacy);

      expect(plan.state, DataRootState.abortedLegacy);
      expect(plan.activeRoot, legacy);
      expect(File(legacyDb()).readAsStringSync(), 'DBDATA');
      expect(namesIn(legacyAtt()), ['a.png']);
      expect(Directory(AppPaths.stagingIn(root)).existsSync(), isFalse);
    });
  });

  group('commitAfterOpen', () {
    test('D3′: legacy DB → .migration_safety/pre_s01_*.isar', () async {
      writeLegacyDb('DBDATA');
      writeLegacyAttachments(['a.png', 'b.png']);
      File('${legacyDb()}-lck').writeAsStringSync('lock');
      Directory(AppPaths.migrationSafetyIn(legacy)).createSync(recursive: true);

      final plan =
          await DataRootMigration.ensure(root: root, legacyRoot: legacy);

      // Στην «moved» διαδρομή το legacy attachments δεν υπάρχει πλέον· το
      // ξαναφτιάχνουμε ώστε να ελεγχθεί ο καθαρισμός του allowlist.
      writeLegacyAttachments(['ghost.png']);

      await DataRootMigration.commitAfterOpen(plan, rebased: 2, missing: 0);

      expect(File(legacyDb()).existsSync(), isFalse);
      expect(File('${legacyDb()}-lck').existsSync(), isFalse);
      expect(Directory(legacyAtt()).existsSync(), isFalse);
      expect(Directory(AppPaths.migrationSafetyIn(legacy)).existsSync(),
          isFalse);

      final safety = namesIn(AppPaths.migrationSafetyIn(root));
      expect(safety.length, 1);
      expect(safety.single, startsWith('pre_s01_'));
      expect(safety.single, endsWith('.isar'));
      expect(
        File(p.join(AppPaths.migrationSafetyIn(root), safety.single))
            .readAsStringSync(),
        'DBDATA',
      );

      // Η νέα θέση μένει ανέπαφη.
      expect(File(newDb()).readAsStringSync(), 'DBDATA');
      expect(namesIn(newAtt()), ['a.png', 'b.png']);
    });

    test('missing > 0 → τα legacy συνημμένα ΔΕΝ διαγράφονται', () async {
      writeLegacyDb();
      writeLegacyAttachments(['a.png']);

      final plan =
          await DataRootMigration.ensure(root: root, legacyRoot: legacy);
      // Προσομοίωση «copy» mode / μερικής αντιγραφής: τα legacy αρχεία είναι
      // ακόμη εκεί μετά το migration.
      writeLegacyAttachments(['a.png']);

      await DataRootMigration.commitAfterOpen(plan, rebased: 0, missing: 1);

      expect(Directory(legacyAtt()).existsSync(), isTrue);
      expect(namesIn(legacyAtt()), ['a.png']);
    });

    test('χωρίς legacy (no-op) → δεν πετά', () async {
      final plan = await DataRootMigration.ensure(
        root: root,
        legacyRoot: legacy,
      );
      await expectLater(
        DataRootMigration.commitAfterOpen(plan, rebased: 0, missing: 0),
        completes,
      );
    });
  });

  group('rollbackAfterInvalidDb (Δ2)', () {
    test('διαγράφει τη νέα βάση και επαναφέρει τα συνημμένα στο legacy',
        () async {
      writeLegacyDb('DBDATA');
      writeLegacyAttachments(['a.png']);

      final plan =
          await DataRootMigration.ensure(root: root, legacyRoot: legacy);
      expect(plan.state, DataRootState.migrated);

      final rolled = await DataRootMigration.rollbackAfterInvalidDb(plan);

      expect(rolled.state, DataRootState.abortedLegacy);
      expect(rolled.activeRoot, legacy);
      expect(File(newDb()).existsSync(), isFalse);
      expect(File(legacyDb()).existsSync(), isTrue);
      expect(namesIn(legacyAtt()), ['a.png']);
      expect(namesIn(newAtt()), isEmpty);
      expect(Directory(AppPaths.stagingIn(root)).existsSync(), isFalse);
    });

    test('χωρίς legacyRoot → επιστρέφει το plan ως έχει', () async {
      final plan = await DataRootMigration.ensure(
        root: legacy,
        legacyRoot: legacy,
      );
      final rolled = await DataRootMigration.rollbackAfterInvalidDb(plan);
      expect(rolled.state, plan.state);
      expect(rolled.activeRoot, plan.activeRoot);
    });
  });

  group('rebasePath (pure)', () {
    final from = p.join('C:', 'docs', 'attachments');
    final to = p.join('C:', 'data', 'attachments');

    test('εντός from → αντίστοιχο path κάτω από to', () {
      final old = p.join(from, 'sub', 'a.png');
      expect(
        DataRootMigration.rebasePath(old, fromDir: from, toDir: to),
        p.join(to, 'sub', 'a.png'),
      );
    });

    test('εκτός from → null', () {
      expect(
        DataRootMigration.rebasePath(p.join('C:', 'docs', 'other', 'a.png'),
            fromDir: from, toDir: to),
        isNull,
      );
      expect(
        DataRootMigration.rebasePath(p.join(from, '..', 'x.png'),
            fromDir: from, toDir: to),
        isNull,
      );
    });

    test('το ίδιο το from / σχετικό / κενό → null', () {
      expect(DataRootMigration.rebasePath(from, fromDir: from, toDir: to),
          isNull);
      expect(
          DataRootMigration.rebasePath('attachments/a.png',
              fromDir: from, toDir: to),
          isNull);
      expect(DataRootMigration.rebasePath('', fromDir: from, toDir: to), isNull);
    });
  });
}
