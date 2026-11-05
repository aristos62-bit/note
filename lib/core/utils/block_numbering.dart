// lib/core/utils/block_numbering.dart
//
// E39 — μετακίνηση από `lib/shared/widgets/block_editor_widget.dart`.
// Καθαρή συνάρτηση (εξαρτάται μόνο από `models/`), ώστε να μπορεί να τη
// χρησιμοποιήσει το share pipeline χωρίς import widget.
//
// Το `block_editor_widget.dart` κάνει re-export → 0 αλλαγή σε call sites/tests.

import '../../models/item_block.dart';

/// Αρίθμηση αριθμημένων blocks σε ένα πέρασμα — O(n).
///
/// Επιστρέφει, για κάθε block, πόσα blocks τύπου [BlockType.numbered]
/// προηγούνται. Το block tile εμφανίζει `index + 1` μόνο στα numbered,
/// οπότε η αρίθμηση είναι συνεχής σε όλη τη σημείωση (όπως πριν, αλλά χωρίς
/// `sublist(0, i)` ανά block).
List<int> numberedIndexesFor(List<ItemBlock> blocks) {
  final indexes = <int>[];
  var seen = 0;
  for (final b in blocks) {
    indexes.add(seen);
    if (b.type == BlockType.numbered) seen++;
  }
  return indexes;
}