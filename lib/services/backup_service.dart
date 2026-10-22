// lib/services/backup_service.dart
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import '../core/core.dart';
import 'attachment_service.dart';
import 'backup_archive.dart';
import 'habit_service.dart';
import 'reminder_scheduler.dart';

// ── Result types ──────────────────────────────────────────────────

class BackupExportResult {
  final bool success;
  final String? path;
  final bool cancelled;
  final String? error;
  const BackupExportResult._({
    this.success = false,
    this.path,
    this.cancelled = false,
    this.error,
  });
  factory BackupExportResult.success(String path) =>
      BackupExportResult._(success: true, path: path);
  factory BackupExportResult.cancelled() =>
      const BackupExportResult._(cancelled: true);
  factory BackupExportResult.failure(String error) =>
      BackupExportResult._(error: error);
}

class BackupImportResult {
  final bool success;
  final String? error;
  final bool cancelled;

  /// true όταν η DB έκλεισε/αντικαταστάθηκε έστω και μερικώς — η εφαρμογή
  /// πρέπει να τερματιστεί ώστε το επόμενο cold start να διαβάσει τη νέα DB
  /// (stale providers/streams δεν επιτρέπεται να συνεχίσουν).
  final bool restartRequired;

  const BackupImportResult._({
    this.success = false,
    this.error,
    this.cancelled = false,
    this.restartRequired = false,
  });
  factory BackupImportResult.success({bool restartRequired = false}) =>
      BackupImportResult._(success: true, restartRequired: restartRequired);
  factory BackupImportResult.cancelled() =>
      const BackupImportResult._(cancelled: true);
  factory BackupImportResult.failure(String error,
      {bool restartRequired = false}) =>
      BackupImportResult._(error: error, restartRequired: restartRequired);
}

class ValidationResult {
  final bool valid;
  final String? reason;
  final int? sizeBytes;
  ValidationResult({required this.valid, this.reason, this.sizeBytes});
  bool get invalid => !valid;
}

class BackupService {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  static const String dbFileName = 'super_note_db.isar';
  static const String zipSuffix = '.zip';
  static const String isarSuffix = '.isar';

  /// Μέγιστο μέγεθος zip προς επαναφορά (o decoder κρατά μνήμη).
  static const int maxRestoreBytes = 500 * 1024 * 1024;

  /// Όριο για save-dialog με bytes (το plugin τα θέλει στη μνήμη).
  /// Πάνω από αυτό → κοινοποίηση (share sheet, path-based, χωρίς μνήμη).
  static const int maxDialogBytes = 100 * 1024 * 1024;
  static const String _backupDirName = 'SuperNoteBackups';
  static const int _maxAutoBackups = 5;

  /// Διάστημα αυτόματων αντιγράφων (σταθερό — χωρίς UI επιλογής).
  static const int autoBackupIntervalHours = 24;

  // ── E33 maintenance (restore/wipe) ──────────────────────────
  /// true όσο τρέχει restore/wipe: queues paused + drain ολοκληρωμένο.
  bool _maintenanceActive = false;

  /// Αυξάνεται σε κάθε έναρξη maintenance — F5: autoBackup που ξεκίνησε
  /// πριν το restore δεν γράφει lastAutoBackupAt σε DB που αλλάζει.
  int _maintenanceEpoch = 0;

  /// Πραγματικά in-flight autoBackup/export — το drain τα περιμένει πριν
  /// το close της DB (F7).
  Future<void>? _autoBackupInFlight;
  Future<void>? _exportInFlight;

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────

  Future<String> _dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, dbFileName);
  }

  // ─────────────────────────────────────────────────────────────────
  // E33 MAINTENANCE: pause + drain πριν από close (restore/wipe)
  // ─────────────────────────────────────────────────────────────────

  /// true όσο είναι ενεργό το maintenance (για UI/B8).
  bool get isMaintenanceActive => _maintenanceActive;

  /// Κλείνει τα gates scheduler/habit και περιμένει ΟΛΑ τα in-flight
  /// (passes + autoBackup + export) έως 65s. false = abort ΧΩΡΙΣ close.
  Future<bool> beginDbMaintenance() async {
    if (_maintenanceActive) {
      DebugConfig.warning(
          'BackupService.maintenance: already active — rejected');
      return false;
    }
    _maintenanceActive = true;
    _maintenanceEpoch++;
    final epoch = _maintenanceEpoch;
    DebugConfig.db('BackupService.maintenance: begin epoch=$epoch');

    ReminderScheduler.instance.pauseForMaintenance();
    HabitService.instance.pauseForMaintenance();

    const maxWait = Duration(seconds: 65); // 60s pass timeout + 5s grace
    final results = await Future.wait<bool>([
      ReminderScheduler.instance.drainForMaintenance(maxWait),
      HabitService.instance.drainForMaintenance(maxWait),
      _waitForInFlight(_autoBackupInFlight, maxWait, 'autoBackup'),
      _waitForInFlight(_exportInFlight, maxWait, 'export'),
    ]);

    if (results.every((ok) => ok)) {
      DebugConfig.db('BackupService.maintenance: drain OK epoch=$epoch');
      return true;
    }
    DebugConfig.warning(
        'BackupService.maintenance: drain TIMEOUT epoch=$epoch — abort ΧΩΡΙΣ close');
    endDbMaintenance();
    return false;
  }

  /// Ανοίγει ξανά τα gates (μόνο σε abort ΠΡΙΝ το close της DB).
  /// [rearmRefresh] true → ένα debounce refresh (F6).
  void endDbMaintenance({bool rearmRefresh = true}) {
    if (!_maintenanceActive) return;
    _maintenanceActive = false;
    ReminderScheduler.instance
        .resumeAfterMaintenance(rearmRefresh: rearmRefresh);
    HabitService.instance.resumeAfterMaintenance();
    DebugConfig.db('BackupService.maintenance: end rearm=$rearmRefresh');
  }

  /// Περιμένει ένα in-flight future με κοινό budget. Ποτέ throw.
  Future<bool> _waitForInFlight(
      Future<void>? future, Duration maxWait, String label) async {
    if (future == null) return true;
    try {
      await future.timeout(maxWait);
      return true;
    } on TimeoutException catch (e) {
      DebugConfig.warning(
          'BackupService.maintenance: $label drain TIMEOUT ($e)');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 1. EXPORT: Αποθήκευση στη συσκευή (με system save dialog)
  // ─────────────────────────────────────────────────────────────────

  /// Δημόσιο entry point — καταγράφει το in-flight future για το drain του
  /// restore/wipe (F7). Το impl μένει αναλλοίωτο.
  Future<BackupExportResult> exportToDevice() {
    final future = _exportToDeviceImpl();
    _exportInFlight = future.then<void>(
          (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return future;
  }

  Future<BackupExportResult> _exportToDeviceImpl() async {
    DebugConfig.db('exportToDevice: starting');
    Directory? workDir;
    try {
      final tempRoot = await getTemporaryDirectory();
      workDir = await Directory(p.join(tempRoot.path,
              '_backup_export_${DateTime.now().millisecondsSinceEpoch}'))
          .create(recursive: true);
      final srcPath = await _dbPath();
      if (!await File(srcPath).exists()) {
        DebugConfig.db('exportToDevice: FAIL — DB file not found: $srcPath');
        throw Exception('Δεν βρέθηκε η βάση δεδομένων');
      }
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'super_note_backup_$timestamp.zip';
      final tempZip = p.join(workDir.path, fileName);
      final docs = await getApplicationDocumentsDirectory();
      await BackupArchive.createBackupZip(
        dbPath: srcPath,
        snapshotIsar: SuperNoteHelper.instance.isar,
        attachmentsDir: Directory(
            p.join(docs.path, AttachmentService.attachmentsDirName)),
        destZipPath: tempZip,
      );
      DebugConfig.db('exportToDevice: zip ready');
      try {
        // Android/iOS: το saveFile ΓΡΑΦΕΙ μόνο του (απαιτεί bytes) —
        // δεν επιστρέφει path για File.copy (file_picker_io).
        final zipSize = await File(tempZip).length();
        if (zipSize > maxDialogBytes) {
          return BackupExportResult.failure(
              'Το αντίγραφο είναι πολύ μεγάλο — χρησιμοποίησε Κοινοποίηση');
        }
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Αποθήκευση αντιγράφου ασφαλείας',
          fileName: fileName,
          bytes: await File(tempZip).readAsBytes(),
        );
        if (savedPath == null) {
          DebugConfig.db('exportToDevice: user cancelled');
          return BackupExportResult.cancelled();
        }
        DebugConfig.db('exportToDevice: SUCCESS — dest=$savedPath');
        return BackupExportResult.success(savedPath);
      } finally {
        DebugConfig.db('exportToDevice: cleaning up temp dir');
        try {
          await workDir.delete(recursive: true);
          DebugConfig.db('exportToDevice: temp dir deleted');
        } catch (e) {
          DebugConfig.warning('exportToDevice: temp dir cleanup failed: $e');
        }
      }
    } catch (e, s) {
      DebugConfig.error('BackupService.exportToDevice', e, s);
      return BackupExportResult.failure('Αποτυχία αποθήκευσης: $e');
    } finally {
      if (workDir != null) {
        try {
          if (await workDir.exists()) await workDir.delete(recursive: true);
        } catch (e) {
          DebugConfig.warning('exportToDevice: workDir cleanup failed: $e');
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 2. EXPORT: Κοινοποίηση (share sheet)
  // ─────────────────────────────────────────────────────────────────

  /// Δημόσιο entry point — ίδιο F7 tracking με το exportToDevice.
  Future<BackupExportResult> exportWithShare() {
    final future = _exportWithShareImpl();
    _exportInFlight = future.then<void>(
          (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return future;
  }

  Future<BackupExportResult> _exportWithShareImpl() async {
    DebugConfig.db('exportWithShare: starting');
    Directory? workDir;
    try {
      final tempRoot = await getTemporaryDirectory();
      workDir = await Directory(p.join(tempRoot.path,
              '_backup_share_${DateTime.now().millisecondsSinceEpoch}'))
          .create(recursive: true);
      final srcPath = await _dbPath();
      if (!await File(srcPath).exists()) {
        throw Exception('Δεν βρέθηκε η βάση δεδομένων');
      }
      final tempZip = p.join(workDir.path, 'super_note_backup_share.zip');
      final docs = await getApplicationDocumentsDirectory();
      await BackupArchive.createBackupZip(
        dbPath: srcPath,
        snapshotIsar: SuperNoteHelper.instance.isar,
        attachmentsDir: Directory(
            p.join(docs.path, AttachmentService.attachmentsDirName)),
        destZipPath: tempZip,
      );
      DebugConfig.db('exportWithShare: zip ready, opening share sheet');
      try {
        await SharePlus.instance.share(ShareParams(
          files: [XFile(tempZip)],
          subject: 'SuperNote Backup',
          text: 'Αντίγραφο ασφαλείας SuperNote',
        ));
        DebugConfig.db('exportWithShare: share sheet closed, scheduling temp cleanup');
        final dirToClean = workDir;
        Future.delayed(const Duration(seconds: 10), () async {
          try {
            await dirToClean.delete(recursive: true);
            DebugConfig.db('exportWithShare: delayed temp dir deleted');
          } catch (e) {
            DebugConfig.warning(
                'exportWithShare: delayed temp cleanup failed: $e');
          }
        });
        return BackupExportResult.success(tempZip);
      } catch (_) {
        DebugConfig.db('exportWithShare: share failed, cleaning up temp');
        try {
          await workDir.delete(recursive: true);
        } catch (cleanupError) {
          DebugConfig.warning(
              'exportWithShare: cleanup after share failure failed: '
                  '$cleanupError');
        }
        rethrow;
      }
    } catch (e, s) {
      DebugConfig.error('BackupService.exportWithShare', e, s);
      return BackupExportResult.failure('${AppErrors.shareFailed}: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 3. IMPORT (validation + atomic restore — βήμα προς βήμα)
  // ─────────────────────────────────────────────────────────────────

  Future<String?> pickBackupFile() async {
    DebugConfig.db('pickBackupFile: opening file picker');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip', 'isar'],
        withData: false,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        DebugConfig.db('pickBackupFile: user cancelled');
        return null;
      }
      final path = result.files.first.path;
      DebugConfig.db('pickBackupFile: user selected: $path');
      return path;
    } catch (e, s) {
      DebugConfig.error('BackupService.pickBackupFile', e, s);
      return null;
    }
  }

  Future<BackupImportResult> restoreBackup(String backupPath) async {
    DebugConfig.db('restoreBackup: starting, path=$backupPath');
    try {
      final file = File(backupPath);
      if (!await file.exists()) {
        DebugConfig.db('restoreBackup: FAIL — file not found');
        return BackupImportResult.failure('Το αρχείο backup δεν βρέθηκε');
      }
      final size = await file.length();
      DebugConfig.db('restoreBackup: file exists, size=$size bytes');
      final isZip = BackupArchive.isBackupZip(backupPath);
      if (isZip) {
        if (size > maxRestoreBytes) {
          return BackupImportResult.failure(
              'Το αρχείο είναι πολύ μεγάλο για επαναφορά');
        }
      } else {
        if (size < 1024) {
          DebugConfig.db('restoreBackup: FAIL — too small');
          return BackupImportResult.failure(
              'Το αρχείο backup είναι πολύ μικρό (πιθανά κατεστραμμένο)');
        }
      }
      DebugConfig.db(
          'restoreBackup: ${isZip ? 'zip' : 'legacy .isar'} → _atomicRestoreDb');
      final result = await _atomicRestoreDb(backupPath, isZip: isZip);
      if (result.success) {
        DebugConfig.db('restoreBackup: SUCCESS — '
            'restartRequired=${result.restartRequired}');
      } else {
        DebugConfig.warning('restoreBackup: FAILED — '
            'restartRequired=${result.restartRequired} error=${result.error}');
      }
      return result;
    } catch (e, s) {
      DebugConfig.error('BackupService.restoreBackup', e, s);
      return BackupImportResult.failure('Σφάλμα επαναφοράς: $e');
    }
  }

  Future<BackupImportResult> import({String? fromPath}) async {
    DebugConfig.db('import: starting${fromPath != null ? ", fromPath=$fromPath" : ""}');
    try {
      final srcPath = fromPath ?? await pickBackupFile();
      if (srcPath == null) {
        DebugConfig.db('import: cancelled by user');
        return BackupImportResult.cancelled();
      }
      DebugConfig.db('import: validating backup');
      final validation = await validateBackupFile(srcPath);
      if (!validation.valid) {
        DebugConfig.db('import: validation FAILED: ${validation.reason}');
        return BackupImportResult.failure(
            validation.reason ?? 'Μη έγκυρο αρχείο backup');
      }
      DebugConfig.db('import: validation passed, proceeding to restore');
      return await restoreBackup(srcPath);
    } catch (e, s) {
      DebugConfig.error('BackupService.import', e, s);
      return BackupImportResult.failure('Σφάλμα επαναφοράς: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 4. AUTO-BACKUP
  // ─────────────────────────────────────────────────────────────────

  /// AUTO-BACKUP — zip (DB + attachments), όπως το export.
  /// Trigger: app-pause με `autoBackupEnabled` + διάστημα 24h (βλ. main).
  /// Σιωπηλό (background, χωρίς context) — μόνο DebugConfig logs.
  /// Δημόσιο entry point (main:378): καταγράφει το in-flight future για το
  /// drain του restore/wipe και σκιπάρει όσο maintenance είναι ενεργό.
  Future<String?> autoBackup() {
    if (_maintenanceActive) {
      DebugConfig.db('autoBackup: maintenance active — skipping');
      return Future<String?>.value(null);
    }
    final future = _autoBackupImpl();
    _autoBackupInFlight = future.then<void>(
          (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return future;
  }

  Future<String?> _autoBackupImpl() async {
    final epoch = _maintenanceEpoch;
    DebugConfig.db('autoBackup: starting (epoch=$epoch)');
    try {
      final settings = await SuperNoteHelper.instance.settings.get();
      if (!settings.autoBackupEnabled) {
        DebugConfig.db('autoBackup: disabled, skipping');
        return null;
      }
      final last = settings.lastAutoBackupAt;
      if (last != null &&
          DateTime.now().difference(last).inHours < autoBackupIntervalHours) {
        DebugConfig.db('autoBackup: interval not due, skipping');
        return null;
      }
      final backupDir = await _getAutoBackupDir();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final destPath = p.join(backupDir.path, 'auto_$timestamp.zip');
      final srcPath = await _dbPath();
      if (!await File(srcPath).exists()) {
        DebugConfig.db('autoBackup: FAIL — DB file not found: $srcPath');
        return null;
      }
      final docs = await getApplicationDocumentsDirectory();
      await BackupArchive.createBackupZip(
        dbPath: srcPath,
        snapshotIsar: SuperNoteHelper.instance.isar,
        attachmentsDir: Directory(
            p.join(docs.path, AttachmentService.attachmentsDirName)),
        destZipPath: destPath,
      );
      if (_maintenanceActive || epoch != _maintenanceEpoch) {
        // F5: restore/wipe ξεκίνησε όσο φτιάχναμε το zip — η DB μπορεί να
        // κλείσει/αντικατασταθεί· κρατάμε το (έγκυρο) zip και σκιπάρουμε
        // ΜΟΝΟ το settings.update.
        DebugConfig.warning(
            'autoBackup: maintenance/epoch changed '
                '(epoch=$epoch now=$_maintenanceEpoch) — zip kept, settings.update skipped');
      } else {
        await SuperNoteHelper.instance.settings.update((s) {
          s.lastAutoBackupAt = DateTime.now();
        });
      }
      DebugConfig.db('autoBackup: saved to $destPath');
      await _rotateAutoBackups(backupDir);
      DebugConfig.db('autoBackup: rotation done');
      return destPath;
    } catch (e, s) {
      DebugConfig.error('BackupService.autoBackup', e, s);
      return null;
    }
  }

  Future<List<String>> listAutoBackups() async {
    try {
      final dir = await _getAutoBackupDir();
      final files = await dir.list().toList();
      return files
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => BackupArchive.isBackupZip(p))
          .toList()
        ..sort((a, b) => b.compareTo(a));
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────

  Future<Directory> _getAutoBackupDir() async {
    final dir = await getTemporaryDirectory();
    final backupDir = Directory(p.join(dir.path, _backupDirName));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<void> _rotateAutoBackups(Directory dir) async {
    final files = await dir.list().toList();
    final zipFiles = files
        .whereType<File>()
        .where((f) => BackupArchive.isBackupZip(f.path))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    while (zipFiles.length > _maxAutoBackups) {
      final file = zipFiles.removeLast();
      try {
        await file.delete();
      } catch (e) {
        DebugConfig.warning(
            'rotateAutoBackups: delete failed (${file.path}): $e');
      }
    }
  }

  /// Trial open Isar σε φάκελο (κοινό για .isar και .zip validation).
  Future<bool> _checkIsarInDir(Directory dir) async {
    Isar? isar;
    try {
      final source = File(p.join(dir.path, dbFileName));
      if (!await source.exists()) {
        return false;
      }

      // Το live Isar είναι ήδη ανοιχτό με όνομα `super_note_db`. Το Isar
      // δεν επιτρέπει δεύτερο instance με το ίδιο όνομα, οπότε ανοίγουμε
      // το backup με μοναδικό όνομα· το αρχείο πρέπει να έχει το ίδιο
      // basename (`<name>.isar`).
      final validationName =
          'backup_validate_${DateTime.now().microsecondsSinceEpoch}';
      final validationPath = p.join(dir.path, '$validationName.isar');
      await source.rename(validationPath);

      final opened = await Isar.open(
        [
          ItemSchema,
          ItemBlockSchema,
          ItemPropertySchema,
          TagSchema,
          ItemTagSchema,
          RelationSchema,
          ReminderSchema,
          FolderSchema,
          WorkspaceSchema,
          AttachmentSchema,
          UserSchema,
          DeviceSchema,
          AppSettingsSchema,
        ],
        directory: dir.path,
        name: validationName,
      );
      isar = opened;

      // ΚΡΙΣΙΜΟ: Το Isar.open δημιουργεί σιωπηλά νέα κενή DB πάνω σε
      // άκυρο/κατεστραμμένο αρχείο. Απαιτούμε το singleton AppSettings
      // (id=1) που γράφει πάντα το SuperNoteHelper.init(), ώστε ένα
      // τέτοιο αρχείο να μην περνά ως valid backup.
      final settings = await opened.appSettings.get(1);
      if (settings == null) {
        DebugConfig.warning(
            'validateBackupFile: λείπει AppSettings(1) — δεν είναι '
                'έγκυρο SuperNote backup');
        return false;
      }
      return true;
    } catch (e) {
      DebugConfig.warning('validateBackupFile: Isar validation failed: $e');
      return false;
    } finally {
      try {
        await isar?.close();
      } catch (e) {
        DebugConfig.warning('validateBackupFile: Isar close failed: $e');
      }
    }
  }

  Future<ValidationResult> validateBackupFile(String path) async {
    DebugConfig.db('validateBackupFile: validating path=$path');
    try {
      final file = File(path);
      if (!await file.exists()) {
        DebugConfig.db('validateBackupFile: FAIL — file not found');
        return ValidationResult(
            valid: false, reason: 'Το αρχείο δεν βρέθηκε');
      }

      final size = await file.length();
      DebugConfig.db('validateBackupFile: file size=$size bytes');

      // ── ZIP: size guard (o decoder κρατά μνήμη) + trial extract ──
      if (BackupArchive.isBackupZip(path)) {
        if (size > maxRestoreBytes) {
          DebugConfig.db('validateBackupFile: FAIL — too large for restore');
          return ValidationResult(
              valid: false,
              reason: 'Το αρχείο είναι πολύ μεγάλο για επαναφορά');
        }
        final zipTemp = Directory(p.join(
          (await getTemporaryDirectory()).path,
          '_backup_zipval_${DateTime.now().millisecondsSinceEpoch}',
        ));
        await zipTemp.create(recursive: true);
        try {
          final entries =
          await BackupArchive.extractBackupZipDbOnly(path, zipTemp.path);
          if (!entries.contains(BackupArchive.dbEntryName)) {
            return ValidationResult(
                valid: false, reason: 'Το zip δεν περιέχει βάση δεδομένων');
          }
          if (!await _checkIsarInDir(zipTemp)) {
            return ValidationResult(
                valid: false,
                reason: 'Μη έγκυρο ή κατεστραμμένο αρχείο backup');
          }
          DebugConfig.db('validateBackupFile: zip VALID');
          return ValidationResult(valid: true, sizeBytes: size);
        } finally {
          try {
            await zipTemp.delete(recursive: true);
          } catch (e) {
            DebugConfig.warning(
                'validateBackupFile: zip temp cleanup failed: $e');
          }
        }
      }

      if (size < 1024) {
        DebugConfig.db('validateBackupFile: FAIL — too small');
        return ValidationResult(
            valid: false, reason: 'Το αρχείο είναι πολύ μικρό');
      }

      final tempDir = Directory(p.join(
        (await getTemporaryDirectory()).path,
        '_backup_validate_${DateTime.now().millisecondsSinceEpoch}',
      ));
      await tempDir.create(recursive: true);
      DebugConfig.db('validateBackupFile: temp dir created at ${tempDir.path}');

      try {
        final copyPath = p.join(tempDir.path, dbFileName);
        await file.copy(copyPath);
        DebugConfig.db('validateBackupFile: copied to temp for Isar open');

        if (!await _checkIsarInDir(tempDir)) {
          DebugConfig.db('validateBackupFile: FAIL — Isar could not open backup');
          return ValidationResult(
              valid: false,
              reason: 'Μη έγκυρο ή κατεστραμμένο αρχείο backup');
        }
        DebugConfig.db('validateBackupFile: Isar closed — VALID backup');
        return ValidationResult(valid: true, sizeBytes: size);
      } finally {
        try {
          await tempDir.delete(recursive: true);
          DebugConfig.db('validateBackupFile: temp dir cleaned up');
        } catch (e) {
          DebugConfig.warning(
              'validateBackupFile: temp dir cleanup failed: $e');
        }
      }
    } catch (e) {
      DebugConfig.db('validateBackupFile: unexpected error: $e');
      return ValidationResult(valid: false, reason: 'Σφάλμα επικύρωσης: $e');
    }
  }

  /// Ενιαίο atomic restore για .zip (DB + attachments) και legacy .isar.
  ///
  /// E33: πριν κλείσει η DB → beginDbMaintenance() (gates + drain 65s).
  /// Αποτυχία drain → abort ΧΩΡΙΣ close· το begin έχει ήδη κάνει resume.
  /// Safety DB με copyToFile (consistent snapshot), attachments με rename.
  /// Μετά το close ΔΕΝ κάνουμε resume — success ή failure → restartRequired.
  Future<BackupImportResult> _atomicRestoreDb(
      String backupPath, {
        required bool isZip,
      }) async {
    DebugConfig.db('_atomicRestoreDb: starting isZip=$isZip');
    final dbDir = await getApplicationDocumentsDirectory();
    final livePath = p.join(dbDir.path, dbFileName);
    final swapPath = p.join(dbDir.path, '_restore_swap.isar');
    final safetyPath = p.join(dbDir.path, '_pre_restore_backup.isar');
    final attLive =
    Directory(p.join(dbDir.path, AttachmentService.attachmentsDirName));
    final attSafety =
    Directory(p.join(dbDir.path, '_pre_restore_attachments'));

    Directory? extractDir;
    var maintenanceStarted = false;
    var dbTouched = false;
    var dbClosed = false;
    var liveExistedBefore = false;
    var attPhaseStarted = false;
    var hadLiveAttachments = false;
    var attSafetyTaken = false;

    try {
      // 1) Πηγή εκτός maintenance: μόνο read-only / temp writes.
      final File dbSrc;
      if (isZip) {
        final tempRoot = await getTemporaryDirectory();
        extractDir = await Directory(p.join(tempRoot.path,
            '_restore_zip_${DateTime.now().millisecondsSinceEpoch}'))
            .create(recursive: true);
        final entries =
        await BackupArchive.extractBackupZip(backupPath, extractDir.path);
        if (!entries.contains(BackupArchive.dbEntryName)) {
          throw Exception('Το zip δεν περιέχει βάση δεδομένων');
        }
        dbSrc = File(p.join(extractDir.path, BackupArchive.dbEntryName));
      } else {
        await File(backupPath).copy(swapPath);
        dbSrc = File(swapPath);
      }

      if (!SuperNoteHelper.isInitialized ||
          !SuperNoteHelper.instance.isar.isOpen) {
        return BackupImportResult.failure(
            'Η βάση δεδομένων δεν είναι ανοιχτή');
      }

      // 2) E33: gates + drain. Αν το drain αποτύχει, abort ΧΩΡΙΣ close.
      final bool drained;
      try {
        drained = await beginDbMaintenance();
      } catch (e) {
        endDbMaintenance();
        rethrow;
      }
      if (!drained) {
        return BackupImportResult.failure(
            'Η εφαρμογή είναι απασχολημένη — δοκίμασε ξανά');
      }
      maintenanceStarted = true;

      try {
        // 3) Safety DB (compacted/consistent) μετά το drain, πριν το close.
        liveExistedBefore = await File(livePath).exists();
        if (liveExistedBefore) {
          final safety = File(safetyPath);
          if (await safety.exists()) await safety.delete();
          await SuperNoteHelper.instance.isar.copyToFile(safetyPath);
          DebugConfig.db('_atomicRestoreDb: safety copyToFile ok');
        } else {
          DebugConfig.db('_atomicRestoreDb: no live DB — fresh install');
        }

        // 4) Close — από εδώ και πέρα κάθε αποτυχία → restart.
        DebugConfig.db('_atomicRestoreDb: closing Isar');
        dbTouched = true;
        await SuperNoteHelper.instance.close();
        dbClosed = true;
        DebugConfig.db('_atomicRestoreDb: Isar closed');

        // 5) Αντικατάσταση live DB.
        if (isZip) {
          await dbSrc.copy(livePath);
        } else {
          await dbSrc.rename(livePath);
        }

        // 6) Attachments (zip) — μετά το close, για καθαρό pre-close abort.
        if (isZip) {
          hadLiveAttachments = await attLive.exists();
          attPhaseStarted = true;
          if (hadLiveAttachments) {
            if (await attSafety.exists()) {
              await attSafety.delete(recursive: true);
            }
            await attLive.rename(attSafety.path);
            attSafetyTaken = true;
          }
          await attLive.create(recursive: true);
          final srcAttDir = Directory(
              p.join(extractDir!.path, BackupArchive.attachmentsPrefix));
          var moved = 0;
          if (await srcAttDir.exists()) {
            await for (final e in srcAttDir.list()) {
              if (e is File) {
                await e.rename(p.join(attLive.path, p.basename(e.path)));
                moved++;
              }
            }
          }
          await SuperNoteHelper.init();
          final atts = await SuperNoteHelper.instance.attachments.getAll();
          var rebased = 0;
          await SuperNoteHelper.instance.isar.writeTxn(() async {
            for (final a in atts) {
              final np = BackupArchive.rebasePath(a.localPath, attLive.path);
              if (np != null && np != a.localPath) {
                a.localPath = np;
                rebased++;
              }
            }
            await SuperNoteHelper.instance.isar.attachments.putAll(atts);
          });
          DebugConfig.db(
              '_atomicRestoreDb: zip re-init OK moved=$moved rebased=$rebased');
        } else {
          await SuperNoteHelper.init();
          DebugConfig.db('_atomicRestoreDb: isar re-init OK');
        }

        // 7) Επιτυχία — καθαρισμός safety.
        try {
          await File(safetyPath).delete();
        } catch (e) {
          DebugConfig.warning(
              '_atomicRestoreDb: safety DB cleanup failed: $e');
        }
        if (attSafetyTaken) {
          try {
            await attSafety.delete(recursive: true);
          } catch (e) {
            DebugConfig.warning(
                '_atomicRestoreDb: attachment safety cleanup failed: $e');
          }
        }
        DebugConfig.db('_atomicRestoreDb: SUCCESS — restart required');
        return BackupImportResult.success(restartRequired: true);
      } catch (e, s) {
        DebugConfig.error('BackupService._atomicRestoreDb', e, s);
        if (!dbTouched) {
          // Abort πριν το close — live DB/attachments άθικτα.
          endDbMaintenance();
          maintenanceStarted = false;
          return BackupImportResult.failure(
              'Σφάλμα επαναφοράς: $e', restartRequired: false);
        }
        if (!dbClosed) {
          // Το close απέτυχε — μην αγγίξεις το live file· restart.
          DebugConfig.warning(
              '_atomicRestoreDb: close failed — restart without rollback');
          return BackupImportResult.failure(
              'Σφάλμα επαναφοράς: $e', restartRequired: true);
        }
        // Μετά το close — best-effort rollback, οπωσδήποτε restart.
        await _rollbackRestoreDb(
          isZip: isZip,
          livePath: livePath,
          safetyPath: safetyPath,
          attLive: attLive,
          attSafety: attSafety,
          liveExistedBefore: liveExistedBefore,
          deleteAttLive:
          attPhaseStarted && (attSafetyTaken || !hadLiveAttachments),
          attSafetyTaken: attSafetyTaken,
        );
        return BackupImportResult.failure(
            'Σφάλμα επαναφοράς: $e', restartRequired: true);
      }
    } catch (e, s) {
      DebugConfig.error('BackupService._atomicRestoreDb (outer)', e, s);
      if (maintenanceStarted && !dbTouched) {
        endDbMaintenance();
      }
      return BackupImportResult.failure(
          'Σφάλμα επαναφοράς: $e', restartRequired: dbTouched);
    } finally {
      if (await File(swapPath).exists()) {
        try {
          await File(swapPath).delete();
        } catch (e) {
          DebugConfig.warning('_atomicRestoreDb: swap cleanup failed: $e');
        }
      }
      if (extractDir != null) {
        try {
          if (await extractDir.exists()) {
            await extractDir.delete(recursive: true);
          }
        } catch (e) {
          DebugConfig.warning(
              '_atomicRestoreDb: extract dir cleanup failed: $e');
        }
      }
    }
  }

  /// Best-effort rollback μετά από αποτυχία μετά το close. Ποτέ throw.
  Future<void> _rollbackRestoreDb({
    required bool isZip,
    required String livePath,
    required String safetyPath,
    required Directory attLive,
    required Directory attSafety,
    required bool liveExistedBefore,
    required bool deleteAttLive,
    required bool attSafetyTaken,
  }) async {
    try {
      // Αν το init άνοιξε νέο instance (π.χ. rebase failure), κλείσε το πρώτα.
      if (SuperNoteHelper.isInitialized) {
        try {
          await SuperNoteHelper.instance.close();
        } catch (e) {
          DebugConfig.warning('_atomicRestoreDb rollback close: $e');
          return;
        }
      }
      if (await File(safetyPath).exists()) {
        await File(safetyPath).copy(livePath);
      } else if (!liveExistedBefore) {
        // Δεν υπήρχε παλιά DB — καθάρισε το μισο-γραμμένο αρχείο.
        try {
          if (await File(livePath).exists()) await File(livePath).delete();
        } catch (e) {
          DebugConfig.warning(
              '_atomicRestoreDb rollback: half-written DB cleanup failed: $e');
        }
      }
      if (isZip) {
        if (deleteAttLive && await attLive.exists()) {
          await attLive.delete(recursive: true);
        }
        if (attSafetyTaken && await attSafety.exists()) {
          await attSafety.rename(attLive.path);
        }
      }
      await SuperNoteHelper.init();
      DebugConfig.db('_atomicRestoreDb: rollback SUCCESS');
    } catch (e, s) {
      DebugConfig.error(
          'BackupService._atomicRestoreDb rollback FAILED', e, s);
    }
  }
}
