// lib/services/backup/backup_rotation.dart
//
// S-02: rotation + listing των αυτόματων αντιγράφων. Καθαρό (χωρίς Isar),
// ώστε να είναι unit-testable με πραγματικό temp dir.
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/debug_config.dart';
import 'backup_container.dart';

class BackupRotation {
  BackupRotation._();

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
  static Future<List<String>> list(Directory dir) async {
    try {
      if (!await dir.exists()) return const <String>[];
      final files = await dir.list().toList();
      return files
          .whereType<File>()
          .map((f) => f.path)
          .where(isAutoBackupFile)
          .toList()
        ..sort((a, b) => b.compareTo(a));
    } catch (e) {
      DebugConfig.warning('BackupRotation.list failed: $e');
      return const <String>[];
    }
  }

  /// Κρατά τα [max] νεότερα και διαγράφει τα υπόλοιπα. Επιστρέφει πόσα
  /// διαγράφηκαν. Ποτέ throw.
  static Future<int> rotate(Directory dir, {required int max}) async {
    if (max < 1) return 0;
    final paths = await list(dir);
    var deleted = 0;
    for (final path in paths.skip(max)) {
      try {
        await File(path).delete();
        deleted++;
      } catch (e) {
        DebugConfig.warning('BackupRotation: delete failed ($path): $e');
      }
    }
    if (deleted > 0) {
      DebugConfig.db('BackupRotation: deleted=$deleted max=$max');
    }
    return deleted;
  }

  /// Καθαρίζει ημιτελή αρχεία (`.partial`/`.tmp`) από τον φάκελο αντιγράφων.
  static Future<int> sweepPartials(Directory dir) async {
    var deleted = 0;
    try {
      if (!await dir.exists()) return 0;
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
    return deleted;
  }
}
