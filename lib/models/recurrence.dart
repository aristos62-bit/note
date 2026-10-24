// lib/models/recurrence.dart
import 'dart:convert';
import '../core/utils/date_utils.dart';
import '../core/utils/debug_config.dart';

enum RecurrenceType { daily, weekly, monthly, yearly, custom }

class Recurrence {
  final RecurrenceType type;
  final int interval;

  /// Χρήση ανά τύπο:
  ///   weekly:  weekday numbers [1=Δευ ... 7=Κυρ]
  ///   monthly: day-of-month numbers [1-31]
  ///   yearly:  [month (1-12), day (1-31)]  ← ΝΕΟ
  final List<int>? days;

  /// Ώρες ειδοποίησης (daily/weekly/monthly): ["08:00", "11:00", "16:00"]
  /// Η πρόοδος/στόχος παραμένουν ημέρας-περιόδου — οι ώρες χτυπούν μόνο ειδοποιήσεις.
  final List<String>? times;

  const Recurrence({
    this.type = RecurrenceType.daily,
    this.interval = 1,
    this.days,
    this.times,
  });

  // ─── Backwards compat getter ───────────────────────────────
  int? get dayOfMonth =>
      (type == RecurrenceType.monthly && days != null && days!.isNotEmpty)
          ? days!.first
          : null;

  // ─── Factory constructors ──────────────────────────────────
  factory Recurrence.daily({List<String>? times}) =>
      Recurrence(type: RecurrenceType.daily, times: times);

  factory Recurrence.weekly({List<int>? days, List<String>? times}) =>
      Recurrence(type: RecurrenceType.weekly, days: days, times: times);

  factory Recurrence.monthly({List<int>? days, List<String>? times}) =>
      Recurrence(type: RecurrenceType.monthly, days: days, times: times);

  /// Ετήσια επανάληψη: days = [month, day]
  factory Recurrence.yearly({required int month, required int day}) =>
      Recurrence(type: RecurrenceType.yearly, days: [month, day]);

  // ─────────────────────────────────────────────────────────
  // fromJson / toJson (για UI)
  // ─────────────────────────────────────────────────────────
  factory Recurrence.fromJson(Map<String, dynamic> json) {
    return Recurrence(
      type: RecurrenceType.values.firstWhere(
            (e) => e.name == json['type'],
        orElse: () => RecurrenceType.daily,
      ),
      interval: json['interval'] ?? 1,
      days: json['days'] != null ? List<int>.from(json['days']) : null,
      times: json['times'] != null ? List<String>.from(json['times']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'interval': interval,
    if (days != null) 'days': days,
    if (times != null) 'times': times,
  };

  // ─────────────────────────────────────────────────────────
  // fromProperties (για habit_service)
  // ─────────────────────────────────────────────────────────
  factory Recurrence.fromProperties(Map<String, String?> props) {
    final typeStr = props['recurrence_type'] ?? 'daily';
    final type = RecurrenceType.values.firstWhere(
          (e) => e.name == typeStr,
      orElse: () => RecurrenceType.daily,
    );
    final interval = int.tryParse(props['recurrence_interval'] ?? '1') ?? 1;

    List<int>? days;
    List<String>? times;

    if (type == RecurrenceType.weekly) {
      final daysJson = props['recurrence_days'];
      if (daysJson != null && daysJson.isNotEmpty) {
        try {
          days = (jsonDecode(daysJson) as List).map((e) => e as int).toList();
        } catch (e) {
          DebugConfig.warning(
              'Recurrence.fromProperties: weekly days parse failed: $e');
        }
      }
    }

    if (type == RecurrenceType.monthly) {
      final dayStr = props['recurrence_days'];
      if (dayStr != null && dayStr.isNotEmpty) {
        try {
          days = (jsonDecode(dayStr) as List).map((e) => e as int).toList();
        } catch (_) {
          final d = int.tryParse(dayStr);
          if (d != null) days = [d];
        }
      }
    }

    if (type == RecurrenceType.yearly) {
      final daysJson = props['recurrence_days'];
      if (daysJson != null && daysJson.isNotEmpty) {
        try {
          days = (jsonDecode(daysJson) as List).map((e) => e as int).toList();
        } catch (e) {
          DebugConfig.warning(
              'Recurrence.fromProperties: yearly days parse failed: $e');
        }
      }
    }

    // Ώρες: daily/custom (από παλιά) + weekly/monthly (ώρες ειδοποίησης).
    // Yearly εξαιρείται ρητά — ώρες σε ετήσια δεν έχουν νόημα.
    if (type != RecurrenceType.yearly) {
      final timesStr = props['recurrence_times'];
      if (timesStr != null && timesStr.isNotEmpty) {
        try {
          times =
              (jsonDecode(timesStr) as List).map((e) => e.toString()).toList();
        } catch (e) {
          DebugConfig.warning(
              'Recurrence.fromProperties: times parse failed: $e');
        }
      }
    }

    return Recurrence(
      type: type,
      interval: interval,
      days: days,
      times: times,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Period logic (για habit_service)
  // ─────────────────────────────────────────────────────────
  DateTime getPeriodStart(DateTime date) {
    switch (type) {
      case RecurrenceType.daily:
        return DateTime(date.year, date.month, date.day);
      case RecurrenceType.weekly:
        final daysSinceMonday = (date.weekday - 1) % 7;
        // Ημερολογιακή αφαίρεση + μεσάνυχτα (όχι subtract(Duration)/add(Duration):
        // DST → ±1ω, ώρα του date διατηρείτο, ref+N·168ω έδινε Δευτέρα 01:00 το καλοκαίρι).
        final startOfWeek =
            DateTime(date.year, date.month, date.day - daysSinceMonday);
        if (interval == 1) return startOfWeek;
        final ref = epochMonday;
        final weeksSinceRef =
        (_calendarDaysBetween(startOfWeek, ref) / 7).floor();
        final alignedWeeks = weeksSinceRef - (weeksSinceRef % interval);
        return DateTime(ref.year, ref.month, ref.day + alignedWeeks * 7);
      case RecurrenceType.monthly:
        if (interval == 1) return DateTime(date.year, date.month, 1);
        final totalMonths = date.year * 12 + (date.month - 1);
        final alignedMonths = totalMonths - (totalMonths % interval);
        final year = alignedMonths ~/ 12;
        final month = alignedMonths % 12 + 1;
        return DateTime(year, month, 1);
      case RecurrenceType.yearly:
      // Αρχή του έτους (aligned με interval)
        if (interval == 1) return DateTime(date.year, 1, 1);
        final alignedYear = date.year - (date.year % interval);
        return DateTime(alignedYear, 1, 1);
      case RecurrenceType.custom:
        return DateTime(date.year, date.month, date.day);
    }
  }

  DateTime nextPeriodStart(DateTime periodStart) {
    switch (type) {
      case RecurrenceType.daily:
        return DateTime(periodStart.year, periodStart.month,
            periodStart.day + interval);
      case RecurrenceType.weekly:
        return DateTime(periodStart.year, periodStart.month,
            periodStart.day + interval * 7);
      case RecurrenceType.monthly:
        int nextMonth = periodStart.month + interval;
        int nextYear = periodStart.year;
        nextYear += (nextMonth - 1) ~/ 12;
        nextMonth = (nextMonth - 1) % 12 + 1;
        return DateTime(nextYear, nextMonth, 1);
      case RecurrenceType.yearly:
        return DateTime(periodStart.year + interval, 1, 1);
      case RecurrenceType.custom:
        return periodStart.add(Duration(days: interval));
    }
  }

  bool hasPeriodEnded(DateTime periodStart, DateTime now) {
    final next = nextPeriodStart(periodStart);
    return now.isAfter(next) || now.isAtSameMomentAs(next);
  }

  // ─────────────────────────────────────────────────────────
  // Week-math SPoT για weekly interval>1 (_BYDAY_).
  // ─────────────────────────────────────────────────────────

  /// ΑΠΟΦΑΣΗ anchor (S54/S61): habit grid + walker μετράνε από epochMonday
  /// (σταθερό, ίδιο για όλους)· ο generic scheduler μετράει από DTSTART
  /// (root.triggerAt — RRULE-σωστό) και ΣΚΙΠΑΡΕΙ habit-roots. Το native
  /// habit flow είναι εσωτερικά συνεπές (αμφότερα epoch)· η απόκλιση
  /// αφορά μόνο παγωμένα bell-rows. ΜΗΝ ενοποιήσεις χωρίς ξεχωριστή απόφαση.
  /// Monday-ref για multi-week στοίχιση χωρίς user anchor (ίδιο με getPeriodStart).
  static final DateTime epochMonday = DateTime(1970, 1, 5);

  static DateTime _mondayOf(DateTime d) {
    return DateTime(d.year, d.month, d.day - (d.weekday - 1) % 7);
  }

  /// Ημερολογιακή διαφορά ημερών (ανοσία DST): UTC-midnights. Το τοπικό
  /// .difference().inDays χάνει/κερδίζει μέρα στα όρια DST (βδομάδα 167/169h
  /// → inDays 6/7 → λάθος ισοτιμία στο interval>1). Εκτελεστικά: 2026 → 0
  /// violations (παλιός τρόπος: 2).
  static int _calendarDaysBetween(DateTime a, DateTime b) {
    final ua = DateTime.utc(a.year, a.month, a.day);
    final ub = DateTime.utc(b.year, b.month, b.day);
    return ua.difference(ub).inDays;
  }

  /// Ακέραιος αριθμός εβδομάδων από την εβδομάδα του anchor (αρνητικό → 0).
  static int _weeksSinceAnchor(DateTime date, DateTime anchor) {
    final w = _calendarDaysBetween(_mondayOf(date), _mondayOf(anchor)) ~/ 7;
    return w < 0 ? 0 : w;
  }

  /// Έγκυρη weekly μέρα: weekday στα days ΚΑΙ εβδομάδα στο interval από anchor.
  /// Με interval <= 1 συμπεριφέρεται ακριβώς όπως το παλιό contains-check.
  static bool isValidWeeklyDay(
      DateTime date, List<int> days, int interval, DateTime anchor) {
    if (!days.contains(date.weekday)) return false;
    if (interval <= 1) return true;
    return _weeksSinceAnchor(date, anchor) % interval == 0;
  }

  // ─────────────────────────────────────────────────────────
  // nextOccurrence — για reminder scheduling
  // ─────────────────────────────────────────────────────────
  DateTime? nextOccurrence(DateTime from, {DateTime? anchor}) {
    DateTime next;

    switch (type) {
      case RecurrenceType.daily:
      case RecurrenceType.custom:
        // Ημερολογιακές μέρες (όχι +24h durations): ανοσία σε DST
        // transitions — η fall-back 25ωρη μέρα θα «κολλούσε» (ίδια μέρα)
        // ή θα μετατόπιζε το πλέγμα interval>1.
        next = DateTime(from.year, from.month, from.day + interval);
        break;

      case RecurrenceType.weekly:
        if (days != null && days!.isNotEmpty) {
          if (interval > 1 && anchor != null) {
            DateTime candidate = DateTime(from.year, from.month, from.day + 1,
                from.hour, from.minute, from.second);
            final cap = 7 * interval + 8;
            int safety = 0;
            while (!isValidWeeklyDay(candidate, days!, interval, anchor) &&
                safety < cap) {
              candidate = DateTime(candidate.year, candidate.month,
                  candidate.day + 1, from.hour, from.minute, from.second);
              safety++;
            }
            next = candidate;
          } else {
            DateTime candidate = DateTime(from.year, from.month, from.day + 1,
                from.hour, from.minute, from.second);
            int safety = 0;
            while (!days!.contains(candidate.weekday) && safety < 8) {
              candidate = DateTime(candidate.year, candidate.month,
                  candidate.day + 1, from.hour, from.minute, from.second);
              safety++;
            }
            next = candidate;
          }
        } else {
          next = DateTime(from.year, from.month,
              from.day + 7 * interval, from.hour, from.minute, from.second);
        }
        break;

      case RecurrenceType.monthly:
        if (days != null && days!.isNotEmpty) {
          final sortedDays = [...days!]..sort();
          DateTime? found;

          // Time-aware (mirror habit walker): η clamped μέρα με την ώρα
          // του from — ισότητα ημερομηνίας δεν αρκεί (θα επέστρεφε το ίδιο).
          for (final d in sortedDays) {
            final safe = _safeMonthDay(from.year, from.month, d);
            final candidate = DateTime(safe.year, safe.month, safe.day,
                from.hour, from.minute, from.second);
            if (candidate.isAfter(from)) {
              found = candidate;
              break;
            }
          }

          if (found == null) {
            int nextMonth = from.month + interval;
            int nextYear = from.year;
            nextYear += (nextMonth - 1) ~/ 12;
            nextMonth = (nextMonth - 1) % 12 + 1;
            final safe = _safeMonthDay(nextYear, nextMonth, sortedDays.first);
            found = DateTime(safe.year, safe.month, safe.day,
                from.hour, from.minute, from.second);
          }

          next = found;
        } else {
          int nextMonth = from.month + interval;
          int nextYear = from.year;
          nextYear += (nextMonth - 1) ~/ 12;
          nextMonth = (nextMonth - 1) % 12 + 1;
          // Anti-drift: η ημέρα από το anchor (root), όχι από το clamped from.
          next = _safeMonthDay(nextYear, nextMonth, anchor?.day ?? from.day);
        }
        break;

    // ── ΝΕΟ: Yearly ─────────────────────────────────────────
      case RecurrenceType.yearly:
        if (days != null && days!.length == 2) {
          // days[0] = μήνας (1-12), days[1] = ημέρα (1-31)
          final month = days![0];
          final day   = days![1];
          final fromDate = DateTime(from.year, from.month, from.day);

          // Πρώτα έλεγξε αν η ημερομηνία του τρέχοντος έτους είναι στο μέλλον
          final thisYear = DateTime(
            from.year,
            month,
            _safeDay(from.year, month, day),
          );

          if (thisYear.isAfter(fromDate)) {
            next = thisYear;
          } else {
            // Πήγαινε στο επόμενο έτος (με interval)
            final targetYear = from.year + interval;
            next = DateTime(
              targetYear,
              month,
              _safeDay(targetYear, month, day),
            );
          }
        } else {
          // Fallback: ίδια μέρα/μήνας του επόμενου έτους (clamp, όπως
          // παντού — το raw DateTime(2025,2,29) γίνεται 1 Μαρτίου).
          next = DateTime(from.year + interval, from.month,
              _safeDay(from.year + interval, from.month, from.day));
        }
        break;
    }

    return DateTime(
        next.year,
        next.month,
        next.day,
        from.hour, from.minute, from.second
    );
  }

  // ─────────────────────────────────────────────────────────
  // RRULE conversion
  // ─────────────────────────────────────────────────────────
  String toRRULE() {
    switch (type) {
      case RecurrenceType.daily:
        return 'FREQ=DAILY;INTERVAL=$interval';
      case RecurrenceType.weekly:
        if (days != null && days!.isNotEmpty) {
          const wd = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
          final byday = days!.map((d) => wd[d - 1]).join(',');
          return 'FREQ=WEEKLY;INTERVAL=$interval;BYDAY=$byday';
        }
        return 'FREQ=WEEKLY;INTERVAL=$interval';
      case RecurrenceType.monthly:
        if (days != null && days!.isNotEmpty) {
          final byMonthDay = days!.join(',');
          return 'FREQ=MONTHLY;INTERVAL=$interval;BYMONTHDAY=$byMonthDay';
        }
        return 'FREQ=MONTHLY;INTERVAL=$interval';
      case RecurrenceType.yearly:
        if (days != null && days!.length == 2) {
          return 'FREQ=YEARLY;INTERVAL=$interval;BYMONTH=${days![0]};BYMONTHDAY=${days![1]}';
        }
        return 'FREQ=YEARLY;INTERVAL=$interval';
      case RecurrenceType.custom:
        return 'FREQ=DAILY;INTERVAL=$interval';
    }
  }

  // ─────────────────────────────────────────────────────────
  // Περιγραφή για UI
  // ─────────────────────────────────────────────────────────
  String describe() {
    switch (type) {
      case RecurrenceType.daily:
        if (times != null && times!.isNotEmpty) {
          final timesStr = times!.join(', ');
          return interval == 1
              ? 'Καθημερινά ($timesStr)'
              : 'Κάθε $interval ημέρες ($timesStr)';
        }
        return interval == 1 ? 'Καθημερινά' : 'Κάθε $interval ημέρες';

      case RecurrenceType.weekly:
        if (days == null || days!.isEmpty) {
          return interval == 1
              ? 'Κάθε εβδομάδα'
              : 'Κάθε $interval εβδομάδες';
        }
        const dayNames = AppDateUtils.weekdayNames;
        final daysStr = days!.map((d) => dayNames[d - 1]).join(', ');
        final base = interval == 1
            ? 'Κάθε εβδομάδα ($daysStr)'
            : 'Κάθε $interval εβδομάδες ($daysStr)';
        if (times != null && times!.isNotEmpty) {
          return '$base • ${times!.join(', ')}';
        }
        return base;

      case RecurrenceType.monthly:
        if (days != null && days!.isNotEmpty) {
          final sorted = [...days!]..sort();
          final daysStr = sorted.map((d) => '$dη').join(', ');
          final base = interval == 1
              ? 'Κάθε μήνα ($daysStr)'
              : 'Κάθε $interval μήνες ($daysStr)';
          if (times != null && times!.isNotEmpty) {
            return '$base • ${times!.join(', ')}';
          }
          return base;
        }
        return interval == 1 ? 'Κάθε μήνα' : 'Κάθε $interval μήνες';

      case RecurrenceType.yearly:
        if (days != null && days!.length == 2) {
          const monthNames = AppDateUtils.monthNames;
          final m = days![0].clamp(1, 12);
          return interval == 1
              ? 'Κάθε χρόνο (${days![1]} ${monthNames[m - 1]})'
              : 'Κάθε $interval χρόνια (${days![1]} ${monthNames[m - 1]})';
        }
        return interval == 1 ? 'Κάθε χρόνο' : 'Κάθε $interval χρόνια';

      case RecurrenceType.custom:
        return 'Κάθε $interval ημέρες';
    }
  }

  // ─────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────

  /// Ασφαλής ημερομηνία — clamp στην τελευταία μέρα του μήνα
  /// SPoT: χρησιμοποιείται και από HabitService αντί για local _safeDay.
  static DateTime safeMonthDay(int year, int month, int day) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final safeDayOfMonth = day.clamp(1, lastDayOfMonth);
    return DateTime(year, month, safeDayOfMonth);
  }

  /// Ασφαλής ημέρα για έτος/μήνα — επιστρέφει int
  static int safeDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return day.clamp(1, lastDay);
  }

  static DateTime _safeMonthDay(int year, int month, int day) =>
      safeMonthDay(year, month, day);

  /// Ασφαλής ημέρα για έτος/μήνα — επιστρέφει int
  static int _safeDay(int year, int month, int day) =>
      safeDay(year, month, day);
}