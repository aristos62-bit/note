// lib/services/habit_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../helpers/super_note_helper.dart';
import '../models/item_property.dart';
import '../models/recurrence.dart';
import '../core/core.dart';
import 'reminder_scheduler.dart';

// ─────────────────────────────────────────────────────────────
// HabitStats
// ─────────────────────────────────────────────────────────────

class HabitStats {
  final int streak;
  final int bestStreak;
  final int completedCount;         // πλήρως ολοκληρωμένες περίοδοι
  final int goalCount;              // effective goal
  final DateTime? lastCompleted;
  final List<DateTime> completions; // ατομικές ημέρες επίτευξης
  final bool completedToday;
  final double progressPercent;     // 0-100
  final int dailyProgress;
  final String unit;
  final Recurrence recurrence;

  /// Για daily με ώρες: ποιες ώρες έχουν ολοκληρωθεί σήμερα
  /// key: "08:00", value: true/false
  final Map<String, bool> todayTimeProgress;

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
    this.todayTimeProgress = const {},
  });
}

// ─────────────────────────────────────────────────────────────
// HabitService
// ─────────────────────────────────────────────────────────────

class HabitService {
  HabitService._internal();
  static final HabitService instance = HabitService._internal();

  // ══════════════════════════════════════════════════════════
  // ΒΟΗΘΗΤΙΚΕΣ
  // ══════════════════════════════════════════════════════════

  int _parseToInt(String? s) {
    if (s == null) return 0;
    final d = double.tryParse(s);
    return d == null ? 0 : d.toInt();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _safeDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDay));
  }

  Future<Map<String, String?>> _getAllProps(int habitId) async {
    final props = await SuperNoteHelper.instance.properties.getAll(habitId);
    final map = <String, String?>{};
    for (final p in props) {
      map[p.key] = p.value;
    }
    return map;
  }

  // ══════════════════════════════════════════════════════════
  // EFFECTIVE GOAL
  // Υπολογίζει τον πραγματικό στόχο βάσει επανάληψης:
  //   daily + times [08:00, 11:00, 16:00, 20:00] → 4
  //   weekly [Δευ, Τετ] + savedGoal=1            → 2
  //   monthly [1η, 15η] + savedGoal=1             → 2
  //   καμία → savedGoal
  // ══════════════════════════════════════════════════════════

  int _effectiveGoal(int savedGoal, Recurrence recurrence) {
    if (recurrence.type == RecurrenceType.daily &&
        recurrence.times != null &&
        recurrence.times!.isNotEmpty) {
      return recurrence.times!.length;
    }
    if (recurrence.type == RecurrenceType.weekly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      return recurrence.days!.length * (savedGoal > 0 ? savedGoal : 1);
    }
    if (recurrence.type == RecurrenceType.monthly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      return recurrence.days!.length * (savedGoal > 0 ? savedGoal : 1);
    }
    return savedGoal;
  }

  // ══════════════════════════════════════════════════════════
  // TIME PROGRESS — για daily habits με ώρες
  // Αποθηκεύει ποιες ώρες ολοκληρώθηκαν σήμερα
  // key: "today_time_progress" → JSON {"08:00": true, "11:00": false}
  // ══════════════════════════════════════════════════════════

  Future<Map<String, bool>> _loadTodayTimeProgress(
      int habitId, List<String> times) async {
    final json = await SuperNoteHelper.instance.properties
        .getValue(habitId, 'today_time_progress');

    final result = <String, bool>{};
    for (final t in times) {
      result[t] = false;
    }

    if (json == null || json.isEmpty) return result;

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      for (final t in times) {
        result[t] = map[t] == true;
      }
    } catch (_) {}

    return result;
  }

  Future<void> _saveTodayTimeProgress(
      int habitId, Map<String, bool> progress) async {
    await SuperNoteHelper.instance.properties.set(
      itemId: habitId,
      key: 'today_time_progress',
      value: jsonEncode(progress),
      type: PropertyType.json,
    );
  }

  // ══════════════════════════════════════════════════════════
  // ΑΤΟΜΙΚΕΣ ΗΜΕΡΕΣ ΟΛΟΚΛΗΡΩΣΗΣ
  // ══════════════════════════════════════════════════════════

  Future<List<DateTime>> _loadDayCompletions(int habitId) async {
    final json = await SuperNoteHelper.instance.properties
        .getValue(habitId, 'period_completions');
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((s) => _dateOnly(DateTime.parse(s.toString())))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveDayCompletions(
      int habitId, List<DateTime> completions) async {
    await SuperNoteHelper.instance.properties.set(
      itemId: habitId,
      key: 'period_completions',
      value: jsonEncode(
          completions.map((d) => d.toIso8601String()).toList()),
      type: PropertyType.json,
    );
  }

  Future<void> _markDayCompleted(int habitId, DateTime date) async {
    final today = _dateOnly(date);
    final completions = await _loadDayCompletions(habitId);
    if (completions.any((d) => _isSameDay(d, today))) return;
    completions.add(today);
    await _saveDayCompletions(habitId, completions);
    await SuperNoteHelper.instance.properties
        .setDate(habitId, 'last_completed', today);
  }

  Future<void> _unmarkDayCompleted(int habitId, DateTime date) async {
    final today = _dateOnly(date);
    final completions = await _loadDayCompletions(habitId);
    final updated =
    completions.where((d) => !_isSameDay(d, today)).toList();
    if (updated.length == completions.length) return;
    await _saveDayCompletions(habitId, updated);
  }

  // ══════════════════════════════════════════════════════════
  // RESET ΗΜΕΡΗΣΙΑΣ ΠΡΟΟΔΟΥ
  // ══════════════════════════════════════════════════════════

  Future<void> _resetDailyIfNeeded(
      int habitId, Recurrence recurrence) async {
    final props = SuperNoteHelper.instance.properties;
    final now = DateTime.now();
    final today = _dateOnly(now);

    final lastDateStr =
    await props.getValue(habitId, 'last_progress_date');
    DateTime? lastDate;
    if (lastDateStr != null) lastDate = DateTime.tryParse(lastDateStr);

    final isSameDay = lastDate != null && _isSameDay(lastDate, today);
    if (!isSameDay) {
      await props.setNumber(habitId, 'daily_progress', 0.0);
      await props.setDate(habitId, 'last_progress_date', now);
      // Reset time progress για νέα μέρα
      if (recurrence.type == RecurrenceType.daily &&
          recurrence.times != null &&
          recurrence.times!.isNotEmpty) {
        await props.set(
          itemId: habitId,
          key: 'today_time_progress',
          value: jsonEncode({}),
          type: PropertyType.json,
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  // ΕΛΕΓΧΟΣ ΟΛΟΚΛΗΡΩΣΗΣ ΠΕΡΙΟΔΟΥ
  // daily + times:   ΟΛΕΣ οι ώρες ✓ (μέσω dayCompletion)
  // daily (no times): η ίδια η μέρα ✓
  // weekly + days:   ΟΛΕΣ οι προγραμματισμένες μέρες ✓
  // weekly (no days): αρκεί 1 ολοκλήρωση
  // monthly + days:  ΟΛΕΣ οι προγραμματισμένες ημέρες ✓
  // monthly (no days): αρκεί 1 ολοκλήρωση
  // ══════════════════════════════════════════════════════════

  bool _isPeriodComplete(
      DateTime periodStart,
      Recurrence recurrence,
      Set<DateTime> completionDays,
      ) {
    switch (recurrence.type) {
      case RecurrenceType.daily:
      case RecurrenceType.custom:
        return completionDays.contains(_dateOnly(periodStart));

      case RecurrenceType.weekly:
        if (recurrence.days != null && recurrence.days!.isNotEmpty) {
          for (int i = 0; i < 7; i++) {
            final day = _dateOnly(periodStart.add(Duration(days: i)));
            if (recurrence.days!.contains(day.weekday)) {
              if (!completionDays.contains(day)) return false;
            }
          }
          return true;
        } else {
          for (int i = 0; i < 7; i++) {
            if (completionDays.contains(
                _dateOnly(periodStart.add(Duration(days: i))))) {
              return true;
            }
          }
          return false;
        }

      case RecurrenceType.monthly:
        if (recurrence.days != null && recurrence.days!.isNotEmpty) {
          for (final d in recurrence.days!) {
            final targetDay =
            _safeDay(periodStart.year, periodStart.month, d);
            if (!completionDays.contains(_dateOnly(targetDay))) {
              return false;
            }
          }
          return true;
        } else {
          final daysInMonth =
              DateTime(periodStart.year, periodStart.month + 1, 0).day;
          for (int i = 0; i < daysInMonth; i++) {
            if (completionDays.contains(
                _dateOnly(periodStart.add(Duration(days: i))))) {
              return true;
            }
          }
          return false;
        }
    }
  }

  bool _isCurrentPeriodFailed(
      DateTime periodStart,
      Recurrence recurrence,
      Set<DateTime> completionDays,
      ) {
    final today = _dateOnly(DateTime.now());

    if (recurrence.type == RecurrenceType.weekly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      for (int i = 0; i < 7; i++) {
        final day = _dateOnly(periodStart.add(Duration(days: i)));
        if (day.isBefore(today) &&
            recurrence.days!.contains(day.weekday) &&
            !completionDays.contains(day)) {
          return true;
        }
      }
    }

    if (recurrence.type == RecurrenceType.monthly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      for (final d in recurrence.days!) {
        final targetDay =
        _safeDay(periodStart.year, periodStart.month, d);
        if (_dateOnly(targetDay).isBefore(today) &&
            !completionDays.contains(_dateOnly(targetDay))) {
          return true;
        }
      }
    }

    return false;
  }

  // ══════════════════════════════════════════════════════════
  // STREAK
  // ══════════════════════════════════════════════════════════

  DateTime _prevPeriodStart(DateTime periodStart, Recurrence recurrence) {
    switch (recurrence.type) {
      case RecurrenceType.daily:
      case RecurrenceType.custom:
        return periodStart.subtract(Duration(days: recurrence.interval));
      case RecurrenceType.weekly:
        return periodStart
            .subtract(Duration(days: recurrence.interval * 7));
      case RecurrenceType.monthly:
        int month = periodStart.month - recurrence.interval;
        int year = periodStart.year;
        while (month <= 0) {
          month += 12;
          year--;
        }
        return DateTime(year, month, 1);
    }
  }

  int _calculateStreak(
      Recurrence recurrence, Set<DateTime> completionDays) {
    if (completionDays.isEmpty) return 0;

    final today = _dateOnly(DateTime.now());
    int streak = 0;
    DateTime checkPeriod = recurrence.getPeriodStart(today);
    bool isFirstIteration = true;

    for (int safety = 0; safety < 3650; safety++) {
      final isComplete =
      _isPeriodComplete(checkPeriod, recurrence, completionDays);

      if (isComplete) {
        streak++;
      } else if (isFirstIteration &&
          !_isCurrentPeriodFailed(checkPeriod, recurrence, completionDays)) {
        // Τρέχουσα περίοδος σε εξέλιξη — δεν σπάει το streak
      } else {
        break;
      }

      isFirstIteration = false;
      checkPeriod = _prevPeriodStart(checkPeriod, recurrence);
      if (checkPeriod.year < 2000) break;
    }

    return streak;
  }

  int _countCompletedPeriods(
      Recurrence recurrence, List<DateTime> completions) {
    if (completions.isEmpty) return 0;

    final completionDays = completions.map(_dateOnly).toSet();
    final earliest = completions
        .map(_dateOnly)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final today = _dateOnly(DateTime.now());

    int count = 0;
    DateTime checkPeriod = recurrence.getPeriodStart(earliest);
    final limitPeriod = recurrence.getPeriodStart(today);

    for (int safety = 0; safety < 10000; safety++) {
      if (checkPeriod.isAfter(limitPeriod)) break;
      if (_isPeriodComplete(checkPeriod, recurrence, completionDays)) {
        count++;
      }
      final next = recurrence.nextPeriodStart(checkPeriod);
      if (!next.isAfter(checkPeriod)) break;
      checkPeriod = next;
    }

    return count;
  }

  // ══════════════════════════════════════════════════════════
  // INCREMENT — γενικό (χωρίς συγκεκριμένη ώρα)
  // ══════════════════════════════════════════════════════════

  Future<HabitStats> incrementProgress(int habitId) async {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);
    final savedGoal = _parseToInt(allProps['goal_per_period']);
    final effectiveGoal = _effectiveGoal(savedGoal, recurrence);

    await _resetDailyIfNeeded(habitId, recurrence);

    int dailyProgress =
    _parseToInt(await props.getValue(habitId, 'daily_progress'));

    if (effectiveGoal > 0 && dailyProgress >= effectiveGoal) {
      return getStats(habitId);
    }

    dailyProgress++;
    await props.setNumber(
        habitId, 'daily_progress', dailyProgress.toDouble());

    final goalMet = effectiveGoal == 0 || dailyProgress >= effectiveGoal;
    if (goalMet) {
      await _markDayCompleted(habitId, DateTime.now());
    }

    return getStats(habitId);
  }

  // ══════════════════════════════════════════════════════════
  // INCREMENT BY TIME — σημειώνει συγκεκριμένη ώρα
  // ══════════════════════════════════════════════════════════

  Future<HabitStats> incrementByTime(int habitId, String time) async {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);

    await _resetDailyIfNeeded(habitId, recurrence);

    final times = recurrence.times ?? [];
    if (!times.contains(time)) return getStats(habitId);

    final timeProgress = await _loadTodayTimeProgress(habitId, times);

    if (timeProgress[time] == true) return getStats(habitId);

    timeProgress[time] = true;
    await _saveTodayTimeProgress(habitId, timeProgress);

    final completedCount = timeProgress.values.where((v) => v).length;
    await props.setNumber(
        habitId, 'daily_progress', completedCount.toDouble());

    // Αν ΟΛΕΣ οι ώρες ολοκληρώθηκαν → σημείωσε τη μέρα
    final allDone = timeProgress.values.every((v) => v);
    if (allDone) {
      await _markDayCompleted(habitId, DateTime.now());
    }

    return getStats(habitId);
  }

  // ══════════════════════════════════════════════════════════
  // DECREMENT BY TIME — αναίρεση συγκεκριμένης ώρας
  // ══════════════════════════════════════════════════════════

  Future<HabitStats> decrementByTime(int habitId, String time) async {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);

    await _resetDailyIfNeeded(habitId, recurrence);

    final times = recurrence.times ?? [];
    if (!times.contains(time)) return getStats(habitId);

    final timeProgress = await _loadTodayTimeProgress(habitId, times);

    if (timeProgress[time] != true) return getStats(habitId);

    // Αν ήταν ολοκληρωμένη η μέρα → un-mark
    final wasAllDone = timeProgress.values.every((v) => v);
    if (wasAllDone) {
      await _unmarkDayCompleted(habitId, DateTime.now());
    }

    timeProgress[time] = false;
    await _saveTodayTimeProgress(habitId, timeProgress);

    final completedCount = timeProgress.values.where((v) => v).length;
    await props.setNumber(
        habitId, 'daily_progress', completedCount.toDouble());

    return getStats(habitId);
  }

  // ══════════════════════════════════════════════════════════
  // DECREMENT — γενικό
  // ══════════════════════════════════════════════════════════

  Future<HabitStats> decrementProgress(int habitId) async {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);
    final savedGoal = _parseToInt(allProps['goal_per_period']);
    final effectiveGoal = _effectiveGoal(savedGoal, recurrence);

    await _resetDailyIfNeeded(habitId, recurrence);

    int dailyProgress =
    _parseToInt(await props.getValue(habitId, 'daily_progress'));

    if (dailyProgress > 0) {
      final wasCompleted = effectiveGoal == 0
          ? dailyProgress > 0
          : dailyProgress >= effectiveGoal;
      if (wasCompleted) {
        await _unmarkDayCompleted(habitId, DateTime.now());
      }

      dailyProgress--;
      await props.setNumber(
          habitId, 'daily_progress', dailyProgress.toDouble());
    }

    return getStats(habitId);
  }

  Future<HabitStats> markCompleted(int habitId) async =>
      incrementProgress(habitId);

  // ══════════════════════════════════════════════════════════
  // SETTINGS
  // ══════════════════════════════════════════════════════════

  Future<void> setGoal(int habitId, int goal) async {
    await SuperNoteHelper.instance.properties
        .setNumber(habitId, 'goal_per_period', goal.toDouble());
  }

  Future<void> setUnit(int habitId, String unit) async {
    await SuperNoteHelper.instance.properties.set(
      itemId: habitId,
      key: 'unit',
      value: unit,
      type: PropertyType.text,
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

    await props.setNumber(
        habitId, 'recurrence_interval', recurrence.interval.toDouble());

    // Ημέρες (weekly weekdays ή monthly day-of-month)
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

    // Ώρες (daily times)
    if (recurrence.times != null && recurrence.times!.isNotEmpty) {
      await props.set(
        itemId: habitId,
        key: 'recurrence_times',
        value: jsonEncode(recurrence.times),
        type: PropertyType.json,
      );
    } else {
      await props.delete(habitId, 'recurrence_times');
    }

    // Reset προόδου
    final periodStart = recurrence.getPeriodStart(DateTime.now());
    await props.setDate(habitId, 'period_start', periodStart);
    await props.setNumber(habitId, 'daily_progress', 0.0);
    await props.set(
      itemId: habitId,
      key: 'today_time_progress',
      value: jsonEncode({}),
      type: PropertyType.json,
    );
  }

  // ══════════════════════════════════════════════════════════
  // REMINDERS — υποστήριξη πολλαπλών ωρών
  // ══════════════════════════════════════════════════════════

  Future<void> setReminderTime(int habitId, TimeOfDay? time) async {
    final props = SuperNoteHelper.instance.properties;
    if (time == null) {
      DebugConfig.db('🕒 Disabling reminders for habit $habitId');
      await props.delete(habitId, 'reminder_time');
      await props.delete(habitId, 'reminder_times');
      await ReminderScheduler.instance.cancelAllForItem(habitId);
      final reminders =
      await SuperNoteHelper.instance.reminders.getForItem(habitId);
      for (final r in reminders) {
        await SuperNoteHelper.instance.reminders.delete(r.id);
      }
    } else {
      DebugConfig.db(
          '🕒 Setting reminder for habit $habitId at ${time.hour}:${time.minute}');
      final timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      await props.set(
        itemId: habitId,
        key: 'reminder_time',
        value: timeStr,
        type: PropertyType.text,
      );
      final allProps = await _getAllProps(habitId);
      final recurrence = Recurrence.fromProperties(allProps);
      await _scheduleReminders(habitId, [time], recurrence);
    }
  }

  /// Ορίζει πολλαπλές ώρες (για daily habits με times)
  Future<void> setReminderTimes(int habitId, List<TimeOfDay> times) async {
    final props = SuperNoteHelper.instance.properties;

    if (times.isEmpty) {
      await setReminderTime(habitId, null);
      return;
    }

    DebugConfig.db(
        '🕒 Setting ${times.length} reminders for habit $habitId');

    final timesStr = times
        .map((t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .toList();

    await props.set(
      itemId: habitId,
      key: 'reminder_times',
      value: jsonEncode(timesStr),
      type: PropertyType.json,
    );

    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);
    await _scheduleReminders(habitId, times, recurrence);
  }

  Future<void> _scheduleReminders(
      int habitId, List<TimeOfDay> times, Recurrence recurrence) async {
    await ReminderScheduler.instance.cancelAllForItem(habitId);
    final old =
    await SuperNoteHelper.instance.reminders.getForItem(habitId);
    for (final r in old) {
      await SuperNoteHelper.instance.reminders.delete(r.id);
    }

    final now = DateTime.now();
    final end = now.add(const Duration(days: 60));
    final item = await SuperNoteHelper.instance.items.getById(habitId);
    final title = item?.title ?? 'Συνήθεια';

    for (final time in times) {
      DateTime current = now;
      int count = 0;
      const maxPerTime = 40;

      while (current.isBefore(end) && count < maxPerTime) {
        final nextOcc =
        _nextOccurrenceForTime(recurrence, time, current);
        if (nextOcc.isAfter(now) && nextOcc.isBefore(end)) {
          final reminder =
          await SuperNoteHelper.instance.reminders.create(
            itemId: habitId,
            triggerAt: nextOcc,
            rrule: recurrence.toRRULE(),
            title: 'Υπενθύμιση συνήθειας',
            body: 'Υπενθύμιση: $title',
          );
          await ReminderScheduler.instance.scheduleReminder(reminder);
          current = nextOcc.add(const Duration(days: 1));
          count++;
        } else {
          break;
        }
      }
    }
  }

  DateTime _nextOccurrenceForTime(
      Recurrence recurrence, TimeOfDay time, DateTime after) {
    DateTime candidate = DateTime(
        after.year, after.month, after.day, time.hour, time.minute);
    if (candidate.isBefore(after)) {
      candidate = recurrence
          .nextPeriodStart(candidate)
          .add(Duration(hours: time.hour, minutes: time.minute));
    }
    if (recurrence.type == RecurrenceType.weekly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      int safety = 0;
      while (!recurrence.days!.contains(candidate.weekday) &&
          safety < 8) {
        candidate = candidate.add(const Duration(days: 1));
        safety++;
      }
    }
    if (recurrence.type == RecurrenceType.monthly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      final sortedDays = [...recurrence.days!]..sort();
      DateTime? found;
      for (final d in sortedDays) {
        final target = DateTime(
            candidate.year, candidate.month, d, time.hour, time.minute);
        if (target.isAfter(after)) {
          found = target;
          break;
        }
      }
      if (found != null) candidate = found;
    }
    return candidate;
  }

  // ══════════════════════════════════════════════════════════
  // GET STATS
  // ══════════════════════════════════════════════════════════

  Future<HabitStats> getStats(int habitId) async {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);
    final unit = allProps['unit'] ?? '';
    final savedGoal = _parseToInt(allProps['goal_per_period']);
    final effectiveGoal = _effectiveGoal(savedGoal, recurrence);

    await _resetDailyIfNeeded(habitId, recurrence);

    final completions = await _loadDayCompletions(habitId);
    final completionDays = completions.map(_dateOnly).toSet();

    final dailyProgress =
    _parseToInt(await props.getValue(habitId, 'daily_progress'));

    final today = _dateOnly(DateTime.now());
    final completedToday = completionDays.contains(today);

    // Time progress για daily με ώρες
    Map<String, bool> todayTimeProgress = {};
    if (recurrence.type == RecurrenceType.daily &&
        recurrence.times != null &&
        recurrence.times!.isNotEmpty) {
      todayTimeProgress =
      await _loadTodayTimeProgress(habitId, recurrence.times!);
    }

    // Ποσοστό προόδου
    final double progressPercent;
    if (effectiveGoal > 0) {
      progressPercent =
          (dailyProgress / effectiveGoal * 100).clamp(0.0, 100.0);
    } else {
      progressPercent = dailyProgress > 0 ? 100.0 : 0.0;
    }

    final streak = _calculateStreak(recurrence, completionDays);
    final completedCount =
    _countCompletedPeriods(recurrence, completions);

    final bestStr = allProps['best_streak'];
    int bestStreak = _parseToInt(bestStr);
    if (streak > bestStreak) {
      bestStreak = streak;
      await props.setNumber(
          habitId, 'best_streak', bestStreak.toDouble());
    }

    final lastCompleted = completions.isNotEmpty
        ? completions.reduce((a, b) => a.isAfter(b) ? a : b)
        : null;

    return HabitStats(
      streak: streak,
      bestStreak: bestStreak,
      completedCount: completedCount,
      goalCount: effectiveGoal,
      lastCompleted: lastCompleted,
      completions: completions,
      completedToday: completedToday,
      progressPercent: progressPercent,
      dailyProgress: dailyProgress,
      unit: unit,
      recurrence: recurrence,
      todayTimeProgress: todayTimeProgress,
    );
  }
}