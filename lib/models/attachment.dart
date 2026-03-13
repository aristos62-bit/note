// lib/models/attachment.dart
// TODO: Σελίδα προς Ανάπτυξη
import 'package:isar/isar.dart';
part 'attachment.g.dart';

@Collection()
class Attachment {
  Id id = Isar.autoIncrement;

  @Index()
  late int itemId;

  int? blockId;

  late String fileName;
  late String localPath;

  String? remoteUrl;

  late String mimeType;
  late int fileSize;

  String? thumbnailPath;

  int? width;
  int? height;
  int? durationSeconds;

  DateTime createdAt = DateTime.now();

  bool isUploaded = false;
  DateTime? uploadedAt;
  bool isDirty = true;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');

  String get readableSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}