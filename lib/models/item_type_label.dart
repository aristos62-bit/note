// lib/models/item_type_label.dart
//
// SPoT για τα ελληνικά ονόματα των ItemTypes (Φ4a βήμα 7).
// Ενοποιεί 3 πηγές που ΔΙΑΦΩΝΟΥΣΑΝ (labelFor / settings _itemTypeLabel /
// AppStringUtils.itemTypeLabel): μία λίστα, 0 κύκλοι (models ← isar μόνο).
//
// Αποφάσεις (code_refactor §7): Ραντεβού (τόνος), project/knowledge → Συλλογή.
// Public API παραμένει το `ItemTypeIcon.labelFor` — όλοι το καλούν.
//
// ΧΡΗΣΗ:
//   ItemTypeIcon.labelFor(ItemType.note)  // 'Σημείωση'
//   AppStringUtils.itemTypeLabel('note')  // 'Σημείωση'
//
import 'item.dart';

extension ItemTypeX on ItemType {
  /// Ελληνικό όνομα τύπου (singular, για κάρτες/pickers).
  String get labelGr {
    switch (this) {
      case ItemType.note:
        return 'Σημείωση';
      case ItemType.task:
        return 'Εργασία';
      case ItemType.event:
        return 'Συμβάν';
      case ItemType.contact:
        return 'Επαφή';
      case ItemType.habit:
        return 'Συνήθεια';
      case ItemType.project:
        return 'Συλλογή';
      case ItemType.goal:
        return 'Στόχος';
      case ItemType.finance:
        return 'Οικονομικά';
      case ItemType.bookmark:
        return 'Σελιδοδείκτης';
      case ItemType.journal:
        return 'Ημερολόγιο';
      case ItemType.appointment:
        return 'Ραντεβού';
      case ItemType.checklist:
        return 'Λίστα';
      case ItemType.knowledge:
        return 'Συλλογή';
    }
  }
}
