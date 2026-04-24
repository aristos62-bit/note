// lib/models/folder.dart
import 'package:isar/isar.dart';
part 'folder.g.dart';

@Collection()
class Folder {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  String? icon;
  String? color;

  @Index()
  late int workspaceId;

  int? parentFolderId;

  @Index()   // ← ΠΡΟΣΘΗΚΗ
  double sortOrder = 0.0;

  bool isDefault = false;

  // ✅ ΝΕΟ ΠΕΔΙΟ – προστασία από διαγραφή
  bool isSystem = false;

  DateTime createdAt = DateTime.now();
  DateTime? updatedAt;

  int localVersion = 0;
  bool isDirty = true;
}