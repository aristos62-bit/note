// lib/services/backup_service.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import '../core/utils/debug_config.dart';

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

  static const String _dbFileName = 'super_note_db.isar';
  static const String _backupDirName = 'SuperNoteBackups';
  static const int _maxAutoBackups = 5;

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────

  Future<String> _dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  Future<String> _createTempBackup() async {
    DebugConfig.db('_createTempBackup: starting');
    final srcPath = await _dbPath();
    final srcFile = File(srcPath);
    if (!await srcFile.exists()) {
      DebugConfig.db('_createTempBackup: FAIL — DB file not found: $srcPath');
      throw Exception('Δεν βρέθηκε η βάση δεδομένων');
    }
    final srcSize = await srcFile.length();
    DebugConfig.db('_createTempBackup: src exists, size=$srcSize bytes');
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final tempPath = p.join(tempDir.path, 'super_note_backup_$timestamp.isar');
    await srcFile.copy(tempPath);
    final tempSize = await File(tempPath).length();
    DebugConfig.db('_createTempBackup: done, temp=$tempPath, size=$tempSize bytes');
    return tempPath;
  }

  // ─────────────────────────────────────────────────────────────────
  // 1. EXPORT: Αποθήκευση στη συσκευή (με system save dialog)
  // ─────────────────────────────────────────────────────────────────

  Future<BackupExportResult> exportToDevice() async {
    DebugConfig.db('exportToDevice: starting');
    try {
      final tempPath = await _createTempBackup();
      DebugConfig.db('exportToDevice: temp copy ready');
      try {
        final timestamp = DateTime.now()
            .toIso8601String()
            .replaceAll(':', '-')
            .split('.')
            .first;
        final fileName = 'super_note_backup_$timestamp.isar';
        final bytes = await File(tempPath).readAsBytes();
        DebugConfig.db('exportToDevice: read ${bytes.length} bytes, opening save dialog');
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Αποθήκευση αντιγράφου ασφαλείας',
          fileName: fileName,
          bytes: bytes,
          type: FileType.any,
        );
        if (savedPath == null) {
          DebugConfig.db('exportToDevice: user cancelled');
          return BackupExportResult.cancelled();
        }
        DebugConfig.db('exportToDevice: SUCCESS — dest=$savedPath');
        return BackupExportResult.success(savedPath);
      } finally {
        DebugConfig.db('exportToDevice: cleaning up temp file');
        try {
          await File(tempPath).delete();
          DebugConfig.db('exportToDevice: temp file deleted');
        } catch (_) {}
      }
    } catch (e, s) {
      DebugConfig.error('BackupService.exportToDevice', e, s);
      return BackupExportResult.failure('Αποτυχία αποθήκευσης: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 2. EXPORT: Κοινοποίηση (share sheet)
  // ─────────────────────────────────────────────────────────────────

  Future<BackupExportResult> exportWithShare() async {
    DebugConfig.db('exportWithShare: starting');
    try {
      final tempPath = await _createTempBackup();
      DebugConfig.db('exportWithShare: temp copy ready, opening share sheet');
      try {
        await SharePlus.instance.share(ShareParams(
          files: [XFile(tempPath)],
          subject: 'SuperNote Backup',
          text: 'Αντίγραφο ασφαλείας SuperNote',
        ));
        DebugConfig.db('exportWithShare: share sheet closed, scheduling temp cleanup');
        Future.delayed(const Duration(seconds: 10), () async {
          try {
            await File(tempPath).delete();
            DebugConfig.db('exportWithShare: delayed temp file deleted');
          } catch (_) {}
        });
        return BackupExportResult.success(tempPath);
      } catch (_) {
        DebugConfig.db('exportWithShare: share failed, cleaning up temp');
        try {
          await File(tempPath).delete();
        } catch (_) {}
        rethrow;
      }
    } catch (e, s) {
      DebugConfig.error('BackupService.exportWithShare', e, s);
      return BackupExportResult.failure('Αποτυχία κοινοποίησης: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 3. IMPORT (validation + atomic restore — βήμα προς βήμα)
  // ─────────────────────────────────────────────────────────────────

  Future<String?> pickBackupFile() async {
    DebugConfig.db('pickBackupFile: opening file picker');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
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
      if (size < 1024) {
        DebugConfig.db('restoreBackup: FAIL — too small');
        return BackupImportResult.failure(
            'Το αρχείο backup είναι πολύ μικρό (πιθανά κατεστραμμένο)');
      }
      DebugConfig.db('restoreBackup: pre-checks passed, calling _atomicRestore');
      await _atomicRestore(backupPath);
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
        final copyPath = p.join(tempDir.path, _dbFileName);
        await file.copy(copyPath);
        DebugConfig.db('validateBackupFile: copied to temp for Isar open');

        final isar = await Isar.open(
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
          directory: tempDir.path,
          name: 'super_note_db_validation_${DateTime.now().millisecondsSinceEpoch}',
        );
        DebugConfig.db('validateBackupFile: Isar opened successfully, closing');
        await isar.close();
        DebugConfig.db('validateBackupFile: Isar closed — VALID backup');
        return ValidationResult(valid: true, sizeBytes: size);
      } catch (_) {
        DebugConfig.db('validateBackupFile: FAIL — Isar could not open backup');
        return ValidationResult(
            valid: false,
            reason: 'Μη έγκυρο ή κατεστραμμένο αρχείο backup');
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
    final livePath = p.join(dbDir.path, _dbFileName);
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
}
