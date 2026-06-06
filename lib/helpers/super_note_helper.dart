// lib/helpers/super_note_helper.dart
//
// Ο κεντρικός helper για όλες τις DB λειτουργίες.
// Pattern: Singleton + static access.
//
// Χρήση:
//   await SuperNoteHelper.init();
//   final helper = SuperNoteHelper.instance;
//   final note = await helper.items.create(type: ItemType.note, title: 'Hello');
//
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/item.dart';
import '../models/item_block.dart';
import '../models/item_property.dart';
import '../models/tag.dart';
import '../models/item_tag.dart';
import '../models/relation.dart';
import '../models/reminder.dart';
import '../models/folder.dart';
import '../models/workspace.dart';
import '../models/attachment.dart';
import '../models/user.dart';
import '../models/device.dart';
import '../models/app_settings.dart';
import 'package:flutter/foundation.dart';
import '../core/core.dart';

// ─────────────────────────────────────────────────────────────────
// SuperNoteHelper — Singleton
// ─────────────────────────────────────────────────────────────────

class SuperNoteHelper {
  SuperNoteHelper._internal(this._isar);

  static SuperNoteHelper? _instance;
  static SuperNoteHelper get instance {
    assert(_instance != null,
    '❌ SuperNoteHelper δεν έχει αρχικοποιηθεί. Κάλεσε πρώτα SuperNoteHelper.init()');
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  final Isar _isar;

  /// Πρόσβαση στο raw Isar instance (για advanced queries)
  Isar get isar => _isar;

  // ─── Sub-helpers ────────────────────────────────────────
  late final ItemRepository items = ItemRepository(_isar);
  late final BlockRepository blocks = BlockRepository(_isar);
  late final PropertyRepository properties = PropertyRepository(_isar);
  late final TagRepository tags = TagRepository(_isar);
  late final RelationRepository relations = RelationRepository(_isar);
  late final ReminderRepository reminders = ReminderRepository(_isar);
  late final FolderRepository folders = FolderRepository(_isar);
  late final WorkspaceRepository workspaces = WorkspaceRepository(_isar);
  late final AttachmentRepository attachments = AttachmentRepository(_isar);
  late final SettingsRepository settings = SettingsRepository(_isar);

  // ─────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────

  /// Αρχικοποίηση της DB. Κάλεσε μία φορά στο main().
  static Future<SuperNoteHelper> init({String? directory}) async {
    if (_instance != null) return _instance!;

    final dir = directory ?? (await getApplicationDocumentsDirectory()).path;

    final isar = await Isar.open(
      [
        ItemSchema,
        ItemBlockSchema,
        ItemPropertySchema,
        TagSchema,
        ItemTagSchema,
        RelationSchema,
        ReminderSchema,
        FolderSchema,
        WorkspaceSchema,
        AttachmentSchema,
        UserSchema,
        DeviceSchema,
        AppSettingsSchema,
      ],
      directory: dir,
      name: 'super_note_db',
      inspector: kDebugMode,
    );

    _instance = SuperNoteHelper._internal(isar);

    // Δημιουργία default workspace αν δεν υπάρχει
    await _instance!._ensureDefaults();

    // Καθαρισμός παλιών pending reminders (π.χ. > 7 ημερών)
    await _instance!.reminders.cleanupOldPending();

    return _instance!;
  }

  /// Κλείσιμο DB (για testing ή app lifecycle)
  Future<void> close() async {
    await _isar.close();
    _instance = null;
  }

  /// Δημιουργία default data αν η DB είναι κενή
  Future<void> _ensureDefaults() async {
    // 1. Default workspace
    final wsCount = await _isar.workspaces.count();
    if (wsCount == 0) {
      await workspaces.create(name: 'Προσωπικός Βοηθός', icon: '⚡️', isDefault: true);
    }

    // 2. Default system folder "Γενικά"
    final defaultWs = await workspaces.getDefault();
    if (defaultWs != null) {
      final existingSystemFolder = await _isar.folders
          .filter()
          .workspaceIdEqualTo(defaultWs.id)
          .isSystemEqualTo(true)
          .findFirst();

      if (existingSystemFolder == null) {
        // Δημιουργία του system folder
        final generalFolder = Folder()
          ..name = 'Γενικά'
          ..workspaceId = defaultWs.id
          ..icon = '📁'
          ..color = '#6366F1'
          ..isSystem = true        // ✅ προστασία
          ..sortOrder = -1000.0    // να εμφανίζεται πρώτο
          ..createdAt = DateTime.now();

        await _isar.writeTxn(() async {
          await _isar.folders.put(generalFolder);
        });
      }
    }

    // 3. Default app settings
    final settingsExist = await _isar.appSettings.get(1) != null;
    if (!settingsExist) {
      await _isar.writeTxn(() async {
        await _isar.appSettings.put(AppSettings());
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// ItemRepository
// ─────────────────────────────────────────────────────────────────

class ItemRepository {
  ItemRepository(this._isar);
  final Isar _isar;

  // Βοηθητική ταξινόμησης για pinned/favorites
  List<Item> _sortByOrder(List<Item> items, double? Function(Item) orderGetter, DateTime Function(Item) timeGetter) {
    final list = List<Item>.from(items);
    list.sort((a, b) {
      final aOrder = orderGetter(a);
      final bOrder = orderGetter(b);
      if (aOrder == null && bOrder == null) {
        return timeGetter(b).compareTo(timeGetter(a));
      }
      if (aOrder == null) return 1;
      if (bOrder == null) return -1;
      return aOrder.compareTo(bOrder);
    });
    return list;
  }

  // ── CREATE ──────────────────────────────────────────────

  Future<Item> create({
    required ItemType type,
    required int workspaceId,
    String? title,
    int? folderId,
    String? icon,
    String? color,
    double sortOrder = 0.0,
  }) async {
    final item = Item()
      ..type = type
      ..workspaceId = workspaceId
      ..title = title
      ..folderId = folderId
      ..icon = icon
      ..color = color
      ..sortOrder = sortOrder
      ..createdAt = DateTime.now()
      ..isDirty = true;

    await _isar.writeTxn(() async {
      await _isar.items.put(item);
    });

    return item;
  }

  // ── READ ────────────────────────────────────────────────

  Future<Item?> getById(int id) => _isar.items.get(id);

  Future<List<Item>> getByWorkspace(
      int workspaceId, {
        ItemType? type,
        bool includeArchived = false,
        bool includeDeleted = false,
        int limit = 1000000,
        int offset = 0,
      }) {
    return _isar.items
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .optional(!includeDeleted, (q) => q.deletedAtIsNull())
        .optional(!includeArchived, (q) => q.archivedEqualTo(false))
        .optional(type != null, (q) => q.typeEqualTo(type!))
        .sortBySortOrder()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<List<Item>> getByFolder(int folderId, {int limit = 1000000, int offset = 0}) {
    return _isar.items
        .filter()
        .folderIdEqualTo(folderId)
        .deletedAtIsNull()
        .archivedEqualTo(false)
        .sortBySortOrder()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<List<Item>> getPinned(int workspaceId) async {
    final items = await _isar.items
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .pinnedEqualTo(true)
        .deletedAtIsNull()
        .findAll();
    return _sortByOrder(items, (i) => i.pinnedOrder, (i) => i.updatedAt ?? i.createdAt);
  }

  Future<List<Item>> getFavorites(int workspaceId) async {
    final items = await _isar.items
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .favoriteEqualTo(true)
        .deletedAtIsNull()
        .findAll();
    return _sortByOrder(items, (i) => i.favoriteOrder, (i) => i.updatedAt ?? i.createdAt);
  }

  /// Full-text search στον τίτλο
  Future<List<Item>> search(String query, int workspaceId) {
    return _isar.items
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .titleContains(query, caseSensitive: false)
        .deletedAtIsNull()
        .findAll();
  }

  // ── UPDATE ──────────────────────────────────────────────

  Future<Item?> update(int id, {
    String? title,
    String? icon,
    String? color,
    ItemStatus? status,
    ItemPriority? priority,
    bool? pinned,
    bool? archived,
    bool? favorite,
    int? folderId,
    double? sortOrder,
  }) async {
    final item = await getById(id);
    if (item == null) return null;

    if (title != null) item.title = title;
    if (icon != null) item.icon = icon;
    if (color != null) item.color = color;
    if (status != null) item.status = status;
    if (priority != null) item.priority = priority;
    if (pinned != null) {
      item.pinned = pinned;
      if (!pinned) item.pinnedOrder = null;
    }
    if (archived != null) {
      DebugConfig.db('ItemRepository.update id=$id setting archived=$archived (was=${item.archived})');
      item.archived = archived;
    }
    if (favorite != null) {
      item.favorite = favorite;
      if (!favorite) item.favoriteOrder = null;
    }
    if (folderId != null) item.folderId = folderId;
    if (sortOrder != null) item.sortOrder = sortOrder;

    item.updatedAt = DateTime.now();
    item.localVersion++;
    item.isDirty = true;

    DebugConfig.db('ItemRepository.update id=$id BEFORE writeTxn localVersion=${item.localVersion}');
    await _isar.writeTxn(() async {
      await _isar.items.put(item);
    });
    DebugConfig.db('ItemRepository.update id=$id AFTER writeTxn - OK');

    return item;
  }

  // ── DELETE ──────────────────────────────────────────────

  /// Soft delete (recommended)
  Future<void> softDelete(int id) async {
    final item = await getById(id);
    if (item == null) return;
    item.deletedAt = DateTime.now();
    item.isDirty = true;
    await _isar.writeTxn(() async {
      await _isar.items.put(item);
    });
  }

  /// Restore soft-deleted item
  Future<void> restore(int id) async {
    final item = await getById(id);
    if (item == null) return;
    item.deletedAt = null;
    item.isDirty = true;
    await _isar.writeTxn(() async {
      await _isar.items.put(item);
    });
  }

  /// Hard delete (permanent — διαγράφει και όλα τα related data)
  Future<void> hardDelete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.items.delete(id);
      // Cascade delete
      await _isar.itemBlocks.filter().itemIdEqualTo(id).deleteAll();
      await _isar.itemPropertys.filter().itemIdEqualTo(id).deleteAll();
      await _isar.itemTags.filter().itemIdEqualTo(id).deleteAll();
      await _isar.relations.filter().fromItemIdEqualTo(id).deleteAll();
      await _isar.relations.filter().toItemIdEqualTo(id).deleteAll();
      await _isar.reminders.filter().itemIdEqualTo(id).deleteAll();
      await _isar.attachments.filter().itemIdEqualTo(id).deleteAll();
    });
  }

  // ── REORDER (new) ──────────────────────────────────────────

  Future<void> reorderPinned(List<int> itemIds) async {
    await _isar.writeTxn(() async {
      for (int i = 0; i < itemIds.length; i++) {
        final item = await _isar.items.get(itemIds[i]);
        if (item != null && item.pinned) {
          item.pinnedOrder = i.toDouble();
          item.isDirty = true;
          await _isar.items.put(item);
        }
      }
      if (itemIds.isNotEmpty) {
        final anyItem = await _isar.items.get(itemIds.first);
        if (anyItem != null) {
          final allPinned = await getPinned(anyItem.workspaceId);
          for (final item in allPinned) {
            if (!itemIds.contains(item.id) && item.pinnedOrder != null) {
              item.pinnedOrder = null;
              item.isDirty = true;
              await _isar.items.put(item);
            }
          }
        }
      }
    });
  }

  Future<void> reorderFavorites(List<int> itemIds) async {
    await _isar.writeTxn(() async {
      for (int i = 0; i < itemIds.length; i++) {
        final item = await _isar.items.get(itemIds[i]);
        DebugConfig.print('   setting favoriteOrder for item ${item?.id} (folder ${item?.folderId}) to $i');
        if (item != null && item.favorite) {
          item.favoriteOrder = i.toDouble();
          item.isDirty = true;
          await _isar.items.put(item);
        }
      }
      if (itemIds.isNotEmpty) {
        final anyItem = await _isar.items.get(itemIds.first);
        if (anyItem != null) {
          final allFavorites = await getFavorites(anyItem.workspaceId);
          for (final item in allFavorites) {
            if (!itemIds.contains(item.id) && item.favoriteOrder != null) {
              item.favoriteOrder = null;
              item.isDirty = true;
              await _isar.items.put(item);
            }
          }
        }
      }
    });
  }

  /// Ενοποιημένη αναδιάταξη για ViewMode.both.
  /// Αποθηκεύει pinnedOrder για ΟΛΑ τα items (pinned και fav-only)
  /// σε ένα transaction → ένα μόνο stream event → χωρίς intermediate state.
  Future<void> reorderCombined(List<int> itemIds) async {
    await _isar.writeTxn(() async {
      for (int i = 0; i < itemIds.length; i++) {
        final item = await _isar.items.get(itemIds[i]);
        if (item != null) {
          item.pinnedOrder = i.toDouble();
          item.isDirty = true;
          await _isar.items.put(item);
        }
      }
    });
  }
  // ── WATCH (Reactive) ────────────────────────────────────

  /// Stream που εκπέμπει ΜΟΝΟ όταν αλλάξουν τα αποτελέσματα
  /// της συγκεκριμένης query (workspace-scoped)
  Stream<List<Item>> watchByWorkspace(
      int workspaceId, {
        ItemType? type,
        bool includeArchived = false,
        bool includeDeleted  = false,
      }) {
    return _isar.items
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .optional(!includeDeleted,  (q) => q.deletedAtIsNull())
        .optional(!includeArchived, (q) => q.archivedEqualTo(false))
        .optional(type != null,     (q) => q.typeEqualTo(type!))
        .sortBySortOrder()
        .watch(fireImmediately: true);
  }

  /// Stream items ενός folder — φωτιά ΜΟΝΟ αν αλλάξει το folder
  Stream<List<Item>> watchByFolder(int folderId) {
    return _isar.items
        .filter()
        .folderIdEqualTo(folderId)
        .deletedAtIsNull()
        .archivedEqualTo(false)
        .sortBySortOrder()
        .watch(fireImmediately: true);
  }

  /// Stream pinned items — φωτιά ΜΟΝΟ αν αλλάξει το pinned status
  Stream<List<Item>> watchPinnedByWorkspace(int workspaceId) {
    return _isar.items
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .pinnedEqualTo(true)
        .deletedAtIsNull()
        .watch(fireImmediately: true)
        .map((items) => _sortByOrder(items, (i) => i.pinnedOrder, (i) => i.updatedAt ?? i.createdAt));
  }

  /// Stream favorite items — φωτιά ΜΟΝΟ αν αλλάξει το favorite status
  Stream<List<Item>> watchFavoritesByWorkspace(int workspaceId) {
    return _isar.items
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .favoriteEqualTo(true)
        .deletedAtIsNull()
        .watch(fireImmediately: true)
        .map((items) => _sortByOrder(items, (i) => i.favoriteOrder, (i) => i.updatedAt ?? i.createdAt));
  }

  /// Stream soft-deleted items
  Stream<List<Item>> watchDeletedByWorkspace(int workspaceId) {
    return _isar.items
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .deletedAtIsNotNull()
        .watch(fireImmediately: true);
  }

  Stream<Item?> watchById(int id) =>
      _isar.items.watchObject(id, fireImmediately: true);

  // ── BULK OPERATIONS ──────────────────────────────────────

  Future<void> reorder(List<Item> items) async {
    await _isar.writeTxn(() async {
      for (int i = 0; i < items.length; i++) {
        items[i].sortOrder = i.toDouble();
        items[i].isDirty = true;
      }
      await _isar.items.putAll(items);
    });
  }

  Future<int> count({required int workspaceId, ItemType? type}) {
    var query = _isar.items
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .deletedAtIsNull();
    if (type != null) {
      return query.typeEqualTo(type).count();
    }
    return query.count();
  }
}

// ─────────────────────────────────────────────────────────────────
// BlockRepository (αμετάβλητο)
// ─────────────────────────────────────────────────────────────────

class BlockRepository {
  BlockRepository(this._isar);
  final Isar _isar;

  Future<ItemBlock> create({
    required int itemId,
    required BlockType type,
    String? text,
    String? url,
    String? filePath,
    String? metadata,
    int? parentBlockId,
    double? order,
  }) async {
    // Auto-calculate order αν δεν δοθεί
    final lastOrder = await _isar.itemBlocks
        .filter()
        .itemIdEqualTo(itemId)
        .sortByOrderDesc()
        .orderProperty()
        .findFirst() ?? -1.0;

    final block = ItemBlock()
      ..itemId = itemId
      ..type = type
      ..text = text
      ..url = url
      ..filePath = filePath
      ..metadata = metadata
      ..parentBlockId = parentBlockId
      ..order = order ?? (lastOrder + 1.0)
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.itemBlocks.put(block);
      // Update parent item's updatedAt
      final item = await _isar.items.get(itemId);
      if (item != null) {
        item.updatedAt = DateTime.now();
        item.isDirty = true;
        await _isar.items.put(item);
      }
    });

    return block;
  }

  Future<List<ItemBlock>> getByItem(int itemId) {
    return _isar.itemBlocks
        .filter()
        .itemIdEqualTo(itemId)
        .sortByOrder()
        .findAll();
  }

  Future<List<ItemBlock>> getChildren(int parentBlockId) {
    return _isar.itemBlocks
        .filter()
        .parentBlockIdEqualTo(parentBlockId)
        .sortByOrder()
        .findAll();
  }

  Future<void> updateText(int id, String text) async {
    final block = await _isar.itemBlocks.get(id);
    if (block == null) return;
    block.text = text;
    block.updatedAt = DateTime.now();
    block.isDirty = true;
    await _isar.writeTxn(() async {
      await _isar.itemBlocks.put(block);
    });
  }

  Future<void> toggleCheck(int id) async {
    final block = await _isar.itemBlocks.get(id);
    if (block == null) return;
    block.checked = !block.checked;
    block.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.itemBlocks.put(block);
    });
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.itemBlocks.delete(id);
    });
  }

  Future<void> reorder(List<ItemBlock> blocks) async {
    await _isar.writeTxn(() async {
      for (int i = 0; i < blocks.length; i++) {
        blocks[i].order = i.toDouble();
      }
      await _isar.itemBlocks.putAll(blocks);
    });
  }

  Stream<List<ItemBlock>> watchByItem(int itemId) {
    return _isar.itemBlocks
        .filter()
        .itemIdEqualTo(itemId)
        .sortByOrder()
        .watch(fireImmediately: true);
  }
}

// ─────────────────────────────────────────────────────────────────
// PropertyRepository (αμετάβλητο)
// ─────────────────────────────────────────────────────────────────

class PropertyRepository {
  PropertyRepository(this._isar);
  final Isar _isar;

  Future<ItemProperty> set({
    required int itemId,
    required String key,
    required String? value,
    PropertyType type = PropertyType.text,
    String? unit,
    bool isVisible = true,
    int sortOrder = 0,
  }) async {
    // Upsert: βρες existing ή φτιάξε νέο
    final existing = await _isar.itemPropertys
        .filter()
        .itemIdEqualTo(itemId)
        .keyEqualTo(key)
        .findFirst();

    final prop = existing ?? ItemProperty()
      ..itemId = itemId
      ..key = key;

    prop
      ..value = value
      ..type = type
      ..unit = unit
      ..isVisible = isVisible
      ..sortOrder = sortOrder
      ..updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.itemPropertys.put(prop);
    });

    return prop;
  }

  Future<ItemProperty?> get(int itemId, String key) {
    return _isar.itemPropertys
        .filter()
        .itemIdEqualTo(itemId)
        .keyEqualTo(key)
        .findFirst();
  }

  Future<String?> getValue(int itemId, String key) async {
    final prop = await get(itemId, key);
    return prop?.value;
  }

  Future<List<ItemProperty>> getAll(int itemId) {
    return _isar.itemPropertys
        .filter()
        .itemIdEqualTo(itemId)
        .isVisibleEqualTo(true)
        .sortBySortOrder()
        .findAll();
  }

  Future<void> delete(int itemId, String key) async {
    await _isar.writeTxn(() async {
      await _isar.itemPropertys
          .filter()
          .itemIdEqualTo(itemId)
          .keyEqualTo(key)
          .deleteAll();
    });
  }

  /// Βοηθητικές typed setters

  Future<void> setDate(int itemId, String key, DateTime date) =>
      set(itemId: itemId, key: key, value: date.toIso8601String(), type: PropertyType.date);

  Future<void> setNumber(int itemId, String key, double number, {String? unit}) =>
      set(itemId: itemId, key: key, value: number.toString(), type: PropertyType.number, unit: unit);

  Future<void> setBool(int itemId, String key, bool value) =>
      set(itemId: itemId, key: key, value: value.toString(), type: PropertyType.boolean);

  Future<void> setCurrency(int itemId, String key, double amount, {String unit = '€'}) =>
      set(itemId: itemId, key: key, value: amount.toString(), type: PropertyType.currency, unit: unit);
}

// ─────────────────────────────────────────────────────────────────
// TagRepository (αμετάβλητο)
// ─────────────────────────────────────────────────────────────────

class TagRepository {
  TagRepository(this._isar);
  final Isar _isar;

  Future<Tag> createOrGet(String name, int workspaceId, {String? color}) async {
    final existing = await _isar.tags
        .filter()
        .nameEqualTo(name, caseSensitive: false)
        .workspaceIdEqualTo(workspaceId)
        .findFirst();

    if (existing != null) return existing;

    final tag = Tag()
      ..name = name
      ..workspaceId = workspaceId
      ..color = color
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.tags.put(tag);
    });

    return tag;
  }

  Future<void> addToItem(int itemId, int tagId) async {
    final exists = await _isar.itemTags
        .filter()
        .itemIdEqualTo(itemId)
        .tagIdEqualTo(tagId)
        .count() > 0;

    if (exists) return;

    final itemTag = ItemTag()
      ..itemId = itemId
      ..tagId = tagId
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.itemTags.put(itemTag);
      // Increment usage count
      final tag = await _isar.tags.get(tagId);
      if (tag != null) {
        tag.usageCount++;
        await _isar.tags.put(tag);
      }
    });
  }

  Future<void> removeFromItem(int itemId, int tagId) async {
    await _isar.writeTxn(() async {
      await _isar.itemTags
          .filter()
          .itemIdEqualTo(itemId)
          .tagIdEqualTo(tagId)
          .deleteAll();
      // Decrement usage count
      final tag = await _isar.tags.get(tagId);
      if (tag != null && tag.usageCount > 0) {
        tag.usageCount--;
        await _isar.tags.put(tag);
      }
    });
  }

  Future<List<Tag>> getForItem(int itemId) async {
    final itemTags = await _isar.itemTags
        .filter()
        .itemIdEqualTo(itemId)
        .findAll();

    final tagIds = itemTags.map((it) => it.tagId).toList();
    return _isar.tags.getAll(tagIds).then(
            (tags) => tags.whereType<Tag>().toList());
  }

  Future<List<Item>> getItemsWithTag(int tagId) async {
    final itemTags = await _isar.itemTags
        .filter()
        .tagIdEqualTo(tagId)
        .findAll();

    final itemIds = itemTags.map((it) => it.itemId).toList();
    return _isar.items.getAll(itemIds).then(
            (items) => items.whereType<Item>().where((i) => i.deletedAt == null).toList());
  }

  Future<List<Tag>> getAll(int workspaceId) {
    return _isar.tags
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .sortByUsageCountDesc()
        .findAll();
  }
}

// ─────────────────────────────────────────────────────────────────
// RelationRepository (αμετάβλητο)
// ─────────────────────────────────────────────────────────────────

class RelationRepository {
  RelationRepository(this._isar);
  final Isar _isar;

  Future<Relation> create({
    required int fromItemId,
    required int toItemId,
    required RelationType type,
    String? note,
  }) async {
    final relation = Relation()
      ..fromItemId = fromItemId
      ..toItemId = toItemId
      ..relationType = type
      ..note = note
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.relations.put(relation);
    });

    return relation;
  }

  Future<List<Relation>> getFrom(int itemId) {
    return _isar.relations
        .filter()
        .fromItemIdEqualTo(itemId)
        .findAll();
  }

  Future<List<Relation>> getTo(int itemId) {
    return _isar.relations
        .filter()
        .toItemIdEqualTo(itemId)
        .findAll();
  }

  Future<List<Item>> getRelatedItems(int itemId) async {
    final outgoing = await getFrom(itemId);
    final incoming = await getTo(itemId);

    final relatedIds = {
      ...outgoing.map((r) => r.toItemId),
      ...incoming.map((r) => r.fromItemId),
    }.toList();

    return _isar.items.getAll(relatedIds).then(
            (items) => items.whereType<Item>().where((i) => i.deletedAt == null).toList());
  }

  Future<void> delete(int relationId) async {
    await _isar.writeTxn(() async {
      await _isar.relations.delete(relationId);
    });
  }
}

// ─────────────────────────────────────────────────────────────────
// ReminderRepository (αμετάβλητο)
// ─────────────────────────────────────────────────────────────────

class ReminderRepository {
  ReminderRepository(this._isar);
  final Isar _isar;

  Future<Reminder> create({
    required int itemId,
    required DateTime triggerAt,
    String? rrule,
    String? title,
    String? body,
  }) async {
    final reminder = Reminder()
      ..itemId = itemId
      ..triggerAt = triggerAt
      ..rrule = rrule
      ..title = title
      ..body = body
      ..status = ReminderStatus.pending
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.reminders.put(reminder);
    });

    return reminder;
  }

  Future<List<Reminder>> getPending() {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    return _isar.reminders
        .filter()
        .statusEqualTo(ReminderStatus.pending)
        .triggerAtBetween(now, end, includeLower: true, includeUpper: false)
        .sortByTriggerAt()
        .findAll();
  }

  Stream<List<Reminder>> watchPending() {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    return _isar.reminders
        .filter()
        .statusEqualTo(ReminderStatus.pending)
        .triggerAtBetween(now, end, includeLower: true, includeUpper: false)
        .sortByTriggerAt()
        .watch(fireImmediately: true);
  }

  Future<List<Reminder>> getForItem(int itemId) {
    return _isar.reminders
        .filter()
        .itemIdEqualTo(itemId)
        .sortByTriggerAt()
        .findAll();
  }

  Future<void> markSent(int id) async {
    final r = await _isar.reminders.get(id);
    if (r == null) return;
    r.status = ReminderStatus.sent;
    r.notifiedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.reminders.put(r);
    });
  }

  Future<void> snooze(int id, Duration duration) async {
    final r = await _isar.reminders.get(id);
    if (r == null) return;
    r.status = ReminderStatus.snoozed;
    r.snoozeUntil = DateTime.now().add(duration);
    r.triggerAt = r.snoozeUntil!;
    await _isar.writeTxn(() async {
      await _isar.reminders.put(r);
    });
  }
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.reminders.delete(id);
    });
  }
  Future<int> cleanupOldPending({Duration maxAge = const Duration(days: 7)}) async {
    final cutoff = DateTime.now().subtract(maxAge);
    return _isar.writeTxn(() async {
      return await _isar.reminders
          .filter()
          .statusEqualTo(ReminderStatus.pending)
          .triggerAtLessThan(cutoff)
          .deleteAll();
    });
  }

  Future<List<Reminder>> getPastPending() {
    final now = DateTime.now();
    return _isar.reminders
        .filter()
        .statusEqualTo(ReminderStatus.pending)
        .triggerAtLessThan(now)
        .sortByTriggerAt()
        .findAll();
  }

  /// Ενημερώνει το root reminder ενός item (το πρώτο με rrule)
  /// Βάζει νέο rrule και triggerAt, π.χ. όταν αλλάζει η ημερομηνία γενεθλίων.
  Future<void> updateRootReminderForItem(
    int itemId, {
    required String newRrule,
    required DateTime newTriggerAt,
  }) async {
    final reminders = await getForItem(itemId);
    final root = reminders.where(
      (r) => r.rrule != null && r.parentReminderId == null,
    ).firstOrNull;
    if (root == null) return;
    root.rrule = newRrule;
    root.triggerAt = newTriggerAt;
    root.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.reminders.put(root);
    });
  }

}
// ─────────────────────────────────────────────────────────────────
// FolderRepository (αμετάβλητο εκτός από reorder που προστέθηκε)
// ─────────────────────────────────────────────────────────────────

class FolderRepository {
  FolderRepository(this._isar);
  final Isar _isar;

  Future<Folder> create({
    required String name,
    required int workspaceId,
    String? icon,
    String? color,
    int? parentFolderId,
    double sortOrder = 0.0,
  }) async {
    final folder = Folder()
      ..name = name
      ..workspaceId = workspaceId
      ..icon = icon
      ..color = color
      ..parentFolderId = parentFolderId
      ..sortOrder = sortOrder
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.folders.put(folder);
    });

    return folder;
  }

  Future<List<Folder>> getByWorkspace(int workspaceId, {int? parentId}) {
    if (parentId != null) {
      return _isar.folders
          .filter()
          .workspaceIdEqualTo(workspaceId)
          .parentFolderIdEqualTo(parentId)
          .sortBySortOrder()
          .findAll();
    }
    // Root folders (χωρίς parent)
    return _isar.folders
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .parentFolderIdIsNull()
        .sortBySortOrder()
        .findAll();
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.folders.delete(id);
    });
  }

  Future<Folder?> getById(int id) => _isar.folders.get(id);

  Stream<Folder?> watchById(int id) =>
      _isar.folders.watchObject(id, fireImmediately: true);

  Future<Folder?> update(int id, {
    String? name,
    String? icon,
    String? color,
  }) async {
    final folder = await _isar.folders.get(id);
    if (folder == null) return null;
    if (name  != null) folder.name  = name;
    if (icon  != null) folder.icon  = icon;
    if (color != null) folder.color = color;
    await _isar.writeTxn(() async {
      await _isar.folders.put(folder);
    });
    return folder;
  }

  /// Stream folders ενός workspace — φωτιά ΜΟΝΟ αν αλλάξουν τα folders
  Stream<List<Folder>> watchByWorkspace(int workspaceId, {int? parentId}) {
    if (parentId != null) {
      return _isar.folders
          .filter()
          .workspaceIdEqualTo(workspaceId)
          .parentFolderIdEqualTo(parentId)
          .sortBySortOrder()
          .watch(fireImmediately: true);
    }
    return _isar.folders
        .filter()
        .workspaceIdEqualTo(workspaceId)
        .parentFolderIdIsNull()
        .sortBySortOrder()
        .watch(fireImmediately: true);
  }

  /// Αναδιάταξη φακέλων (drag & drop)
  Future<void> reorder(List<Folder> foldersInNewOrder) async {
    await _isar.writeTxn(() async {
      for (int i = 0; i < foldersInNewOrder.length; i++) {
        final folder = foldersInNewOrder[i];
        folder.sortOrder = i.toDouble();
      }
      await _isar.folders.putAll(foldersInNewOrder);
    });
  }
}

// ─────────────────────────────────────────────────────────────────
// WorkspaceRepository (αμετάβλητο)
// ─────────────────────────────────────────────────────────────────

class WorkspaceRepository {
  WorkspaceRepository(this._isar);
  final Isar _isar;

  Future<Workspace> create({
    required String name,
    String? icon,
    String? color,
    bool isDefault = false,
  }) async {
    if (isDefault) {
      // Αφαίρεσε default από άλλα
      final others = await _isar.workspaces
          .filter()
          .isDefaultEqualTo(true)
          .findAll();
      await _isar.writeTxn(() async {
        for (final ws in others) {
          ws.isDefault = false;
          await _isar.workspaces.put(ws);
        }
      });
    }

    final ws = Workspace()
      ..name = name
      ..icon = icon
      ..color = color
      ..isDefault = isDefault
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.workspaces.put(ws);
    });

    return ws;
  }

  Future<List<Workspace>> getAll() {
    return _isar.workspaces.where().sortBySortOrder().findAll();
  }

  Future<Workspace?> getDefault() {
    return _isar.workspaces
        .filter()
        .isDefaultEqualTo(true)
        .findFirst();
  }
}

// ─────────────────────────────────────────────────────────────────
// AttachmentRepository (αμετάβλητο)
// ─────────────────────────────────────────────────────────────────

class AttachmentRepository {
  AttachmentRepository(this._isar);
  final Isar _isar;

  Future<Attachment> create({
    required int itemId,
    required String fileName,
    required String localPath,
    required String mimeType,
    required int fileSize,
    int? blockId,
    String? thumbnailPath,
    int? width,
    int? height,
    int? durationSeconds,
  }) async {
    final attachment = Attachment()
      ..itemId = itemId
      ..blockId = blockId
      ..fileName = fileName
      ..localPath = localPath
      ..mimeType = mimeType
      ..fileSize = fileSize
      ..thumbnailPath = thumbnailPath
      ..width = width
      ..height = height
      ..durationSeconds = durationSeconds
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.attachments.put(attachment);
    });

    return attachment;
  }

  Future<List<Attachment>> getForItem(int itemId) {
    return _isar.attachments
        .filter()
        .itemIdEqualTo(itemId)
        .sortByCreatedAt()
        .findAll();
  }

  Future<Attachment?> getById(int id) => _isar.attachments.get(id);

  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.attachments.delete(id);
    });
  }
}

// ─────────────────────────────────────────────────────────────────
// SettingsRepository (αμετάβλητο)
// ─────────────────────────────────────────────────────────────────

class SettingsRepository {
  SettingsRepository(this._isar);
  final Isar _isar;

  /// Πάντα χρησιμοποιεί id=1 (singleton)
  Future<AppSettings> get() async {
    return await _isar.appSettings.get(1) ?? AppSettings();
  }

  Future<void> update(void Function(AppSettings) updater) async {
    final settings = await get();
    updater(settings);
    settings.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });
  }

  Stream<AppSettings?> watch() {
    return _isar.appSettings.watchObject(1, fireImmediately: true);
  }
}