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
    ItemType? filterType,        // Optional: αναζήτηση μόνο σε συγκεκριμένο τύπο
    int maxResults = 50,
  }) async {
    DebugConfig.print('🔍 SEARCH | entered with query="$query", workspaceId=$workspaceId, filterType=$filterType');

    if (query.trim().isEmpty) {
      DebugConfig.print('🔍 SEARCH | query empty, returning []');
      return [];
    }

    final q = query.trim().toLowerCase();
    DebugConfig.print('🔍 SEARCH | normalized query="$q"');

    final results = <SearchResult>[];
    final foundIds = <int>{}; // Για deduplication

    // 1️⃣ Αναζήτηση στους τίτλους (γρηγορότερο — index)
    DebugConfig.print('🔍 SEARCH | searching titles...');
    try {
      final titleMatches = await SuperNoteHelper.instance.items
          .search(q, workspaceId);
      DebugConfig.print('🔍 SEARCH | titleMatches count = ${titleMatches.length}');
      for (final item in titleMatches) {
        DebugConfig.print('🔍 SEARCH | title match item: id=${item.id}, title="${item.title}", type=${item.type}');
      }
      for (final item in titleMatches) {
        if (filterType != null && item.type != filterType) continue;
        if (foundIds.contains(item.id)) continue;
        foundIds.add(item.id);
        results.add(SearchResult(
          item: item,
          matchType: SearchMatchType.title,
          matchedText: item.title,
        ));
        DebugConfig.print('🔍 SEARCH | added title match: item.id=${item.id}, title="${item.title}"');
      }
    } catch (e, stack) {
      DebugConfig.error('🔍 SEARCH | ERROR in title search', e, stack);
    }

    // 2️⃣ Αναζήτηση στο περιεχόμενο (blocks)
    DebugConfig.print('🔍 SEARCH | loading all items for content search...');
    try {
      final allItems = await SuperNoteHelper.instance.items
          .getByWorkspace(workspaceId, type: filterType);
      DebugConfig.print('🔍 SEARCH | allItems count = ${allItems.length}');
      for (int i = 0; i < allItems.length && i < 5; i++) {
        DebugConfig.print('🔍 SEARCH | sample item $i: id=${allItems[i].id}, title="${allItems[i].title}"');
      }

      for (final item in allItems) {
        if (foundIds.contains(item.id)) continue;
        if (results.length >= maxResults) break;

        final blocks = await SuperNoteHelper.instance.blocks
            .getByItem(item.id);
        DebugConfig.print('🔍 SEARCH | item ${item.id} blocks count = ${blocks.length}');

        final match = _findBlockMatch(blocks, q);
        if (match != null) {
          foundIds.add(item.id);
          results.add(SearchResult(
            item: item,
            matchType: SearchMatchType.content,
            matchedText: match,
          ));
          DebugConfig.print('🔍 SEARCH | content match: item.id=${item.id}, title="${item.title}", snippet="$match"');
        }
      }
    } catch (e, stack) {
      DebugConfig.error('🔍 SEARCH | ERROR in content search', e, stack);
    }

    // 3️⃣ Αναζήτηση σε properties (email, phone, κλπ.)
    DebugConfig.print('🔍 SEARCH | searching properties...');
    try {
      // Ξαναπαίρνουμε τα allItems γιατί μπορεί να μην τα έχουμε αν προηγήθηκε exception
      final allItems = await SuperNoteHelper.instance.items
          .getByWorkspace(workspaceId, type: filterType);
      for (final item in allItems) {
        if (foundIds.contains(item.id)) continue;
        if (results.length >= maxResults) break;

        final props = await SuperNoteHelper.instance.properties
            .getAll(item.id);
        DebugConfig.print('🔍 SEARCH | item ${item.id} props count = ${props.length}');

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
          DebugConfig.print('🔍 SEARCH | property match: item.id=${item.id}, title="${item.title}", value="$match"');
        }
      }
    } catch (e, stack) {
      DebugConfig.error('🔍 SEARCH | ERROR in property search', e, stack);
    }

    // Ταξινόμηση: title matches πρώτα, μετά content, μετά property
    results.sort((a, b) => a.matchType.index.compareTo(b.matchType.index));

    DebugConfig.print('🔍 SEARCH | FINAL RESULTS count = ${results.length} (before maxResults limit)');
    for (int i = 0; i < results.length && i < 5; i++) {
      DebugConfig.print('🔍 SEARCH | result $i: item.id=${results[i].item.id}, type=${results[i].matchType}');
    }

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