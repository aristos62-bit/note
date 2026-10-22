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
import 'package:isar/isar.dart';
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
  ///
  /// Αν δοθεί [snapshotIsar], πρώτα παίρνει compacted, consistent snapshot της
  /// βάσης με `Isar.copyToFile` και zipάρει αυτό — όχι το live `.isar`.
  /// Επιστρέφει το μέγεθος του zip σε bytes.
  static Future<int> createBackupZip({
    required String dbPath,
    required Directory attachmentsDir,
    required String destZipPath,
    Isar? snapshotIsar,
  }) async {
    String? snapshotPath;
    var sourceDbPath = dbPath;
    final encoder = ZipFileEncoder();
    try {
      if (snapshotIsar != null) {
        if (!snapshotIsar.isOpen) {
          throw StateError('Isar is closed — cannot create snapshot');
        }
        snapshotPath = '$destZipPath.'
            '${DateTime.now().microsecondsSinceEpoch}.snapshot.isar';
        await snapshotIsar.copyToFile(snapshotPath);
        sourceDbPath = snapshotPath;
        DebugConfig.db('BackupArchive.create: snapshot '
            '${await File(snapshotPath).length()} bytes');
      }
      encoder.open(destZipPath);
      await encoder.addFile(File(sourceDbPath), dbEntryName);
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
      } catch (closeError) {
        DebugConfig.warning(
            'BackupArchive.create: encoder close failed: $closeError');
      }
      rethrow;
    } finally {
      if (snapshotPath != null) {
        try {
          final snapshot = File(snapshotPath);
          if (await snapshot.exists()) await snapshot.delete();
        } catch (e) {
          DebugConfig.warning(
              'BackupArchive.create: snapshot cleanup failed: $e');
        }
      }
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
  /// Εξάγει μόνο το DB entry για validation — χωρίς attachments.
  /// Επιστρέφει όλα τα ονόματα entries (για τον έλεγχο παρουσίας DB).
  static Future<List<String>> extractBackupZipDbOnly(
      String zipPath, String outDir) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = <String>[];
      for (final f in archive.files) {
        if (!f.isDirectory) names.add(f.name);
      }
      final db = archive.findFile(dbEntryName);
      if (db != null && !db.isDirectory) {
        await File(p.join(outDir, dbEntryName)).writeAsBytes(db.content);
      }
      DebugConfig.db(
          'BackupArchive.extractDbOnly: entries=${names.length} out=$outDir');
      return names;
    } catch (e, stack) {
      DebugConfig.error('BackupArchive.extractDbOnly', e, stack);
      rethrow;
    }
  }
}
