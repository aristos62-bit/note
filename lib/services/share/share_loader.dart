// lib/services/share/share_loader.dart
//
// E39 — Load: φορτώνει ό,τι χρειάζεται το render με **batch** queries
// (όχι N+1). Καμία εγγραφή στη DB, κανένα side effect.

import 'dart:convert';

import '../../core/core.dart';
import '../../helpers/super_note_helper.dart';
import '../../models/models.dart';

/// Πλήρες υλικό ενός item, φορτωμένο **μία φορά**.
class ShareData {
  const ShareData({
    required this.item,
    this.blocks = const [],
    this.properties = const [],
    this.subtasks = const [],
    this.attachments = const [],
    this.fields = const [],
    this.collectionName,
  });

  final Item item;
  final List<ItemBlock> blocks;
  final List<ItemProperty> properties;
  final List<Item> subtasks;

  /// Συνημμένα του item + όσα αναφέρονται σε attachment fields (χωρίς
  /// διπλότυπα). Η επιλογή/φιλτράρισμα γίνεται στο `share_attachments.dart`.
  final List<Attachment> attachments;

  /// Schema συλλογής — μόνο για `ItemType.knowledge`, αλλιώς κενό.
  final List<FieldDef> fields;

  /// Όνομα parent συλλογής — μόνο για `ItemType.knowledge`.
  final String? collectionName;
}

class ShareLoader {
  ShareLoader._();

  /// Φορτώνει item + εξαρτήματα. `null` αν το item δεν βρέθηκε (διαγραμμένο).
  static Future<ShareData?> load(int itemId) async {
    final item = await SuperNoteHelper.instance.items.getById(itemId);
    if (item == null) return null;
    return loadFor(item);
  }

  /// Ίδιο με το [load], για item που έχουμε ήδη.
  static Future<ShareData> loadFor(Item item) async {
    final helper = SuperNoteHelper.instance;

    final loaded = await Future.wait([
      helper.blocks.getByItem(item.id),
      helper.properties.getAll(item.id),
      helper.attachments.getForItem(item.id),
    ]);
    final blocks = loaded[0] as List<ItemBlock>;
    final properties = loaded[1] as List<ItemProperty>;
    final direct = loaded[2] as List<Attachment>;

    var subtasks = const <Item>[];
    if (item.type == ItemType.task || item.type == ItemType.checklist) {
      subtasks = await _subtasksOf(item);
    }

    var fields = const <FieldDef>[];
    String? collectionName;
    var fieldAttachments = const <Attachment>[];
    if (item.type == ItemType.knowledge) {
      final extras = await _knowledgeExtras(properties);
      fields = extras.fields;
      collectionName = extras.collectionName;
      fieldAttachments = extras.attachments;
    }

    return ShareData(
      item: item,
      blocks: blocks,
      properties: properties,
      subtasks: subtasks,
      attachments: _merge(direct, fieldAttachments),
      fields: fields,
      collectionName: collectionName,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Υποεργασίες — 2 queries αντί για N+1
  // ─────────────────────────────────────────────────────────────

  static Future<List<Item>> _subtasksOf(Item item) async {
    final helper = SuperNoteHelper.instance;
    final allTasks = await helper.items.getByWorkspace(
      item.workspaceId,
      type: ItemType.task,
    );
    final candidates =
    allTasks.where((t) => t.id != item.id).toList(growable: false);
    if (candidates.isEmpty) return const [];

    final propsMap = await helper.properties.getAllForItems(
      candidates.map((t) => t.id).toList(growable: false),
    );

    final subtasks = candidates.where((t) {
      final pid =
          propsMap[t.id]?.where((p) => p.key == 'parent_id').firstOrNull?.value;
      return pid != null && int.tryParse(pid) == item.id;
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return subtasks;
  }

  // ─────────────────────────────────────────────────────────────
  // Knowledge entry: schema + collection name + files από fields
  // ─────────────────────────────────────────────────────────────

  static Future<
      ({
      List<FieldDef> fields,
      String? collectionName,
      List<Attachment> attachments,
      })> _knowledgeExtras(List<ItemProperty> properties) async {
    final helper = SuperNoteHelper.instance;

    final collectionId = collectionIdOf(properties);
    if (collectionId == null) {
      return (
      fields: const <FieldDef>[],
      collectionName: null,
      attachments: const <Attachment>[],
      );
    }

    final loaded = await Future.wait([
      helper.properties.get(collectionId, 'schema'),
      helper.items.getById(collectionId),
    ]);
    final schemaProp = loaded[0] as ItemProperty?;
    final collection = loaded[1] as Item?;

    // Exception-safe: '' ή άκυρο JSON → κενή λίστα (όπως πριν).
    final fields = FieldDef.listFromJson(schemaProp?.value ?? '');

    final ids = <int>[];
    for (final field in fields) {
      if (field.type != FieldType.attachment) continue;
      final raw =
          properties.where((p) => p.key == field.key).firstOrNull?.value;
      if (raw == null || raw.isEmpty) continue;
      ids.addAll(_parseIds(raw));
    }

    final attachments = ids.isEmpty
        ? const <Attachment>[]
        : await helper.attachments.getByIds(ids);

    return (
    fields: fields,
    collectionName: collection?.title,
    attachments: attachments,
    );
  }

  /// `[1,2,3]` → `[1,2,3]` — ανεκτικό σε `num`, σιωπή σε άκυρο JSON.
  static List<int> _parseIds(String raw) {
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.whereType<num>().map((e) => e.toInt()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Direct πρώτα (createdAt order), μετά τα field attachments χωρίς διπλότυπα.
  static List<Attachment> _merge(
      List<Attachment> direct,
      List<Attachment> extra,
      ) {
    if (extra.isEmpty) return direct;

    final seen = direct.map((a) => a.id).toSet();
    final out = <Attachment>[...direct];
    for (final attachment in extra) {
      if (seen.add(attachment.id)) out.add(attachment);
    }
    return out;
  }
}