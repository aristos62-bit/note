// lib/services/backup/backup_rotation.dart
//
// S-02: rotation + listing των αυτόματων αντιγράφων. Καθαρό (χωρίς Isar),
// ώστε να είναι unit-testable με πραγματικό temp dir.
//
// E50 (S305): ο φάκελος των auto backups μετακόμισε στο support dir. Εδώ
// ζει η **πολιτική** για πολλαπλούς φακέλους (support + legacy cache):
// merged list/rotation/sweep, μέγεθος και μία φορά adopt των legacy.
// Καμία εξάρτηση από path_provider/Isar — μόνο `dart:io`.
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/debug_config.dart';
import '../../core/utils/string_utils.dart';
import 'backup_container.dart';

class BackupRotation {
  BackupRotation._();

  /// E50: όριο για το copy-fallback του [adoptLegacy]. Πάνω από αυτό, το
  /// αρχείο μένει legacy (ορατό από το dual-read) αντί να μπλοκάρει το
  /// startup με μεγάλη αντιγραφή. Το rename (ίδιο volume) είναι στιγμιαίο.
  static const int adoptCopyMaxBytes = 20 * 1024 * 1024;

  /// true για αρχεία που μετράνε ως αντίγραφο (νέο `.snb` ή legacy `.zip`).
  static bool isBackupFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith(BackupContainer.suffix) || lower.endsWith('.zip');
  }

  /// Αυτόματα αντίγραφα: `<dir>/auto_*.<snb|zip>`. Μόνο αυτά διαχειρίζεται το
  /// rotation — ποτέ άλλα αρχεία που τυχόν βρίσκονται στον φάκελο.
  static bool isAutoBackupFile(String path) {
    final name = p.basename(path);
    if (!name.toLowerCase().startsWith('auto_')) return false;
    return isBackupFile(name);
  }

  /// Νεότερα πρώτα (το όνομα περιέχει sortable timestamp).
  /// Λεπτό wrapper του [listIn] — αμετάβλητη συμπεριφορά για τους callers.
  static Future<List<String>> list(Directory dir) =>
      listIn(<Directory>[dir]);

  /// E50: merged λίστα από πολλούς φακέλους.
  ///
  /// - **dedupe κατά basename**: ο **πρώτος** φάκελος στη σειρά κερδίζει —
  ///   ο caller περνά πρώτα τον νέο (support) φάκελο.
  /// - ταξινόμηση κατά **basename** φθίνουσα: το όνομα είναι UTC (S-02/C5),
  ///   άρα η σειρά είναι χρονολογική ανεξάρτητα από φάκελο/ζώνη ώρας.
  /// Ποτέ throw· φάκελος που αποτυγχάνει απλώς συνεισφέρει 0 αρχεία.
  static Future<List<String>> listIn(Iterable<Directory> dirs) async {
    final seen = <String>{};
    final paths = <String>[];
    for (final dir in dirs) {
      for (final path in await _listOne(dir)) {
        if (seen.add(p.basename(path))) paths.add(path);
      }
    }
    paths.sort((a, b) => p.basename(b).compareTo(p.basename(a)));
    return paths;
  }

  static Future<List<String>> _listOne(Directory dir) async {
    try {
      if (!await dir.exists()) return const <String>[];
      final files = await dir.list().toList();
      return files
          .whereType<File>()
          .map((f) => f.path)
          .where(isAutoBackupFile)
          .toList();
    } catch (e) {
      DebugConfig.warning('BackupRotation.list failed: $e');
      return const <String>[];
    }
  }

  /// Κρατά τα [max] νεότερα και διαγράφει τα υπόλοιπα. Επιστρέφει πόσα
  /// διαγράφηκαν. Ποτέ throw. Wrapper του [rotateIn] (αμετάβλητο API).
  static Future<int> rotate(Directory dir, {required int max}) =>
      rotateIn(<Directory>[dir], max: max);

  /// E50: merged rotation — το όριο [max] ισχύει **συνολικά** στους φακέλους
  /// (όχι ανά φάκελο), ώστε να μη διπλασιάζονται τα αντίγραφα. Ποτέ throw·
  /// ποτέ διαγραφή αρχείου που δεν είναι `auto_*.<snb|zip>`.
  static Future<int> rotateIn(Iterable<Directory> dirs,
      {required int max}) async {
    if (max < 1) return 0;
    final paths = await listIn(dirs);
    var deleted = 0;
    for (final path in paths.skip(max)) {
      try {
        await File(path).delete();
        deleted++;
      } catch (e) {
        DebugConfig.warning(
            'BackupRotation: delete failed (${AppStringUtils.redact(p.basename(path), label: 'file')}): $e');
      }
    }
    if (deleted > 0) {
      DebugConfig.db('BackupRotation: deleted=$deleted max=$max');
    }
    return deleted;
  }

  /// Καθαρίζει ημιτελή αρχεία (`.partial`/`.tmp`) από τον φάκελο αντιγράφων.
  /// Wrapper του [sweepPartialsIn] (αμετάβλητο API).
  static Future<int> sweepPartials(Directory dir) =>
      sweepPartialsIn(<Directory>[dir]);

  /// E50: sweep ημιτελών σε πολλούς φακέλους (support + legacy cache).
  /// Αγγίζει **μόνο** `.partial`/`.tmp` — ποτέ έγκυρο `.snb`/`.zip`.
  static Future<int> sweepPartialsIn(Iterable<Directory> dirs) async {
    var deleted = 0;
    for (final dir in dirs) {
      try {
        if (!await dir.exists()) continue;
        await for (final e in dir.list()) {
          final name = p.basename(e.path).toLowerCase();
          if (!name.endsWith('.partial') && !name.endsWith('.tmp')) continue;
          try {
            await e.delete(recursive: true);
            deleted++;
          } catch (err) {
            DebugConfig.warning('BackupRotation: partial cleanup failed: $err');
          }
        }
      } catch (e) {
        DebugConfig.warning('BackupRotation.sweepPartials failed: $e');
      }
    }
    if (deleted > 0) {
      DebugConfig.db('BackupRotation: partials deleted=$deleted');
    }
    return deleted;
  }

  /// E50: συνολικό μέγεθος (bytes) των δοσμένων αρχείων — για τη γραμμή
  /// πληροφορίας στο UI. Λείπον/σφάλμα ⇒ skip (ποτέ throw).
  static Future<int> totalBytes(Iterable<String> paths) async {
    var total = 0;
    for (final path in paths) {
      try {
        total += await File(path).length();
      } catch (e) {
        // Αρχείο που διαγράφηκε στο μεταξύ (rotation) — δεν είναι σφάλμα.
        DebugConfig.warning('BackupRotation.totalBytes: skip '
            '${AppStringUtils.redact(p.basename(path), label: 'file')}');
      }
    }
    return total;
  }

  /// E50: μετακίνηση legacy auto backups (cache) → [target] (support), ώστε
  /// να μη χαθούν σε «Εκκαθάριση cache». Best-effort, **idempotent**:
  /// δεύτερη κλήση επιστρέφει moved=0.
  ///
  /// - Αγγίζει **μόνο** `auto_*.<snb|zip>`.
  /// - **rename-first** (ίδιο volume στο app sandbox = στιγμιαίο)·
  ///   copy+delete μόνο αν το rename αποτύχει **και** το αρχείο είναι
  ///   ≤ [adoptCopyMaxBytes] (ώστε να μη μπλοκάρει το startup).
  /// - Σύγκρουση ίδιου basename: ίδιο μέγεθος ⇒ διαγράφεται το legacy
  ///   (αληθινό διπλότυπο)· διαφορετικό ⇒ μένουν **και τα δύο** (κανένα
  ///   delete, καμία απώλεια) και μετράνε ως skipped.
  /// - Αν ο [legacy] μείνει **άδειος**, διαγράφεται ο φάκελος (όχι ο root).
  static Future<({int moved, int skipped, int failed})> adoptLegacy({
    required Directory target,
    required Directory legacy,
  }) async {
    var moved = 0;
    var skipped = 0;
    var failed = 0;
    try {
      if (!await legacy.exists()) {
        return (moved: 0, skipped: 0, failed: 0);
      }
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      final entries = await legacy.list().toList();
      for (final e in entries) {
        if (e is! File) continue;
        final name = p.basename(e.path);
        if (!isAutoBackupFile(name)) continue;
        final dest = p.join(target.path, name);
        try {
          final destFile = File(dest);
          if (await destFile.exists()) {
            final legacyBytes = await e.length();
            final destBytes = await destFile.length();
            if (legacyBytes == destBytes) {
              // Αληθινό διπλότυπο — το αντίγραφο υπάρχει ήδη στον support.
              await e.delete();
              skipped++;
            } else {
              // Διαφορετικό περιεχόμενο: δεν σβήνουμε τίποτα.
              skipped++;
            }
            continue;
          }
          try {
            await e.rename(dest);
            moved++;
          } catch (err) {
            final len = await e.length();
            if (len > adoptCopyMaxBytes) {
              DebugConfig.warning('BackupRotation.adoptLegacy: too large to '
                  'copy (${AppStringUtils.redact(name, label: 'file')})');
              skipped++;
              continue;
            }
            await e.copy(dest);
            await e.delete();
            moved++;
          }
        } catch (err) {
          failed++;
          DebugConfig.warning('BackupRotation.adoptLegacy: failed '
              '(${AppStringUtils.redact(name, label: 'file')}): $err');
        }
      }
      // Άδειος legacy φάκελος ⇒ διαγραφή του φακέλου (ποτέ του root).
      try {
        if (await legacy.exists() && await legacy.list().isEmpty) {
          await legacy.delete();
          DebugConfig.db('BackupRotation.adoptLegacy: empty legacy dir removed');
        }
      } catch (err) {
        DebugConfig.warning('BackupRotation.adoptLegacy: legacy dir: $err');
      }
    } catch (e) {
      failed++;
      DebugConfig.warning('BackupRotation.adoptLegacy failed: $e');
    }
    DebugConfig.db(
        'BackupRotation.adoptLegacy: moved=$moved skipped=$skipped failed=$failed');
    return (moved: moved, skipped: skipped, failed: failed);
  }
}
