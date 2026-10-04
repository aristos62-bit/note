// lib/services/backup_archive.dart
//
// Zip helpers για backup με attachments (βάση + αρχεία σε ένα .zip).
// Streaming εξαγωγή (addFile) — η εισαγωγή/validation είναι memory-bound
// (ZipDecoder.decodeBytes), οπότε ισχύει size guard στο service.
//
// Δομή zip:
//   super_note_db.isar            (η βάση)
//   attachments/<basename>...      (αρχεία, σχετικά ονόματα)
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../core/utils/debug_config.dart';

class BackupArchive {
  BackupArchive._();

  static const String dbEntryName = 'super_note_db.isar';
  static const String attachmentsPrefix = 'attachments/';

  static bool isBackupZip(String path) =>
      path.toLowerCase().endsWith('.zip');

  /// Pure: ξαναβάζει absolute path μέσα στο νέο attachments dir.
  /// Επιστρέφει null αν το path δεν έχει basename (δεν πρέπει να συμβεί).
  static String? rebasePath(String oldAbsolutePath, String newDir) {
    final base = p.basename(oldAbsolutePath);
    if (base.isEmpty || base == '.' || base == '/') return null;
    return p.join(newDir, base);
  }

  /// Δημιουργεί το zip (streaming, αρχείο-προς-αρχείο).
  /// Επιστρέφει το μέγεθος του zip σε bytes.
  static Future<int> createBackupZip({
    required String dbPath,
    required Directory attachmentsDir,
    required String destZipPath,
  }) async {
    final encoder = ZipFileEncoder();
    try {
      encoder.open(destZipPath);
      await encoder.addFile(File(dbPath), dbEntryName);
      var count = 0;
      if (await attachmentsDir.exists()) {
        await for (final e in attachmentsDir.list()) {
          if (e is File) {
            await encoder.addFile(e, '$attachmentsPrefix${p.basename(e.path)}');
            count++;
          }
        }
      }
      await encoder.close();
      final size = await File(destZipPath).length();
      DebugConfig.db(
          'BackupArchive.create: files=$count size=$size bytes dest=$destZipPath');
      return size;
    } catch (e, stack) {
      DebugConfig.error('BackupArchive.create', e, stack);
      try {
        await encoder.close();
      } catch (_) {}
      rethrow;
    }
  }

  /// Εξάγει το zip σε φάκελο εργασίας. Επιστρέφει τα ονόματα entries.
  /// Προσοχή: κρατά το zip στη μνήμη (ZipDecoder) — καλείται ΜΟΝΟ
  /// μετά από size guard στο service.
  static Future<List<String>> extractBackupZip(
      String zipPath, String outDir) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      extractArchiveToDisk(archive, outDir);
      final names = <String>[];
      for (final f in archive.files) {
        if (!f.isDirectory) names.add(f.name);
      }
      DebugConfig.db(
          'BackupArchive.extract: entries=${names.length} out=$outDir');
      return names;
    } catch (e, stack) {
      DebugConfig.error('BackupArchive.extract', e, stack);
      rethrow;
    }
  }
}
