// lib/services/backup_service.dart
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
  const BackupImportResult._({
    this.success = false,
    this.error,
    this.cancelled = false,
  });
  factory BackupImportResult.success() =>
      const BackupImportResult._(success: true);
  factory BackupImportResult.cancelled() =>
      const BackupImportResult._(cancelled: true);
  factory BackupImportResult.failure(String error) =>
      BackupImportResult._(error: error);
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

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────

  Future<String> _dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, dbFileName);
  }

  // ─────────────────────────────────────────────────────────────────
  // 1. EXPORT: Αποθήκευση στη συσκευή (με system save dialog)
  // ─────────────────────────────────────────────────────────────────

  Future<BackupExportResult> exportToDevice() async {
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
        } catch (_) {}
      }
    } catch (e, s) {
      DebugConfig.error('BackupService.exportToDevice', e, s);
      return BackupExportResult.failure('Αποτυχία αποθήκευσης: $e');
    } finally {
      if (workDir != null) {
        try {
          if (await workDir.exists()) await workDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 2. EXPORT: Κοινοποίηση (share sheet)
  // ─────────────────────────────────────────────────────────────────

  Future<BackupExportResult> exportWithShare() async {
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
          } catch (_) {}
        });
        return BackupExportResult.success(tempZip);
      } catch (_) {
        DebugConfig.db('exportWithShare: share failed, cleaning up temp');
        try {
          await workDir.delete(recursive: true);
        } catch (_) {}
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
      if (BackupArchive.isBackupZip(backupPath)) {
        if (size > maxRestoreBytes) {
          return BackupImportResult.failure(
              'Το αρχείο είναι πολύ μεγάλο για επαναφορά');
        }
        DebugConfig.db('restoreBackup: zip → _atomicRestoreZip');
        await _atomicRestoreZip(backupPath);
      } else {
        if (size < 1024) {
          DebugConfig.db('restoreBackup: FAIL — too small');
          return BackupImportResult.failure(
              'Το αρχείο backup είναι πολύ μικρό (πιθανά κατεστραμμένο)');
        }
        DebugConfig.db(
            'restoreBackup: legacy .isar (χωρίς attachments) → _atomicRestore');
        await _atomicRestore(backupPath);
      }
      DebugConfig.db('restoreBackup: SUCCESS');
      return BackupImportResult.success();
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

  Future<String?> autoBackup() async {
    DebugConfig.db('autoBackup: starting');
    try {
      final backupDir = await _getAutoBackupDir();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final destPath = p.join(backupDir.path, 'auto_$timestamp.isar');
      final srcPath = await _dbPath();
      await File(srcPath).copy(destPath);
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
          .where((p) => p.endsWith('.isar'))
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
    final isarFiles = files
        .whereType<File>()
        .where((f) => f.path.endsWith('.isar'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    while (isarFiles.length > _maxAutoBackups) {
      try {
        await isarFiles.removeLast().delete();
      } catch (_) {}
    }
  }

  /// Trial open Isar σε φάκελο (κοινό για .isar και .zip validation).
  Future<bool> _checkIsarInDir(Directory dir) async {
    Isar? isar;
    try {
      isar = await Isar.open(
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
        name: 'super_note_db_validation_${DateTime.now().millisecondsSinceEpoch}',
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        await isar?.close();
      } catch (_) {}
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
              await BackupArchive.extractBackupZip(path, zipTemp.path);
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
          } catch (_) {}
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
        } catch (_) {}
      }
    } catch (e) {
      DebugConfig.db('validateBackupFile: unexpected error: $e');
      return ValidationResult(valid: false, reason: 'Σφάλμα επικύρωσης: $e');
    }
  }

  Future<void> _atomicRestore(String backupPath) async {
    DebugConfig.db('_atomicRestore: starting');
    final dbDir = await getApplicationDocumentsDirectory();
    final livePath = p.join(dbDir.path, dbFileName);
    final tempSwapPath = p.join(dbDir.path, '_restore_swap.isar');
    final safetyPath = p.join(dbDir.path, '_pre_restore_backup.isar');

    DebugConfig.db('_atomicRestore: copying backup → tempSwap ($tempSwapPath)');
    await File(backupPath).copy(tempSwapPath);

    if (await File(livePath).exists()) {
      final liveSize = await File(livePath).length();
      DebugConfig.db('_atomicRestore: live DB exists (size=$liveSize), creating safety net');
      await File(livePath).copy(safetyPath);
      DebugConfig.db('_atomicRestore: safety net created at $safetyPath');
    } else {
      DebugConfig.db('_atomicRestore: no live DB found — fresh install scenario');
    }

    DebugConfig.db('_atomicRestore: closing Isar');
    await SuperNoteHelper.instance.close();
    DebugConfig.db('_atomicRestore: Isar closed');

    try {
      DebugConfig.db('_atomicRestore: renaming tempSwap → live ($livePath)');
      await File(tempSwapPath).rename(livePath);
      DebugConfig.db('_atomicRestore: rename done, re-initializing Isar');
      await SuperNoteHelper.init();
      DebugConfig.db('_atomicRestore: Isar re-initialized — SUCCESS');
      try {
        await File(safetyPath).delete();
        DebugConfig.db('_atomicRestore: safety net deleted');
      } catch (_) {}
    } catch (e) {
      DebugConfig.db('_atomicRestore: RESTORE FAILED, rolling back');
      try {
        if (await File(safetyPath).exists()) {
          DebugConfig.db('_atomicRestore: rollback — copying safety net back to live');
          await File(safetyPath).copy(livePath);
        }
        DebugConfig.db('_atomicRestore: rollback — re-initializing Isar');
        await SuperNoteHelper.init();
        DebugConfig.db('_atomicRestore: rollback SUCCESS');
      } catch (rollbackError) {
        DebugConfig.error(
            'BackupService._atomicRestore rollback FAILED', rollbackError);
      }
      rethrow;
    } finally {
      if (await File(tempSwapPath).exists()) {
        try {
          await File(tempSwapPath).delete();
          DebugConfig.db('_atomicRestore: tempSwap cleanup done');
        } catch (_) {}
      }
    }
  }

  /// Atomic restore από .zip (βάση + attachments, με safety και για τα δύο).
  Future<void> _atomicRestoreZip(String backupPath) async {
    DebugConfig.db('_atomicRestoreZip: starting');
    final dbDir = await getApplicationDocumentsDirectory();
    final livePath = p.join(dbDir.path, dbFileName);
    final safetyPath = p.join(dbDir.path, '_pre_restore_backup.isar');
    final attLive =
        Directory(p.join(dbDir.path, AttachmentService.attachmentsDirName));
    final attSafety =
        Directory(p.join(dbDir.path, '_pre_restore_attachments'));
    final tempRoot = await getTemporaryDirectory();
    final extractDir = await Directory(p.join(tempRoot.path,
            '_restore_zip_${DateTime.now().millisecondsSinceEpoch}'))
        .create(recursive: true);
    try {
      final entries =
          await BackupArchive.extractBackupZip(backupPath, extractDir.path);
      if (!entries.contains(BackupArchive.dbEntryName)) {
        throw Exception('Το zip δεν περιέχει βάση δεδομένων');
      }
      final dbSrc = File(p.join(extractDir.path, BackupArchive.dbEntryName));

      // Safety copies πριν αγγίξουμε live.
      if (await File(livePath).exists()) {
        await File(livePath).copy(safetyPath);
      }
      var attSafetyTaken = false;
      if (await attLive.exists()) {
        if (await attSafety.exists()) {
          await attSafety.delete(recursive: true);
        }
        await attLive.rename(attSafety.path);
        attSafetyTaken = true;
      }

      DebugConfig.db('_atomicRestoreZip: closing Isar');
      await SuperNoteHelper.instance.close();

      try {
        await dbSrc.copy(livePath);
        await attLive.create(recursive: true);
        final srcAttDir = Directory(
            p.join(extractDir.path, BackupArchive.attachmentsPrefix));
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
        // Rebase absolute paths στο νέο attachments dir.
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
            '_atomicRestoreZip: re-init OK moved=$moved rebased=$rebased');
        try {
          await File(safetyPath).delete();
        } catch (_) {}
        if (attSafetyTaken) {
          try {
            await attSafety.delete(recursive: true);
          } catch (_) {}
        }
      } catch (e) {
        DebugConfig.db('_atomicRestoreZip: FAILED, rolling back');
        try {
          if (await File(safetyPath).exists()) {
            await File(safetyPath).copy(livePath);
          }
          if (await attLive.exists()) {
            await attLive.delete(recursive: true);
          }
          if (attSafetyTaken && await attSafety.exists()) {
            await attSafety.rename(attLive.path);
          }
          await SuperNoteHelper.init();
          DebugConfig.db('_atomicRestoreZip: rollback SUCCESS');
        } catch (rollbackError) {
          DebugConfig.error(
              'BackupService._atomicRestoreZip rollback FAILED',
              rollbackError);
        }
        rethrow;
      }
    } finally {
      try {
        if (await extractDir.exists()) {
          await extractDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}
