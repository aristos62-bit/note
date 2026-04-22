// lib/services/habit_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../helpers/super_note_helper.dart';
import '../models/item_property.dart';
import '../models/recurrence.dart';   // ✅ κεντρικός ορισμός
import '../core/core.dart';
import 'reminder_scheduler.dart';

// ─────────────────────────────────────────────────────────────
// HabitStats
// ─────────────────────────────────────────────────────────────

class HabitStats {
  final int streak;
  final int bestStreak;
  final int completedCount;
  final int goalCount;
  final DateTime? lastCompleted;
  final List<DateTime> completions;
  final bool completedToday;
  final double progressPercent;
  final int dailyProgress;
  final String unit;
  final Recurrence recurrence;

  const HabitStats({
    required this.streak,
    required this.bestStreak,
    required this.completedCount,
    required this.goalCount,
    required this.lastCompleted,
    required this.completions,
    required this.completedToday,
    required this.progressPercent,
    required this.dailyProgress,
    required this.unit,
    required this.recurrence,
  });
}

// ─────────────────────────────────────────────────────────────
// HabitService
// ─────────────────────────────────────────────────────────────

class HabitService {
  HabitService._internal();
  static final HabitService instance = HabitService._internal();

  int _parseToInt(String? s) {
    if (s == null) return 0;
    final d = double.tryParse(s);
    return d == null ? 0 : d.toInt();
  }

  Future<Map<String, String?>> _getAllProps(int habitId) async {
    final props = await SuperNoteHelper.instance.properties.getAll(habitId);
    final map = <String, String?>{};
    for (final p in props) {map[p.key] = p.value;}
    return map;
  }

  Future<DateTime> _ensurePeriodStart(int habitId, Recurrence recurrence) async {
    final props = SuperNoteHelper.instance.properties;
    final now = DateTime.now();
    final periodStartStr = await props.getValue(habitId, 'period_start');
    if (periodStartStr != null) {
      return DateTime.parse(periodStartStr);
    }
    final periodStart = recurrence.getPeriodStart(now);
    await props.setDate(habitId, 'period_start', periodStart);
    return periodStart;
  }

  Future<void> _resetDailyIfNeeded(int habitId, Recurrence recurrence) async {
    final props = SuperNoteHelper.instance.properties;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastDateStr = await props.getValue(habitId, 'last_progress_date');
    DateTime? lastDate;
    if (lastDateStr != null) lastDate = DateTime.tryParse(lastDateStr);

    bool isSameDay = false;
    if (lastDate != null) {
      isSameDay = lastDate.year == today.year && lastDate.month == today.month && lastDate.day == today.day;
    }
    if (!isSameDay) {
      await props.setNumber(habitId, 'daily_progress', 0.0);
      await props.setDate(habitId, 'last_progress_date', now);
    }
  }

  Future<void> _markPeriodCompleted(int habitId, DateTime periodStart) async {
    final props = SuperNoteHelper.instance.properties;
    final completionsJson = await props.getValue(habitId, 'period_completions');
    List<DateTime> completions = [];
    if (completionsJson != null && completionsJson.isNotEmpty) {
      try {
        final list = jsonDecode(completionsJson) as List;
        completions = list.map((s) => DateTime.parse(s.toString())).toList();
      } catch (_) {}
    }
    if (!completions.contains(periodStart)) {
      completions.add(periodStart);
      await props.set(
        itemId: habitId,
        key: 'period_completions',
        value: jsonEncode(completions.map((d) => d.toIso8601String()).toList()),
        type: PropertyType.json,
      );
      final countStr = await props.getValue(habitId, 'completed_count');
      final newCount = _parseToInt(countStr) + 1;
      await props.setNumber(habitId, 'completed_count', newCount.toDouble());
      await props.setDate(habitId, 'last_completed', periodStart);

      final sorted = [...completions]..sort((a,b) => b.compareTo(a));
      int streak = 1;
      DateTime? prev = sorted.first;
      for (int i = 1; i < sorted.length; i++) {
        if (prev!.difference(sorted[i]).inDays == 1) {
          streak++;
          prev = sorted[i];
        } else {break;}
      }
      await props.setNumber(habitId, 'streak', streak.toDouble());

      final bestStr = await props.getValue(habitId, 'best_streak');
      final best = _parseToInt(bestStr);
      if (streak > best) {
        await props.setNumber(habitId, 'best_streak', streak.toDouble());
      }
    }
  }

  Future<HabitStats> incrementProgress(int habitId) async {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);
    final goal = _parseToInt(allProps['goal_per_period']);

    await _resetDailyIfNeeded(habitId, recurrence);
    final periodStart = await _ensurePeriodStart(habitId, recurrence);

    int dailyProgress = 0;
    final progressStr = await props.getValue(habitId, 'daily_progress');
    if (progressStr != null) dailyProgress = _parseToInt(progressStr);

    if (goal > 0 && dailyProgress >= goal) return getStats(habitId);

    dailyProgress++;
    await props.setNumber(habitId, 'daily_progress', dailyProgress.toDouble());

    if (goal > 0 && dailyProgress >= goal) {
      await _markPeriodCompleted(habitId, periodStart);
    }

    return getStats(habitId);
  }

  Future<HabitStats> decrementProgress(int habitId) async {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);

    await _resetDailyIfNeeded(habitId, recurrence);

    int dailyProgress = 0;
    final progressStr = await props.getValue(habitId, 'daily_progress');
    if (progressStr != null) dailyProgress = _parseToInt(progressStr);

    if (dailyProgress > 0) {
      dailyProgress--;
      await props.setNumber(habitId, 'daily_progress', dailyProgress.toDouble());
    }
    return getStats(habitId);
  }

  Future<HabitStats> markCompleted(int habitId) async => incrementProgress(habitId);

  Future<void> setGoal(int habitId, int goal) async {
    await SuperNoteHelper.instance.properties.setNumber(habitId, 'goal_per_period', goal.toDouble());
  }

  Future<void> setUnit(int habitId, String unit) async {
    await SuperNoteHelper.instance.properties.set(
      itemId: habitId, key: 'unit', value: unit, type: PropertyType.text,
    );
  }

  Future<void> setRecurrence(int habitId, Recurrence recurrence) async {
    final props = SuperNoteHelper.instance.properties;
    await props.set(
      itemId: habitId,
      key: 'recurrence_type',
      value: recurrence.type.name,
      type: PropertyType.text,
    );
    await props.setNumber(habitId, 'recurrence_interval', recurrence.interval.toDouble());
    if (recurrence.days != null && recurrence.days!.isNotEmpty) {
      await props.set(
        itemId: habitId,
        key: 'recurrence_days',
        value: jsonEncode(recurrence.days),
        type: PropertyType.json,
      );
    } else {
      await props.delete(habitId, 'recurrence_days');
    }
    if (recurrence.dayOfMonth != null) {
      await props.set(
        itemId: habitId,
        key: 'recurrence_days',
        value: recurrence.dayOfMonth.toString(),
        type: PropertyType.text,
      );
    } else if (recurrence.type != RecurrenceType.weekly) {
      await props.delete(habitId, 'recurrence_days');
    }
    final periodStart = recurrence.getPeriodStart(DateTime.now());
    await props.setDate(habitId, 'period_start', periodStart);
    await props.setNumber(habitId, 'daily_progress', 0.0);
  }

  Future<void> setReminderTime(int habitId, TimeOfDay? time) async {
    final props = SuperNoteHelper.instance.properties;
    if (time == null) {
      DebugConfig.db('🕒 Disabling reminders for habit $habitId');
      await props.delete(habitId, 'reminder_time');
      await ReminderScheduler.instance.cancelAllForItem(habitId);
      final reminders = await SuperNoteHelper.instance.reminders.getForItem(habitId);
      for (final r in reminders) {await SuperNoteHelper.instance.reminders.delete(r.id);}
    } else {
      DebugConfig.db('🕒 Enabling reminder for habit $habitId at ${time.hour}:${time.minute}');
      final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      await props.set(
        itemId: habitId, key: 'reminder_time', value: timeStr, type: PropertyType.text,
      );
      final allProps = await _getAllProps(habitId);
      final recurrence = Recurrence.fromProperties(allProps);
      await _scheduleReminders(habitId, time, recurrence);
    }
  }

  Future<void> _scheduleReminders(int habitId, TimeOfDay time, Recurrence recurrence) async {
    await ReminderScheduler.instance.cancelAllForItem(habitId);
    final old = await SuperNoteHelper.instance.reminders.getForItem(habitId);
    for (final r in old) {await SuperNoteHelper.instance.reminders.delete(r.id);}

    final now = DateTime.now();
    final end = now.add(const Duration(days: 60));
    DateTime current = now;
    int count = 0;
    const maxReminders = 40;

    while (current.isBefore(end) && count < maxReminders) {
      final nextOccurrence = _nextOccurrence(recurrence, time, current);
      if (nextOccurrence.isAfter(now) && nextOccurrence.isBefore(end)) {
        final item = await SuperNoteHelper.instance.items.getById(habitId);
        final title = item?.title ?? 'Συνήθεια';
        final reminder = await SuperNoteHelper.instance.reminders.create(
          itemId: habitId,
          triggerAt: nextOccurrence,
          rrule: recurrence.toRRULE(),
          title: 'Υπενθύμιση συνήθειας',
          body: 'Υπενθύμιση: $title',
        );
        await ReminderScheduler.instance.scheduleReminder(reminder);
        current = nextOccurrence.add(const Duration(days: 1));
        count++;
      } else {
        break;
      }
    }
  }

  DateTime _nextOccurrence(Recurrence recurrence, TimeOfDay time, DateTime after) {
    DateTime candidate = DateTime(after.year, after.month, after.day, time.hour, time.minute);
    if (candidate.isBefore(after)) {
      candidate = recurrence.nextPeriodStart(candidate).add(Duration(hours: time.hour, minutes: time.minute));
    }
    if (recurrence.type == RecurrenceType.weekly && recurrence.days != null && recurrence.days!.isNotEmpty) {
      while (!recurrence.days!.contains(candidate.weekday)) {
        candidate = candidate.add(const Duration(days: 1));
      }
    }
    if (recurrence.type == RecurrenceType.monthly && recurrence.dayOfMonth != null) {
      final periodStart = recurrence.getPeriodStart(candidate);
      candidate = DateTime(periodStart.year, periodStart.month, recurrence.dayOfMonth!, time.hour, time.minute);
      if (candidate.isBefore(after)) {
        final nextPeriod = recurrence.nextPeriodStart(periodStart);
        candidate = DateTime(nextPeriod.year, nextPeriod.month, recurrence.dayOfMonth!, time.hour, time.minute);
      }
    }
    return candidate;
  }

  Future<HabitStats> getStats(int habitId) async {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);
    final unit = allProps['unit'] ?? '';
    final goal = _parseToInt(allProps['goal_per_period']);

    await _resetDailyIfNeeded(habitId, recurrence);

    final completionsJson = await props.getValue(habitId, 'period_completions');
    List<DateTime> completions = [];
    if (completionsJson != null && completionsJson.isNotEmpty) {
      try {
        final list = jsonDecode(completionsJson) as List;
        completions = list.map((s) => DateTime.parse(s.toString())).toList();
      } catch (_) {}
    }

    int dailyProgress = 0;
    final progressStr = await props.getValue(habitId, 'daily_progress');
    if (progressStr != null) dailyProgress = _parseToInt(progressStr);

    final completedToday = goal > 0 && dailyProgress >= goal;
    final progressPercent = goal > 0 ? (dailyProgress / goal * 100).clamp(0.0, 100.0) : 0.0;

    int streak = 0;
    if (completions.isNotEmpty) {
      final sorted = [...completions]..sort((a,b) => b.compareTo(a));
      streak = 1;
      DateTime? prev = sorted.first;
      for (int i = 1; i < sorted.length; i++) {
        if (prev!.difference(sorted[i]).inDays == 1) {
          streak++;
          prev = sorted[i];
        } else {break;}
      }
    }
    final bestStr = allProps['best_streak'];
    int bestStreak = _parseToInt(bestStr);
    if (streak > bestStreak) {
      bestStreak = streak;
      await props.setNumber(habitId, 'best_streak', bestStreak.toDouble());
    } else {
      if (completions.length > 1) {
        final sorted = [...completions]..sort((a,b) => a.compareTo(b));
        int current = 1, best = 1;
        for (int i = 1; i < sorted.length; i++) {
          if (sorted[i-1].difference(sorted[i]).inDays == 1) {
            current++;
            if (current > best) best = current;
          } else {current = 1;}
        }
        if (best > bestStreak) {
          bestStreak = best;
          await props.setNumber(habitId, 'best_streak', bestStreak.toDouble());
        }
      }
    }

    return HabitStats(
      streak: streak,
      bestStreak: bestStreak,
      completedCount: completions.length,
      goalCount: goal,
      lastCompleted: completions.isNotEmpty ? completions.last : null,
      completions: completions,
      completedToday: completedToday,
      progressPercent: progressPercent,
      dailyProgress: dailyProgress,
      unit: unit,
      recurrence: recurrence,
    );
  }
}