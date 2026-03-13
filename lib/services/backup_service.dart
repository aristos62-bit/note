// lib/services/backup_service.dart
//
// ═══════════════════════════════════════════════════════════════
// ΟΔΗΓΙΕΣ ΠΡΟΣΑΡΜΟΓΗΣ
// ═══════════════════════════════════════════════════════════════
//
// ΧΡΗΣΗ στο SettingsScreen:
//
//   // Export:
//   final path = await BackupService.instance.export();
//   // Μοίρασε το αρχείο με Share.shareXFiles([XFile(path)])
//   // (χρειάζεται package: share_plus)
//
//   // Import:
//   await BackupService.instance.import();
//   // Μετά το import κάνε hot restart για να φορτωθεί η νέα DB
//
// ΠΡΟΣΘΗΚΗ στο pubspec.yaml αν θες share:
//   share_plus: ^9.0.0
//
// ═══════════════════════════════════════════════════════════════

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
  // EXPORT — Αντίγραψε το .isar αρχείο σε downloads
  // ─────────────────────────────────────────────────────────

  Future<String> export() async {
    final dbDir   = await getApplicationDocumentsDirectory();
    final srcPath = p.join(dbDir.path, _dbFileName);
    final srcFile = File(srcPath);

    if (!await srcFile.exists()) {
      throw Exception('Δεν βρέθηκε η βάση δεδομένων');
    }

    // Αποθήκευσε στα Documents με timestamp
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.').first;
    final destName = 'super_note_backup_$timestamp.isar';
    final destPath = p.join(dbDir.path, destName);

    await srcFile.copy(destPath);
    return destPath; // Επέστρεψε το path για share
  }

  // ─────────────────────────────────────────────────────────
  // IMPORT — Επαναφορά από backup αρχείο
  // ΠΡΟΣΟΧΗ: Αντικαθιστά ΟΛΟΚΛΗΡΗ την τρέχουσα DB
  // ─────────────────────────────────────────────────────────

  Future<bool> import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return false;
    final srcPath = result.files.first.path;
    if (srcPath == null) return false;

    // Κλείσε την DB πριν αντικατάσταση
    await SuperNoteHelper.instance.close();

    final dbDir   = await getApplicationDocumentsDirectory();
    final destPath = p.join(dbDir.path, _dbFileName);

    await File(srcPath).copy(destPath);

    // Επανεκκίνηση DB
    await SuperNoteHelper.init();
    return true;
  }
}