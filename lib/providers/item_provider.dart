// lib/providers/item_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'db_provider.dart';
import 'workspace_provider.dart';
import 'pinned_provider.dart';
import '../core/utils/debug_config.dart';
import 'dart:async';
import '../services/reminder_scheduler.dart';
import '../services/habit_service.dart';

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
      // A2: προηγούμενο status + τίτλος/icon (1 read — re-bake μόνο σε
      // πραγματική αλλαγή, όχι σε κάθε no-op save).
      final prev = (status != null || title != null || icon != null)
          ? await ref.read(dbProvider).items.getById(id)
          : null;
      final prevStatus = prev?.status;
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
      // A2: done/cancelled = σίγαση OS reminders (rows μένουν)· επιστροφή
      // σε ενεργό status = reschedule (ίδια λογική με toggleArchive).
      if (status != null && prevStatus != status) {
        bool silenced(ItemStatus? s) =>
            s == ItemStatus.done || s == ItemStatus.cancelled;
        if (silenced(status)) {
          await ReminderScheduler.instance.cancelAllForItem(id);
          DebugConfig.notif('updateItem: status=${status.name} id=$id → cancelled OS (rows kept)');
        } else if (silenced(prevStatus)) {
          await ReminderScheduler.instance.refreshRecurringReminders();
          await ReminderScheduler.instance.rescheduleForItem(id);
          DebugConfig.notif('updateItem: status=${status.name} id=$id → rescheduled');
        }
      }
      // Μετονομασία → ξαναψήσιμο OS alarms (εκτός αν μόλις άλλαξε status —
      // το A2 κάλυψε ήδη το reschedule/cancel· εκτός αν το item χάθηκε).
      // color/priority/pinned/favorite δεν μπαίνουν στο κείμενο — σκόπιμα έξω.
      final statusChanged = status != null && prevStatus != status;
      final titleChanged = title != null && prev != null && title != prev.title;
      final iconChanged = icon != null && prev != null && icon != prev.icon;
      if ((titleChanged || iconChanged) && !statusChanged) {
        await ReminderScheduler.instance.rescheduleForItem(id);
        DebugConfig.notif('updateItem: title/icon changed id=$id → rescheduled OS');
      }
      ref.invalidateSelf();
      ref.invalidate(itemByIdProvider(id));
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.updateItem', e, s);
    }
  }

  /// Soft delete — cascade delete reminders (root + children) + cancel OS notifications.
  /// D1/F1: Αν είναι συλλογή (project) → soft-delete cascade και των εγγραφών της (→ κάδος).
  Future<void> deleteItem(int id) async {
    try {
      final db = ref.read(dbProvider);
      await _cascadeCollectionEntries(id, deleteItem);
      final reminders = await db.reminders.getForItem(id);
      DebugConfig.db('ItemNotifier.deleteItem id=$id reminders=${reminders.length}');
      if (reminders.isNotEmpty) {
        DebugConfig.notif('deleteItem: cancelling OS for $id — rows kept for restore (symmetric with archive)');
        await ReminderScheduler.instance.cancelAllForItem(id);
      }
      await db.items.softDelete(id);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.deleteItem', e, s);
    }
  }

  /// P1#1 (S250): serialized διαγραφή — wipe + soft delete στο ίδιο pass (S234).
  Future<void> deleteHabit(int id) async {
    try {
      await HabitService.instance
          .deleteHabitReminders(id, afterRows: () => deleteItem(id));
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.deleteHabit', e, s);
    }
  }

  /// D1/F1: εφαρμόζει [action] στις knowledge εγγραφές της συλλογής [id] (αν project).
  /// includeDeleted=true → και soft-deleted (restore/permanent). Εγγραφές πρώτα (interrupt-safe).
  Future<void> _cascadeCollectionEntries(int id, Future<void> Function(int) action, {bool includeDeleted = false, String logTag = 'deleteItem'}) async {
    final db = ref.read(dbProvider);
    final item = await db.items.getById(id);
    if (item == null || item.type != ItemType.project) return;
    final entries = await db.items.getByWorkspace(item.workspaceId, type: ItemType.knowledge, includeArchived: true, includeDeleted: includeDeleted);
    final colIds = await db.properties.getCollectionIds([for (final e in entries) e.id]);
    final ids = [for (final e in colIds.entries) if (e.value == id.toString()) e.key];
    DebugConfig.db('$logTag cascade collection=$id entries=${ids.length}');
    for (final eid in ids) { await action(eid); }
  }

  /// Restore από soft delete (F1: αν συλλογή → restore και των εγγραφών της)
  Future<void> restoreItem(int id) async {
    try {
      await _cascadeCollectionEntries(id, (eid) => ref.read(dbProvider).items.restore(eid),
          includeDeleted: true, logTag: 'restoreItem');
      await ref.read(dbProvider).items.restore(id);
      // Συμμετρικό με unarchive: οι κρατημένες rows ξαναπρογραμματίζονται·
      // οι συνήθειες θέλουν top-up (ο ορίζοντας εξαντλήθηκε στον κάδο).
      await ReminderScheduler.instance.refreshRecurringReminders();
      await ReminderScheduler.instance.rescheduleForItem(id);
      await HabitService.instance.topUpHabitReminders(force: true);
      DebugConfig.notif('restoreItem: id=$id → rescheduled');
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.restoreItem', e, s);
    }
  }

  /// Permanent delete
  Future<void> permanentDelete(int id) async {
    try {
      await _cascadeCollectionEntries(id, permanentDelete, includeDeleted: true, logTag: 'permanentDelete');
      final reminders = await ref.read(dbProvider).reminders.getForItem(id);
      DebugConfig.db('ItemNotifier.permanentDelete id=$id reminders=${reminders.length}');
      for (final r in reminders) {
        DebugConfig.notif('  reminder id=${r.id} trigger=${r.triggerAt} status=${r.status.name}');
      }
      final item = await ref.read(dbProvider).items.getById(id);
      if (item?.type == ItemType.habit) {
        // P1#1 (S250): habit — wipe + hard delete στο ίδιο pass (S234 race).
        await HabitService.instance.deleteHabitReminders(id,
            afterRows: () => ref.read(dbProvider).items.hardDelete(id));
      } else {
        if (reminders.isNotEmpty) {
          DebugConfig.notif('permanentDelete: calling deleteAllRemindersForItem($id) — cascade delete + cancel notifications');
          await ReminderScheduler.instance.deleteAllRemindersForItem(id);
        }
        await ref.read(dbProvider).items.hardDelete(id);
      }
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

  /// Toggle archive (#2): archive = σίγαση OS reminders· unarchive = reschedule.
  /// Τα Reminder rows ΔΕΝ διαγράφονται (non-destructive) — μόνο τα OS alarms.
  Future<void> toggleArchive(int id, bool currentValue) async {
    final newValue = !currentValue;
    DebugConfig.db('ItemNotifier.toggleArchive id=$id → archived=$newValue');
    await updateItem(id, archived: newValue);
    if (newValue) {
      await ReminderScheduler.instance.cancelAllForItem(id);
      DebugConfig.notif('toggleArchive: ARCHIVE id=$id → cancelled OS (rows kept)');
    } else {
      await ReminderScheduler.instance.refreshRecurringReminders();
      await ReminderScheduler.instance.rescheduleForItem(id);
      // Συνήθειες: ο ορίζοντας 60ημ. μπορεί να εξαντλήθηκε όσο ήταν
      // αρχειοθετημένη (το topUp εξαιρεί archived) — top-up τώρα, όχι στο resume.
      await HabitService.instance.topUpHabitReminders(force: true);
      DebugConfig.notif('toggleArchive: UNARCHIVE id=$id → rescheduled');
    }
    ref.invalidate(archivedItemsProvider);
  }

  /// S255 (F13): bulk unarchive — αντί για N × (reschedule + 2 global passes),
  /// 1 × global pass. Σειρά: write+reschedule ανά item → 1× refresh recurring
  /// (τα global passes σκιπάρουν archived) → 1× topUp habits. NEVER-THROW.
  Future<void> unarchiveMany(List<int> ids) async {
    if (ids.isEmpty) return;
    final sw = Stopwatch()..start();
    DebugConfig.db('ItemNotifier.unarchiveMany n=${ids.length} ids=$ids');
    try {
      for (final id in ids) {
        await updateItem(id, archived: false);
        await ReminderScheduler.instance.rescheduleForItem(id);
      }
      await ReminderScheduler.instance.refreshRecurringReminders();
      await HabitService.instance.topUpHabitReminders(force: true);
      DebugConfig.notif(
          'S255/F13 unarchiveMany: n=${ids.length} → 1× refresh + 1× topUp took=${sw.elapsedMilliseconds}ms');
    } catch (e, s) {
      DebugConfig.error('ItemNotifier.unarchiveMany', e, s);
    } finally {
      ref.invalidate(archivedItemsProvider);
    }
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