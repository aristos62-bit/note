// lib/providers/item_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'db_provider.dart';
import 'workspace_provider.dart';
import '../core/utils/debug_config.dart';
import 'dart:async';
import '../services/reminder_scheduler.dart';

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

final itemsStreamProvider = StreamProvider<List<Item>>((ref) {
  final db           = ref.watch(dbProvider);
  final wsId         = ref.watch(activeWorkspaceIdProvider);
  final typeFilter   = ref.watch(activeItemTypeFilterProvider);
  final showArchived = ref.watch(showArchivedProvider);

  if (wsId == null) return Stream.value(const []);

  return db.items.watchByWorkspace(
    wsId,
    type:            typeFilter,
    includeArchived: showArchived,
  );
});

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
    try {
      final db = ref.watch(dbProvider);
      final wsId = ref.watch(activeWorkspaceIdProvider);
      final typeFilter = ref.watch(activeItemTypeFilterProvider);
      final showArchived = ref.watch(showArchivedProvider);

      if (wsId == null) return [];

      return await db.items.getByWorkspace(
        wsId,
        type: typeFilter,
        includeArchived: showArchived,
      );
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.build', e, s);
      return [];
    }
  }

  /// Δημιουργία νέου item
  Future<Item?> create({
    required ItemType type,
    String? title,
    String? icon,
    String? color,
    int? folderId,
    Map<String, String>? initialProperties,
  }) async {
    try {
      final wsId = ref.read(activeWorkspaceIdProvider);
      if (wsId == null) return null;

      final db = ref.read(dbProvider);
      final isar = db.isar;

      Item? item;
      await isar.writeTxn(() async {
        item = Item()
          ..type = type
          ..workspaceId = wsId
          ..title = title
          ..icon = icon
          ..color = color
          ..folderId = folderId
          ..sortOrder = 0.0
          ..createdAt = DateTime.now()
          ..isDirty = true;
        await isar.items.put(item!);

        if (initialProperties != null) {
          for (final entry in initialProperties.entries) {
            await isar.itemPropertys.put(ItemProperty()
              ..itemId = item!.id
              ..key = entry.key
              ..value = entry.value
            );
          }
        }
      });

      ref.invalidateSelf();
      return item;
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.create', e, s);
      return null;
    }
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
    try {
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
      ref.invalidate(itemByIdProvider(id));
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.updateItem', e, s);
    }
  }

  /// Soft delete — cascade delete reminders (root + children) + cancel OS notifications.
  /// D1: Αν είναι συλλογή (project) → soft-delete cascade και των εγγραφών της (→ κάδος).
  Future<void> deleteItem(int id) async {
    try {
      final db = ref.read(dbProvider);
      final item = await db.items.getById(id);
      if (item != null && item.type == ItemType.project) {
        await _cascadeCollectionEntries(id, item.workspaceId);
      }
      final reminders = await db.reminders.getForItem(id);
      DebugConfig.db('ItemNotifier.deleteItem id=$id reminders=${reminders.length}');
      if (reminders.isNotEmpty) {
        DebugConfig.notif('deleteItem: calling deleteAllRemindersForItem($id) — cascade delete + cancel notifications');
        await ReminderScheduler.instance.deleteAllRemindersForItem(id);
      }
      await db.items.softDelete(id);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.deleteItem', e, s);
    }
  }

  /// D1: cascade των knowledge εγγραφών της συλλογής (reuse getByWorkspace + getCollectionIds).
  /// Εγγραφές πρώτα, συλλογή τελευταία (interrupt-safe). Οι εγγραφές είναι knowledge → χωρίς recursion βρόχο.
  Future<void> _cascadeCollectionEntries(int collectionId, int workspaceId) async {
    final db = ref.read(dbProvider);
    final entries = await db.items.getByWorkspace(workspaceId, type: ItemType.knowledge, includeArchived: true);
    final colIds = await db.properties.getCollectionIds([for (final e in entries) e.id]);
    final target = collectionId.toString();
    final ids = [for (final e in colIds.entries) if (e.value == target) e.key];
    DebugConfig.db('deleteItem cascade collection=$collectionId entries=${ids.length}');
    for (final eid in ids) { await deleteItem(eid); }
  }

  /// Restore από soft delete
  Future<void> restoreItem(int id) async {
    try {
      await ref.read(dbProvider).items.restore(id);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.restoreItem', e, s);
    }
  }

  /// Permanent delete
  Future<void> permanentDelete(int id) async {
    try {
      final reminders = await ref.read(dbProvider).reminders.getForItem(id);
      DebugConfig.db('ItemNotifier.permanentDelete id=$id reminders=${reminders.length}');
      for (final r in reminders) {
        DebugConfig.notif('  reminder id=${r.id} trigger=${r.triggerAt} status=${r.status.name}');
      }
      if (reminders.isNotEmpty) {
        DebugConfig.notif('permanentDelete: calling deleteAllRemindersForItem($id) — cascade delete + cancel notifications');
        await ReminderScheduler.instance.deleteAllRemindersForItem(id);
      }
      await ref.read(dbProvider).items.hardDelete(id);
      ref.invalidateSelf();
      DebugConfig.db('ItemNotifier.permanentDelete done id=$id');
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.permanentDelete', e, s);
    }
  }

  /// Reorder items (drag & drop)
  Future<void> reorder(List<Item> reorderedItems) async {
    try {
      await ref.read(dbProvider).items.reorder(reorderedItems);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.reorder', e, s);
    }
  }

  /// Toggle pin
  Future<void> togglePin(int id, bool currentValue) =>
      updateItem(id, pinned: !currentValue);

  /// Toggle favorite
  Future<void> toggleFavorite(int id, bool currentValue) =>
      updateItem(id, favorite: !currentValue);

  /// Toggle archive
  Future<void> toggleArchive(int id, bool currentValue) async {
    final reminders = await ref.read(dbProvider).reminders.getForItem(id);
    DebugConfig.db('ItemNotifier.toggleArchive id=$id new=${!currentValue} reminders=${reminders.length} — NO reminder handling!');
    for (final r in reminders) {
      DebugConfig.notif('  reminder id=${r.id} trigger=${r.triggerAt} status=${r.status.name}');
    }
    await updateItem(id, archived: !currentValue);
  }

  /// Μετακίνηση item σε άλλο φάκελο
  Future<void> moveToFolder(int itemId, int? newFolderId) async {
    try {
      await ref.read(dbProvider).items.update(itemId, folderId: newFolderId);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.moveToFolder', e, s);
    }
  }

  // ─── ΝΕΕΣ ΜΕΘΟΔΟΙ ΓΙΑ REORDER PINNED / FAVORITES ─────────────

  /// Αναδιάταξη pinned items (αποθήκευση νέας σειράς)
  Future<void> reorderPinned(List<int> newOrder) async {
    try {
      await ref.read(dbProvider).items.reorderPinned(newOrder);
      ref.invalidateSelf();
      ref.invalidate(pinnedItemsProvider);
      ref.invalidate(pinnedAndFavoritesProvider);
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.reorderPinned', e, s);
    }
  }

  /// Αναδιάταξη favorite items (αποθήκευση νέας σειράς)
  Future<void> reorderFavorites(List<int> newOrder) async {
    try {
      await ref.read(dbProvider).items.reorderFavorites(newOrder);
      ref.invalidateSelf();
      ref.invalidate(pinnedAndFavoritesProvider);
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.reorderFavorites', e, s);
    }
  }

  /// Ενοποιημένη αναδιάταξη για ViewMode.both
  Future<void> reorderCombined(List<int> itemIds) async {
    try {
      await ref.read(dbProvider).items.reorderCombined(itemIds);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.reorderCombined', e, s);
    }
  }
}

final itemNotifierProvider =
AsyncNotifierProvider<ItemNotifier, List<Item>>(ItemNotifier.new);

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

// ── Provider για αρχειοθετημένα items ──────────────────────────
// (Φ4a βήμα 18: μεταφέρθηκε από settings_screen — DB via dbProvider)
final archivedItemsProvider = FutureProvider<List<Item>>((ref) async {
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return [];
  final all = await ref.watch(dbProvider).items.getByWorkspace(
    wsId,
    includeArchived: true,
  );
  return all.where((i) => i.archived && i.deletedAt == null).toList();
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

// ─────────────────────────────────────────────────────────────────
// ΑΝΕΞΑΡΤΗΤΑ STREAMS ΓΙΑ PINNED / FAVORITES (ΥΨΗΛΗ ΑΠΟΔΟΣΗ)
// 🔹 Δεν εξαρτώνται από το itemsStreamProvider
// 🔹 Κάνουν yield μόνο όταν αλλάζουν τα σχετικά δεδομένα
// ─────────────────────────────────────────────────────────────────

/// Stream όλων των pinned items του active workspace — ανεξάρτητο
final pinnedItemsStreamProvider = StreamProvider<List<Item>>((ref) {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return Stream.value(const []);
  return db.items.watchPinnedByWorkspace(wsId);
});

/// Stream όλων των favorite items του active workspace — ανεξάρτητο
/// Stream pinned + favorites — ανεξάρτητα Isar queries.
/// ΔΕΝ εξαρτάται από itemsStreamProvider.
/// Φωτίζει ΜΟΝΟ όταν αλλάξει pinned ή favorite status.
final pinnedAndFavoritesProvider =
StreamProvider<({List<Item> pinned, List<Item> favorites})>((ref) {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);

  if (wsId == null) {
    return Stream.value((pinned: <Item>[], favorites: <Item>[]));
  }

  // ignore: close_sinks — κλείνει στο onDispose
  final controller =
  StreamController<({List<Item> pinned, List<Item> favorites})>();

  List<Item> currentPinned    = [];
  List<Item> currentFavorites = [];
  bool pinnedLoaded    = false;
  bool favoritesLoaded = false;

  void emit() {
    if (pinnedLoaded && favoritesLoaded && !controller.isClosed) {
      controller.add((pinned: currentPinned, favorites: currentFavorites));
    }
  }

  final pinnedSub = db.items.watchPinnedByWorkspace(wsId).listen((items) {
    currentPinned = items;
    pinnedLoaded  = true;
    emit();
  });

  final favoritesSub =
  db.items.watchFavoritesByWorkspace(wsId).listen((items) {
    currentFavorites = items;
    favoritesLoaded  = true;
    emit();
  });

  ref.onDispose(() {
    pinnedSub.cancel();
    favoritesSub.cancel();
    controller.close();
  });

  return controller.stream;
});