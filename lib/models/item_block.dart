// lib/models/item_block.dart
import 'package:isar/isar.dart';
part 'item_block.g.dart';

// ─────────────────────────────────────────────────────────────────
// Enum για τον τύπο κάθε block
// ─────────────────────────────────────────────────────────────────
enum BlockType {
  text,       // Απλό κείμενο
  heading1,   // Τίτλος H1
  heading2,   // Τίτλος H2
  heading3,   // Τίτλος H3
  checklist,  // ✅ Checklist item
  bulletList, // • Bullet list
  numbered,   // 1. Numbered list
  image,      // 📷 Εικόνα
  file,       // 📎 Αρχείο
  link,       // 🔗 Link
  quote,      // 💬 Blockquote
  code,       // 💻 Code block
  divider,    // ─── Διαχωριστής
  table,      // 📊 Πίνακας (JSON data στο metadata)
  bookmark,   // 🔖 Web bookmark με preview
  callout,    // 💡 Callout/highlight box
  toggle,     // ▶ Collapsible toggle
  embed,      // 🌐 Embedded content (YouTube, maps κλπ.)
  mention,    // @ Mention άλλου item
  formula,    // ∑ Math formula (LaTeX)
}

// ─────────────────────────────────────────────────────────────────
// ItemBlock Collection
// ─────────────────────────────────────────────────────────────────

@Collection()
class ItemBlock {
  Id id = Isar.autoIncrement;

  /// Ποιο item ανήκει αυτό το block
  @Index()
  late int itemId;

  /// Για nested blocks (π.χ. toggle children, table cells)
  int? parentBlockId;

  /// Ο τύπος του block
  @Enumerated(EnumType.name)
  late BlockType type;

  // ─── Content fields ─────────────────────────────────────

  /// Κείμενο (για text, heading, quote, code, formula κλπ.)
  String? text;

  /// Για checklist items: checked ή όχι
  bool checked = false;

  /// URL (για link, bookmark, embed)
  String? url;

  /// Για attachments/images (local path)
  String? filePath;

  // ─── Ordering ───────────────────────────────────────────
  /// double για εύκολο reordering
  @Index()
  double order = 0.0;

  // ─── Metadata (JSON string) ─────────────────────────────
  /// Extra data σε JSON format:
  /// - Image: {"width": 800, "height": 600, "caption": "..."}
  /// - File: {"size": 1024, "mimeType": "application/pdf", "name": "doc.pdf"}
  /// - Table: {"columns": [...], "rows": [...]}
  /// - Bookmark: {"title": "...", "description": "...", "thumbnail": "..."}
  /// - Code: {"language": "dart"}
  /// - Callout: {"emoji": "💡", "color": "#FFF9C4"}
  String? metadata;

  // ─── Timestamps ─────────────────────────────────────────
  DateTime createdAt = DateTime.now();
  DateTime? updatedAt;

  // ─── Sync ───────────────────────────────────────────────
  int localVersion = 0;
  bool isDirty = true;
}