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
// ─────────────────────────────────────────────────────────────────
// Real-time items ανά folder (για home folder view)
// ─────────────────────────────────────────────────────────────────

/// Stream items ενός folder — real-time
final itemsByFolderStreamProvider =
StreamProvider.family<List<Item>, int>((ref, folderId) async* {
  final db = ref.watch(dbProvider);

  // 1) Αρχικό snapshot
  final initial = await db.items.getByFolder(folderId);
  yield initial;

  // 2) Reactive updates
  yield* db.items.watchAll().asyncMap((_) {
    return db.items.getByFolder(folderId);
  });
});

/// Pinned items ενός folder — real-time (derived από itemsByFolderStreamProvider)
final pinnedByFolderStreamProvider =
StreamProvider.family<List<Item>, int>((ref, folderId) async* {
  // Παρακολουθούμε το AsyncValue<List<Item>>
  final asyncItems = ref.watch(itemsByFolderStreamProvider(folderId));

  // Όταν έχει τιμή, κάνουμε yield το φιλτραρισμένο αποτέλεσμα
  if (asyncItems.hasValue) {
    final items = asyncItems.value ?? [];
    final pinned = items
        .where((i) => i.pinned && i.deletedAt == null)
        .toList();
    yield pinned;
  }

  // Και μετά ακούμε όλες τις επόμενες αλλαγές του base stream
  yield* asyncItems.when(
    data: (items) async* {
      yield items.where((i) => i.pinned && i.deletedAt == null).toList();
    },
    loading: () async* {
      // προαιρετικά: yield [];
    },
    error: (_, __) async* {
      // προαιρετικά: yield [];
    },
  );
});

/// Favorite items ενός συγκεκριμένου folder — real-time
final favoritesByFolderStreamProvider =
StreamProvider.family<List<Item>, int>((ref, folderId) async* {
  final asyncItems = ref.watch(itemsByFolderStreamProvider(folderId));

  if (asyncItems.hasValue) {
    final items = asyncItems.value ?? [];
    yield items
        .where((i) => i.favorite && i.deletedAt == null)
        .toList();
  }

  yield* asyncItems.when(
    data: (items) async* {
      yield items
          .where((i) => i.favorite && i.deletedAt == null)
          .toList();
    },
    loading: () async* {},
    error: (_, __) async* {},
  );
});


/// Stream με όλα τα soft‑deleted items του active workspace
final trashedItemsStreamProvider = StreamProvider<List<Item>>((ref) async* {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) {
    yield const [];
    return;
  }

  // Αρχικό snapshot: όλα τα διαγραμμένα
  final initial = await db.items.getByWorkspace(
    wsId,
    includeDeleted: true,   // συμπεριλαμβάνει deleted
    includeArchived: true,  // δείχνουμε και archived αν υπάρχουν
  );
  // φιλτράρουμε μόνο αυτά με deletedAt != null
  yield initial.where((i) => i.deletedAt != null).toList();

  // Reactive updates
  final changes = db.items.watchAll();
  yield* changes.asyncMap((_) async {
    final all = await db.items.getByWorkspace(
      wsId,
      includeDeleted: true,
      includeArchived: true,
    );
    return all.where((i) => i.deletedAt != null).toList();
  });
});

/// Pinned items ΟΛΩΝ των folders — real-time
final allPinnedStreamProvider = StreamProvider<List<Item>>((ref) async* {
  final asyncItems = ref.watch(itemsStreamProvider);

  // Αρχικό snapshot όταν υπάρχουν data
  if (asyncItems.hasValue) {
    final items = asyncItems.value ?? [];
    yield items
        .where((i) => i.pinned && i.deletedAt == null)
        .toList();
  }

  // Reactive updates από το base stream
  yield* asyncItems.when(
    data: (items) async* {
      yield items
          .where((i) => i.pinned && i.deletedAt == null)
          .toList();
    },
    loading: () async* {
      // optionally: yield [];
    },
    error: (_, __) async* {
      // optionally: yield [];
    },
  );
});

/// Favorite items ΟΛΩΝ των folders — real-time
final allFavoritesStreamProvider = StreamProvider<List<Item>>((ref) async* {
  final asyncItems = ref.watch(itemsStreamProvider);

  // Αρχικό snapshot όταν υπάρχουν data
  if (asyncItems.hasValue) {
    final items = asyncItems.value ?? [];
    yield items
        .where((i) => i.favorite && i.deletedAt == null)
        .toList();
  }

  // Reactive updates από το base stream
  yield* asyncItems.when(
    data: (items) async* {
      yield items
          .where((i) => i.favorite && i.deletedAt == null)
          .toList();
    },
    loading: () async* {
      // optionally: yield [];
    },
    error: (_, __) async* {
      // optionally: yield [];
    },
  );
});
/// Stats ανά τύπο για συγκεκριμένο folder — real-time
final folderStatsProvider =
StreamProvider.family<Map<ItemType, int>, int>((ref, folderId) async* {
  final asyncItems = ref.watch(itemsByFolderStreamProvider(folderId));

  Map<ItemType, int> computeCounts(List<Item> items) {
    final counts = <ItemType, int>{};
    for (final type in ItemType.values) {
      counts[type] =
          items.where((i) => i.type == type && i.deletedAt == null).length;
    }
    return counts;
  }

  // Αρχικό snapshot
  if (asyncItems.hasValue) {
    final items = asyncItems.value ?? [];
    yield computeCounts(items);
  }

  // Reactive updates
  yield* asyncItems.when(
    data: (items) async* {
      yield computeCounts(items);
    },
    loading: () async* {
      // optionally: yield {};
    },
    error: (_, __) async* {
      // optionally: yield {};
    },
  );
});


/// Today's tasks για συγκεκριμένο folder (due today ή overdue, μη completed)
final todayTasksByFolderProvider =
StreamProvider.family<List<Item>, int>((ref, folderId) async* {
  final asyncItems = ref.watch(itemsByFolderStreamProvider(folderId));

  List<Item> filter(List<Item> items) {
    return items.where((i) {
      if (i.type != ItemType.task) return false;
      if (i.status == ItemStatus.done) return false;
      if (i.deletedAt != null) return false;
      return true; // Θα φιλτράρουμε per due date στο UI
    }).toList();
  }

  if (asyncItems.hasValue) {
    yield filter(asyncItems.value ?? []);
  }

  yield* asyncItems.when(
    data: (items) async* {
      yield filter(items);
    },
    loading: () async* {
      // optionally: yield [];
    },
    error: (_, __) async* {
      // optionally: yield [];
    },
  );
});


/// Recent items ενός folder (τελευταία 10, ταξινομημένα κατά updatedAt)
final recentByFolderProvider =
StreamProvider.family<List<Item>, int>((ref, folderId) async* {
  final asyncItems = ref.watch(itemsByFolderStreamProvider(folderId));

  List<Item> compute(List<Item> items) {
    final active =
    items.where((i) => !i.archived && i.deletedAt == null).toList();
    active.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt;
      final bDate = b.updatedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
    return active.take(10).toList();
  }

  if (asyncItems.hasValue) {
    yield compute(asyncItems.value ?? []);
  }

  yield* asyncItems.when(
    data: (items) async* {
      yield compute(items);
    },
    loading: () async* {
      // optionally: yield [];
    },
    error: (_, __) async* {
      // optionally: yield [];
    },
  );
});

