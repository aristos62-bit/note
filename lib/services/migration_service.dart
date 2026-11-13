import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../core/utils/app_paths.dart';
import '../core/utils/debug_config.dart';
import 'app_lock_service.dart';

class MigrationService {
  MigrationService._();

  static const int _targetVersion = 4;

  static Future<void> ensureSchemaVersion(Isar isar) async {
    final settings = await isar.appSettings.get(1);
    final currentVersion = settings?.schemaVersion ?? 1;

    // Αν η τρέχουσα version είναι αρνητική ή παράλογη (π.χ. από
    // schema change που άλλαξε property IDs), γράφουμε κατευθείαν target.
    if (currentVersion < 0 || currentVersion > _targetVersion) {
      DebugConfig.db('Migration: invalid version v$currentVersion — resetting to v$_targetVersion');
      await _updateSchemaVersion(isar, _targetVersion);
      return;
    }

    if (currentVersion >= _targetVersion) {
      DebugConfig.db('Migration: current v$currentVersion, target v$_targetVersion — no action needed');
      return;
    }

    DebugConfig.db('Migration: STARTING — current v$currentVersion → target v$_targetVersion');

    await _createSafetyBackup(isar);

    for (int v = currentVersion; v < _targetVersion; v++) {
      DebugConfig.db('Migration: running v$v → v${v + 1}');
      await _runMigration(isar, v);
    }

    await _updateSchemaVersion(isar, _targetVersion);
    DebugConfig.db('Migration: COMPLETED to v$_targetVersion');
  }

  static Future<void> _createSafetyBackup(Isar isar) async {
    try {
      final dbDir = isar.directory ?? (await getApplicationDocumentsDirectory()).path;
      final dbFile = File(p.join(dbDir, AppPaths.dbFileName));
      if (!await dbFile.exists()) return;

      final backupDir = Directory(p.join(dbDir, AppPaths.migrationSafetyDirName));
      if (!await backupDir.exists()) {
        await backupDir.create();
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await dbFile.copy(p.join(backupDir.path, 'pre_migration_$timestamp.isar'));

      final existing = await backupDir.list().toList();
      if (existing.length > 3) {
        existing.sort((a, b) => a.path.compareTo(b.path));
        await (existing.first as File).delete();
      }

      DebugConfig.db('Migration: safety backup created');
    } catch (e) {
      DebugConfig.warning('Migration: safety backup failed — continuing without backup: $e');
    }
  }

  static Future<void> _updateSchemaVersion(Isar isar, int version) async {
    await isar.writeTxn(() async {
      final s = await isar.appSettings.get(1) ?? AppSettings();
      s.schemaVersion = version;
      await isar.appSettings.put(s);
    });
  }

  static Future<void> _runMigration(Isar isar, int fromVersion) async {
    switch (fromVersion) {
      case 1:
        await _v1ToV2(isar);
        break;
      case 2:
        await _v2ToV3(isar);
        break;
      case 3:
        await _v3ToV4(isar);
        break;
    }
  }

  static Future<void> _v1ToV2(Isar isar) async {
    DebugConfig.db('Migration v1→v2: fixing AppSettings.maxAttachmentSizeMB');
    await isar.writeTxn(() async {
      final s = await isar.appSettings.get(1) ?? AppSettings();
      if (s.maxAttachmentSizeMB < 0 || s.maxAttachmentSizeMB > 1000) {
        s.maxAttachmentSizeMB = 20;
        await isar.appSettings.put(s);
        DebugConfig.db('Migration v1→v2: maxAttachmentSizeMB reset to 20');
      } else {
        DebugConfig.db('Migration v1→v2: maxAttachmentSizeMB already valid (${s.maxAttachmentSizeMB})');
      }
    });
  }

  /// v2→v3: additive πεδία auto-backup (defaults false/null) — κανένας
  /// μετασχηματισμός δεδομένων, μόνο καταγραφή (safety-backup ήδη έγινε).
  static Future<void> _v2ToV3(Isar isar) async {
    DebugConfig.db('Migration v2→v3: autoBackup fields use safe defaults — no data transform');
  }

  /// v3→v4 (S-03): additive πεδία lockout — το Isar τα προσθέτει μόνο του.
  /// Εδώ γίνεται **μόνο sanitize** (clamp) ώστε κατεστραμμένο/παλιό backup να
  /// μην μπορεί να επιβάλει παράλογο lockout ή μήκος PIN.
  static Future<void> _v3ToV4(Isar isar) async {
    await isar.writeTxn(() async {
      final s = await isar.appSettings.get(1) ?? AppSettings();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final rawLen = s.appLockPinLength;
      if (rawLen < 4 || rawLen > 6) s.appLockPinLength = 6;

      s.appLockFailedAttempts =
          AppLockService.sanitizeAttempts(s.appLockFailedAttempts);
      s.appLockLockoutDurationSeconds =
          AppLockService.sanitizeLockoutDuration(
              s.appLockLockoutDurationSeconds);

      if (s.appLockLockoutDurationSeconds == 0) {
        s.appLockLockoutUntilEpochMs = 0;
        s.appLockLockoutMonoMs = 0;
      } else {
        final maxUntil =
            nowMs + s.appLockLockoutDurationSeconds * 1000;
        if (s.appLockLockoutUntilEpochMs < 0) {
          s.appLockLockoutUntilEpochMs = 0;
        }
        if (s.appLockLockoutUntilEpochMs > maxUntil) {
          s.appLockLockoutUntilEpochMs = maxUntil;
        }
        if (s.appLockLockoutMonoMs < 0) s.appLockLockoutMonoMs = 0;
      }

      if (s.appLockLastSeenWallMs < 0) s.appLockLastSeenWallMs = 0;
      if (s.appLockLastSeenWallMs > nowMs) s.appLockLastSeenWallMs = nowMs;

      await isar.appSettings.put(s);
      DebugConfig.db('Migration v3→v4: app-lock lockout fields sanitized');
    });
  }
}
