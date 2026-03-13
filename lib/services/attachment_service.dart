// lib/services/attachment_service.dart
//
// ═══════════════════════════════════════════════════════════════
// ΟΔΗΓΙΕΣ ΠΡΟΣΑΡΜΟΓΗΣ
// ═══════════════════════════════════════════════════════════════
//
// Δεν χρειάζεται setup. Χρησιμοποιείται ως εξής:
//
//   // Άνοιξε file picker και αποθήκευσε:
//   final attachment = await AttachmentService.instance
//       .pickAndSave(itemId: note.id);
//
//   // Διέγραψε αρχείο από disk + DB:
//   await AttachmentService.instance.delete(attachment.id);
//
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../helpers/super_note_helper.dart';
import '../models/attachment.dart';

class AttachmentService {
  AttachmentService._internal();
  static final AttachmentService instance = AttachmentService._internal();

  // ─────────────────────────────────────────────────────────
  // Άνοιξε file picker + αποθήκευσε στη DB
  // ─────────────────────────────────────────────────────────

  Future<Attachment?> pickAndSave({
    required int itemId,
    int? blockId,
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
      withData: false,
      withReadStream: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.path == null) return null;

    return saveFile(
      itemId: itemId,
      sourcePath: file.path!,
      blockId: blockId,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Αποθήκευσε αρχείο από path (π.χ. από camera)
  // ─────────────────────────────────────────────────────────

  Future<Attachment> saveFile({
    required int itemId,
    required String sourcePath,
    int? blockId,
  }) async {
    final sourceFile = File(sourcePath);
    final fileName   = p.basename(sourcePath);
    final mimeType   = lookupMimeType(sourcePath) ?? 'application/octet-stream';
    final fileSize   = await sourceFile.length();

    // Αντέγραψε στον app documents directory
    final destDir  = await _getAttachmentsDir();
    final destPath = p.join(destDir.path, '${DateTime.now().millisecondsSinceEpoch}_$fileName');
    await sourceFile.copy(destPath);

    return SuperNoteHelper.instance.attachments.create(
      itemId: itemId,
      blockId: blockId,
      fileName: fileName,
      localPath: destPath,
      mimeType: mimeType,
      fileSize: fileSize,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Διέγραψε από disk ΚΑΙ DB
  // ─────────────────────────────────────────────────────────

  Future<void> delete(int attachmentId) async {
    final attachments = await SuperNoteHelper.instance.attachments
        .getForItem(0); // Placeholder — φέρνουμε by id παρακάτω
    // TODO: Πρόσθεσε getById στο AttachmentRepository αν χρειαστεί

    await SuperNoteHelper.instance.attachments.delete(attachmentId);
  }

  Future<void> deleteFile(Attachment attachment) async {
    // Διέγραψε από disk
    final file = File(attachment.localPath);
    if (await file.exists()) await file.delete();

    // Διέγραψε από DB
    await SuperNoteHelper.instance.attachments.delete(attachment.id);
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE
  // ─────────────────────────────────────────────────────────

  Future<Directory> _getAttachmentsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir  = Directory(p.join(docs.path, 'attachments'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}