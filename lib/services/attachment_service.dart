// lib/services/attachment_service.dart
// ═══════════════════════════════════════════════════════════════
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../helpers/super_note_helper.dart';
import '../models/attachment.dart';
import '../core/utils/debug_config.dart';
import '../core/utils/string_utils.dart';

class AttachmentService {
  AttachmentService._internal();
  static final AttachmentService instance = AttachmentService._internal();

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

      if (maxSizeBytes != null && file.size > maxSizeBytes) {
        throw FormatException(
          'Το αρχείο υπερβαίνει το όριο των ${(maxSizeBytes / 1048576).toStringAsFixed(0)}MB',
        );
      }

      final cleanName = AppStringUtils.sanitizeFileName(file.name);
      if (cleanName != file.name) {
        DebugConfig.db('pickAndSave sanitize: "${file.name}" → "$cleanName"');
      }

      final existing = await SuperNoteHelper.instance.attachments.findDuplicate(
        itemId: itemId,
        fileName: cleanName,
        fileSize: file.size,
      );
      if (existing != null) {
        if (existing.itemId == itemId) {
          DebugConfig.db('pickAndSave duplicate "${file.name}" (${file.size} bytes) → reusing id=${existing.id} (same item)');
          return existing;
        }
        DebugConfig.db('pickAndSave duplicate "${file.name}" (${file.size} bytes) → creating new record for itemId=$itemId');
        return await SuperNoteHelper.instance.attachments.create(
          itemId: itemId,
          blockId: blockId,
          fileName: cleanName,
          localPath: existing.localPath,
          mimeType: existing.mimeType,
          fileSize: file.size,
        );
      }

      return await saveFile(
        itemId: itemId,
        sourcePath: file.path!,
        blockId: blockId,
      );
    } catch (e) {
      debugPrint('[AttachmentService] pickAndSave failed: $e');
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
        DebugConfig.db('saveFile sanitize: "$originalName" → "$fileName"');
      }
      final mimeType = lookupMimeType(sourcePath) ?? 'application/octet-stream';
      final fileSize = await sourceFile.length();

      final destDir = await _getAttachmentsDir();
      destPath = p.join(
        destDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );
      await sourceFile.copy(destPath);

      DebugConfig.db('saveFile: stored fileName="$fileName" path="$destPath" size=$fileSize');
      return await SuperNoteHelper.instance.attachments.create(
        itemId: itemId,
        blockId: blockId,
        fileName: fileName,
        localPath: destPath,
        mimeType: mimeType,
        fileSize: fileSize,
      );
    } catch (e) {
      debugPrint('[AttachmentService] saveFile failed: $e');
      // Αν το αντίγραφο έγινε αλλά η DB απέτυχε, καθάρισε το orphan αρχείο
      if (destPath != null) {
        try {
          final orphan = File(destPath);
          if (await orphan.exists()) await orphan.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> delete(int attachmentId) async {
    try {
      final attachment = await SuperNoteHelper.instance.attachments
          .getById(attachmentId);
      if (attachment == null) return;

      // Διέγραψε από disk — μη σταματάς αν αποτύχει (file ήδη missing)
      try {
        final file = File(attachment.localPath);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('[AttachmentService] disk delete failed (continuing): $e');
      }

      // Διέγραψε από DB — αυτό πρέπει να πετύχει
      await SuperNoteHelper.instance.attachments.delete(attachmentId);
    } catch (e) {
      debugPrint('[AttachmentService] delete failed: $e');
      rethrow;
    }
  }

  Future<Directory> _getAttachmentsDir() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'attachments'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (e) {
      debugPrint('[AttachmentService] _getAttachmentsDir failed: $e');
      rethrow;
    }
  }
}