// lib/core/utils/collection_id.dart
//
// E39 — μετακίνηση από `lib/features/collections/knowledge_entry_nav.dart`.
// Καθαρή συνάρτηση (μόνο `models/`), ώστε να τη χρησιμοποιεί και το share
// pipeline χωρίς import feature screen.
//
// Το `knowledge_entry_nav.dart` κάνει re-export → 0 αλλαγή σε call sites/tests.

import 'package:collection/collection.dart';

import '../../models/item_property.dart';

/// Pure: collection_id από properties (null αν λείπει/άκυρο) — unit-testable.
int? collectionIdOf(List<ItemProperty> props) {
  final raw =
      props.where((p) => p.key == 'collection_id').firstOrNull?.value;
  if (raw == null) return null;
  return int.tryParse(raw);
}