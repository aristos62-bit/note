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
import '../core/core.dart';

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
    ItemType? filterType,
    int maxResults = 50,
  }) async {
    DebugConfig.print('🔍 SEARCH | entered with query="$query", workspaceId=$workspaceId, filterType=$filterType');

    if (query.trim().isEmpty) {
      DebugConfig.print('🔍 SEARCH | query empty, returning []');
      return [];
    }

    final q = query.trim().toLowerCase();
    final results = <SearchResult>[];
    final foundIds = <int>{};

    // 1️⃣ Αναζήτηση στους τίτλους (index — γρήγορο)
    try {
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
      DebugConfig.print('🔍 SEARCH | title matches: ${results.length}');
    } catch (e, stack) {
      DebugConfig.error('🔍 SEARCH | ERROR in title search', e, stack);
    }

    // Φόρτωση όλων των items μία φορά — χρησιμοποιείται και για blocks και για properties
    List<Item> allItems = [];
    try {
      allItems = await SuperNoteHelper.instance.items
          .getByWorkspace(workspaceId, type: filterType);
      DebugConfig.print('🔍 SEARCH | allItems count = ${allItems.length}');
    } catch (e, stack) {
      DebugConfig.error('🔍 SEARCH | ERROR loading items', e, stack);
      results.sort((a, b) => a.matchType.index.compareTo(b.matchType.index));
      return results.take(maxResults).toList();
    }

    final remainingItems = allItems
        .where((i) => !foundIds.contains(i.id))
        .toList();
    final remainingIds = remainingItems.map((i) => i.id).toList();

    // 2️⃣ Αναζήτηση στο περιεχόμενο (blocks) — 1 batch call
    try {
      final blocksMap = await SuperNoteHelper.instance.blocks
          .getByItems(remainingIds);
      DebugConfig.print('🔍 SEARCH | blocksMap items with blocks: ${blocksMap.length}');

      for (final item in remainingItems) {
        if (results.length >= maxResults) break;
        final blocks = blocksMap[item.id] ?? [];
        final match = _findBlockMatch(blocks, q);
        if (match != null) {
          foundIds.add(item.id);
          results.add(SearchResult(
            item: item,
            matchType: SearchMatchType.content,
            matchedText: match,
          ));
          DebugConfig.print('🔍 SEARCH | content match: id=${item.id} title="${item.title}"');
        }
      }
    } catch (e, stack) {
      DebugConfig.error('🔍 SEARCH | ERROR in content search', e, stack);
    }

    // 3️⃣ Αναζήτηση σε properties — 1 batch call
    try {
      final stillRemaining = remainingItems
          .where((i) => !foundIds.contains(i.id))
          .toList();
      final stillRemainingIds = stillRemaining.map((i) => i.id).toList();

      final propsMap = await SuperNoteHelper.instance.properties
          .getAllForItems(stillRemainingIds);
      DebugConfig.print('🔍 SEARCH | propsMap items with props: ${propsMap.length}');

      for (final item in stillRemaining) {
        if (results.length >= maxResults) break;
        final props = propsMap[item.id] ?? [];
        final match = props
            .where((p) => p.value != null && p.value!.toLowerCase().contains(q))
            .map((p) => p.value!)
            .firstOrNull;
        if (match != null) {
          foundIds.add(item.id);
          results.add(SearchResult(
            item: item,
            matchType: SearchMatchType.property,
            matchedText: match,
          ));
          DebugConfig.print('🔍 SEARCH | property match: id=${item.id} title="${item.title}"');
        }
      }
    } catch (e, stack) {
      DebugConfig.error('🔍 SEARCH | ERROR in property search', e, stack);
    }

    results.sort((a, b) => a.matchType.index.compareTo(b.matchType.index));
    DebugConfig.print('🔍 SEARCH | FINAL RESULTS: ${results.length}');
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