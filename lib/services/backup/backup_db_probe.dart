// lib/services/backup/backup_db_probe.dart
//
// S-02: trial open + sanitize + consistent snapshot της βάσης ενός
// αντιγράφου — ΠΡΙΝ αγγίξει η ροή την live DB (verify-before-open).
//
// Γιατί ξεχωριστό αρχείο: το `validateBackupFile` του service έκανε
// extract+open+delete σε `finally`, άρα δεν μπορούσε να είναι το «prepare»
// στάδιο του restore. Εδώ η λειτουργία είναι καθαρή και επαναχρησιμοποιήσιμη.
import 'dart:io';
import 'dart:math';

import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/debug_config.dart';
import '../../models/app_settings.dart';
import '../../models/isar_schemas.dart';

class BackupSanitizeResult {
  /// true όταν το αντίγραφο περιείχε ενεργό κλείδωμα/lockout και καθαρίστηκε.
  final bool strippedAppLock;

  const BackupSanitizeResult({required this.strippedAppLock});
}

class BackupDbProbe {
  BackupDbProbe._();

  /// Ανοίγει το [dbFile] σε αντίγραφο μέσα στο [workDir], επαληθεύει ότι
  /// είναι πραγματικό SuperNote backup (υπάρχει AppSettings id=1), καθαρίζει
  /// τα lock/lockout πεδία (strip — D6/S-02) και γράφει consistent snapshot
  /// στο [destSnapshotPath].
  ///
  /// Επιστρέφει null όταν το αρχείο δεν είναι έγκυρο SuperNote backup.
  /// Ποτέ δεν πετά — ο caller μεταφράζει το null σε μήνυμα χρήστη.
  static Future<BackupSanitizeResult?> openSanitizeAndSnapshot({
    required File dbFile,
    required Directory workDir,
    required String destSnapshotPath,
  }) async {
    final unique = 'snb_probe_${DateTime.now().microsecondsSinceEpoch}_'
        '${Random().nextInt(1 << 20)}';
    final probePath = p.join(workDir.path, '$unique.isar');
    Isar? isar;
    try {
      await dbFile.copy(probePath);

      isar = await Isar.open(
        isarSchemas,
        directory: workDir.path,
        name: unique,
      );

      // ΚΡΙΣΙΜΟ: το Isar.open δημιουργεί σιωπηλά νέα κενή DB πάνω σε
      // άκυρο/κατεστραμμένο αρχείο. Το singleton AppSettings (id=1) γράφεται
      // πάντα από το SuperNoteHelper.init() → η απουσία του σημαίνει «όχι
      // έγκυρο SuperNote backup».
      final settings = await isar.appSettings.get(1);
      if (settings == null) {
        DebugConfig.warning(
            'BackupDbProbe: λείπει AppSettings(1) — μη έγκυρο αντίγραφο');
        return null;
      }

      final stripped = settings.appLockEnabled ||
          settings.appLockPinHash != null ||
          settings.biometricEnabled ||
          settings.appLockFailedAttempts != 0 ||
          settings.appLockLockoutUntilEpochMs != 0 ||
          settings.appLockLockoutDurationSeconds != 0 ||
          settings.appLockLockoutMonoMs != 0 ||
          settings.appLockLastSeenWallMs != 0;

      if (stripped) {
        await isar.writeTxn(() async {
          settings.appLockEnabled = false;
          settings.appLockPinHash = null;
          settings.biometricEnabled = false;
          settings.appLockPinLength = 6;
          settings.appLockFailedAttempts = 0;
          settings.appLockLockoutUntilEpochMs = 0;
          settings.appLockLockoutDurationSeconds = 0;
          settings.appLockLockoutMonoMs = 0;
          settings.appLockLastSeenWallMs = 0;
          await isar!.appSettings.put(settings);
        });
        DebugConfig.db('BackupDbProbe: lock/lockout fields stripped');
      }

      // Consistent, compacted snapshot για το atomic restore.
      await isar.copyToFile(destSnapshotPath);
      final size = await File(destSnapshotPath).length();
      DebugConfig.db(
          'BackupDbProbe: OK snapshot=$size bytes stripped=$stripped');
      return BackupSanitizeResult(strippedAppLock: stripped);
    } catch (e) {
      DebugConfig.warning('BackupDbProbe: Isar validation failed: $e');
      return null;
    } finally {
      try {
        await isar?.close();
      } catch (e) {
        DebugConfig.warning('BackupDbProbe: Isar close failed: $e');
      }
      try {
        final probeFile = File(probePath);
        if (await probeFile.exists()) await probeFile.delete();
      } catch (e) {
        DebugConfig.warning('BackupDbProbe: probe file cleanup failed: $e');
      }
    }
  }
}
