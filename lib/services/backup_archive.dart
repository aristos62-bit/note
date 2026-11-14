// lib/services/backup_archive.dart
//
// Zip helpers για backup με attachments (βάση + αρχεία σε ένα .zip).
//
// S-307: και η εξαγωγή είναι streaming (ZipDecoder.decodeStream +
// ArchiveFile.writeContent(OutputFileStream)) — το zip ΔΕΝ φορτώνεται πλέον
// ολόκληρο στη μνήμη. Καμία size guard: το μέγεθος ακολουθεί τη βάση.
//
// Δομή zip:
//   super_note_db.isar            (η βάση)
//   attachments/<basename>...      (αρχεία, σχετικά ονόματα)
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import '../core/utils/debug_config.dart';
import 'backup/backup_progress.dart';

class BackupArchive {
  BackupArchive._();

  static const String dbEntryName = 'super_note_db.isar';
  static const String attachmentsPrefix = 'attachments/';

  static bool isBackupZip(String path) =>
      path.toLowerCase().endsWith('.zip');

  /// S-02 (C7): allowlist zip entries.
  ///
  /// Δεχόμαστε ΜΟΝΟ:
  ///  • `super_note_db.isar`
  ///  • `attachments/<basename>` (ένα επίπεδο, χωρίς διαχωριστικά)
  ///
  /// Οτιδήποτε άλλο (path traversal, nested dirs, symlinks, άγνωστα entries)
  /// αγνοείται — δεν γράφεται ποτέ στον δίσκο.
  static bool isAllowedEntry(String name) {
    if (name == dbEntryName) return true;
    if (!name.startsWith(attachmentsPrefix)) return false;
    final rest = name.substring(attachmentsPrefix.length);
    if (rest.isEmpty) return false;
    if (rest.contains('/') || rest.contains('\\')) return false;
    if (rest == '.' || rest == '..') return false;
    return true;
  }

  /// Pure: ξαναβάζει absolute path μέσα στο νέο attachments dir.
  /// Επιστρέφει null αν το path δεν έχει basename (δεν πρέπει να συμβεί).
  static String? rebasePath(String oldAbsolutePath, String newDir) {
    final base = p.basename(oldAbsolutePath);
    if (base.isEmpty || base == '.' || base == '/') return null;
    return p.join(newDir, base);
  }

  /// Συνολικά bytes που θα μπουν στο zip (DB + συνημμένα).
  ///
  /// Χρησιμοποιείται για την πρόοδο του zip και για τον έλεγχο ελεύθερου
  /// χώρου ΠΡΙΝ ξεκινήσει η εργασία (S-307).
  static Future<int> estimateSourceBytes({
    required String dbPath,
    required Directory attachmentsDir,
  }) async {
    var total = 0;
    try {
      final db = File(dbPath);
      if (await db.exists()) total += await db.length();
    } catch (e) {
      DebugConfig.warning('BackupArchive.estimateSourceBytes (db): $e');
    }
    try {
      if (await attachmentsDir.exists()) {
        await for (final e in attachmentsDir.list()) {
          if (e is File) total += await e.length();
        }
      }
    } catch (e) {
      DebugConfig.warning('BackupArchive.estimateSourceBytes (attachments): $e');
    }
    return total;
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
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    String? snapshotPath;
    var sourceDbPath = dbPath;
    final encoder = ZipFileEncoder();
    try {
      if (snapshotIsar != null) {
        if (!snapshotIsar.isOpen) {
          throw StateError('Isar is closed — cannot create snapshot');
        }
        onProgress?.call(const BackupProgress(BackupPhase.snapshot, 0, 0));
        snapshotPath = '$destZipPath.'
            '${DateTime.now().microsecondsSinceEpoch}.snapshot.isar';
        await snapshotIsar.copyToFile(snapshotPath);
        sourceDbPath = snapshotPath;
        DebugConfig.db('BackupArchive.create: snapshot '
            '${await File(snapshotPath).length()} bytes');
      }

      // Μέτρηση ΠΡΙΝ το γράψιμο — το zip progress είναι byte-based.
      final dbFile = File(sourceDbPath);
      final dbSize = await dbFile.length();
      final attachmentFiles = <File>[];
      var attachmentBytes = 0;
      if (await attachmentsDir.exists()) {
        await for (final e in attachmentsDir.list()) {
          if (e is File) {
            attachmentFiles.add(e);
            try {
              attachmentBytes += await e.length();
            } catch (e2) {
              DebugConfig.warning(
                  'BackupArchive.create: attachment size failed: $e2');
            }
          }
        }
      }

      final totalBytes = dbSize + attachmentBytes;
      var doneBytes = 0;
      onProgress?.call(BackupProgress(BackupPhase.zip, 0, totalBytes));

      encoder.open(destZipPath);
      await encoder.addFile(dbFile, dbEntryName);
      doneBytes += dbSize;
      onProgress?.call(BackupProgress(BackupPhase.zip, doneBytes, totalBytes));

      var count = 0;
      for (final e in attachmentFiles) {
        if (isCancelled?.call() ?? false) {
          throw const BackupCancelledException();
        }
        // S-307: store (level 0) για συνημμένα — JPEG/PDF δεν συμπιέζονται
        // και το deflate καίει CPU χωρίς κέρδος.
        await encoder.addFile(
          e,
          '$attachmentsPrefix${p.basename(e.path)}',
          ZipFileEncoder.store,
        );
        doneBytes += await e.length();
        count++;
        onProgress
            ?.call(BackupProgress(BackupPhase.zip, doneBytes, totalBytes));
      }
      await encoder.close();
      final size = await File(destZipPath).length();
      DebugConfig.db(
          'BackupArchive.create: files=$count size=$size bytes dest=$destZipPath');
      return size;
    } catch (e, stack) {
      if (e is! BackupCancelledException) {
        DebugConfig.error('BackupArchive.create', e, stack);
      }
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

  /// Εξάγει το zip σε φάκελο εργασίας **streaming** (O(1) RAM ανά entry).
  /// Επιστρέφει ΟΛΑ τα ονόματα entries (και τα μη-επιτρεπτά — για διαγνωστικά),
  /// αλλά γράφει στον δίσκο μόνο όσα περνούν το [isAllowedEntry] (C7).
  static Future<List<String>> extractBackupZip(
    String zipPath,
    String outDir, {
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final names = <String>[];
      var written = 0;
      var skipped = 0;
      var doneBytes = 0;

      var totalBytes = 0;
      for (final f in archive.files) {
        if (f.isDirectory) continue;
        if (isAllowedEntry(f.name)) totalBytes += f.size;
      }
      onProgress?.call(BackupProgress(BackupPhase.extract, 0, totalBytes));

      for (final f in archive.files) {
        if (f.isDirectory) continue;
        names.add(f.name);
        if (!isAllowedEntry(f.name)) {
          skipped++;
          continue;
        }
        if (isCancelled?.call() ?? false) {
          throw const BackupCancelledException();
        }
        final segments = f.name.split('/');
        final outPath = p.joinAll(<String>[outDir, ...segments]);
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        final output = OutputFileStream(outPath);
        try {
          f.writeContent(output);
        } finally {
          output.closeSync();
        }
        written++;
        doneBytes += f.size;
        onProgress
            ?.call(BackupProgress(BackupPhase.extract, doneBytes, totalBytes));
      }
      DebugConfig.db('BackupArchive.extract: entries=${names.length} '
          'written=$written skipped=$skipped out=$outDir');
      return names;
    } catch (e, stack) {
      if (e is! BackupCancelledException) {
        DebugConfig.error('BackupArchive.extract', e, stack);
      }
      rethrow;
    } finally {
      input.closeSync();
    }
  }

  /// Εξάγει μόνο το DB entry για validation — χωρίς attachments (streaming).
  /// Επιστρέφει όλα τα ονόματα entries (για τον έλεγχο παρουσίας DB).
  static Future<List<String>> extractBackupZipDbOnly(
    String zipPath,
    String outDir, {
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final names = <String>[];
      for (final f in archive.files) {
        if (!f.isDirectory) names.add(f.name);
      }
      final db = archive.findFile(dbEntryName);
      if (db != null && !db.isDirectory && isAllowedEntry(db.name)) {
        if (isCancelled?.call() ?? false) {
          throw const BackupCancelledException();
        }
        onProgress
            ?.call(BackupProgress(BackupPhase.extract, 0, db.size));
        final outPath = p.join(outDir, dbEntryName);
        await File(outPath).parent.create(recursive: true);
        final output = OutputFileStream(outPath);
        try {
          db.writeContent(output);
        } finally {
          output.closeSync();
        }
        onProgress
            ?.call(BackupProgress(BackupPhase.extract, db.size, db.size));
      }
      DebugConfig.db(
          'BackupArchive.extractDbOnly: entries=${names.length} out=$outDir');
      return names;
    } catch (e, stack) {
      if (e is! BackupCancelledException) {
        DebugConfig.error('BackupArchive.extractDbOnly', e, stack);
      }
      rethrow;
    } finally {
      input.closeSync();
    }
  }
}
