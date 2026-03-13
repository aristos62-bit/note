// lib/models/relation.dart
import 'package:isar/isar.dart';
part 'relation.g.dart';

// ─────────────────────────────────────────────────────────────────
// Τύποι σχέσεων μεταξύ items
// ─────────────────────────────────────────────────────────────────
enum RelationType {
  /// Project → Task (parent → child hierarchy)
  parent,
  child,

  /// Γενική σύνδεση
  related,

  /// Task A μπλοκάρει Task B (για project management)
  blocks,
  blockedBy,

  /// Αναφορά (π.χ. σημείωση αναφέρει επαφή)
  references,

  /// Αντίγραφο / clone
  duplicate,

  /// Σχετίζεται με (goal → habit, project → notes)
  linkedTo,
}

@Collection()
class Relation {
  Id id = Isar.autoIncrement;

  /// Το item που ξεκινά τη σχέση
  @Index(composite: [CompositeIndex('toItemId')])
  late int fromItemId;

  @Index()
  late int toItemId;

  /// Ο τύπος της σχέσης
  @Enumerated(EnumType.name)
  late RelationType relationType;

  /// Optional σημείωση για τη σχέση
  String? note;

  DateTime createdAt = DateTime.now();
}