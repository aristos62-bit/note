// lib/services/habit_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import '../core/core.dart';
import 'reminder_scheduler.dart';
import 'reminder_text.dart';
import 'notification_service.dart';

// ─────────────────────────────────────────────────────────────
// HabitStats
// ─────────────────────────────────────────────────────────────

class HabitStats {
  final int streak;
  final int bestStreak;
  final int completedCount;         // πλήρως ολοκληρωμένες περίοδοι (ημέρες)
  final int goalCount;              // effective goal (ημερήσιος στόχος)
  final DateTime? lastCompleted;
  final List<DateTime> completions; // ημέρες επίτευξης
  final bool completedToday;
  final double progressPercent;     // 0-100
  final int dailyProgress;
  final String unit;
  final Recurrence recurrence;

  /// Για daily με ώρες: ποιες ώρες έχουν ολοκληρωθεί σήμερα
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

  DateTime _safeDay(int year, int month, int day) =>
      Recurrence.safeMonthDay(year, month, day);

  Future<Map<String, String?>> _getAllProps(int habitId) async {
    final props = await SuperNoteHelper.instance.properties.getAll(habitId);
    final map = <String, String?>{};
    for (final p in props) {
      map[p.key] = p.value;
    }
    return map;
  }

  // ══════════════════════════════════════════════════════════
  // EFFECTIVE GOAL (ημερήσιος στόχος)
  // Επιστρέφει τον πραγματικό στόχο για ΜΙΑ ΗΜΕΡΑ.
  // - daily + times → αριθμός ωρών
  // - αλλιώς → savedGoal (1 για τις περισσότερες συνήθειες)
  // ΔΕΝ πολλαπλασιάζεται ποτέ με τον αριθμό ημερών της εβδομάδας/μήνα.
  // ══════════════════════════════════════════════════════════

  int _effectiveGoal(int savedGoal, Recurrence recurrence) {
    // Αν είναι daily habit με συγκεκριμένες ώρες, στόχος = πλήθος ωρών
    if (recurrence.type == RecurrenceType.daily &&
        recurrence.times != null &&
        recurrence.times!.isNotEmpty) {
      return recurrence.times!.length;
    }
    // Σε κάθε άλλη περίπτωση (weekly, monthly, daily χωρίς ώρες, custom, etc.)
    // ο στόχος ανά ημέρα είναι το savedGoal (συνήθως 1)
    return savedGoal;
  }

  // ══════════════════════════════════════════════════════════
  // TIME PROGRESS — για daily habits με ώρες
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
    } catch (e) {
      DebugConfig.warning(
          'HabitService._loadTodayTimeProgress: parse failed (habitId=$habitId): $e');
    }

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
    } catch (e) {
      DebugConfig.warning(
          'HabitService._loadDayCompletions: parse failed (habitId=$habitId): $e');
      return [];
    }
  }

  Future<void> _saveDayCompletions(
      int habitId, List<DateTime> completions) async {
    await SuperNoteHelper.instance.properties.set(
      itemId: habitId,
      key: 'period_completions',
      value: jsonEncode(completions.map((d) => d.toIso8601String()).toList()),
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
    final updated = completions.where((d) => !_isSameDay(d, today)).toList();
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

    final lastDateStr = await props.getValue(habitId, 'last_progress_date');
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

  HabitStats _emptyStats(int habitId) => const HabitStats(
        streak: 0,
        bestStreak: 0,
        completedCount: 0,
        goalCount: 0,
        lastCompleted: null,
        completions: [],
        completedToday: false,
        progressPercent: 0.0,
        dailyProgress: 0,
        unit: '',
        recurrence: Recurrence(type: RecurrenceType.daily, interval: 1),
      );

  // ══════════════════════════════════════════════════════════
  // INCREMENT — γενικό (χωρίς συγκεκριμένη ώρα)
  // ══════════════════════════════════════════════════════════

  Future<HabitStats> incrementProgress(int habitId) async {
    try {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);
    final savedGoal = _parseToInt(allProps['goal_per_period']);
    final effectiveGoal = _effectiveGoal(savedGoal, recurrence); // π.χ. 1

    await _resetDailyIfNeeded(habitId, recurrence);

    int dailyProgress =
    _parseToInt(await props.getValue(habitId, 'daily_progress'));

    if (effectiveGoal > 0 && dailyProgress >= effectiveGoal) {
      return await getStats(habitId);
    }

    dailyProgress++;
    await props.setNumber(habitId, 'daily_progress', dailyProgress.toDouble());

    final goalMet = effectiveGoal == 0 || dailyProgress >= effectiveGoal;
    if (goalMet) {
      await _markDayCompleted(habitId, DateTime.now());
    }

    return await getStats(habitId);
    } catch (e, stack) {
      DebugConfig.error('incrementProgress', e, stack);
      return _emptyStats(habitId);
    }
  }

  // ══════════════════════════════════════════════════════════
  // INCREMENT BY TIME — σημειώνει συγκεκριμένη ώρα
  // ══════════════════════════════════════════════════════════

  Future<HabitStats> incrementByTime(int habitId, String time) async {
    try {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);

    await _resetDailyIfNeeded(habitId, recurrence);

    final times = recurrence.times ?? [];
    if (!times.contains(time)) return await getStats(habitId);

    final timeProgress = await _loadTodayTimeProgress(habitId, times);

    if (timeProgress[time] == true) return await getStats(habitId);

    timeProgress[time] = true;
    await _saveTodayTimeProgress(habitId, timeProgress);

    final completedCount = timeProgress.values.where((v) => v).length;
    await props.setNumber(habitId, 'daily_progress', completedCount.toDouble());

    // Αν ΟΛΕΣ οι ώρες ολοκληρώθηκαν → σημείωσε τη μέρα
    final allDone = timeProgress.values.every((v) => v);
    if (allDone) {
      await _markDayCompleted(habitId, DateTime.now());
    }

    return await getStats(habitId);
    } catch (e, stack) {
      DebugConfig.error('incrementByTime', e, stack);
      return _emptyStats(habitId);
    }
  }

  // ══════════════════════════════════════════════════════════
  // DECREMENT BY TIME — αναίρεση συγκεκριμένης ώρας
  // ══════════════════════════════════════════════════════════

  Future<HabitStats> decrementByTime(int habitId, String time) async {
    try {
    final props = SuperNoteHelper.instance.properties;
    final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);

    await _resetDailyIfNeeded(habitId, recurrence);

    final times = recurrence.times ?? [];
    if (!times.contains(time)) return await getStats(habitId);

    final timeProgress = await _loadTodayTimeProgress(habitId, times);

    if (timeProgress[time] != true) return await getStats(habitId);

    // Αν ήταν ολοκληρωμένη η μέρα → un-mark
    final wasAllDone = timeProgress.values.every((v) => v);
    if (wasAllDone) {
      await _unmarkDayCompleted(habitId, DateTime.now());
    }

    timeProgress[time] = false;
    await _saveTodayTimeProgress(habitId, timeProgress);

    final completedCount = timeProgress.values.where((v) => v).length;
    await props.setNumber(habitId, 'daily_progress', completedCount.toDouble());

    return await getStats(habitId);
    } catch (e, stack) {
      DebugConfig.error('decrementByTime', e, stack);
      return _emptyStats(habitId);
    }
  }

  // ══════════════════════════════════════════════════════════
  // DECREMENT — γενικό
  // ══════════════════════════════════════════════════════════

  Future<HabitStats> decrementProgress(int habitId) async {
    try {
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
      await props.setNumber(habitId, 'daily_progress', dailyProgress.toDouble());
    }

    return await getStats(habitId);
    } catch (e, stack) {
      DebugConfig.error('decrementProgress', e, stack);
      return _emptyStats(habitId);
    }
  }

  Future<HabitStats> markCompleted(int habitId) async =>
      incrementProgress(habitId);

  // ══════════════════════════════════════════════════════════
  // SETTINGS
  // ══════════════════════════════════════════════════════════

  Future<void> setGoal(int habitId, int goal) async {
    try {
      await SuperNoteHelper.instance.properties
          .setNumber(habitId, 'goal_per_period', goal.toDouble());
    } catch (e, stack) {
      DebugConfig.error('setGoal', e, stack);
    }
  }

  Future<void> setUnit(int habitId, String unit) async {
    try {
      await SuperNoteHelper.instance.properties.set(
        itemId: habitId,
        key: 'unit',
        value: unit,
        type: PropertyType.text,
      );
    } catch (e, stack) {
      DebugConfig.error('setUnit', e, stack);
    }
  }

  Future<void> setRecurrence(int habitId, Recurrence recurrence) async {
    try {
    final props = SuperNoteHelper.instance.properties;

    await props.set(
      itemId: habitId,
      key: 'recurrence_type',
      value: recurrence.type.name,
      type: PropertyType.text,
    );

    await props.setNumber(
        habitId, 'recurrence_interval', recurrence.interval.toDouble());

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

    // Reset προόδου για τη νέα περίοδο
    final periodStart = recurrence.getPeriodStart(DateTime.now());
    await props.setDate(habitId, 'period_start', periodStart);
    await props.setNumber(habitId, 'daily_progress', 0.0);
    await props.set(
      itemId: habitId,
      key: 'today_time_progress',
      value: jsonEncode({}),
      type: PropertyType.json,
    );
    } catch (e, stack) {
      DebugConfig.error('setRecurrence', e, stack);
    }
  }

  // ══════════════════════════════════════════════════════════
  // REMINDERS
  // ══════════════════════════════════════════════════════════

  Future<void> setReminderTime(int habitId, TimeOfDay? time) async {
    try {
    final props = SuperNoteHelper.instance.properties;
    if (time == null) {
      DebugConfig.db('🕒 Disabling reminders for habit $habitId');
      await props.delete(habitId, 'reminder_time');
      await props.delete(habitId, 'reminder_times');
      await _passQueue.run(() => _clearHabitGenerated(habitId));
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
      // N1: το legacy μονό δεν πρέπει να συνυπάρχει με λίστα — αλλιώς το
      // topUp ενώνει και τις δύο πηγές και επαναφέρει παλιά ώρα.
      await props.delete(habitId, 'reminder_times');
      final allProps = await _getAllProps(habitId);
      final recurrence = Recurrence.fromProperties(allProps);
      await _scheduleReminders(habitId, [time], recurrence);
    }
    } catch (e, stack) {
      DebugConfig.error('setReminderTime', e, stack);
    }
  }

  Future<void> setReminderTimes(int habitId, List<TimeOfDay> times) async {
    try {
      final props = SuperNoteHelper.instance.properties;

      if (times.isEmpty) {
        await setReminderTime(habitId, null);
        return;
      }

    DebugConfig.db('🕒 Setting ${times.length} reminders for habit $habitId');

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
      // H1: το legacy μονό 'reminder_time' δεν πρέπει να επιβιώνει — το
      // topUpHabitReminders ενώνει reminder_time + reminder_times και θα
      // ξαναδημιουργούσε «φάντασμα» ώρα που ο χρήστης έχει αλλάξει.
      await props.delete(habitId, 'reminder_time');

      final allProps = await _getAllProps(habitId);
    final recurrence = Recurrence.fromProperties(allProps);
    await _scheduleReminders(habitId, times, recurrence);
    } catch (e, stack) {
      DebugConfig.error('setReminderTimes', e, stack);
    }
  }

  // ──────────────────────────────────────────────────────────
  // HABIT SCHEDULING — native ownership (βλ. supernote.md S61)
  // Αγγίζονται ΜΟΝΟ habit-generated rows (title == generatedTitle)·
  // τα generic bell rows (title 'Υπενθύμιση') δεν διαγράφονται ποτέ.
  // ──────────────────────────────────────────────────────────

  /// Τίτλος όλων των habit-generated one-shots (διαχωρισμός από bell rows).
  static const String generatedTitle = habitGeneratedTitle;

  /// Ορίζοντας προ-δημιουργίας occurrences.
  static const int horizonDays = 60;

  static const int _maxPerTime = 60;

  /// Pure: ποιες needed λείπουν από existing (για unit test).
  static List<DateTime> planTopUp(
      Set<DateTime> existing, List<DateTime> needed) {
    return needed.where((d) => !existing.contains(d)).toList();
  }

  /// Pure: "HH:MM" → TimeOfDay (null αν άκυρο).
  static TimeOfDay? parseHabitTime(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  /// Κοινός occurrence walker (ίδια σημασιολογία για schedule + top-up).
  List<DateTime> _computeOccurrences(
    Recurrence recurrence,
    List<TimeOfDay> times,
    DateTime from,
    DateTime end,
  ) {
    final out = <DateTime>[];
    for (final time in times) {
      DateTime current = from;
      int count = 0;
      while (current.isBefore(end) && count < _maxPerTime) {
        final nextOcc = _nextOccurrenceForTime(recurrence, time, current);
        if (nextOcc.isAfter(from) && nextOcc.isBefore(end)) {
          out.add(nextOcc);
          // H2: μεσάνυχτα της επόμενης ημερολογιακής μέρας (όχι +24h: την
          // αλλαγή ώρας Μαρτίου η ημέρα έχει 23ω και χανόταν μία εμφάνιση).
          // Διορθώνει και τις διαδοχικές μέρες μήνα (π.χ. [10,11]) που
          // παραλείπονταν επειδή target == after.
          current = DateTime(nextOcc.year, nextOcc.month, nextOcc.day + 1);
          count++;
        } else {
          break;
        }
      }
    }
    return out;
  }

  /// Σβήνει ΜΟΝΟ habit-generated rows (DB πρώτα, μετά OS cancel) και
  /// ξαναπρογραμματίζει τυχόν grandfathered bell rows (έμειναν χωρίς OS).
  /// N3: ΠΟΤΕ cancelAllForItem — δεν αγγίζουμε generic bell rows.
  Future<void> _clearHabitGenerated(int habitId) async {
    try {
      final old =
          await SuperNoteHelper.instance.reminders.getForItem(habitId);
      final generated =
          old.where((r) => r.title == generatedTitle).toList();
      final generatedIds = generated.map((r) => r.id).toList();
      var deletedFromDb = false;
      if (generatedIds.isNotEmpty) {
        try {
          await SuperNoteHelper.instance.isar.writeTxn(() async {
            await SuperNoteHelper.instance.isar.reminders
                .deleteAll(generatedIds);
          });
          deletedFromDb = true;
        } catch (e, stack) {
          DebugConfig.error('_clearHabitGenerated DB delete', e, stack);
        } finally {
          await ReminderScheduler.instance.cancelReminderIds(generatedIds);
        }
      }

      final rest =
          await SuperNoteHelper.instance.reminders.getForItem(habitId);
      final now = DateTime.now();
      // Αν το DB delete απέτυχε, μην ξαναψήσεις τα generated rows που μόλις
      // ακυρώθηκαν στο OS — θα ξαναγεννούσαν το πρόβλημα.
      final pending = rest
          .where((r) =>
              r.status == ReminderStatus.pending &&
              r.triggerAt.isAfter(now) &&
              (deletedFromDb || r.title != generatedTitle))
          .toList();
      if (pending.isNotEmpty) {
        await ReminderScheduler.instance.scheduleReminders(pending);
      }
      DebugConfig.notif(
          '_clearHabitGenerated: habitId=$habitId generated=${generatedIds.length} restoredBell=${pending.length} dbDeleted=$deletedFromDb');
    } catch (e, stack) {
      DebugConfig.error('_clearHabitGenerated', e, stack);
    }
  }

  /// Συγχρονίζει τον προγραμματισμό με το recurrence (καλείται από UI).
  /// Daily/weekly/monthly με ώρες → αναγέννηση 60d· οτιδήποτε άλλο
  /// (συμπ. yearly) → καθαρισμός.
  Future<void> syncScheduleWithRecurrence(int habitId) async {
    try {
      final allProps = await _getAllProps(habitId);
      final recurrence = Recurrence.fromProperties(allProps);
      if (recurrence.type != RecurrenceType.yearly &&
          recurrence.times != null &&
          recurrence.times!.isNotEmpty) {
        final times = <TimeOfDay>[];
        for (final t in recurrence.times!) {
          final parsed = parseHabitTime(t);
          if (parsed != null) times.add(parsed);
        }
        if (times.isNotEmpty) {
          await setReminderTimes(habitId, times);
          return;
        }
      }
      await setReminderTimes(habitId, []);
    } catch (e, stack) {
      DebugConfig.error('syncScheduleWithRecurrence', e, stack);
    }
  }

  /// Top-up ορίζοντα: δημιουργεί ΜΟΝΟ τα λείποντα occurrences (προσθετικό).
  /// Τρέχει ΜΟΝΟ όπου υπάρχουν reminder_time(s) (ρητό opt-in).
  static DateTime? _lastTopUp;

  /// A6-mirror: σειριοποίηση habit row-mutations (topUp/set/clear).
  /// Check-then-act με awaits (read existing → create) + ταυτόχρονο
  /// setReminderTimes/_clearHabitGenerated (π.χ. αλλαγή ωρών στο startup)
  /// έβγαζε διπλά rows/ghosts. Κάθε pass περιμένει το προηγούμενο·
  /// οι υπογραφές μένουν ίδιες.
  /// S212-hardening: timeout 60s/pass (fail-open — δεν ακυρώνει το
  /// υποκείμενο Isar/OS work) + μόνιμα queued/started/done logs.
  /// Σύμβαση ουράς: NEVER-THROW (όλα logάρονται εδώ· η αλυσίδα μένει
  /// ζωντανή· οι καλούντες προχωρούν — το resume-rebake δεν σκιπάρεται).
  /// S246: η ουρά εξήχθη στο SPoT `SerialPassQueue` (core/utils) — ίδια
  /// logs/timeout/συμπεριφορά· το timeout-reset της φρουράς → `onTimeout`.
  final SerialPassQueue _passQueue = SerialPassQueue(
    label: 'HabitService.pass',
    onTimeout: () => _lastTopUp = null, // retry, όχι guard-skip
  );

  /// S248: one-shot repair pass (cold start) — ΔΙΚΟ του instance του SPoT.
  /// ΠΟΤΕ κοινό chain με `_passQueue`: το impl καλεί
  /// `syncScheduleWithRecurrence` → `_passQueue.run` (self-wait trap).
  /// Χωρίς onTimeout (χωρίς guard) — 60s fail-open + μόνιμα logs.
  final SerialPassQueue _repairQueue = SerialPassQueue(
    label: 'HabitService.repair',
  );

  /// P1#1 (S250): wipe reminder rows + follow-up (soft/hard delete) στο ΙΔΙΟ
  /// pass της _passQueue — κλείνει το race delete ↔ topUp (εύρημα S234).
  /// [afterRows]: τρέχει αφού σβηστούν ΟΛΕΣ οι rows (item soft/hard delete).
  /// E05: thin wrapper πάνω στο batch [deleteHabitRemindersMany] (1 impl).
  Future<void> deleteHabitReminders(
          int habitId, {Future<void> Function()? afterRows}) =>
      deleteHabitRemindersMany([habitId], afterRows: afterRows);

  /// E05 (F13b): batch εκδοχή — 1 pass + 1 wipe αντί N×. Το [itemIds] μπορεί
  /// να περιέχει και μη-habit items (μικτό bulk delete): το wipe τους τρέχει
  /// κι αυτό μέσα στο pass, ώστε habit wipe + hard delete να είναι αδιαίρετα
  /// (S250/S234). Σύμβαση ουράς: NEVER-THROW · fail-open 60s · skip σε
  /// maintenance (E33).
  Future<void> deleteHabitRemindersMany(List<int> itemIds,
      {Future<void> Function()? afterRows}) {
    final ids = itemIds.toSet().toList();
    if (ids.isEmpty) return Future<void>.value();
    return _passQueue.run(() async {
      // Id list μόνο σε μικρά batch (αποφυγή τεράστιων γραμμών logcat).
      final idLog = ids.length <= 20 ? ' ids=$ids' : '';
      DebugConfig.notif(ids.length == 1
          ? 'deleteHabitReminders: habitId=${ids.first}'
          : 'deleteHabitRemindersMany: n=${ids.length}$idLog');
      await ReminderScheduler.instance.deleteAllRemindersForItems(ids);
      if (afterRows != null) await afterRows();
    });
  }

  Future<void> topUpHabitReminders({bool force = false}) =>
      _passQueue.run(() => _topUpHabitRemindersImpl(force: force));

  Future<void> _topUpHabitRemindersImpl({bool force = false}) async {
    try {
      final now = DateTime.now();
      if (!force &&
          _lastTopUp != null &&
          now.difference(_lastTopUp!).inMinutes < 10) {
        DebugConfig.notif('HabitService.topUp: guard-skip');
        return;
      }
      _lastTopUp = now;

      final topUpSw = Stopwatch()..start(); // PERF#9 (S224)

      final helper = SuperNoteHelper.instance;
      final end = now.add(const Duration(days: horizonDays));
      var created = 0;
      var habits = 0;
      var scanned = 0;
      // N2/E35: ένα batch στο τέλος για ΟΛΑ τα habits — μία ανάγνωση OS cache,
      // ένα plan και κοινό budget, αντί για scheduleReminders ανά habit.
      final pendingToSchedule = <Reminder>[];

      final workspaces = await helper.workspaces.getAll();
      for (final ws in workspaces) {
        // Χωρίς archived/deleted (default φίλτρα) — δεν τα αγγίζουμε.
        final items = await helper.items
            .getByWorkspace(ws.id, type: ItemType.habit);
        for (final habit in items) {
          // Defense-in-depth: ακόμη κι αν το query επιστρέψει archived/deleted,
          // μην αναγεννήσεις reminders (archive/κάδος = σίγαση).
          if (habit.archived ||
              habit.isDeleted ||
              habit.status == ItemStatus.done ||
              habit.status == ItemStatus.cancelled) {
            DebugConfig.notif(
                'HabitService.topUp: skipping archived/deleted/done habit=${habit.id}');
            continue;
          }
          final allProps = await _getAllProps(habit.id);
          if ((allProps['reminder_time'] ?? '').isEmpty &&
              (allProps['reminder_times'] ?? '').isEmpty) {
            continue; // ποτέ opt-in — δεν ενεργοποιούμε μόνα μας
          }
          final times = <TimeOfDay>[];
          final single = parseHabitTime(allProps['reminder_time'] ?? '');
          if (single != null) times.add(single);
          final timesJson = allProps['reminder_times'] ?? '';
          if (timesJson.isNotEmpty) {
            try {
              final list = jsonDecode(timesJson) as List;
              for (final e in list) {
                final parsed = parseHabitTime(e.toString());
                if (parsed != null && !times.any((t) =>
                    t.hour == parsed.hour && t.minute == parsed.minute)) {
                  times.add(parsed);
                }
              }
            } catch (e) {
              DebugConfig.warning(
                  'HabitService.topUp: reminder_times parse failed (habitId=${habit.id}): $e');
            }
          }
          if (times.isEmpty) continue;

          final recurrence = Recurrence.fromProperties(allProps);
          final existing = await helper.reminders.getForItem(habit.id);
          final futureTriggers = <DateTime>{};
          for (final r in existing) {
            if (r.status == ReminderStatus.pending &&
                r.triggerAt.isAfter(now)) {
              futureTriggers.add(r.triggerAt);
            }
          }
          final missing = planTopUp(futureTriggers,
              _computeOccurrences(recurrence, times, now, end));
          scanned++;
          final futurePending = existing
              .where((r) =>
                  r.status == ReminderStatus.pending &&
                  r.triggerAt.isAfter(now))
              .toList();
          if (missing.isEmpty) {
            // N2: ακόμη και χωρίς νέες rows, κάνε repair των υπαρχόντων OS
            // alarms (π.χ. μετά από reboot/force-stop ή rename) — στο κοινό
            // batch του τέλους, όχι ένα OS read εδώ.
            pendingToSchedule.addAll(futurePending);
            continue;
          }
          habits++;
          final title = habit.title ?? 'Συνήθεια';
          final createdRows = <Reminder>[];
          for (final occ in missing) {
            final reminder = await helper.reminders.create(
              itemId: habit.id,
              triggerAt: occ,
              rrule: null,
              title: generatedTitle,
              body: 'Υπενθύμιση: $title',
            );
            createdRows.add(reminder);
            created++;
          }
          pendingToSchedule.addAll(futurePending);
          pendingToSchedule.addAll(createdRows);
        }
      }
      if (pendingToSchedule.isNotEmpty) {
        await ReminderScheduler.instance.scheduleReminders(pendingToSchedule);
      }
      DebugConfig.notif(
          'HabitService.topUp: done scanned=$scanned needTopUp=$habits created=$created '
          'scheduledBatch=${pendingToSchedule.length}');
      // H3 debug: πόσα alarms υπάρχουν πραγματικά στο OS (Android ~500/app,
      // iOS 64) — αν πλησιάζει το όριο, μείωσε το horizonDays.
      final osPending =
      await NotificationService.instance.getPendingNotifications();
      DebugConfig.notif('HabitService.topUp: OS pending=${osPending.length}');
      DebugConfig.notif( // PERF#9 (S224)
          'PERF#9 topUp: scanned=$scanned needTopUp=$habits created=$created '
          'os=${osPending.length} took=${topUpSw.elapsedMilliseconds}ms');
    } catch (e, stack) {
      DebugConfig.error('topUpHabitReminders', e, stack);
    }
  }

  /// One-shot repair προ-51 ψευδο-roots (rrule + parent null σε habits).
  /// Idempotent: χωρίς ψευδο-roots κάνει τίποτα.
  ///
  /// S248: ο δημόσιος δρόμος περνά από το `_repairQueue` (SPoT) — fail-open
  /// 60s + μόνιμα queued/started/done/FAILED logs.
  Future<void> repairLegacyHabitRows() =>
      _repairQueue.run(_repairLegacyHabitRowsImpl);

  Future<void> _repairLegacyHabitRowsImpl() async {
    try {
      final helper = SuperNoteHelper.instance;
      var repaired = 0;
      var healedProps = 0;
      final workspaces = await helper.workspaces.getAll();
      for (final ws in workspaces) {
        final items = await helper.items
            .getByWorkspace(ws.id, type: ItemType.habit);
        for (final habit in items) {
          // Heal διπλοτύπων property rows (non-unique index + παλιό set()
          // race → last-wins ανάγνωση). Ίδιος LWW κανόνας με το set():
          // επιβίωση νεότερου, διαγραφή υπολοίπων με υπάρχουσες μεθόδους.
          final hprops = await helper.properties.getAll(habit.id);
          final byKey = <String, List<ItemProperty>>{};
          for (final p in hprops) {
            byKey.putIfAbsent(p.key, () => []).add(p);
          }
          const healKeys = [
            'recurrence_type',
            'recurrence_interval',
            'recurrence_days',
            'recurrence_times',
            'reminder_time',
            'reminder_times',
          ];
          for (final hk in healKeys) {
            final dupes = byKey[hk];
            if (dupes == null || dupes.length < 2) continue;
            dupes.sort((a, b) {
              final at = a.updatedAt ?? a.createdAt;
              final bt = b.updatedAt ?? b.createdAt;
              final c = at.compareTo(bt);
              return c != 0 ? c : a.id.compareTo(b.id);
            });
            final keep = dupes.last;
            DebugConfig.warning(
                'HabitService.repair: habitId=${habit.id} duplicate props key=$hk rows=${dupes.length} — keeping id=${keep.id}');
            await helper.properties.delete(habit.id, hk);
            await helper.properties.set(
              itemId: habit.id,
              key: keep.key,
              value: keep.value,
              type: keep.type,
              unit: keep.unit,
              isVisible: keep.isVisible,
              sortOrder: keep.sortOrder,
            );
            healedProps++;
          }
          final rows = await helper.reminders.getForItem(habit.id);
          final pseudoRoots = rows.where((r) =>
              r.rrule != null &&
              r.rrule!.isNotEmpty &&
              r.parentReminderId == null);
          if (pseudoRoots.isEmpty) continue;
          DebugConfig.warning(
              'HabitService.repair: habitId=${habit.id} pseudo-roots=${pseudoRoots.length}');
          for (final root in pseudoRoots) {
            await ReminderScheduler.instance.deleteReminderThread(root.id);
          }
          await syncScheduleWithRecurrence(habit.id);
          repaired++;
        }
      }
      if (repaired > 0) {
        DebugConfig.notif('HabitService.repair: done habits=$repaired');
      }
      if (healedProps > 0) {
        DebugConfig.notif(
            'HabitService.repair: healed duplicate habit props=$healedProps');
      }
    } catch (e, stack) {
      DebugConfig.error('repairLegacyHabitRows', e, stack);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Maintenance gate (B3/E33) — restore/wipe orchestration
  // ─────────────────────────────────────────────────────────

  /// B3/E33: maintenance gate για restore/wipe — όσο true, τα passes και
  /// των 2 ουρών (pass/repair) σκιπάρονται μέσω των queue gates.
  bool _maintenance = false;

  /// Κλείνει τα gates και των 2 ουρών ΠΡΙΝ το drain (E33).
  void pauseForMaintenance() {
    if (_maintenance) return;
    _maintenance = true;
    _passQueue.pauseForMaintenance();
    _repairQueue.pauseForMaintenance();
    DebugConfig.notif('HabitService.maintenance: paused');
  }

  /// Περιμένει τα πραγματικά in-flight passes (παράλληλα).
  /// false = δεν καθάρισαν εντός [maxWait] → ο caller κάνει abort ΧΩΡΙΣ close.
  Future<bool> drainForMaintenance(Duration maxWait) async {
    final results = await Future.wait([
      _passQueue.waitForIdle(maxWait),
      _repairQueue.waitForIdle(maxWait),
    ]);
    final ok = results.every((idle) => idle);
    if (!ok) {
      DebugConfig.warning(
          'HabitService.maintenance: drain TIMEOUT '
              '(pass=${_passQueue.inFlightCount} '
              'repair=${_repairQueue.inFlightCount})');
    }
    return ok;
  }

  /// Ανοίγει τα gates (μόνο σε abort). Το topUp είναι idempotent/additive
  /// και ξανατρέχει στο επόμενο lifecycle resume/cold start — δεν κάνουμε
  /// forced rearm εδώ (καμία επίπτωση αν ένα pass σκιπαρίστηκε).
  void resumeAfterMaintenance() {
    if (!_maintenance) return;
    _maintenance = false;
    _passQueue.resumeAfterMaintenance();
    _repairQueue.resumeAfterMaintenance();
    DebugConfig.notif('HabitService.maintenance: resumed');
  }

  Future<void> _scheduleReminders(
      int habitId, List<TimeOfDay> times, Recurrence recurrence) =>
      _passQueue.run(
          () => _scheduleRemindersImpl(habitId, times, recurrence));

  Future<void> _scheduleRemindersImpl(
      int habitId, List<TimeOfDay> times, Recurrence recurrence) async {
    await _clearHabitGenerated(habitId);

    final now = DateTime.now();
    final end = now.add(const Duration(days: horizonDays));
    final item = await SuperNoteHelper.instance.items.getById(habitId);
    if (item == null ||
        item.isDeleted ||
        item.archived ||
        item.status == ItemStatus.done ||
        item.status == ItemStatus.cancelled) {
      // P1#1 (S250): pass μετά τη διαγραφή (π.χ. repair→sync) — skip (S234).
      // E37/N: archived/done δεν αναγεννούν OS alarms.
      DebugConfig.notif(
          'HabitService._scheduleReminders: missing/deleted/archived/done, SKIP habitId=$habitId');
      return;
    }
    final title = item.title ?? 'Συνήθεια';
    DebugConfig.notif('HabitService._scheduleReminders: habitId=$habitId times=${times.length} recurrence=${recurrenceToRRULE(recurrence)} → one-shot occurrences');

    final createdRows = <Reminder>[];
    for (final occ in _computeOccurrences(recurrence, times, now, end)) {
      final reminder = await SuperNoteHelper.instance.reminders.create(
        itemId: habitId,
        triggerAt: occ,
        // One-shot: η recurrence ζει στα props· με rrule το scheduleAll()
        // θα το έκοβε μετά από restart και το cleanup δεν θα το μάζευε.
        rrule: null,
        title: generatedTitle,
        body: 'Υπενθύμιση: $title',
      );
      createdRows.add(reminder);
    }
    // N2/E35: ένα batch bake για όλες τις νέες rows, με budget — όχι N calls.
    if (createdRows.isNotEmpty) {
      await ReminderScheduler.instance.scheduleReminders(createdRows);
    }
  }

  DateTime _nextOccurrenceForTime(
      Recurrence recurrence, TimeOfDay time, DateTime after) {
    DateTime candidate = DateTime(
        after.year, after.month, after.day, time.hour, time.minute);
    // Με μέρες το scan/search παρακάτω βρίσκει την επόμενη έγκυρη·
    // jump μόνο για καθαρά περιοδικά (daily — weekly/monthly χωρίς
    // μέρες αδύνατα από UI). Αλλιώς χάνουμε μέρες της τρέχουσας περιόδου.
    final hasDays = (recurrence.days != null &&
        recurrence.days!.isNotEmpty) &&
        (recurrence.type == RecurrenceType.weekly ||
            recurrence.type == RecurrenceType.monthly);
    if (candidate.isBefore(after) && !hasDays) {
      // nextPeriodStart κρατά ώρα σε daily/custom, μηδενίζει σε
      // monthly/yearly — ομαλοποίηση σε μεσάνυχτα + μία προσθήκη.
      final midnight =
      DateTime(candidate.year, candidate.month, candidate.day);
      // H2: wall-clock ώρα με constructor (όχι .add(Duration(hours:)) —
      // την ημέρα DST έδινε +1ω).
      final nps = recurrence.nextPeriodStart(midnight);
      candidate =
          DateTime(nps.year, nps.month, nps.day, time.hour, time.minute);
    }
    if (recurrence.type == RecurrenceType.weekly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      // Same-day-passed slot (candidate πάντα σήμερα-με-ώρα): αύριο,
      // αλλιώς το loop σπάει με άδειο ορίζοντα (isValid = date-only).
      if (candidate.isBefore(after)) {
        // H2
        candidate = DateTime(candidate.year, candidate.month,
            candidate.day + 1, time.hour, time.minute);
      }
      // Anchor = epochMonday, όπως το getPeriodStart — grid και walker
      // συμφωνούν· ο scheduler χρησιμοποιεί DTSTART (σκόπιμα).
      final cap = recurrence.interval > 1 ? 7 * recurrence.interval + 8 : 8;
      int safety = 0;
      while (!Recurrence.isValidWeeklyDay(candidate, recurrence.days!,
          recurrence.interval, Recurrence.epochMonday) &&
          safety < cap) {
        // H2
        candidate = DateTime(candidate.year, candidate.month,
            candidate.day + 1, time.hour, time.minute);
        safety++;
      }
    }
    if (recurrence.type == RecurrenceType.monthly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      final sortedDays = [...recurrence.days!]..sort();
      DateTime? found;
      for (final d in sortedDays) {
        // Clamp (όχι rollover — το DateTime(2027,2,30) γίνεται 2 Μαρτίου).
        final safe = _safeDay(candidate.year, candidate.month, d);
        final target = DateTime(
            safe.year, safe.month, safe.day, time.hour, time.minute);
        if (target.isAfter(after)) {
          found = target;
          break;
        }
      }
      if (found != null) {
        candidate = found;
      } else {
        // Όλες οι μέρες πέρασαν — επόμενος μήνας (με interval) + clamp.
        int nextMonth = candidate.month + recurrence.interval;
        int nextYear = candidate.year;
        nextYear += (nextMonth - 1) ~/ 12;
        nextMonth = (nextMonth - 1) % 12 + 1;
        final safe = _safeDay(nextYear, nextMonth, sortedDays.first);
        candidate = DateTime(
            safe.year, safe.month, safe.day, time.hour, time.minute);
      }
    }
    return candidate;
  }

  // ══════════════════════════════════════════════════════════
  // GET STATS
  // ══════════════════════════════════════════════════════════

  Future<HabitStats> getStats(int habitId) async {
    try {
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

    // Ποσοστό προόδου για την τρέχουσα ημέρα
    double progressPercent = 0.0;
// Υπολογισμός εβδομαδιαίας προόδου (για weekly habits)
    if (recurrence.type == RecurrenceType.weekly && recurrence.days != null && recurrence.days!.isNotEmpty) {
      final now = DateTime.now();
      final periodStart = recurrence.getPeriodStart(now);
      int totalDaysInPeriod = recurrence.days!.length;
      int completedDaysInPeriod = 0;
      for (int i = 0; i < 7; i++) {
        final day = _dateOnly(periodStart.add(Duration(days: i)));
        if (recurrence.days!.contains(day.weekday)) {
          if (completionDays.contains(day)) {
            completedDaysInPeriod++;
          }
        }
      }
      if (totalDaysInPeriod > 0) {
        progressPercent = (completedDaysInPeriod / totalDaysInPeriod * 100).clamp(0.0, 100.0);
      }
    } else {
      // Παλιός τρόπος για daily/monthly/custom
      if (effectiveGoal > 0) {
        progressPercent = (dailyProgress / effectiveGoal * 100).clamp(0.0, 100.0);
      } else {
        progressPercent = dailyProgress > 0 ? 100.0 : 0.0;
      }
    }

    final streak = _calculateStreak(recurrence, completionDays);
    final completedCount = _countCompletedPeriods(recurrence, completions);

    final bestStr = allProps['best_streak'];
    int bestStreak = _parseToInt(bestStr);
    if (streak > bestStreak) {
      bestStreak = streak;
      await props.setNumber(habitId, 'best_streak', bestStreak.toDouble());
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
    } catch (e, stack) {
      DebugConfig.error('getStats', e, stack);
      return _emptyStats(habitId);
    }
  }

  // ══════════════════════════════════════════════════════════
  // ΒΟΗΘΗΤΙΚΕΣ ΓΙΑ STREAK ΚΑΙ PERIOD CHECK
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
            final targetDay = _safeDay(periodStart.year, periodStart.month, d);
            if (!completionDays.contains(_dateOnly(targetDay))) {
              return false;
            }
          }
          return true;
        } else {
          final daysInMonth =
              DateTime(periodStart.year, periodStart.month + 1, 0).day;
          final base = _dateOnly(periodStart);
          for (int i = 0; i < daysInMonth; i++) {
            if (completionDays.contains(DateTime(
                base.year, base.month, base.day + i))) {
              return true;
            }
          }
          return false;
        }
      case RecurrenceType.yearly:
        if (recurrence.days != null && recurrence.days!.length == 2) {
          // Clamp (όπως monthly) — 29 Φεβ σε μη-δίσεκτο → 28 Φεβ, όχι 1 Μαρ.
          final targetDate = _safeDay(
            periodStart.year,
            recurrence.days![0],
            recurrence.days![1],
          );
          return completionDays.contains(_dateOnly(targetDate));
        }
        return completionDays.contains(_dateOnly(periodStart));
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
        final targetDay = _safeDay(periodStart.year, periodStart.month, d);
        if (_dateOnly(targetDay).isBefore(today) &&
            !completionDays.contains(_dateOnly(targetDay))) {
          return true;
        }
      }
    }

    return false;
  }

  DateTime _prevPeriodStart(DateTime periodStart, Recurrence recurrence) {
    switch (recurrence.type) {
      case RecurrenceType.daily:
      case RecurrenceType.custom:
      // H2: ημερολογιακή αφαίρεση (όχι −24h: την αλλαγή ώρας Μαρτίου
      // παραλειπόταν μέρα στον υπολογισμό streak).
        return DateTime(periodStart.year, periodStart.month,
            periodStart.day - recurrence.interval);
      case RecurrenceType.weekly:
        return DateTime(periodStart.year, periodStart.month,
            periodStart.day - recurrence.interval * 7);
      case RecurrenceType.monthly:
        int month = periodStart.month - recurrence.interval;
        int year = periodStart.year;
        while (month <= 0) {
          month += 12;
          year--;
        }
        return DateTime(year, month, 1);
      case RecurrenceType.yearly:
        return DateTime(periodStart.year - recurrence.interval, 1, 1);
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
        // τρέχουσα περίοδος σε εξέλιξη — δεν σπάει το streak
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
}