// lib/services/backup_service.dart
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import '../core/core.dart';
import '../platform/file_save_channel.dart';
import 'attachment_service.dart';
import 'backup/backup_container.dart';
import 'backup/backup_db_probe.dart';
import 'backup/backup_passphrase_cache.dart';
import 'backup/backup_progress.dart';
import 'backup/backup_rotation.dart';
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
  /// S-308 (F1): το [path] είναι προαιρετικό — η ροή «Κοινοποίηση» δεν
  /// αποθηκεύει σε προορισμό (το `.snb` μένει temp και διαγράφεται), οπότε
  /// δεν πρέπει να αναφέρεται ως «αποθηκευμένο».
  factory BackupExportResult.success([String? path]) =>
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

/// S-02: αποτέλεσμα του σταδίου «prepare» (decrypt → allowlist extract →
/// probe/sanitize) — ΠΡΙΝ αγγίξει οτιδήποτε τη live DB.
///
/// Το [workDir] ανήκει στο αποτέλεσμα: ο caller οφείλει να καλέσει
/// [BackupService.restorePrepared] ή [BackupService.discardPrepared].
class PreparedRestore {
  final BackupFormat format;
  final Directory workDir;
  final File dbFile;
  final Directory? attachmentsDir;
  final int entryCount;
  final int attachmentCount;
  final int plaintextBytes;

  /// true όταν το αντίγραφο περιείχε ενεργό κλείδωμα και καθαρίστηκε.
  final bool strippedAppLock;

  const PreparedRestore({
    required this.format,
    required this.workDir,
    required this.dbFile,
    required this.attachmentsDir,
    required this.entryCount,
    required this.attachmentCount,
    required this.plaintextBytes,
    required this.strippedAppLock,
  });
}

class BackupPrepareResult {
  final PreparedRestore? prepared;
  final String? error;

  /// true όταν ο χρήστης ακύρωσε από το progress dialog (όχι σφάλμα).
  final bool cancelled;

  const BackupPrepareResult.success(PreparedRestore this.prepared)
      : error = null,
        cancelled = false;
  const BackupPrepareResult.failure(String this.error)
      : prepared = null,
        cancelled = false;
  const BackupPrepareResult.cancelled()
      : prepared = null,
        error = null,
        cancelled = true;
  bool get success => prepared != null;
}

class BackupService {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  static const String dbFileName = 'super_note_db.isar';
  static const String zipSuffix = '.zip';
  static const String isarSuffix = '.isar';
  static const String snbSuffix = BackupContainer.suffix;

  /// S-307: περιθώριο ασφαλείας στον έλεγχο ελεύθερου χώρου (+15%).
  static const double freeSpaceMargin = 1.15;

  /// E50: όνομα του υποφακέλου των auto backups — **ίδιο** στο support dir
  /// (νέο) και στο legacy cache dir, ώστε το adopt να είναι απλή μετακίνηση.
  /// SPoT του ονόματος (το χρησιμοποιεί και το wipe).
  static const String autoBackupDirName = 'SuperNoteBackups';

  /// E50: πόσα auto backups κρατάμε **συνολικά** (support + legacy). Public
  /// ώστε το UI να μη γράφει σκληρό «5» — SPoT της πολιτικής πλήθους.
  static const int maxAutoBackups = 5;

  /// Διάστημα αυτόματων αντιγράφων (σταθερό — χωρίς UI επιλογής).
  static const int autoBackupIntervalHours = 24;

  // ── E33 maintenance (restore/wipe) ──────────────────────────
  /// true όσο τρέχει restore/wipe: queues paused + drain ολοκληρωμένο.
  bool _maintenanceActive = false;

  /// Αυξάνεται σε κάθε έναρξη maintenance — F5: autoBackup που ξεκίνησε
  /// πριν το restore δεν γράφει lastAutoBackupAt σε DB που αλλάζει.
  int _maintenanceEpoch = 0;

  /// Πραγματικά in-flight autoBackup/export/prepare — το drain τα περιμένει
  /// πριν το close της DB (F7). Το prepare (S-02) είναι 5ο.
  Future<void>? _autoBackupInFlight;
  Future<void>? _exportInFlight;
  Future<void>? _prepareInFlight;

  /// E50: adopt των legacy auto backups (cache → support). Μία φορά ανά
  /// process, **single-flight** (startup sweep + μετά restore μπορούν να
  /// συμπέσουν) — ίδιο pattern με τα in-flight futures παραπάνω.
  bool _legacyAdoptDone = false;
  Future<void>? _legacyAdoptInFlight;

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────

  Future<String> _dbPath() async {
    // S-01: SPoT της ρίζας δεδομένων (legacy μετά από rollback migration).
    final dir = await AppPaths.activeDataRoot();
    return p.join(dir, dbFileName);
  }

  /// S-02 (C5): sortable UTC timestamp για ονόματα αντιγράφων.
  static String fileTimestamp([DateTime? now]) {
    final ts = (now ?? DateTime.now())
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    return ts;
  }

  /// S-307 (Δ4): true όταν τρέχει κάποια ροή αντιγράφου (για disabling tiles).
  /// ΔΕΝ χρησιμοποιείται το `_maintenanceActive` — αυτό μένει μόνο για
  /// restore/wipe (θα πάγωνε queues όσο είναι ανοιχτό το share sheet).
  bool get isBusy =>
      _exportInFlight != null ||
      _prepareInFlight != null ||
      _autoBackupInFlight != null;

  /// Καταγράφει ένα in-flight future και το καθαρίζει όταν ολοκληρωθεί
  /// (ώστε το [isBusy] να μη μένει «κολλημένο» μετά την πρώτη ροή).
  Future<void> _trackExport(Future<BackupExportResult> future) {
    late final Future<void> tracked;
    tracked = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    ).whenComplete(() {
      if (identical(_exportInFlight, tracked)) _exportInFlight = null;
    });
    _exportInFlight = tracked;
    return tracked;
  }

  Future<void> _trackPrepare(Future<BackupPrepareResult> future) {
    late final Future<void> tracked;
    tracked = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    ).whenComplete(() {
      if (identical(_prepareInFlight, tracked)) _prepareInFlight = null;
    });
    _prepareInFlight = tracked;
    return tracked;
  }

  /// S-307: έλεγχος ελεύθερου χώρου. null = OK/άγνωστο (desktop → try/catch).
  Future<BackupSpaceException?> _checkFreeSpace(
      String dirPath, int requiredBytes) async {
    if (requiredBytes <= 0) return null;
    final free = await FileSaveChannel.freeSpace(dirPath);
    if (free == null) return null;
    final needed = (requiredBytes * freeSpaceMargin).ceil();
    if (free < needed) {
      DebugConfig.warning('BackupService: no space free=$free '
          'needed=$needed dir=$dirPath');
      return const BackupSpaceException(AppErrors.backupNoSpace);
    }
    return null;
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
      _waitForInFlight(_prepareInFlight, maxWait, 'prepare'),
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
  // Κοινό χτίσιμο .snb (zip → encrypt) — export/Share/autoBackup
  // ─────────────────────────────────────────────────────────────────

  /// Κωδικός εξαγωγής: null = ενσωματωμένο κλειδί (Δ1), αλλιώς Δ6.
  Future<String?> _exportPassphraseOrThrow() async {
    final settings = await SuperNoteHelper.instance.settings.get();
    if (!settings.backupLockEnabled) return null;
    final cached = BackupPassphraseCache.instance.passphrase;
    if (cached == null || cached.isEmpty) {
      throw const BackupAuthException(AppErrors.backupPassphraseRequired);
    }
    return cached;
  }

  /// Φτιάχνει το `.snb` στο [destSnbPath] (temp zip στο [workDir]).
  /// Επιστρέφει το path του τελικού container.
  Future<String> _buildBackupSnb({
    required Directory workDir,
    required String destSnbPath,
    required String? passphrase,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final srcPath = await _dbPath();
    if (!await File(srcPath).exists()) {
      throw Exception('Δεν βρέθηκε η βάση δεδομένων');
    }
    final dataRoot = await AppPaths.activeDataRoot();
    final attachmentsDir =
        Directory(p.join(dataRoot, AttachmentService.attachmentsDirName));

    // S-307: χώρος ΠΡΙΝ το γράψιμο (temp zip ≈ πηγή, snb ≈ πηγή).
    final estimate = await BackupArchive.estimateSourceBytes(
      dbPath: srcPath,
      attachmentsDir: attachmentsDir,
    );
    final tempNoSpace = await _checkFreeSpace(workDir.path, estimate * 2);
    if (tempNoSpace != null) throw tempNoSpace;
    final destDir = p.dirname(destSnbPath);
    if (!p.equals(destDir, workDir.path)) {
      final destNoSpace = await _checkFreeSpace(destDir, estimate);
      if (destNoSpace != null) throw destNoSpace;
    }

    final tempZip = p.join(workDir.path, 'payload.zip');
    await BackupArchive.createBackupZip(
      dbPath: srcPath,
      snapshotIsar: SuperNoteHelper.instance.isar,
      attachmentsDir: attachmentsDir,
      destZipPath: tempZip,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    // S-02 (D7): το container γράφει σε `.partial` και μετονομάζει μόνο
    // μετά την ολοκλήρωση — ποτέ μισό `.snb` με τελικό όνομα.
    await BackupContainer.encryptFileTo(
      source: File(tempZip),
      destPath: destSnbPath,
      passphrase: passphrase,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    // Ελευθερώνει χώρο πριν το αντιγράφημα στον προορισμό.
    await _deleteFileSilently(File(tempZip));
    return destSnbPath;
  }

  // ─────────────────────────────────────────────────────────────────
  // 1. EXPORT: Αποθήκευση στη συσκευή (system save dialog)
  // ─────────────────────────────────────────────────────────────────

  /// Δημόσιο entry point — καταγράφει το in-flight future για το drain του
  /// restore/wipe (F7).
  Future<BackupExportResult> exportToDevice({
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) {
    final future = _exportToDeviceImpl(
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    unawaited(_trackExport(future));
    return future;
  }

  Future<BackupExportResult> _exportToDeviceImpl({
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    DebugConfig.db('exportToDevice: starting');
    Directory? workDir;
    try {
      final passphrase = await _exportPassphraseOrThrow();
      final tempRoot = await getTemporaryDirectory();
      workDir = await Directory(p.join(tempRoot.path,
              '_backup_export_${DateTime.now().millisecondsSinceEpoch}'))
          .create(recursive: true);
      final fileName = 'super_note_backup_${fileTimestamp()}$snbSuffix';
      final tempSnb = await _buildBackupSnb(
        workDir: workDir,
        destSnbPath: p.join(workDir.path, fileName),
        passphrase: passphrase,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      DebugConfig.db('exportToDevice: snb ready');

      // S-307 (Δ3): Android → SAF streaming (χωρίς bytes μέσω channel).
      if (Platform.isAndroid) {
        final saved = await FileSaveChannel.saveDocument(
          sourcePath: tempSnb,
          fileName: fileName,
          onProgress: onProgress,
        );
        if (saved == null) {
          DebugConfig.db('exportToDevice: user cancelled');
          return BackupExportResult.cancelled();
        }
        DebugConfig.db('exportToDevice: SUCCESS — dest=$saved');
        return BackupExportResult.success(saved);
      }

      // iOS εκτός scope (S-307): ίδια ροή με «Κοινοποίηση».
      if (Platform.isIOS) {
        await _shareFile(tempSnb);
        final dirToClean = workDir;
        workDir = null;
        _scheduleTempCleanup(dirToClean);
        return BackupExportResult.success(tempSnb);
      }

      // Desktop: το file_picker επιστρέφει path (αγνοεί τα bytes) → copy με
      // streaming, χωρίς readAsBytes (fix του παλιού 88MB στο heap).
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Αποθήκευση αντιγράφου SuperNote',
        fileName: fileName,
        type: FileType.any,
      );
      if (savedPath == null) {
        DebugConfig.db('exportToDevice: user cancelled');
        return BackupExportResult.cancelled();
      }
      await _copyWithProgress(
        File(tempSnb),
        savedPath,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      DebugConfig.db('exportToDevice: SUCCESS — dest=$savedPath');
      return BackupExportResult.success(savedPath);
    } on BackupCancelledException {
      DebugConfig.db('exportToDevice: cancelled by user');
      return BackupExportResult.cancelled();
    } on BackupSpaceException catch (e) {
      DebugConfig.warning('exportToDevice: no space — ${e.message}');
      return BackupExportResult.failure(e.message);
    } on BackupAuthException catch (e) {
      return BackupExportResult.failure(e.message);
    } catch (e, s) {
      DebugConfig.error('BackupService.exportToDevice', e, s);
      return BackupExportResult.failure(_friendlyExportError(e));
    } finally {
      if (workDir != null) {
        try {
          if (await workDir.exists()) await workDir.delete(recursive: true);
          DebugConfig.db('exportToDevice: temp dir deleted');
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
  Future<BackupExportResult> exportWithShare({
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) {
    final future = _exportWithShareImpl(
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    unawaited(_trackExport(future));
    return future;
  }

  Future<BackupExportResult> _exportWithShareImpl({
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    DebugConfig.db('exportWithShare: starting');
    Directory? workDir;
    try {
      final passphrase = await _exportPassphraseOrThrow();
      final tempRoot = await getTemporaryDirectory();
      workDir = await Directory(p.join(tempRoot.path,
              '_backup_share_${DateTime.now().millisecondsSinceEpoch}'))
          .create(recursive: true);
      final fileName = 'super_note_backup_${fileTimestamp()}$snbSuffix';
      final tempSnb = await _buildBackupSnb(
        workDir: workDir,
        destSnbPath: p.join(workDir.path, fileName),
        passphrase: passphrase,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      DebugConfig.db('exportWithShare: snb ready, opening share sheet');
      try {
        await _shareFile(tempSnb);
        DebugConfig.db(
            'exportWithShare: share sheet closed, scheduling temp cleanup');
        final dirToClean = workDir;
        workDir = null;
        _scheduleTempCleanup(dirToClean);
        // S-308 (F1): κανένα path — το μήνυμα γίνεται «Εξαγωγή επιτυχής» και
        // όχι «Αντίγραφο αποθηκεύτηκε» (δεν υπάρχει προορισμός· μόνο temp).
        return BackupExportResult.success();
      } catch (_) {
        DebugConfig.db('exportWithShare: share failed, cleaning up temp');
        try {
          final dir = workDir;
          if (dir != null && await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } catch (cleanupError) {
          DebugConfig.warning(
              'exportWithShare: cleanup after share failure failed: '
              '$cleanupError');
        }
        rethrow;
      }
    } on BackupCancelledException {
      DebugConfig.db('exportWithShare: cancelled by user');
      return BackupExportResult.cancelled();
    } on BackupSpaceException catch (e) {
      return BackupExportResult.failure(e.message);
    } on BackupAuthException catch (e) {
      return BackupExportResult.failure(e.message);
    } catch (e, s) {
      DebugConfig.error('BackupService.exportWithShare', e, s);
      return BackupExportResult.failure('${AppErrors.shareFailed}: $e');
    } finally {
      if (workDir != null) {
        try {
          if (await workDir.exists()) await workDir.delete(recursive: true);
        } catch (e) {
          DebugConfig.warning('exportWithShare: workDir cleanup failed: $e');
        }
      }
    }
  }

  Future<void> _shareFile(String path) async {
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile(path, mimeType: 'application/octet-stream'),
      ],
      subject: 'SuperNote Backup',
      text: 'Αντίγραφο ασφαλείας SuperNote',
    ));
  }

  /// Το share sheet χρειάζεται το αρχείο ανοιχτό· καθαρισμός μετά.
  void _scheduleTempCleanup(Directory dir) {
    Future.delayed(const Duration(seconds: 10), () async {
      try {
        await dir.delete(recursive: true);
        DebugConfig.db('export: delayed temp dir deleted');
      } catch (e) {
        DebugConfig.warning('export: delayed temp cleanup failed: $e');
      }
    });
  }

  /// Desktop copy με πρόοδο (256 KiB chunks) + partial + rename.
  Future<void> _copyWithProgress(
    File source,
    String destPath, {
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final total = await source.length();
    final partial = File('$destPath.partial');
    RandomAccessFile? input;
    RandomAccessFile? out;
    try {
      input = await source.open();
      out = await partial.open(mode: FileMode.write);
      var done = 0;
      onProgress?.call(BackupProgress(BackupPhase.copy, 0, total));
      while (true) {
        if (isCancelled?.call() ?? false) {
          throw const BackupCancelledException();
        }
        final bytes = await input.read(256 * 1024);
        if (bytes.isEmpty) break;
        await out.writeFrom(bytes);
        done += bytes.length;
        onProgress?.call(BackupProgress(BackupPhase.copy, done, total));
      }
      await out.flush();
      await out.close();
      out = null;
      await input.close();
      input = null;
      final dest = File(destPath);
      if (await dest.exists()) await dest.delete();
      await partial.rename(destPath);
    } catch (e) {
      try {
        await out?.close();
      } catch (_) {}
      try {
        await input?.close();
      } catch (_) {}
      try {
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
      rethrow;
    }
  }

  String _friendlyExportError(Object e) {
    final text = e.toString();
    if (text.contains('ENOSPC') ||
        text.contains('No space left') ||
        text.contains('No space')) {
      return AppErrors.backupNoSpace;
    }
    if (e is PlatformException) {
      return '${AppErrors.backupSaveFailed}: ${e.message ?? e.code}';
    }
    return 'Αποτυχία αποθήκευσης: $e';
  }

  // ─────────────────────────────────────────────────────────────────
  // 3. IMPORT (validation + atomic restore — βήμα προς βήμα)
  // ─────────────────────────────────────────────────────────────────

  Future<String?> pickBackupFile() async {
    DebugConfig.db('pickBackupFile: opening file picker');
    try {
      // S-02 (N1): `FileType.custom` + άγνωστο extension (`.snb`) κάνει το
      // plugin να πετά (getMimeTypes) ή να κρύβει το αρχείο στο Android.
      // Διαλέγουμε με `FileType.any` και ανιχνεύουμε μορφή από magic bytes.
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

  /// Πλήρης ροή (prepare + restore). Χρησιμοποιείται από tests/εσωτερικά·
  /// το UI κάνει τα δύο βήματα ξεχωριστά για να μεσολαβήσει επιβεβαίωση.
  Future<BackupImportResult> restoreBackup(String backupPath,
      {String? passphrase}) async {
    DebugConfig.db('restoreBackup: starting, path=$backupPath');
    final prep = await prepare(backupPath, passphrase: passphrase);
    if (!prep.success) {
      if (prep.cancelled) return BackupImportResult.cancelled();
      DebugConfig.warning('restoreBackup: prepare FAILED — ${prep.error}');
      return BackupImportResult.failure(prep.error ?? AppErrors.backupInvalid);
    }
    return restorePrepared(prep.prepared!);
  }

  Future<BackupImportResult> import({String? fromPath, String? passphrase}) async {
    DebugConfig.db('import: starting${fromPath != null ? ", fromPath=$fromPath" : ""}');
    try {
      final srcPath = fromPath ?? await pickBackupFile();
      if (srcPath == null) {
        DebugConfig.db('import: cancelled by user');
        return BackupImportResult.cancelled();
      }
      return await restoreBackup(srcPath, passphrase: passphrase);
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
  /// S-307 (Δ5): χωρίς ενσωματωμένο κλειδί δεν χρειάζεται session passphrase.
  /// Αν το «Κλείδωμα αντιγράφου» είναι ON, απαιτείται session passphrase —
  /// αλλιώς το αντίγραφο σκιπάρεται (ποτέ plaintext, όπως D8).
  Future<String?> autoBackup() {
    if (_maintenanceActive) {
      DebugConfig.db('autoBackup: maintenance active — skipping');
      return Future<String?>.value(null);
    }
    final future = _autoBackupImpl();
    late final Future<void> tracked;
    tracked = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    ).whenComplete(() {
      if (identical(_autoBackupInFlight, tracked)) _autoBackupInFlight = null;
    });
    _autoBackupInFlight = tracked;
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
      // S-307 (Δ5/Δ6): embedded key από προεπιλογή· με «Κλείδωμα αντιγράφου»
      // χρειάζεται ο κωδικός της συνεδρίας (αλλιώς skip — ποτέ plaintext).
      String? passphrase;
      if (settings.backupLockEnabled) {
        passphrase = BackupPassphraseCache.instance.passphrase;
        if (passphrase == null || passphrase.isEmpty) {
          DebugConfig.db(
              'autoBackup: lock enabled without session passphrase — skipping');
          return null;
        }
      }
      final backupDir = await _getAutoBackupDir();
      final timestamp = fileTimestamp();
      final destPath = p.join(backupDir.path, 'auto_$timestamp$snbSuffix');
      // E50: το temp zip είναι **plaintext** (DB + attachments) → ποτέ στον
      // μόνιμο φάκελο. Ζει σε δικό του temp dir στον cache και διαγράφεται
      // στο finally (ή από το `sweepStaleArtifacts` αν χαθεί το finally).
      final tempRoot = await getTemporaryDirectory();
      final workDir =
          Directory(p.join(tempRoot.path, '_backup_auto_$timestamp'));
      await workDir.create(recursive: true);
      try {
        await _buildBackupSnb(
          workDir: workDir,
          destSnbPath: destPath,
          passphrase: passphrase,
        );
      } finally {
        try {
          if (await workDir.exists()) await workDir.delete(recursive: true);
        } catch (e) {
          DebugConfig.warning('autoBackup: temp dir cleanup failed: $e');
        }
      }
      if (_maintenanceActive || epoch != _maintenanceEpoch) {
        // F5: restore/wipe ξεκίνησε όσο φτιάχναμε το αντίγραφο — η DB μπορεί
        // να κλείσει/αντικατασταθεί· κρατάμε το (έγκυρο) αρχείο και
        // σκιπάρουμε ΜΟΝΟ το settings.update.
        DebugConfig.warning(
            'autoBackup: maintenance/epoch changed '
                '(epoch=$epoch now=$_maintenanceEpoch) — backup kept, settings.update skipped');
      } else {
        await SuperNoteHelper.instance.settings.update((s) {
          s.lastAutoBackupAt = DateTime.now();
        });
      }
      DebugConfig.db('autoBackup: saved to $destPath');
      await _rotateAutoBackups();
      DebugConfig.db('autoBackup: rotation done');
      return destPath;
    } catch (e, s) {
      DebugConfig.error('BackupService.autoBackup', e, s);
      return null;
    }
  }

  /// E50: λίστα auto backups από **όλους** τους φακέλους (support + legacy),
  /// dedupe κατά basename. Το dual-read μένει **μόνιμο**: αποτυχία
  /// μετακίνησης/ανάγνωσης δεν εξαφανίζει τίποτα από το UI.
  Future<List<String>> listAutoBackups() async {
    try {
      return await BackupRotation.listIn(await _autoBackupRoots());
    } catch (e) {
      // E50: ποτέ σιωπηλό (SPoT: κανένα `catch (_)`).
      DebugConfig.warning('BackupService.listAutoBackups failed: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────────

  /// E50: ο **μόνιμος** φάκελος των auto backups —
  /// `getApplicationSupportDirectory()` (= `filesDir` στο Android: επιβιώνει
  /// σε «Εκκαθάριση cache» / OS purge). Fallback documents → temp, ώστε
  /// αστοχία του path_provider να μη σπάει τη ροή (best-effort, ποτέ crash).
  Future<Directory> _getAutoBackupDir() async {
    final dir = await _autoBackupSupportDir();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// E50: το root του μόνιμου φακέλου **χωρίς δημιουργία** — ώστε το startup
  /// sweep / η λίστα να μην αφήνουν άδειο φάκελο σε χρήστες χωρίς auto-backup.
  Future<Directory> _autoBackupSupportDir() async {
    Directory? root;
    try {
      root = await getApplicationSupportDirectory();
    } catch (e) {
      DebugConfig.warning('autoBackup: support dir unavailable: $e');
    }
    if (root == null) {
      try {
        // S-01: fallback στη ρίζα δεδομένων — ποτέ ξανά στα Documents.
        root = Directory(await AppPaths.activeDataRoot());
      } catch (e) {
        DebugConfig.warning('autoBackup: data root unavailable: $e');
      }
    }
    root ??= await getTemporaryDirectory();
    return Directory(p.join(root.path, autoBackupDirName));
  }

  /// E50: ο legacy φάκελος (cache, pre-E50). Μόνο για ανάγνωση/μετακίνηση.
  Future<Directory?> _getLegacyAutoBackupDir() async {
    try {
      final temp = await getTemporaryDirectory();
      return Directory(p.join(temp.path, autoBackupDirName));
    } catch (e) {
      DebugConfig.warning('autoBackup: legacy dir unavailable: $e');
      return null;
    }
  }

  /// E50: φάκελοι που βλέπει το UI/rotation — **νέος πρώτος** (κερδίζει στο
  /// dedupe του `listIn`), μετά ο legacy.
  Future<List<Directory>> _autoBackupRoots() async {
    final roots = <Directory>[await _autoBackupSupportDir()];
    final legacy = await _getLegacyAutoBackupDir();
    if (legacy != null) roots.add(legacy);
    return roots;
  }

  /// E50: μετακίνηση των legacy auto backups στον μόνιμο φάκελο — **μία φορά
  /// ανά process**, single-flight. Σκιπάρεται όσο maintenance είναι ενεργό
  /// (E33: κανένα νέο file op μέσα στο παράθυρο restore/wipe) και
  /// επαναλαμβάνεται στην επόμενη κλήση. Καλείται από το `sweepStaleArtifacts`
  /// (startup + μετά restore) — **ποτέ** από UI read.
  Future<void> _ensureLegacyAutoBackupsAdopted() async {
    if (_legacyAdoptDone) return;
    if (_maintenanceActive) {
      DebugConfig.db('adoptLegacy: maintenance active — skipping');
      return;
    }
    final inFlight = _legacyAdoptInFlight;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (e) {
        DebugConfig.warning('BackupService.adoptLegacy (join): $e');
      }
      return;
    }
    final future = _adoptLegacyImpl();
    _legacyAdoptInFlight = future;
    try {
      await future;
    } finally {
      _legacyAdoptInFlight = null;
    }
  }

  Future<void> _adoptLegacyImpl() async {
    try {
      final legacy = await _getLegacyAutoBackupDir();
      if (legacy == null || !await legacy.exists()) {
        _legacyAdoptDone = true;
        return;
      }
      final target = await _getAutoBackupDir();
      final r =
          await BackupRotation.adoptLegacy(target: target, legacy: legacy);
      _legacyAdoptDone = true;
      DebugConfig.db('adoptLegacy: done — moved=${r.moved} '
          'skipped=${r.skipped} failed=${r.failed}');
    } catch (e) {
      // Best-effort: δεν σηματοδοτείται done → retry στην επόμενη κλήση.
      DebugConfig.warning('BackupService.adoptLegacy: $e');
    }
  }

  /// E50: merged rotation (support + legacy) με **συνολικό** όριο
  /// (`maxAutoBackups`) — όχι 5 ανά φάκελο.
  Future<void> _rotateAutoBackups() async {
    try {
      await BackupRotation.rotateIn(await _autoBackupRoots(),
          max: maxAutoBackups);
    } catch (e) {
      DebugConfig.warning('BackupService.rotateAutoBackups: $e');
    }
  }

  /// S-02 (N6) + E50: καθαρισμός ημιτελών/εγκαταλελειμμένων temp artifacts και
  /// **μία φορά** adopt των legacy auto backups (cache → support).
  /// Καλείται στην εκκίνηση (postFrame) και μετά από κάθε restore
  /// (kill/force-stop δεν προλαβαίνει τα `finally`).
  Future<void> sweepStaleArtifacts() async {
    const prefixes = <String>[
      '_backup_export_',
      '_backup_share_',
      '_backup_zipval_',
      '_backup_validate_',
      '_restore_zip_',
      '_restore_prepare_',
      // E50: temp dir του auto-backup (plaintext zip — ζει μόνο στον cache).
      '_backup_auto_',
    ];
    var removed = 0;
    try {
      final tempRoot = await getTemporaryDirectory();
      if (await tempRoot.exists()) {
        await for (final e in tempRoot.list()) {
          final name = p.basename(e.path);
          if (!prefixes.any(name.startsWith)) continue;
          try {
            await e.delete(recursive: true);
            removed++;
          } catch (err) {
            DebugConfig.warning('sweepStaleArtifacts: delete failed: $err');
          }
        }
      }
    } catch (e) {
      DebugConfig.warning('sweepStaleArtifacts failed: $e');
    }
    // E50: adopt μία φορά (ποτέ σε maintenance) + partials σε όλους τους
    // φακέλους. Καμία δημιουργία φακέλου αν δεν υπάρχει.
    await _ensureLegacyAutoBackupsAdopted();
    try {
      removed +=
          await BackupRotation.sweepPartialsIn(await _autoBackupRoots());
    } catch (e) {
      DebugConfig.warning('sweepStaleArtifacts (auto backups) failed: $e');
    }
    DebugConfig.db('sweepStaleArtifacts: removed=$removed');
  }

  /// S-02: στάδιο 1 του import — decrypt → allowlist extract → probe/sanitize
  /// σε temp work dir, ΧΩΡΙΣ να αγγίξει η live DB (verify-before-open).
  ///
  /// S-307: streaming (χωρίς όρια μεγέθους) + πρόοδος + ακύρωση.
  Future<BackupPrepareResult> prepare(
    String backupPath, {
    String? passphrase,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) {
    final future = _prepareImpl(
      backupPath,
      passphrase,
      onProgress,
      isCancelled,
    );
    unawaited(_trackPrepare(future));
    return future;
  }

  Future<BackupPrepareResult> _prepareImpl(
    String backupPath,
    String? passphrase,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  ) async {
    DebugConfig.db('prepare: starting path=$backupPath');
    Directory? workDir;
    try {
      final file = File(backupPath);
      if (!await file.exists()) {
        return const BackupPrepareResult.failure(AppErrors.backupNotFound);
      }
      final size = await file.length();
      final format = await BackupContainer.detectFormat(backupPath);
      DebugConfig.db('prepare: format=${format.name} size=$size');
      if (format == BackupFormat.unknown) {
        return const BackupPrepareResult.failure(AppErrors.backupInvalid);
      }
      if (format == BackupFormat.isar) {
        if (size < 1024) {
          return const BackupPrepareResult.failure(
              'Το αρχείο backup είναι πολύ μικρό (πιθανά κατεστραμμένο)');
        }
      }

      // S-307: το plaintext μέγεθος έρχεται από το header (snb) ή το zip.
      var plaintextEstimate = size;
      if (format == BackupFormat.snb) {
        try {
          final header = await BackupContainer.readHeader(file);
          plaintextEstimate = header.plaintextLength;
          if (header.requiresPassphrase &&
              (passphrase == null || passphrase.isEmpty)) {
            return const BackupPrepareResult.failure(
                AppErrors.backupPassphraseRequired);
          }
        } on SnbFormatException catch (e) {
          return BackupPrepareResult.failure(e.message);
        }
      }

      final tempRoot = await getTemporaryDirectory();
      workDir = await Directory(p.join(tempRoot.path,
              '_restore_prepare_${DateTime.now().millisecondsSinceEpoch}'))
          .create(recursive: true);
      // Temp: payload + unpacked ≈ 2× plaintext (+ snapshot της βάσης).
      final noSpace = await _checkFreeSpace(
        workDir.path,
        plaintextEstimate * 2 + 32 * 1024 * 1024,
      );
      if (noSpace != null) {
        await _cleanupDir(workDir);
        return BackupPrepareResult.failure(noSpace.message);
      }
      final unpackDir = Directory(p.join(workDir.path, 'unpacked'));
      await unpackDir.create();

      late final File dbSource;
      var entries = 0;
      var attachments = 0;
      var plaintextBytes = size;
      var payloadFormat = format;

      if (format == BackupFormat.snb) {
        final payload = File(p.join(workDir.path, 'payload.zip'));
        try {
          plaintextBytes = await BackupContainer.decryptFileTo(
            source: file,
            destPath: payload.path,
            passphrase: passphrase,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        } on BackupAuthException {
          await _cleanupDir(workDir);
          return const BackupPrepareResult.failure(
              AppErrors.backupWrongPassphrase);
        } on SnbFormatException catch (e) {
          await _cleanupDir(workDir);
          return BackupPrepareResult.failure(e.message);
        }
        final names = await BackupArchive.extractBackupZip(
          payload.path,
          unpackDir.path,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        if (!names.contains(BackupArchive.dbEntryName)) {
          await _cleanupDir(workDir);
          return const BackupPrepareResult.failure(
              'Το αντίγραφο δεν περιέχει βάση δεδομένων');
        }
        entries = names.length;
        dbSource = File(p.join(unpackDir.path, BackupArchive.dbEntryName));
        await _deleteFileSilently(payload);
        payloadFormat = BackupFormat.zip;
      } else if (format == BackupFormat.zip) {
        final names = await BackupArchive.extractBackupZip(
          backupPath,
          unpackDir.path,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        if (!names.contains(BackupArchive.dbEntryName)) {
          await _cleanupDir(workDir);
          return const BackupPrepareResult.failure(
              'Το zip δεν περιέχει βάση δεδομένων');
        }
        entries = names.length;
        dbSource = File(p.join(unpackDir.path, BackupArchive.dbEntryName));
      } else {
        final copy = File(p.join(unpackDir.path, BackupArchive.dbEntryName));
        await file.copy(copy.path);
        dbSource = copy;
        entries = 1;
      }

      // Probe + strip lock/lockout + consistent snapshot (S-02).
      onProgress?.call(const BackupProgress(BackupPhase.verify, 0, 0));
      final snapshotPath = p.join(workDir.path, 'restore_db.isar');
      final sanitize = await BackupDbProbe.openSanitizeAndSnapshot(
        dbFile: dbSource,
        workDir: workDir,
        destSnapshotPath: snapshotPath,
      );
      if (sanitize == null) {
        await _cleanupDir(workDir);
        return const BackupPrepareResult.failure(AppErrors.backupInvalid);
      }

      final attDir =
          Directory(p.join(unpackDir.path, BackupArchive.attachmentsPrefix));
      if (payloadFormat != BackupFormat.isar && await attDir.exists()) {
        await for (final e in attDir.list()) {
          if (e is File) attachments++;
        }
      }

      DebugConfig.db('prepare: OK entries=$entries attachments=$attachments '
          'strippedLock=${sanitize.strippedAppLock}');
      return BackupPrepareResult.success(PreparedRestore(
        format: payloadFormat,
        workDir: workDir,
        dbFile: File(snapshotPath),
        attachmentsDir: payloadFormat == BackupFormat.isar ? null : attDir,
        entryCount: entries,
        attachmentCount: attachments,
        plaintextBytes: plaintextBytes,
        strippedAppLock: sanitize.strippedAppLock,
      ));
    } on BackupCancelledException {
      DebugConfig.db('prepare: cancelled by user');
      await _cleanupDir(workDir);
      return const BackupPrepareResult.cancelled();
    } on BackupSpaceException catch (e) {
      await _cleanupDir(workDir);
      return BackupPrepareResult.failure(e.message);
    } catch (e, s) {
      DebugConfig.error('BackupService.prepare', e, s);
      await _cleanupDir(workDir);
      return BackupPrepareResult.failure('Σφάλμα επικύρωσης: $e');
    }
  }

  /// Πετάει τα temp artifacts ενός prepare που δεν θα χρησιμοποιηθεί.
  Future<void> discardPrepared(PreparedRestore prepared) =>
      _cleanupDir(prepared.workDir);

  /// Στάδιο 2: atomic restore από έτοιμο (και sanitized) prepare.
  Future<BackupImportResult> restorePrepared(
    PreparedRestore prepared, {
    BackupProgressCallback? onProgress,
  }) async {
    DebugConfig.db('restorePrepared: starting format=${prepared.format.name}');
    onProgress?.call(const BackupProgress(BackupPhase.restore, 0, 0));
    final result = await _atomicRestoreDb(prepared);
    if (result.success) {
      DebugConfig.db('restorePrepared: SUCCESS — '
          'restartRequired=${result.restartRequired}');
    } else {
      DebugConfig.warning('restorePrepared: FAILED — '
          'restartRequired=${result.restartRequired} error=${result.error}');
    }
    onProgress?.call(const BackupProgress(BackupPhase.restore, 1, 1));
    await sweepStaleArtifacts();
    return result;
  }

  /// Legacy-compatible validation (χωρίς UI). Πλέον είναι «prepare + discard».
  Future<ValidationResult> validateBackupFile(String path,
      {String? passphrase}) async {
    DebugConfig.db('validateBackupFile: validating path=$path');
    final prep = await prepare(path, passphrase: passphrase);
    if (!prep.success) {
      return ValidationResult(valid: false, reason: prep.error);
    }
    final size = prep.prepared!.plaintextBytes;
    await discardPrepared(prep.prepared!);
    DebugConfig.db('validateBackupFile: VALID (size=$size)');
    return ValidationResult(valid: true, sizeBytes: size);
  }

  Future<void> _cleanupDir(Directory? dir) async {
    if (dir == null) return;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      DebugConfig.warning('BackupService: temp dir cleanup failed: $e');
    }
  }

  Future<void> _deleteFileSilently(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      DebugConfig.warning('BackupService: temp file cleanup failed: $e');
    }
  }

  /// Ενιαίο atomic restore από έτοιμο (ελεγμένο + sanitized) [prepared].
  ///
  /// E33: πριν κλείσει η DB → beginDbMaintenance() (gates + drain 65s).
  /// Αποτυχία drain → abort ΧΩΡΙΣ close· το begin έχει ήδη κάνει resume.
  /// Safety DB με copyToFile (consistent snapshot), attachments με rename.
  /// Μετά το close ΔΕΝ κάνουμε resume — success ή failure → restartRequired.
  Future<BackupImportResult> _atomicRestoreDb(PreparedRestore prepared) async {
    final isZip = prepared.format != BackupFormat.isar;
    DebugConfig.db('_atomicRestoreDb: starting format=${prepared.format.name}');
    // S-01: η restore γράφει στη ρίζα που χρησιμοποιείται τώρα.
    final dbDir = await AppPaths.activeDataRoot();
    final livePath = p.join(dbDir, dbFileName);
    final safetyPath = p.join(dbDir, '_pre_restore_backup.isar');
    final attLive =
    Directory(p.join(dbDir, AttachmentService.attachmentsDirName));
    final attSafety =
    Directory(p.join(dbDir, '_pre_restore_attachments'));

    var maintenanceStarted = false;
    var dbTouched = false;
    var dbClosed = false;
    var liveExistedBefore = false;
    var attPhaseStarted = false;
    var hadLiveAttachments = false;
    var attSafetyTaken = false;

    try {
      // 1) Η πηγή είναι ήδη ελεγμένη (probe) και sanitized (strip lock).
      final dbSrc = prepared.dbFile;
      if (!await dbSrc.exists()) {
        throw Exception('Το έτοιμο αντίγραφο δεν βρέθηκε');
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

        // 5) Αντικατάσταση live DB (πάντα copy από το sanitized snapshot).
        await dbSrc.copy(livePath);

        // 6) Attachments (zip/snb) — μετά το close, για καθαρό pre-close abort.
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
          final srcAttDir = prepared.attachmentsDir;
          var moved = 0;
          if (srcAttDir != null && await srcAttDir.exists()) {
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
      // S-02: το work dir του prepare περιέχει plaintext DB/attachments —
      // καθαρίζεται ΠΑΝΤΑ (και μετά από abort).
      await _cleanupDir(prepared.workDir);
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
