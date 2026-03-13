// lib/services/habit_service.dart
//
// ═══════════════════════════════════════════════════════════════
// ΟΔΗΓΙΕΣ ΠΡΟΣΑΡΜΟΓΗΣ
// ═══════════════════════════════════════════════════════════════
//
// Τα habits αποθηκεύουν τα δεδομένα τους ως ItemProperties:
//
//   KEY               TYPE      ΠΕΡΙΓΡΑΦΗ
//   ─────────────     ──────    ─────────────────────────────
//   streak            number    Τρέχον streak (ημέρες)
//   best_streak       number    Καλύτερο streak ever
//   goal_count        number    Στόχος (π.χ. 30 φορές)
//   completed_count   number    Πόσες φορές έχει γίνει
//   frequency         text      RRULE (π.χ. FREQ=DAILY)
//   last_completed    date      Τελευταία ολοκλήρωση
//   completions       json      JSON array με DateTime strings
//   unit              text      Μονάδα (π.χ. "λεπτά", "ποτήρια")
//
// ΧΡΗΣΗ στο HabitDetailScreen:
//
//   // Σήμανση ως done:
//   await HabitService.instance.markCompleted(habitItemId);
//
//   // Φόρτωσε stats:
//   final stats = await HabitService.instance.getStats(habitItemId);
//
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import '../helpers/super_note_helper.dart';
import '../models/item_property.dart';

class HabitStats {
  final int streak;
  final int bestStreak;
  final int completedCount;
  final int goalCount;
  final DateTime? lastCompleted;
  final List<DateTime> completions;
  final bool completedToday;
  final double progressPercent;

  const HabitStats({
    required this.streak,
    required this.bestStreak,
    required this.completedCount,
    required this.goalCount,
    required this.lastCompleted,
    required this.completions,
    required this.completedToday,
    required this.progressPercent,
  });
}

class HabitService {
  HabitService._internal();
  static final HabitService instance = HabitService._internal();

  // ─────────────────────────────────────────────────────────
  // Σήμανση ολοκλήρωσης για σήμερα
  // ─────────────────────────────────────────────────────────

  Future<HabitStats> markCompleted(int habitItemId) async {
    final props = SuperNoteHelper.instance.properties;
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Φόρτωσε completions
    final completionsJson = await props.getValue(habitItemId, 'completions');
    final completions = _parseCompletions(completionsJson);

    // Αν έχει ήδη γίνει σήμερα, μην ξανακαταχωρήσεις
    final alreadyToday = completions.any((d) =>
    DateTime(d.year, d.month, d.day) == today);
    if (!alreadyToday) {
      completions.add(now);

      // Αποθήκευσε completions
      await props.set(
        itemId: habitItemId,
        key: 'completions',
        value: jsonEncode(
            completions.map((d) => d.toIso8601String()).toList()),
        type: PropertyType.json,
      );

      // Ενημέρωσε last_completed
      await props.setDate(habitItemId, 'last_completed', now);

      // Ενημέρωσε completed_count
      final count = (await props.getValue(habitItemId, 'completed_count'));
      final newCount = (double.tryParse(count ?? '0') ?? 0) + 1;
      await props.setNumber(habitItemId, 'completed_count', newCount);
    }

    // Υπολόγισε και αποθήκευσε streak
    final newStreak = _calculateStreak(completions);
    await props.setNumber(habitItemId, 'streak', newStreak.toDouble());

    // Ενημέρωσε best streak
    final bestStr = await props.getValue(habitItemId, 'best_streak');
    final best = double.tryParse(bestStr ?? '0') ?? 0;
    if (newStreak > best) {
      await props.setNumber(
          habitItemId, 'best_streak', newStreak.toDouble());
    }

    return getStats(habitItemId);
  }

  // ─────────────────────────────────────────────────────────
  // Φόρτωσε stats για habit
  // ─────────────────────────────────────────────────────────

  Future<HabitStats> getStats(int habitItemId) async {
    final props = SuperNoteHelper.instance.properties;

    final completionsJson =
    await props.getValue(habitItemId, 'completions');
    final completions = _parseCompletions(completionsJson);

    final streak = (await props.getValue(habitItemId, 'streak'));
    final bestStreak = (await props.getValue(habitItemId, 'best_streak'));
    final completedCount =
    (await props.getValue(habitItemId, 'completed_count'));
    final goalCount = (await props.getValue(habitItemId, 'goal_count'));
    final lastCompletedStr =
    await props.getValue(habitItemId, 'last_completed');

    final goal   = double.tryParse(goalCount ?? '0') ?? 0;
    final done   = double.tryParse(completedCount ?? '0') ?? 0;
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);

    final completedToday = completions.any((d) =>
    DateTime(d.year, d.month, d.day) == today);

    return HabitStats(
      streak: (double.tryParse(streak ?? '0') ?? 0).toInt(),
      bestStreak: (double.tryParse(bestStreak ?? '0') ?? 0).toInt(),
      completedCount: done.toInt(),
      goalCount: goal.toInt(),
      lastCompleted: lastCompletedStr != null
          ? DateTime.tryParse(lastCompletedStr)
          : null,
      completions: completions,
      completedToday: completedToday,
      progressPercent: goal > 0 ? (done / goal * 100).clamp(0, 100) : 0,
    );
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE — Υπολογισμός streak
  // ─────────────────────────────────────────────────────────

  int _calculateStreak(List<DateTime> completions) {
    if (completions.isEmpty) return 0;

    // Μοναδικές ημέρες, ταξινομημένες φθίνουσα
    final days = completions
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final today     = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterday = todayDate.subtract(const Duration(days: 1));

    // Αν η τελευταία μέρα δεν είναι σήμερα ή χθες, streak = 0
    if (days.first != todayDate && days.first != yesterday) return 0;

    int streak = 1;
    for (int i = 1; i < days.length; i++) {
      final diff = days[i - 1].difference(days[i]).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  List<DateTime> _parseCompletions(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((s) => DateTime.tryParse(s.toString()))
          .whereType<DateTime>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}