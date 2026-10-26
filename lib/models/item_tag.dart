// lib/models/item_tag.dart
import 'package:isar/isar.dart';
part 'item_tag.g.dart';

@Collection()
class ItemTag {
  Id id = Isar.autoIncrement;

  @Index()
  late int itemId;

  @Index()
  late int tagId;

  DateTime createdAt = DateTime.now();
}