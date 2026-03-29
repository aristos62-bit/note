// lib/models/item.dart
//
// ΣΗΜΑΝΤΙΚΟ: Μετά από οποιαδήποτε αλλαγή σε αυτό το αρχείο, τρέξε:
//   flutter pub run build_runner build --delete-conflicting-outputs
//
import 'package:isar/isar.dart';
part 'item.g.dart';

// ─────────────────────────────────────────────────────────────────
// Enums για type-safety
// ─────────────────────────────────────────────────────────────────

/// Ο τύπος κάθε Item. Όλα τα objects της εφαρμογής είναι Items.
enum ItemType {
  note,
  task,
  event,
  contact,
  habit,
  project,
  goal,
  finance,
  bookmark,
  journal,
  appointment,
  checklist,
  knowledge,
}

/// Η κατάσταση ενός Item.
enum ItemStatus {
  active,
  done,
  cancelled,
  archived,
  draft,
  inProgress,
}

/// Η προτεραιότητα ενός Item.
enum ItemPriority {
  none,   // 0
  low,    // 1
  medium, // 2
  high,   // 3
  urgent, // 4
}

// ─────────────────────────────────────────────────────────────────
// Item Collection
// ─────────────────────────────────────────────────────────────────

@Collection()
class Item {
  /// Auto-increment ID από Isar
  Id id = Isar.autoIncrement;

  /// Ποιο workspace ανήκει (multi-workspace support)
  @Index()
  late int workspaceId;

  /// Ποιο folder ανήκει (optional)
  @Index()
  int? folderId;

  /// Ο τύπος του item (note, task, event κλπ.)
  @Index()
  @Enumerated(EnumType.name)
  late ItemType type;

  /// Τίτλος
  @Index(type: IndexType.value, caseSensitive: false)
  String? title;

  /// Emoji ή icon identifier
  String? icon;

  /// Hex color (π.χ. "#FF5733")
  String? color;

  // ─── Flags ──────────────────────────────────────────────
  @Index()
  bool pinned = false;

  @Index()
  bool archived = false;

  bool favorite = false;

  // ─── Priority & Status ──────────────────────────────────
  @Enumerated(EnumType.ordinal)
  ItemPriority priority = ItemPriority.none;

  @Index()
  @Enumerated(EnumType.name)
  ItemStatus status = ItemStatus.active;

  // ─── Ordering ───────────────────────────────────────────
  /// double για να μπορούμε να βάλουμε 1.5 ανάμεσα σε 1 και 2
  /// χωρίς να ξαναγράψουμε όλα τα records
  double sortOrder = 0.0;

  // ─── Template ───────────────────────────────────────────
  /// Αν αυτό το item δημιουργήθηκε από template, εδώ είναι το ID
  int? templateId;

  // ─── Timestamps ─────────────────────────────────────────
  @Index()
  DateTime createdAt = DateTime.now();

  DateTime? updatedAt;

  /// Soft delete: δεν διαγράφουμε ποτέ hard
  DateTime? deletedAt;

  // ─── Sync fields (για multi-device) ─────────────────────
  DateTime? syncedAt;

  /// Αυξάνεται με κάθε local αλλαγή (optimistic locking)
  int localVersion = 0;

  /// Η έκδοση που έχει ο server
  int? serverVersion;

  /// true = έχει αλλαγές που δεν έχουν sync-αριστεί
  @Index()
  bool isDirty = true;

  // ─── Computed helpers ───────────────────────────────────
  /// Ελέγχει αν το item είναι soft-deleted
  bool get isDeleted => deletedAt != null;

  /// Ελέγχει αν το item είναι ορατό (δεν είναι deleted ή archived)
  bool get isVisible => deletedAt == null && !archived;
}