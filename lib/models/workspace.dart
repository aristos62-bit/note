// lib/models/workspace.dart
// TODO: Σελίδα προς Ανάπτυξη
import 'package:isar/isar.dart';
part 'workspace.g.dart';

@Collection()
class Workspace {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  String? icon;
  String? color;
  String? description;

  bool isDefault = false;

  @Index()
  double sortOrder = 0.0;

  DateTime createdAt = DateTime.now();
  DateTime? updatedAt;

  int localVersion = 0;
  bool isDirty = true;
}