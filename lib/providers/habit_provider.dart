import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart';
import '../services/habit_service.dart';
import 'db_provider.dart';

// Real-time habit (Item) by id
final habitStreamProvider =
StreamProvider.family<Item?, int>((ref, id) {
  final db = ref.watch(dbProvider);
  return db.items.watchById(id);
});

// Real-time *stats* για habit
// ✅ ΜΕΤΑ:
final habitStatsProvider =
FutureProvider.family<HabitStats, int>((ref, habitId) async {
  // Αντί για watch, χρησιμοποιούμε listen μόνο για invalidation
  ref.listen(habitStreamProvider(habitId), (_, __) {
    ref.invalidateSelf();
  });
  final stats = await HabitService.instance.getStats(habitId);
  return stats;
});
