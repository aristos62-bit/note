// lib/services/backup_service.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../helpers/super_note_helper.dart';

class BackupService {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  static const String _dbFileName = 'super_note_db.isar';

  // ─────────────────────────────────────────────────────────
  // EXPORT — Ο χρήστης επιλέγει αρχείο προορισμού (USB, SD, Documents)
  // ─────────────────────────────────────────────────────────

  Future<String> export() async {
    final dbDir = await getApplicationDocumentsDirectory();
    final srcPath = p.join(dbDir.path, _dbFileName);
    final srcFile = File(srcPath);

    if (!await srcFile.exists()) {
      throw Exception('Δεν βρέθηκε η βάση δεδομένων');
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.').first;
    final suggestedName = 'super_note_backup_$timestamp.isar';

    // Διάβασε τα bytes του αρχείου
    final bytes = await srcFile.readAsBytes();

    // Αποθήκευση μέσω FilePicker (SAF)
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Αποθήκευση αντιγράφου ασφαλείας',
      fileName: suggestedName,
      bytes: bytes, // ✅ απαραίτητο
    );

    if (result == null) {
      throw Exception('Ακυρώθηκε από τον χρήστη');
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────
  // IMPORT — Επιλογή αρχείου backup για επαναφορά
  // ─────────────────────────────────────────────────────────

  Future<bool> import({String? fromPath}) async {
    String? srcPath = fromPath;

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

    // Κλείσιμο της DB
    await SuperNoteHelper.instance.close();

    try {
      final dbDir = await getApplicationDocumentsDirectory();
      final destPath = p.join(dbDir.path, _dbFileName);
      await File(srcPath).copy(destPath);
    } catch (e) {
      // Απέτυχε το copy — ξανάνοιξε την παλιά DB
      try { await SuperNoteHelper.init(); } catch (_) {}
      rethrow;
    }

    // Επανεκκίνηση DB με το νέο αρχείο
    await SuperNoteHelper.init();
    return true;
  }
}