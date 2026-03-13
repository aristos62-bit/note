// lib/services/search_service.dart
//
// ═══════════════════════════════════════════════════════════════
// ΟΔΗΓΙΕΣ ΠΡΟΣΑΡΜΟΓΗΣ
// ═══════════════════════════════════════════════════════════════
//
// Δεν χρειάζεται setup. Χρησιμοποιείται απευθείας στο UI:
//
//   // Στο SearchScreen:
//   final results = await SearchService.instance.search(
//     query: 'flutter',
//     workspaceId: activeWorkspaceId,
//   );
//
// Για reactive search (καθώς ο χρήστης πληκτρολογεί):
//   Χρησιμοποίησε debounce 300ms πριν καλέσεις το search
//   για να μην κάνεις query σε κάθε γράμμα.
//
// ═══════════════════════════════════════════════════════════════

import '../helpers/super_note_helper.dart';
import '../models/item.dart';
import '../models/item_block.dart';

// Αποτέλεσμα αναζήτησης — περιέχει το item και πού βρέθηκε
class SearchResult {
  final Item item;
  final SearchMatchType matchType;
  final String? matchedText; // Το κείμενο που ταίριαξε (για highlight)

  const SearchResult({
    required this.item,
    required this.matchType,
    this.matchedText,
  });
}

enum SearchMatchType {
  title,    // Βρέθηκε στον τίτλο
  content,  // Βρέθηκε στο περιεχόμενο (blocks)
  property, // Βρέθηκε σε property (π.χ. phone, email)
  tag,      // Βρέθηκε σε tag
}

class SearchService {
  SearchService._internal();
  static final SearchService instance = SearchService._internal();

  // ─────────────────────────────────────────────────────────
  // ΚΥΡΙΑ ΜΕΘΟΔΟΣ — Αναζήτηση σε όλο το workspace
  // ─────────────────────────────────────────────────────────

  Future<List<SearchResult>> search({
    required String query,
    required int workspaceId,
    ItemType? filterType,        // Optional: αναζήτηση μόνο σε συγκεκριμένο τύπο
    int maxResults = 50,
  }) async {
    if (query.trim().isEmpty) return [];

    final q = query.trim().toLowerCase();
    final results = <SearchResult>[];
    final foundIds = <int>{}; // Για deduplication

    // 1️⃣ Αναζήτηση στους τίτλους (γρηγορότερο — index)
    final titleMatches = await SuperNoteHelper.instance.items
        .search(q, workspaceId);

    for (final item in titleMatches) {
      if (filterType != null && item.type != filterType) continue;
      if (foundIds.contains(item.id)) continue;
      foundIds.add(item.id);
      results.add(SearchResult(
        item: item,
        matchType: SearchMatchType.title,
        matchedText: item.title,
      ));
    }

    // 2️⃣ Αναζήτηση στο περιεχόμενο (blocks)
    final allItems = await SuperNoteHelper.instance.items
        .getByWorkspace(workspaceId, type: filterType);

    for (final item in allItems) {
      if (foundIds.contains(item.id)) continue;
      if (results.length >= maxResults) break;

      final blocks = await SuperNoteHelper.instance.blocks
          .getByItem(item.id);

      final match = _findBlockMatch(blocks, q);
      if (match != null) {
        foundIds.add(item.id);
        results.add(SearchResult(
          item: item,
          matchType: SearchMatchType.content,
          matchedText: match,
        ));
      }
    }

    // 3️⃣ Αναζήτηση σε properties (email, phone, κλπ.)
    for (final item in allItems) {
      if (foundIds.contains(item.id)) continue;
      if (results.length >= maxResults) break;

      final props = await SuperNoteHelper.instance.properties
          .getAll(item.id);

      final match = props
          .where((p) =>
      p.value != null &&
          p.value!.toLowerCase().contains(q))
          .map((p) => p.value!)
          .firstOrNull;

      if (match != null) {
        foundIds.add(item.id);
        results.add(SearchResult(
          item: item,
          matchType: SearchMatchType.property,
          matchedText: match,
        ));
      }
    }

    // Ταξινόμηση: title matches πρώτα, μετά content, μετά property
    results.sort((a, b) => a.matchType.index.compareTo(b.matchType.index));

    return results.take(maxResults).toList();
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE
  // ─────────────────────────────────────────────────────────

  String? _findBlockMatch(List<ItemBlock> blocks, String query) {
    for (final block in blocks) {
      if (block.text != null &&
          block.text!.toLowerCase().contains(query)) {
        // Επέστρεψε ένα snippet γύρω από το match (max 100 chars)
        final idx = block.text!.toLowerCase().indexOf(query);
        final start = (idx - 30).clamp(0, block.text!.length);
        final end   = (idx + 70).clamp(0, block.text!.length);
        return (start > 0 ? '...' : '') +
            block.text!.substring(start, end) +
            (end < block.text!.length ? '...' : '');
      }
    }
    return null;
  }
}