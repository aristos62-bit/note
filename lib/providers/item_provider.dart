// lib/providers/item_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart';
import 'db_provider.dart';
import 'workspace_provider.dart';

// ─────────────────────────────────────────────────────────────────
// Filters (για το UI — φίλτρα λίστας)
// ─────────────────────────────────────────────────────────────────

/// Το τρέχον φίλτρο τύπου (note, task κλπ.) — null = όλα
final activeItemTypeFilterProvider = StateProvider<ItemType?>((ref) => null);

/// Αν εμφανίζονται archived items
final showArchivedProvider = StateProvider<bool>((ref) => false);

// ─────────────────────────────────────────────────────────────────
// Items του active workspace (με φίλτρα)
// ─────────────────────────────────────────────────────────────────

final itemsStreamProvider = StreamProvider<List<Item>>((ref) async* {
  final db         = ref.watch(dbProvider);
  final wsId       = ref.watch(activeWorkspaceIdProvider);
  final typeFilter = ref.watch(activeItemTypeFilterProvider);
  final showArchived = ref.watch(showArchivedProvider);

  if (wsId == null) {
    yield const [];
    return;
  }

  // 1) Στείλε άμεσα το τρέχον snapshot (όπως παλιά ο FutureProvider)
  final initial = await db.items.getByWorkspace(
    wsId,
    type: typeFilter,
    includeArchived: showArchived,
  );
  yield initial;

  // 2) Και μετά άκου τις αλλαγές από Isar
  final changesStream = db.items.watchAll();

  yield* changesStream.asyncMap((_) {
    return db.items.getByWorkspace(
      wsId,
      type: typeFilter,
      includeArchived: showArchived,
    );
  });
});


// /// Backwards-compatible provider: Future<List<Item>> πάνω από το real-time stream
// final itemsProvider = FutureProvider<List<Item>>((ref) async {
//   // Περιμένουμε μέχρι ο itemsStreamProvider να έχει data
//   final asyncValue = ref.watch(itemsStreamProvider);
//
//   // Αν ήδη έχουμε data, το επιστρέφουμε
//   if (asyncValue.hasValue) {
//     return asyncValue.value!;
//   }
//
//   // Αλλιώς, περιμένουμε το πρώτο data event
//   return await ref.watch(itemsStreamProvider.future);
// });

/// Items ενός συγκεκριμένου folder
final itemsByFolderProvider =
FutureProvider.family<List<Item>, int>((ref, folderId) {
  final db = ref.watch(dbProvider);
  return db.items.getByFolder(folderId);
});

/// Pinned items
final pinnedItemsProvider = FutureProvider<List<Item>>((ref) async {
  final db = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return [];
  return db.items.getPinned(wsId);
});

/// Favorite items
final favoriteItemsProvider = FutureProvider<List<Item>>((ref) async {
  final db = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return [];
  return db.items.getFavorites(wsId);
});

/// Ένα συγκεκριμένο item by ID (για detail screen)
final itemByIdProvider = FutureProvider.family<Item?, int>((ref, id) {
  final db = ref.watch(dbProvider);
  return db.items.getById(id);
});

/// Stream ενός item — reactive updates στο detail screen
final itemStreamProvider =
StreamProvider.family<Item?, int>((ref, id) {
  final db = ref.watch(dbProvider);
  return db.items.watchById(id);
});

/// Count ανά τύπο
final itemCountProvider =
FutureProvider.family<int, ItemType>((ref, type) async {
  final db = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return 0;
  return db.items.count(workspaceId: wsId, type: type);
});

// ─────────────────────────────────────────────────────────────────
// ItemNotifier — CRUD operations
// ─────────────────────────────────────────────────────────────────

class ItemNotifier extends AsyncNotifier<List<Item>> {
  @override
  Future<List<Item>> build() async {
    final db = ref.watch(dbProvider);
    final wsId = ref.watch(activeWorkspaceIdProvider);
    final typeFilter = ref.watch(activeItemTypeFilterProvider);
    final showArchived = ref.watch(showArchivedProvider);

    if (wsId == null) return [];

    return db.items.getByWorkspace(
      wsId,
      type: typeFilter,
      includeArchived: showArchived,
    );
  }

  /// Δημιουργία νέου item
  Future<Item?> create({
    required ItemType type,
    String? title,
    String? icon,
    String? color,
    int? folderId,
  }) async {
    final wsId = ref.read(activeWorkspaceIdProvider);
    if (wsId == null) return null;

    final item = await ref.read(dbProvider).items.create(
      type: type,
      workspaceId: wsId,
      title: title,
      icon: icon,
      color: color,
      folderId: folderId,
    );

    ref.invalidateSelf();
    return item;
  }

  /// Ενημέρωση item
  /// ΣΗΜΑΝΤΙΚΟ: Ονομάζεται updateItem() και ΟΧΙ update()
  /// γιατί το AsyncNotifier έχει built-in update() που θα συγκρουόταν
  Future<void> updateItem(
      int id, {
        String? title,
        String? icon,
        String? color,
        ItemStatus? status,
        ItemPriority? priority,
        bool? pinned,
        bool? archived,
        bool? favorite,
      }) async {
    await ref.read(dbProvider).items.update(
      id,
      title: title,
      icon: icon,
      color: color,
      status: status,
      priority: priority,
      pinned: pinned,
      archived: archived,
      favorite: favorite,
    );
    ref.invalidateSelf();
  }

  /// Soft delete
  Future<void> deleteItem(int id) async {
    await ref.read(dbProvider).items.softDelete(id);
    ref.invalidateSelf();
  }

  /// Restore από soft delete
  Future<void> restoreItem(int id) async {
    await ref.read(dbProvider).items.restore(id);
    ref.invalidateSelf();
  }

  /// Permanent delete
  Future<void> permanentDelete(int id) async {
    await ref.read(dbProvider).items.hardDelete(id);
    ref.invalidateSelf();
  }

  /// Reorder items (drag & drop)
  Future<void> reorder(List<Item> reorderedItems) async {
    await ref.read(dbProvider).items.reorder(reorderedItems);
    ref.invalidateSelf();
  }

  /// Toggle pin
  Future<void> togglePin(int id, bool currentValue) =>
      updateItem(id, pinned: !currentValue);

  /// Toggle favorite
  Future<void> toggleFavorite(int id, bool currentValue) =>
      updateItem(id, favorite: !currentValue);

  /// Toggle archive
  Future<void> toggleArchive(int id, bool currentValue) =>
      updateItem(id, archived: !currentValue);
}

final itemNotifierProvider =
AsyncNotifierProvider<ItemNotifier, List<Item>>(ItemNotifier.new);