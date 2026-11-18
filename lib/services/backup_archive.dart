// lib/services/backup_archive.dart
//
// Zip helpers για backup με attachments (βάση + αρχεία σε ένα .zip).
//
// S-307: και η εξαγωγή είναι streaming (ZipDecoder.decodeStream +
// ArchiveFile.writeContent(OutputFileStream)) — το zip ΔΕΝ φορτώνεται πλέον
// ολόκληρο στη μνήμη.
//
// S-08: όρια **μόνο στην επαναφορά** (η εξαγωγή αντιγράφου μένει χωρίς όρια):
//  1. preflight στα **δηλωμένα** μεγέθη (φθηνή, attacker-controlled ένδειξη),
//  2. μετρητής **πραγματικών** bytes στην έξοδο (writeBytes + writeStream),
//  3. `ENOSPC` → καθαρό μήνυμα «δεν υπάρχει χώρος»,
//  4. πλήθος entries από το κεντρικό ευρετήριο **πριν** το decode (μνήμη).
// Η πραγματική άμυνα για τον δίσκο είναι το (2): ο επιτιθέμενος ελέγχει το
// header, όχι τα bytes που βγαίνουν από το inflate. Για τη μνήμη, το (4): το
// decode φτιάχνει ένα header αντικείμενο ανά entry, οπότε εκατομμύρια entries
// θα κατανάλωναν εκατοντάδες MB πριν προλάβει να τρέξει οποιοσδήποτε μετρητής.
//
// Δομή zip:
//   super_note_db.isar            (η βάση)
//   attachments/<basename>...      (αρχεία, σχετικά ονόματα)
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import '../core/utils/app_errors.dart';
import '../core/utils/debug_config.dart';
import 'backup/backup_progress.dart';

class BackupArchive {
  BackupArchive._();

  static const String dbEntryName = 'super_note_db.isar';
  static const String attachmentsPrefix = 'attachments/';

  // ── S-08: όρια επαναφοράς (SPoT) ─────────────────────────────
  /// Μέγιστο **πραγματικό** μέγεθος ανά entry (512 MB).
  ///
  /// 5× το απόλυτο ceiling συνημμένου (`AppSettings.maxAttachmentCeilingMB`,
  /// S-13 = 100 MB) ώστε να μη σπάνε legacy συνημμένα που δημιουργήθηκαν πριν
  /// το ceiling. Η ρύθμιση χρήστη είναι φράγμα **εισαγωγής**, όχι εγγύηση για
  /// τα παλιά αρχεία.
  static const int maxEntryBytes = 512 * 1024 * 1024;

  /// Μέγιστο συνολικό μέγεθος εξαγωγής (2 GB).
  ///
  /// ≈20× το σημερινό τυπικό αντίγραφο. Το export **δεν** φράσσεται (S-307/Δ3)
  /// — ένα αντίγραφο πάνω από το όριο εξάγεται αλλά δεν επαναφέρεται (μόνο
  /// `DebugConfig.warning` στο export).
  static const int maxTotalBytes = 2 * 1024 * 1024 * 1024;

  /// S-08 residual: μέγιστο πλήθος entries του zip (50.000).
  ///
  /// Ο μετρητής bytes δεν προστατεύει τη **μνήμη**: το `decodeStream` χτίζει
  /// ένα header αντικείμενο ανά entry πριν ελεγχθεί οτιδήποτε, άρα ένα zip με
  /// εκατομμύρια entries δεσμεύει εκατοντάδες MB. 50k ≈ 15–25 MB στο decode
  /// (~4 MB κεντρικό ευρετήριο) — πρακτικά απρόσιτο για νόμιμο αντίγραφο: ένα
  /// 2 GB αντίγραφο με 50k αρχεία θα είχε μέσο όρο 40 KB/αρχείο.
  static const int maxEntries = 50000;

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

  /// S-08 residual: πλήθος entries από το **κεντρικό ευρετήριο**, χωρίς decode.
  ///
  /// Διαβάζει το EOCD (τέλος αρχείου) και μετά μόνο τις σταθερές κεφαλίδες των
  /// 46 bytes του κεντρικού ευρετηρίου, πηδώντας name/extra/comment — καμία
  /// δομή ανά entry. Σταματά στο [limit] + 1 (το ακριβές πλήθος δεν χρειάζεται).
  ///
  /// Επιστρέφει 0 όταν το αρχείο δεν είναι zip ή δεν βρεθεί EOCD: τότε το
  /// σφάλμα το δίνει ο decoder με το υπάρχον μήνυμα.
  static int countCentralDirectoryEntries(
    String zipPath, {
    int limit = maxEntries,
  }) {
    RandomAccessFile? raf;
    try {
      raf = File(zipPath).openSync();
      final fileLength = raf.lengthSync();
      final eocd = _findEocd(raf, fileLength);
      if (eocd < 0) return 0;
      final eocdBytes = _readAt(raf, eocd + 12, 8);
      if (eocdBytes == null) return 0;
      final eocdView = ByteData.sublistView(eocdBytes);
      var cdSize = eocdView.getUint32(0, Endian.little);
      var cdOffset = eocdView.getUint32(4, Endian.little);
      if (cdOffset == 0xFFFFFFFF || cdSize == 0xFFFFFFFF) {
        final zip64 = _readZip64Directory(raf, eocd);
        if (zip64 == null) return 0;
        cdOffset = zip64.$1;
        cdSize = zip64.$2;
      }
      if (cdOffset < 0 || cdOffset >= fileLength) return 0;
      // Δηλωμένο CD μεγαλύτερο από το αρχείο → κόβεται στο πραγματικό μέγεθος
      // (το `decodeStream` κάνει το ίδιο: το subset του σταματά στο EOF).
      if (cdOffset + cdSize > fileLength) cdSize = fileLength - cdOffset;
      if (cdSize < 46) return 0;

      var pos = 0;
      var count = 0;
      final header = Uint8List(46);
      while (pos + 46 <= cdSize) {
        if (!_readInto(raf, cdOffset + pos, header)) break;
        final view = ByteData.sublistView(header);
        // 0x02014b50 = central directory file header· ίδιο σημείο τερματισμού
        // με τον βρόχο του `ZipDecoder`.
        if (view.getUint32(0, Endian.little) != 0x02014b50) break;
        count++;
        if (count > limit) break;
        pos += 46 +
            view.getUint16(28, Endian.little) +
            view.getUint16(30, Endian.little) +
            view.getUint16(32, Endian.little);
      }
      return count;
    } finally {
      raf?.closeSync();
    }
  }

  /// S-08 residual: απόρριψη zip με περισσότερα από [limit] entries **πριν**
  /// το decode (άρα πριν δεσμευτεί μνήμη ανά entry).
  static void ensureEntryCountWithinLimit(
    String zipPath, {
    int limit = maxEntries,
  }) {
    if (countCentralDirectoryEntries(zipPath, limit: limit) > limit) {
      throw const BackupLimitException(AppErrors.backupTooLarge);
    }
  }

  static const int _eocdSignature = 0x06054b50;

  /// Αναζήτηση του EOCD record από το τέλος (με έως 64 KB σχόλιο zip).
  /// Επιστρέφει απόλυτο offset ή -1.
  static int _findEocd(RandomAccessFile raf, int fileLength) {
    const eocdSize = 22;
    const maxComment = 0xFFFF;
    if (fileLength < eocdSize) return -1;
    final window = fileLength < eocdSize + maxComment
        ? fileLength
        : eocdSize + maxComment;
    final start = fileLength - window;
    final bytes = _readAt(raf, start, window);
    if (bytes == null) return -1;
    for (var i = window - 4; i >= 0; i--) {
      if (bytes[i] == (_eocdSignature & 0xFF) &&
          bytes[i + 1] == ((_eocdSignature >> 8) & 0xFF) &&
          bytes[i + 2] == ((_eocdSignature >> 16) & 0xFF) &&
          bytes[i + 3] == ((_eocdSignature >> 24) & 0xFF)) {
        return start + i;
      }
    }
    return -1;
  }

  /// zip64: `(cdOffset, cdSize)` από τον locator + το zip64 EOCD record.
  static (int, int)? _readZip64Directory(RandomAccessFile raf, int eocd) {
    final locator = _readAt(raf, eocd - 20, 20);
    if (locator == null) return null;
    final loc = ByteData.sublistView(locator);
    if (loc.getUint32(0, Endian.little) != 0x07064b50) return null;
    final record = _readAt(raf, loc.getUint64(8, Endian.little), 56);
    if (record == null) return null;
    final rec = ByteData.sublistView(record);
    if (rec.getUint32(0, Endian.little) != 0x06064b50) return null;
    return (
      rec.getUint64(48, Endian.little),
      rec.getUint64(40, Endian.little),
    );
  }

  static Uint8List? _readAt(RandomAccessFile raf, int offset, int length) {
    final buffer = Uint8List(length);
    return _readInto(raf, offset, buffer) ? buffer : null;
  }

  static bool _readInto(RandomAccessFile raf, int offset, Uint8List buffer) {
    if (offset < 0) return false;
    raf.setPositionSync(offset);
    var read = 0;
    while (read < buffer.length) {
      final n = raf.readIntoSync(buffer, read);
      if (n <= 0) break;
      read += n;
    }
    return read == buffer.length;
  }

  /// S-08: άθροισμα **δηλωμένων** (uncompressed) μεγεθών των επιτρεπτών entries.
  ///
  /// Τα μεγέθη προέρχονται από το κεντρικό ευρετήριο και είναι
  /// attacker-controlled — χρησιμοποιούνται μόνο για φθηνή προ-πτήση και για
  /// σωστό έλεγχο ελεύθερου χώρου. Η άμυνα είναι ο μετρητής bytes στην
  /// `_LimitedOutputFileStream`.
  ///
  /// Μετρά **μόνο** ό,τι θα γραφτεί (`isAllowedEntry`), ώστε ένα τεράστιο
  /// μη-επιτρεπτό entry να μην απορρίπτει έγκυρο αντίγραφο.
  static Future<int> declaredUncompressedBytes(String zipPath) async {
    ensureEntryCountWithinLimit(zipPath);
    final input = InputFileStream(zipPath);
    try {
      return declaredBytesOf(ZipDecoder().decodeStream(input));
    } finally {
      input.closeSync();
    }
  }

  /// S-08: το ίδιο άθροισμα πάνω σε ήδη αποκωδικοποιημένο [archive] (χωρίς
  /// δεύτερο άνοιγμα του αρχείου). Overflow-safe: ένα κακόβουλο header μπορεί
  /// να δηλώνει μεγέθη που αθροίζονται πάνω από 2^63 — σε κάθε τέτοια
  /// περίπτωση επιστρέφεται [_overflowSentinel] (απορρίπτεται σίγουρα).
  static int declaredBytesOf(Archive archive) {
    var total = 0;
    for (final f in archive.files) {
      if (f.isDirectory) continue;
      if (!isAllowedEntry(f.name)) continue;
      final size = f.size;
      if (size < 0) return _overflowSentinel;
      total += size;
      if (total < 0 || total > _overflowSentinel) return _overflowSentinel;
    }
    return total;
  }

  /// 2^61: «άπειρο» για πρακτικούς σκοπούς, αλλά ασφαλές σε `*2`/`+32MB`.
  static const int _overflowSentinel = 1 << 61;

  /// S-08: αναγνώριση «ο δίσκος γέμισε» χωρίς πλατφορμικό dependency.
  ///
  /// POSIX `ENOSPC` = 28 · Windows `ERROR_DISK_FULL` = 112 και
  /// `ERROR_HANDLE_DISK_FULL` = 39· fallback στο μήνυμα. Pure — τη
  /// χρησιμοποιεί και το export (`BackupService._friendlyExportError`).
  static bool isNoSpaceError(Object error) {
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      if (code == 28 || code == 112 || code == 39) return true;
    }
    final text = error.toString();
    return text.contains('ENOSPC') ||
        text.contains('No space left') ||
        text.contains('not enough space') ||
        text.contains('No space');
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
  ///
  /// S-08: αν [declaredBytes] δοθεί (το έχει ήδη υπολογίσει ο caller), δεν
  /// ξαναδιαβάζεται το κεντρικό ευρετήριο. Τα [entryLimit]/[totalLimit]/
  /// [entryCountLimit] είναι injectable για tests — οι default είναι τα όρια
  /// του S-08.
  static Future<List<String>> extractBackupZip(
    String zipPath,
    String outDir, {
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
    int? declaredBytes,
    int entryLimit = maxEntryBytes,
    int totalLimit = maxTotalBytes,
    int entryCountLimit = maxEntries,
  }) async {
    final input = InputFileStream(zipPath);
    try {
      // S-08 residual: πρώτα το πλήθος entries (μνήμη), μετά το decode.
      ensureEntryCountWithinLimit(zipPath, limit: entryCountLimit);
      final archive = ZipDecoder().decodeStream(input);
      final names = <String>[];
      var written = 0;
      var skipped = 0;
      var doneBytes = 0;
      var totalWritten = 0;

      // S-08: προ-πτήση στα δηλωμένα μεγέθη — απόρριψη πριν γραφτεί byte.
      final totalBytes = declaredBytes ?? declaredBytesOf(archive);
      if (totalBytes > totalLimit) {
        throw const BackupLimitException(AppErrors.backupTooLarge);
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
        if (f.size > entryLimit) {
          throw const BackupLimitException(AppErrors.backupTooLarge);
        }
        final segments = f.name.split('/');
        final outPath = p.joinAll(<String>[outDir, ...segments]);
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);
        final output = _LimitedOutputFileStream(
          outPath,
          totalWritten: totalWritten,
          entryLimit: entryLimit,
          totalLimit: totalLimit,
          isCancelled: isCancelled,
        );
        try {
          f.writeContent(output);
        } finally {
          output.closeSync();
        }
        totalWritten = output.totalWritten;
        written++;
        doneBytes += f.size;
        onProgress
            ?.call(BackupProgress(BackupPhase.extract, doneBytes, totalBytes));
      }
      DebugConfig.db('BackupArchive.extract: entries=${names.length} '
          'written=$written skipped=$skipped bytes=$totalWritten '
          'declared=$totalBytes out=$outDir');
      return names;
    } on FileSystemException catch (e, stack) {
      if (isNoSpaceError(e)) {
        DebugConfig.warning('BackupArchive.extract: no space — '
            'code=${e.osError?.errorCode}');
        throw const BackupSpaceException(AppErrors.backupNoSpace);
      }
      DebugConfig.error('BackupArchive.extract', e, stack);
      rethrow;
    } catch (e, stack) {
      if (e is! BackupCancelledException && e is! BackupLimitException) {
        DebugConfig.error('BackupArchive.extract', e, stack);
      }
      rethrow;
    } finally {
      input.closeSync();
    }
  }

  /// Εξάγει μόνο το DB entry για validation — χωρίς attachments (streaming).
  /// Επιστρέφει όλα τα ονόματα entries (για τον έλεγχο παρουσίας DB).
  ///
  /// S-08: ίδια όρια/μετρητής με το [extractBackupZip] (defense in depth).
  static Future<List<String>> extractBackupZipDbOnly(
    String zipPath,
    String outDir, {
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
    int entryLimit = maxEntryBytes,
    int totalLimit = maxTotalBytes,
    int entryCountLimit = maxEntries,
  }) async {
    final input = InputFileStream(zipPath);
    try {
      ensureEntryCountWithinLimit(zipPath, limit: entryCountLimit);
      final archive = ZipDecoder().decodeStream(input);
      final names = <String>[];
      for (final f in archive.files) {
        if (!f.isDirectory) names.add(f.name);
      }
      final db = archive.findFile(dbEntryName);
      if (db != null && !db.isDirectory && isAllowedEntry(db.name)) {
        if (db.size > entryLimit) {
          throw const BackupLimitException(AppErrors.backupTooLarge);
        }
        if (isCancelled?.call() ?? false) {
          throw const BackupCancelledException();
        }
        onProgress
            ?.call(BackupProgress(BackupPhase.extract, 0, db.size));
        final outPath = p.join(outDir, dbEntryName);
        await File(outPath).parent.create(recursive: true);
        final output = _LimitedOutputFileStream(
          outPath,
          totalWritten: 0,
          entryLimit: entryLimit,
          totalLimit: totalLimit,
          isCancelled: isCancelled,
        );
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
    } on FileSystemException catch (e, stack) {
      if (isNoSpaceError(e)) {
        DebugConfig.warning('BackupArchive.extractDbOnly: no space — '
            'code=${e.osError?.errorCode}');
        throw const BackupSpaceException(AppErrors.backupNoSpace);
      }
      DebugConfig.error('BackupArchive.extractDbOnly', e, stack);
      rethrow;
    } catch (e, stack) {
      if (e is! BackupCancelledException && e is! BackupLimitException) {
        DebugConfig.error('BackupArchive.extractDbOnly', e, stack);
      }
      rethrow;
    } finally {
      input.closeSync();
    }
  }
}

/// S-08: φραγμένη έξοδος εξαγωγής.
///
/// Μετρά **πραγματικά** bytes (όχι τα δηλωμένα του zip) και σταματά το inflate
/// μόλις ξεπεραστεί το όριο του entry ή το συνολικό. Το [writeStream] πρέπει να
/// ξαναϋλοποιηθεί εδώ: τα stored entries (όλα τα συνημμένα) γράφονται μέσω
/// αυτού και το `OutputFileStream` γράφει απευθείας στο handle, παρακάμπτοντας
/// το [writeBytes] — χωρίς αυτό, τα συνημμένα δεν θα μετριούνταν καθόλου.
class _LimitedOutputFileStream extends OutputStream {
  final OutputFileStream _inner;
  final int _entryLimit;
  final int _totalLimit;
  final bool Function()? _isCancelled;

  int _entryWritten = 0;
  int _totalWritten;
  int _cancelCheckpoint;

  _LimitedOutputFileStream(
    String path, {
    required int totalWritten,
    required int entryLimit,
    required int totalLimit,
    required bool Function()? isCancelled,
  })  : _inner = OutputFileStream(path),
        _entryLimit = entryLimit,
        _totalLimit = totalLimit,
        _isCancelled = isCancelled,
        _totalWritten = totalWritten,
        _cancelCheckpoint = totalWritten,
        super(byteOrder: ByteOrder.littleEndian);

  /// Bytes που γράφτηκαν συνολικά σε όλα τα entries μέχρι τώρα.
  int get totalWritten => _totalWritten;

  @override
  int get length => _inner.length;

  @override
  bool get isOpen => _inner.isOpen;

  @override
  void clear() {
    _inner.clear();
  }

  @override
  void flush() => _inner.flush();

  @override
  void closeSync() => _inner.closeSync();

  @override
  Future<void> close() => _inner.close();

  @override
  Uint8List subset(int start, [int? end]) => _inner.subset(start, end);

  @override
  void writeByte(int value) {
    _account(1);
    _inner.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    if (count <= 0) return;
    _account(count);
    _inner.writeBytes(bytes, length: length);
  }

  /// Ίδιο σχήμα με το `OutputFileStream.writeStream` (σταθερό [InputStream.length]
  /// ανά κλήση), αλλά κάθε chunk περνά από το μετρημένο [writeBytes].
  @override
  void writeStream(InputStream stream) {
    var remaining = stream.length;
    const chunkSize = 1024 * 1024;
    while (remaining > chunkSize) {
      final bytes = stream.readBytes(chunkSize).toUint8List();
      if (bytes.isEmpty) return;
      writeBytes(bytes);
      remaining -= chunkSize;
    }
    if (remaining > 0) {
      final bytes = stream.readBytes(remaining).toUint8List();
      if (bytes.isEmpty) return;
      writeBytes(bytes);
    }
  }

  /// Έλεγχος ορίων + περιοδικός έλεγχος ακύρωσης (ανά ~1 MB γραμμένων).
  void _account(int count) {
    if (_entryWritten + count > _entryLimit ||
        _totalWritten + count > _totalLimit) {
      throw const BackupLimitException(AppErrors.backupTooLarge);
    }
    _entryWritten += count;
    _totalWritten += count;
    final cancelled = _isCancelled;
    if (cancelled != null &&
        _totalWritten - _cancelCheckpoint >= 1024 * 1024) {
      _cancelCheckpoint = _totalWritten;
      if (cancelled()) throw const BackupCancelledException();
    }
  }
}
