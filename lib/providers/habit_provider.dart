import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart';
import '../services/habit_service.dart';
import 'db_provider.dart';
import '../core/utils/debug_config.dart';

// Real-time habit (Item) by id
final habitStreamProvider =
StreamProvider.family<Item?, int>((ref, id) {
  final db = ref.watch(dbProvider);
  return db.items.watchById(id);
});

// Real-time *stats* για habit
final habitStatsProvider =
FutureProvider.family<HabitStats, int>((ref, habitId) async {
  DebugConfig.db('habitStatsProvider id=$habitId');

  // Όποτε αλλάζει το habit, ξαναϋπολογίζουμε stats
  ref.watch(habitStreamProvider(habitId));

  final stats = await HabitService.instance.getStats(habitId);
  DebugConfig.db(
      'stats id=$habitId today=${stats.completedToday} total=${stats.completedCount}');
  return stats;
});
