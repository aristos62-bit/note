// lib/features/collections/knowledge_entry_nav.dart
//
// SPoT για το άνοιγμα εγγραφής συλλογής (knowledge + collection_id).
// Ενοποιεί 2 privates: search _openKnowledgeEntry + home _openKnowledgeEntry.
// Reconcile διαφορών: itemByIdProvider (one-shot Future, όχι stream) +
// context.mounted (αυστηρότερο από state-mounted).
// FieldDef.listFromJson exception-safe → κανένα try-catch εδώ.
//
// ΧΡΗΣΗ:
//   if (item.type == ItemType.knowledge) {
//     openKnowledgeEntry(context, ref, item);
//     return;
//   }
//
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'collection_entries_screen.dart';
import 'collection_fields.dart' show FieldDef;

/// Pure: collection_id από properties (null αν λείπει/άκυρο) — unit-testable.
int? collectionIdOf(List<ItemProperty> props) {
  final raw =
      props.where((p) => p.key == 'collection_id').firstOrNull?.value;
  if (raw == null) return null;
  return int.tryParse(raw);
}

/// Ανοίγει CollectionEntryDetailScreen. Ορφανές → σιωπή + log (status quo).
Future<void> openKnowledgeEntry(
    BuildContext context, WidgetRef ref, Item entry) async {
  DebugConfig.nav('KnowledgeEntry open id=${entry.id}');
  final props = await ref.read(itemPropertiesProvider(entry.id).future);
  final collectionId = collectionIdOf(props);
  if (collectionId == null) {
    DebugConfig.error('Knowledge entry without collection_id', null);
    return;
  }
  final collection =
      await ref.read(itemByIdProvider(collectionId).future);
  if (collection == null) {
    DebugConfig.warning('KnowledgeEntry collection $collectionId not found');
    return;
  }
  final collectionProps =
      await ref.read(itemPropertiesProvider(collectionId).future);
  final schemaJson =
      collectionProps.where((p) => p.key == 'schema').firstOrNull?.value ?? '';
  final fields = FieldDef.listFromJson(schemaJson);
  if (!context.mounted) return;
  DebugConfig.nav(
      'KnowledgeEntry → collection=$collectionId entry=${entry.id}');
  Navigator.of(context).push(AppTransitions.slideRoute(
    CollectionEntryDetailScreen(
      entryId: entry.id,
      collectionId: collectionId,
      fields: fields,
      isNew: false,
    ),
  ));
}
