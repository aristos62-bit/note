// lib/providers/items_query_provider.dart
//
// S255 (F13): split από item_provider.dart (R1: <500 γραμμές) — read/derived
// providers: streams folder/κάδου, aggregate folder view, collection counts.
// Το `archivedItemsProvider` μένει στο item_provider.dart (το invalidate-άρει
// ο ItemNotifier.toggleArchive).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'db_provider.dart';
import 'workspace_provider.dart';
import 'item_provider.dart'; // itemsStreamProvider (collectionEntriesCountProvider)
import '../core/utils/debug_config.dart';
import 'dart:async';

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

// ─────────────────────────────────────────────────────────────────
// Combined data για HomeFolderView (αντικαθιστά 4 ξεχωριστά providers)
// ─────────────────────────────────────────────────────────────────

class FolderViewData {
  final Map<ItemType, int> stats;
  final List<Item> pinned;
  final List<Item> favorites;
  final List<Item> recent;

  FolderViewData({
    required this.stats,
    required this.pinned,
    required this.favorites,
    required this.recent,
  });
}

/// Ένας provider — 1 rebuild αντί για 4
final folderViewDataProvider =
    StreamProvider.family<FolderViewData, int>((ref, folderId) async* {
  FolderViewData compute(List<Item> items) {
    final stats = <ItemType, int>{};
    for (final type in ItemType.values) {
      stats[type] = items.where((i) => i.type == type && i.deletedAt == null).length;
    }
    final pinned = items.where((i) => i.pinned && i.deletedAt == null).toList();
    final favorites = items.where((i) => i.favorite && i.deletedAt == null).toList();
    final active = items.where((i) => !i.archived && i.deletedAt == null).toList();
    active.sort((a, b) => (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));
    final recent = active.take(10).toList();
    return FolderViewData(stats: stats, pinned: pinned, favorites: favorites, recent: recent);
  }

  yield* ref.watch(itemsByFolderStreamProvider(folderId)).when(
    data: (items) async* {
      yield compute(items);
    },
    loading: () async* {},
    error: (_, __) async* {},
  );
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
