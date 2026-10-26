// lib/providers/items_query_provider.dart
//
// S255 (F13): split από item_provider.dart (R1: <500 γραμμές) — read/derived
// providers: streams folder/κάδου, collection counts.
// Το `archivedItemsProvider` μένει στο item_provider.dart (το invalidate-άρει
// ο ItemNotifier.toggleArchive).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'db_provider.dart';
import 'workspace_provider.dart';
import 'item_provider.dart'; // itemsStreamProvider (collectionEntriesCountProvider)
import '../core/utils/debug_config.dart';

// ─────────────────────────────────────────────────────────────────
// Real-time items ανά folder (για home folder view)
// ─────────────────────────────────────────────────────────────────

/// Stream items ενός folder — real-time
final itemsByFolderStreamProvider =
StreamProvider.family<List<Item>, int>((ref, folderId) {
  final db = ref.watch(dbProvider);
  return db.items.watchByFolder(folderId);
});

/// Stream με όλα τα soft‑deleted items του active workspace
final trashedItemsStreamProvider = StreamProvider<List<Item>>((ref) {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return Stream.value(const []);
  return db.items.watchDeletedByWorkspace(wsId);
});

// ── Collection entry counts (Φ4a βήμα 18: από collections_screen,
//    Stream-single-yield → Future — recompute-on-watch ident)
final collectionEntriesCountProvider = FutureProvider<Map<int, int>>((ref) async {
  final itemsAsync = ref.watch(itemsStreamProvider);
  final entries = itemsAsync.valueOrNull
      ?.where((i) => i.type == ItemType.knowledge)
      .toList() ??
      [];

  if (entries.isEmpty) {
    return {};
  }

  // Ένα lightweight DB call αντί για N
  final entryIds = entries.map((e) => e.id).toList();
  DebugConfig.db('collectionEntriesCountProvider: entries=${entryIds.length}');
  final collectionIdMap = await ref.watch(dbProvider).properties
      .getCollectionIds(entryIds);
  DebugConfig.db('collectionEntriesCountProvider: found ${collectionIdMap.length} pairs');

  final Map<int, int> counts = {};
  for (final colIdStr in collectionIdMap.values) {
    final colId = int.tryParse(colIdStr);
    if (colId != null) counts[colId] = (counts[colId] ?? 0) + 1;
  }
  return counts;
});
