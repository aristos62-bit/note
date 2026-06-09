// lib/services/backup_service.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../helpers/super_note_helper.dart';

class BackupService {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  static const String _dbFileName = 'super_note_db.isar';

  // ─────────────────────────────────────────────────────────
  // EXPORT
  // ─────────────────────────────────────────────────────────

  Future<String> export() async {
    try {
      final dbDir = await getApplicationDocumentsDirectory();
      final srcPath = p.join(dbDir.path, _dbFileName);
      final srcFile = File(srcPath);

      if (!await srcFile.exists()) {
        throw Exception('Δεν βρέθηκε η βάση δεδομένων');
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final suggestedName = 'super_note_backup_$timestamp.isar';

      final bytes = await srcFile.readAsBytes();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Αποθήκευση αντιγράφου ασφαλείας',
        fileName: suggestedName,
        bytes: bytes,
      );

      if (result == null) {
        throw Exception('Ακυρώθηκε από τον χρήστη');
      }

      return result;
    } catch (e) {
      debugPrint('[BackupService] export failed: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────
  // IMPORT
  // ─────────────────────────────────────────────────────────

  Future<bool> import({String? fromPath}) async {
    String? srcPath = fromPath;

    try {
      if (srcPath == null) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: false,
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) return false;
        srcPath = result.files.first.path;
        if (srcPath == null) return false;
      }

      if (!await File(srcPath).exists()) {
        throw Exception('Το αρχείο backup δεν βρέθηκε: $srcPath');
      }

    } catch (e) {
      debugPrint('[BackupService] import pre-check failed: $e');
      rethrow;
    }

    // Από εδώ η DB είναι κλειστή — κάθε exception πρέπει να ξανανοίξει
    await SuperNoteHelper.instance.close();

    try {
      final dbDir = await getApplicationDocumentsDirectory();
      final destPath = p.join(dbDir.path, _dbFileName);
      await File(srcPath).copy(destPath);
      await SuperNoteHelper.init();
      return true;
    } catch (e) {
      debugPrint('[BackupService] import failed: $e');
      // Η DB είναι κλειστή — πρέπει οπωσδήποτε να ξανανοίξει
      try {
        await SuperNoteHelper.init();
      } catch (initError) {
        debugPrint('[BackupService] CRITICAL: DB re-init failed: $initError');
      }
      rethrow;
    }
  }
}