// lib/core/utils/reorder_utils.dart
//
// SPoT για drag-reorder σε φιλτραρισμένες λίστες (Φ4c-44).
// Ενοποιεί 8 sites: entries, item_list, embedded, habit, task (+adapter),
// browser, collections (subset → full merge) + folder_view (ήδη full-merge).
// Pure Dart — χωρίς Riverpod/DB· unit-testable χωρίς Isar (Λ1 S147).
import '../../models/models.dart';
import 'debug_config.dart';

class ReorderUtils {
  ReorderUtils._();

  /// Move [oldIndex]→[newIndex] μέσα στη [filtered] και merge στη [full]:
  /// τα slots των επιζώντων filtered-ids παίρνουν τη νέα σειρά, τα
  /// non-filtered μένουν στις θέσεις τους (pattern HomeFolderView).
  /// Stale ids (διαγραφή μεταξύ build και drop) αγνοούνται —
  /// υπερχείλιση αποδεδειγμένα αδύνατη (place ⊆ full, μοναδικά ids).
  /// Επιστρέφει την ΠΛΗΡΗ λίστα για `ItemNotifier.reorder()`.
  static List<Item> moveAndMerge({
    required List<Item> full,
    required List<Item> filtered,
    required int oldIndex,
    required int newIndex,
    String? debugLabel,
  }) {
    if (oldIndex == newIndex) return List<Item>.from(full);
    final moved = List<Item>.from(filtered);
    final item = moved.removeAt(oldIndex);
    moved.insert(newIndex, item);
    final fullIds = full.map((f) => f.id).toSet();
    final place = moved.where((m) => fullIds.contains(m.id)).toList();
    final placeIds = place.map((m) => m.id).toSet();
    final merged = <Item>[];
    var j = 0;
    for (final f in full) {
      merged.add(placeIds.contains(f.id) ? place[j++] : f);
    }
    final tag = debugLabel == null ? 'ReorderUtils' : 'ReorderUtils[$debugLabel]';
    DebugConfig.db('$tag move full=${full.length} filtered=${filtered.length} $oldIndex→$newIndex');
    DebugConfig.db('$tag merged order: ${_describeOrder(merged)}');
    return merged;
  }

  /// Compact `id:title` σειρά, capped — για οπτική επαλήθευση σειράς στο logcat.
  static String _describeOrder(List<Item> items, [int max = 30]) {
    final shown = items.take(max).map((i) {
      final t = (i.title ?? '').replaceAll('\n', ' ');
      final short = t.length > 20 ? '${t.substring(0, 20)}…' : t;
      return '${i.id}:$short';
    }).join(', ');
    return items.length > max ? '[$shown, …+${items.length - max}]' : '[$shown]';
  }
}
