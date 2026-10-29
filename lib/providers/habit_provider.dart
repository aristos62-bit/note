import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart';
import '../services/habit_service.dart';
import 'db_provider.dart';
import 'ui_provider.dart';

// Real-time habit (Item) by id
final habitStreamProvider =
StreamProvider.family<Item?, int>((ref, id) {
  final db = ref.watch(dbProvider);
  return db.items.watchById(id);
});

/// Real-time *stats* για habit
// ✅ select στο updatedAt — αποφεύγει rebuild loop από property writes
final habitStatsProvider =
FutureProvider.family<HabitStats, int>((ref, habitId) async {
  // Αλλαγή μέρας → recompute (το cached αποτέλεσμα της χθεσινής μέρας
  // δεν πρέπει να επιβιώνει μετά τα μεσάνυχτα). SPoT: ui_provider.dart.
  ref.watch(dayTickProvider);
  // Ακούμε ΜΟΝΟ το updatedAt του item — όχι κάθε property write
  ref.listen(
    habitStreamProvider(habitId).select(
          (value) => value.valueOrNull?.updatedAt,
    ),
        (_, __) => ref.invalidateSelf(),
  );
  final stats = await HabitService.instance.getStats(habitId);
  return stats;
});
