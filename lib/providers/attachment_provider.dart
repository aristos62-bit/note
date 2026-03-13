// lib/providers/attachment_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attachment.dart';
import 'db_provider.dart';

/// Attachments ενός item
final attachmentsProvider =
FutureProvider.family<List<Attachment>, int>((ref, itemId) {
  return ref.watch(dbProvider).attachments.getForItem(itemId);
});

class AttachmentNotifier
    extends FamilyAsyncNotifier<List<Attachment>, int> {
  @override
  Future<List<Attachment>> build(int arg) {
    return ref.watch(dbProvider).attachments.getForItem(arg);
  }

  Future<void> add({
    required String fileName,
    required String localPath,
    required String mimeType,
    required int fileSize,
    int? blockId,
    String? thumbnailPath,
    int? width,
    int? height,
  }) async {
    await ref.read(dbProvider).attachments.create(
      itemId: arg,
      fileName: fileName,
      localPath: localPath,
      mimeType: mimeType,
      fileSize: fileSize,
      blockId: blockId,
      thumbnailPath: thumbnailPath,
      width: width,
      height: height,
    );
    ref.invalidateSelf();
  }

  Future<void> delete(int attachmentId) async {
    await ref.read(dbProvider).attachments.delete(attachmentId);
    ref.invalidateSelf();
  }
}

final attachmentNotifierProvider =
AsyncNotifierProviderFamily<AttachmentNotifier, List<Attachment>, int>(
  AttachmentNotifier.new,
);