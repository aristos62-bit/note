// lib/services/attachment_service.dart
// ═══════════════════════════════════════════════════════════════
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../helpers/super_note_helper.dart';
import '../models/attachment.dart';
import '../core/utils/app_errors.dart';
import '../core/utils/app_paths.dart';
import '../core/utils/attachment_path_guard.dart';
import '../core/utils/debug_config.dart';
import '../core/utils/string_utils.dart';

class AttachmentService {
  AttachmentService._internal();
  static final AttachmentService instance = AttachmentService._internal();

  /// Υποφάκελος attachments μέσα στο app data root (κοινό const για backup).
  /// SPoT του ονόματος: `AttachmentPathGuard.dirName` (S-18).
  static const String attachmentsDirName = AttachmentPathGuard.dirName;

  Future<Attachment?> pickAndSave({
    required int itemId,
    int? blockId,
    List<String>? allowedExtensions,
    int? maxSizeBytes,
  }) async {
    DebugConfig.db('pickAndSave itemId=$itemId extensions=$allowedExtensions maxBytes=$maxSizeBytes');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      if (file.path == null) return null;

      // E09: το `PlatformFile.size` είναι 0 όταν ο provider δεν το δίνει
      // (content-URI) → θα περνούσε το όριο. Παίρνουμε το πραγματικό μέγεθος.
      var actualSize = file.size;
      try {
        actualSize = await File(file.path!).length();
      } catch (e) {
        DebugConfig.warning(
            'pickAndSave: actual size fallback (file.size=$actualSize): $e');
      }

      if (maxSizeBytes != null && actualSize > maxSizeBytes) {
        throw FormatException(
          AppErrors.attachTooLarge((maxSizeBytes / 1048576).round()),
        );
      }

      final cleanName = AppStringUtils.sanitizeFileName(file.name);
      if (cleanName != file.name) {
        DebugConfig.db('pickAndSave sanitize: ${AppStringUtils.redact(file.name, label: 'file')} → ${AppStringUtils.redact(cleanName, label: 'file')}');
      }

      // Dedupe ΜΟΝΟ ανά item (E09/D5β): ίδιο αρχείο σε άλλο item
      // δημιουργεί νέο αντίγραφο — μηδέν κοινά localPath.
      final existing = await SuperNoteHelper.instance.attachments.findDuplicate(
        itemId: itemId,
        fileName: cleanName,
        fileSize: actualSize,
      );
      if (existing != null) {
        DebugConfig.db('pickAndSave duplicate ${AppStringUtils.redact(file.name, label: 'file')} ($actualSize bytes) → reusing id=${existing.id} (same item)');
        return existing;
      }

      return await saveFile(
        itemId: itemId,
        sourcePath: file.path!,
        blockId: blockId,
      );
    } catch (e, stack) {
      DebugConfig.error('[AttachmentService] pickAndSave failed', e, stack);
      rethrow;
    }
  }

  Future<Attachment> saveFile({
    required int itemId,
    required String sourcePath,
    int? blockId,
  }) async {
    String? destPath;
    try {
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        throw Exception('Το αρχείο δεν βρέθηκε: $sourcePath');
      }

      final originalName = p.basename(sourcePath);
      final fileName = AppStringUtils.sanitizeFileName(originalName);
      if (fileName != originalName) {
        DebugConfig.db('saveFile sanitize: ${AppStringUtils.redact(originalName, label: 'file')} → ${AppStringUtils.redact(fileName, label: 'file')}');
      }
      final mimeType = lookupMimeType(sourcePath) ?? 'application/octet-stream';
      final fileSize = await sourceFile.length();

      final destDir = await _getAttachmentsDir();
      destPath = p.join(
        destDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );
      await sourceFile.copy(destPath);

      DebugConfig.db('saveFile: stored fileName=${AppStringUtils.redact(fileName, label: 'file')} path=${AppStringUtils.redact(destPath, label: 'path')} size=$fileSize');
      return await SuperNoteHelper.instance.attachments.create(
        itemId: itemId,
        blockId: blockId,
        fileName: fileName,
        localPath: destPath,
        mimeType: mimeType,
        fileSize: fileSize,
      );
    } catch (e, stack) {
      DebugConfig.error('[AttachmentService] saveFile failed', e, stack);
      // Αν το αντίγραφο έγινε αλλά η DB απέτυχε, καθάρισε το orphan αρχείο
      if (destPath != null) {
        try {
          final orphan = File(destPath);
          if (await orphan.exists()) await orphan.delete();
        } catch (e, stack) {
          DebugConfig.error(
              '[AttachmentService] orphan cleanup failed (continuing)', e, stack);
        }
      }
      rethrow;
    }
  }

  Future<void> delete(int attachmentId) async {
    try {
      final repo = SuperNoteHelper.instance.attachments;
      final attachment = await repo.getById(attachmentId);
      if (attachment == null) return;

      // 1) DB-first (E09): αν αποτύχει, το αρχείο μένει — δεν χάνονται δεδομένα.
      await repo.delete(attachmentId);

      // 2) Disk — μόνο αν καμία άλλη γραμμή δεν δείχνει το ίδιο αρχείο
      //    (legacy rows πριν το per-item dedupe).
      try {
        final refs = await repo.countByLocalPath(attachment.localPath);
        if (refs > 0) {
          DebugConfig.db(
              '[AttachmentService] keep shared file (refs=$refs) id=$attachmentId');
          return;
        }
        final safePath = AttachmentPathGuard.resolve(attachment.localPath);
        if (safePath == null) {
          DebugConfig.warning(
              '[AttachmentService] file outside attachments root — skipped (id=$attachmentId)');
          return;
        }
        final file = File(safePath);
        if (await file.exists()) await file.delete();
      } catch (e, stack) {
        DebugConfig.error(
            '[AttachmentService] disk delete failed (continuing)', e, stack);
      }
    } catch (e, stack) {
      DebugConfig.error('[AttachmentService] delete failed', e, stack);
      rethrow;
    }
  }

  /// Άνοιγμα συνημμένου με την εφαρμογή του συστήματος (S-16/1β, S-25).
  /// Επιστρέφει `null` σε επιτυχία, αλλιώς μήνυμα [AppErrors].
  /// Το path περνά ΠΑΝΤΑ από [AttachmentPathGuard] (fail-closed).
  /// S-25: εκτελέσιμος τύπος (Windows) → [AppErrors.attachOpenBlocked], εκτός
  /// αν ο caller έχει ρητή επιβεβαίωση (`allowRisky: true`). Το μήνυμα δεν
  /// εμφανίζεται από την τρέχουσα UI (το `openAttachment` ρωτά πρώτα) — μένει
  /// ως δικτυωμένη ασφάλεια για μελλοντικούς callers.
  Future<String?> open(Attachment attachment,
      {bool allowRisky = false}) async {
    final safePath = AttachmentPathGuard.resolve(attachment.localPath);
    if (safePath == null) return AppErrors.attachNotFound;
    if (!allowRisky && AttachmentPathGuard.isRiskyToLaunch(safePath)) {
      DebugConfig.warning('open: risky type blocked id=${attachment.id}');
      return AppErrors.attachOpenBlocked;
    }
    if (!await File(safePath).exists()) {
      DebugConfig.db('open: file not found id=${attachment.id}');
      return AppErrors.attachNotFound;
    }
    try {
      if (Platform.isWindows) {
        // S-16: ShellExecuteW μέσω url_launcher — χωρίς cmd/command line.
        final ok = await launchUrl(
          Uri.file(safePath),
          mode: LaunchMode.externalApplication,
        );
        DebugConfig.db('open (windows): launched=$ok id=${attachment.id}');
        return ok ? null : AppErrors.attachOpenFailed;
      }
      final result = await OpenFilex.open(safePath);
      if (result.type != ResultType.done) {
        DebugConfig.db('open failed: ${result.type} id=${attachment.id}');
        return AppErrors.attachOpenFailed;
      }
      return null;
    } catch (e, stack) {
      // Ποτέ το exception object: μπορεί να περιέχει path.
      DebugConfig.error(
          '[AttachmentService] open failed (${e.runtimeType})', null, stack);
      return AppErrors.attachOpenFailed;
    }
  }

  Future<Directory> _getAttachmentsDir() async {
    try {
      final root = await AppPaths.activeDataRoot();
      final dir = Directory(p.join(root, attachmentsDirName));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (e, stack) {
      DebugConfig.error('[AttachmentService] _getAttachmentsDir failed', e, stack);
      rethrow;
    }
  }
}