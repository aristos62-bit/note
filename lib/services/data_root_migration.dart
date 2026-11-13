// lib/services/data_root_migration.dart
//
// S-01: μετανάστευση της βάσης + των συνημμένων από το legacy root
// (`getApplicationDocumentsDirectory()` — στα Windows `%USERPROFILE%\Documents`)
// στο νέο root (`AppPaths.dataRoot()` — `%LOCALAPPDATA%\SuperNoteData`).
//
// Σχεδιαστικοί κανόνες:
//  • **Κανένα delete πριν από commit point.** Το commit είναι το τελευταίο
//    βήμα (`rename` της staging βάσης στη θέση της).
//  • Όλα τα ενδιάμεσα αρχεία ζουν στο `<root>/.staging` (ίδιο volume ⇒
//    `rename` στιγμιαίο, ποτέ μισό αρχείο με τελικό όνομα).
//  • Το legacy root μένει **ακέραιο** σε κάθε αποτυχία· χειρότερο σενάριο =
//    «η μετανάστευση δεν έγινε, η εφαρμογή δουλεύει όπως πριν».
//  • Crash-safe: η κατάσταση παράγεται από artifacts (χωρίς marker file),
//    άρα μια διακοπή συνεχίζεται στο επόμενο launch.
//  • D3′: μετά το επιτυχές open, το legacy DB **δεν διαγράφεται** — γίνεται
//    `pre_s01_<ts>.isar` μέσα στο `<root>/.migration_safety` (rename, εκτός
//    Documents). Καθαρίζεται από το wipe ή από επόμενη schema migration.
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/core.dart';

/// Κατάσταση που βρέθηκε/έγινε κατά την προετοιμασία της ρίζας.
enum DataRootState {
  /// Υπάρχει ήδη βάση στο νέο root — no-op (και μετά από restore: Δ5).
  existing,

  /// Καμία βάση πουθενά — καθαρή εγκατάσταση.
  fresh,

  /// Έγινε μετανάστευση σε αυτό το launch (χρειάζεται gate + cleanup).
  migrated,

  /// Η βάση υπάρχει στο νέο root αλλά το legacy είναι ακόμη εκεί
  /// (crash μετά το commit) — εκτελείται rebase + cleanup.
  resumed,

  /// Αποτυχία πριν το commit — η εφαρμογή ανοίγει το legacy root.
  abortedLegacy,
}

class DataRootException implements Exception {
  final String message;
  const DataRootException(this.message);

  @override
  String toString() => 'DataRootException: $message';
}

class DataRootPlan {
  /// Η ρίζα-στόχος (`AppPaths.dataRoot()`).
  final String root;

  /// Η ρίζα που πρέπει να ανοίξει το Isar.
  final String activeRoot;

  /// Το legacy root, όταν υπάρχει εκκρεμότητα (migration ή cleanup).
  final String? legacyRoot;

  final DataRootState state;

  const DataRootPlan({
    required this.root,
    required this.activeRoot,
    required this.legacyRoot,
    required this.state,
  });

  /// Έγινε μετανάστευση βάσης σε αυτό το launch.
  bool get migratedThisRun => state == DataRootState.migrated;

  /// Χρειάζεται rebase συνημμένων + καθαρισμός legacy μετά το open.
  bool get needsCleanup => state == DataRootState.migrated ||
      state == DataRootState.resumed;
}

enum _AttachmentsMode { none, moved, copied }

class DataRootMigration {
  DataRootMigration._();

  /// Αποφασίζει/εκτελεί τη μετανάστευση. Δεν ανοίγει τη βάση.
  ///
  /// [root] = νέα ρίζα, [legacyRoot] = παλιά ρίζα (null εκτός Windows ή όταν
  /// είναι ίδια με τη νέα). Ποτέ δεν πετά για λόγους μετανάστευσης: σε
  /// αποτυχία επιστρέφει plan με `activeRoot = legacyRoot`.
  /// Πετά [DataRootException] μόνο όταν δεν μπορεί να δημιουργήσει τη ρίζα.
  static Future<DataRootPlan> ensure({
    required String root,
    String? legacyRoot,
  }) async {
    await _ensureDir(root);

    final staging = AppPaths.stagingIn(root);
    final newDb = File(AppPaths.dbFileIn(root));
    final sameRoot = legacyRoot == null || AppPaths.sameRoot(root, legacyRoot);

    // S0/S4: υπάρχει ήδη βάση στη νέα ρίζα.
    if (await newDb.exists()) {
      final legacyDb = sameRoot ? null : File(AppPaths.dbFileIn(legacyRoot));
      final needsCleanup = legacyDb != null && await legacyDb.exists();
      await _cleanStaging(staging);
      return DataRootPlan(
        root: root,
        activeRoot: root,
        legacyRoot: needsCleanup ? legacyRoot : null,
        state:
            needsCleanup ? DataRootState.resumed : DataRootState.existing,
      );
    }

    if (sameRoot) {
      await _cleanStaging(staging);
      return DataRootPlan(
        root: root,
        activeRoot: root,
        legacyRoot: null,
        state: DataRootState.fresh,
      );
    }

    final legacyDb = File(AppPaths.dbFileIn(legacyRoot));
    if (!await legacyDb.exists()) {
      await _cleanStaging(staging);
      return DataRootPlan(
        root: root,
        activeRoot: root,
        legacyRoot: null,
        state: DataRootState.fresh,
      );
    }

    final legacyAtt = AppPaths.attachmentsIn(legacyRoot);
    final newAtt = AppPaths.attachmentsIn(root);
    final stagingAtt = p.join(staging, AttachmentPathGuard.dirName);
    final stagingDb = p.join(staging, AppPaths.dbFileName);

    var mode = _AttachmentsMode.none;
    try {
      // Α) Αντιγραφή βάσης (μη-καταστροφικό): .partial → size check → rename.
      if (!await File(stagingDb).exists()) {
        await _ensureDir(staging);
        final partial = File('$stagingDb.partial');
        if (await partial.exists()) await partial.delete();
        await legacyDb.copy(partial.path);
        final srcLen = await legacyDb.length();
        final dstLen = await partial.length();
        if (srcLen != dstLen) {
          throw DataRootException(
              'copy size mismatch dst=$dstLen src=$srcLen');
        }
        await partial.rename(stagingDb);
      }

      // Β) Μετακίνηση συνημμένων → staging → νέα ρίζα.
      if (!await Directory(newAtt).exists()) {
        if (await Directory(stagingAtt).exists()) {
          mode = _AttachmentsMode.moved;
        } else if (await Directory(legacyAtt).exists()) {
          await _ensureDir(staging);
          mode = await _moveDir(legacyAtt, stagingAtt);
        }
        if (mode != _AttachmentsMode.none) {
          if (await Directory(newAtt).exists()) {
            throw const DataRootException(
                'attachments υπάρχουν και στους δύο χώρους');
          }
          await Directory(stagingAtt).rename(newAtt);
        }
      }

      // Γ) Commit point: η βάση παίρνει το τελικό της όνομα.
      await File(stagingDb).rename(newDb.path);
      await _cleanStaging(staging);
      DebugConfig.warning('S-01: migration OK (attachments=${mode.name})');
      return DataRootPlan(
        root: root,
        activeRoot: root,
        legacyRoot: legacyRoot,
        state: DataRootState.migrated,
      );
    } catch (e) {
      DebugConfig.warning('S-01: migration aborted → legacy ($e)');
      await _rollback(
        root: root,
        legacyRoot: legacyRoot,
        mode: mode,
      );
      await _cleanStaging(staging);
      return DataRootPlan(
        root: root,
        activeRoot: legacyRoot,
        legacyRoot: legacyRoot,
        state: DataRootState.abortedLegacy,
      );
    }
  }

  /// Rollback όταν το άνοιγμα της νέας βάσης απέτυχε το integrity gate
  /// (`AppSettings(1)` λείπει ⇒ το Isar δημιούργησε σιωπηλά κενή DB).
  /// Επαναφέρει τα συνημμένα στο legacy root και επιστρέφει plan για legacy.
  static Future<DataRootPlan> rollbackAfterInvalidDb(
      DataRootPlan plan) async {
    final legacy = plan.legacyRoot;
    if (legacy == null) return plan;
    DebugConfig.error('S-01: rollback μετά από invalid migrated DB');

    for (final name in <String>[AppPaths.dbFileName, '${AppPaths.dbFileName}-lck']) {
      try {
        final f = File(p.join(plan.root, name));
        if (await f.exists()) await f.delete();
      } catch (e) {
        DebugConfig.warning('S-01: rollback db cleanup: $e');
      }
    }
    try {
      final newAtt = Directory(AppPaths.attachmentsIn(plan.root));
      final legacyAtt = Directory(AppPaths.attachmentsIn(legacy));
      if (await newAtt.exists()) {
        if (await legacyAtt.exists()) {
          await newAtt.delete(recursive: true);
        } else {
          await newAtt.rename(legacyAtt.path);
        }
      }
    } catch (e) {
      DebugConfig.warning('S-01: rollback attachments: $e');
    }
    await _cleanStaging(AppPaths.stagingIn(plan.root));

    return DataRootPlan(
      root: plan.root,
      activeRoot: legacy,
      legacyRoot: null,
      state: DataRootState.abortedLegacy,
    );
  }

  /// Μετά το επιτυχές open + rebase: καθαρισμός legacy (allowlist).
  ///
  /// [rebased] / [missing] προέρχονται από το rebase των `Attachment.localPath`.
  /// Αν [missing] > 0 τα legacy αρχεία **δεν** διαγράφονται (προστασία).
  static Future<void> commitAfterOpen(
    DataRootPlan plan, {
    required int rebased,
    required int missing,
  }) async {
    final legacy = plan.legacyRoot;
    if (legacy == null) return;
    if (AppPaths.sameRoot(plan.root, legacy)) return;

    // 1) Legacy DB → safety snapshot μέσα στη νέα ρίζα (D3′).
    final legacyDb = File(AppPaths.dbFileIn(legacy));
    try {
      if (await legacyDb.exists()) {
        final safetyDir = Directory(AppPaths.migrationSafetyIn(plan.root));
        if (!await safetyDir.exists()) {
          await safetyDir.create(recursive: true);
        }
        final ts = DateTime.now().millisecondsSinceEpoch;
        final dest = p.join(safetyDir.path, 'pre_s01_$ts.isar');
        try {
          await legacyDb.rename(dest);
        } catch (e) {
          DebugConfig.warning('S-01: rename snapshot failed ($e) — copy');
          await legacyDb.copy(dest);
          await legacyDb.delete();
        }
        DebugConfig.warning('S-01: legacy DB → .migration_safety/pre_s01');
      }
    } catch (e) {
      // Κρατάμε το legacy DB — καμία απώλεια.
      DebugConfig.error('S-01: legacy DB snapshot failed', e);
    }

    // 2) Legacy lock (Isar: `<db>-lck`), migration snapshots, συνημμένα.
    try {
      final lck = File('${AppPaths.dbFileIn(legacy)}-lck');
      if (await lck.exists()) await lck.delete();
    } catch (e) {
      DebugConfig.warning('S-01: legacy lock cleanup: $e');
    }
    try {
      final safety = Directory(AppPaths.migrationSafetyIn(legacy));
      if (await safety.exists()) await safety.delete(recursive: true);
    } catch (e) {
      DebugConfig.warning('S-01: legacy .migration_safety cleanup: $e');
    }
    if (missing > 0) {
      DebugConfig.warning(
          'S-01: $missing συνημμένα δεν βρέθηκαν — legacy attachments kept');
    } else {
      try {
        final att = Directory(AppPaths.attachmentsIn(legacy));
        if (await att.exists()) await att.delete(recursive: true);
      } catch (e) {
        DebugConfig.warning('S-01: legacy attachments cleanup: $e');
      }
    }

    // 3) Staging.
    await _cleanStaging(AppPaths.stagingIn(plan.root));
    DebugConfig.warning(
        'S-01: cleanup done (rebased=$rebased missing=$missing)');
  }

  /// Pure: `oldPath` → αντίστοιχο path κάτω από [toDir], **μόνο** αν είναι
  /// μέσα στο [fromDir]. Επιστρέφει `null` όταν δεν επιτρέπεται/δεν αλλάζει.
  static String? rebasePath(
    String oldPath, {
    required String fromDir,
    required String toDir,
  }) {
    if (oldPath.isEmpty || !p.isAbsolute(oldPath)) return null;
    if (!p.isWithin(fromDir, oldPath)) return null;
    final rel = p.relative(oldPath, from: fromDir);
    if (rel.isEmpty || rel == '.' || rel.startsWith('..')) return null;
    return p.join(toDir, rel);
  }

  // ── internals ────────────────────────────────────────────────

  static Future<void> _ensureDir(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (e) {
      throw DataRootException('cannot create $path: $e');
    }
  }

  /// Μετακινεί φάκελο. Σε αποτυχία `rename` (άλλο volume / OneDrive / AV)
  /// αντιγράφει **χωρίς να σβήσει την πηγή** — ο καθαρισμός γίνεται μόνο
  /// μετά το commit.
  static Future<_AttachmentsMode> _moveDir(String src, String dst) async {
    try {
      await Directory(src).rename(dst);
      return _AttachmentsMode.moved;
    } catch (e) {
      DebugConfig.warning('S-01: rename attachments failed ($e) — copy');
    }
    await _ensureDir(dst);
    await for (final entity in Directory(src).list()) {
      if (entity is! File) continue;
      await entity.copy(p.join(dst, p.basename(entity.path)));
    }
    return _AttachmentsMode.copied;
  }

  /// Επαναφορά σε κατάσταση «legacy only». Best-effort, ποτέ throw.
  static Future<void> _rollback({
    required String root,
    required String legacyRoot,
    required _AttachmentsMode mode,
  }) async {
    final staging = AppPaths.stagingIn(root);
    final stagingAtt = Directory(p.join(staging, AttachmentPathGuard.dirName));
    final newAtt = Directory(AppPaths.attachmentsIn(root));
    final legacyAtt = Directory(AppPaths.attachmentsIn(legacyRoot));

    try {
      // Το commit δεν έχει γίνει, αλλά καθάρισε ό,τι μπορεί να γράφτηκε.
      for (final name in <String>[
        AppPaths.dbFileName,
        '${AppPaths.dbFileName}-lck',
      ]) {
        final f = File(p.join(root, name));
        if (await f.exists()) await f.delete();
      }
    } catch (e) {
      DebugConfig.warning('S-01: rollback db: $e');
    }

    try {
      if (await newAtt.exists()) {
        if (await legacyAtt.exists()) {
          // copy-mode: το legacy έχει τα αυθεντικά.
          await newAtt.delete(recursive: true);
        } else {
          await newAtt.rename(legacyAtt.path);
        }
      } else if (mode == _AttachmentsMode.moved &&
          await stagingAtt.exists() &&
          !await legacyAtt.exists()) {
        await stagingAtt.rename(legacyAtt.path);
      }
    } catch (e) {
      DebugConfig.warning('S-01: rollback attachments: $e');
    }
  }

  static Future<void> _cleanStaging(String staging) async {
    try {
      final dir = Directory(staging);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      DebugConfig.warning('S-01: staging cleanup: $e');
    }
  }
}
