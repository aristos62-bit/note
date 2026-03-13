// lib/models/tag.dart
// TODO: Σελίδα προς Ανάπτυξη
import 'package:isar/isar.dart';
part 'tag.g.dart';

@Collection()
class Tag {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  String? color;
  String? icon;

  @Index()
  late int workspaceId;

  int usageCount = 0;

  DateTime createdAt = DateTime.now();
}