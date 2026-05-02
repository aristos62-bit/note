// lib/models/recurrence.dart
import 'dart:convert';

enum RecurrenceType { daily, weekly, monthly, custom }

class Recurrence {
  final RecurrenceType type;
  final int interval;

  /// Χρήση ανά τύπο:
  ///   weekly:  weekday numbers [1=Δευ ... 7=Κυρ]
  ///   monthly: day-of-month numbers [1-31]
  final List<int>? days;

  /// Μόνο για daily: λίστα ωρών ["08:00", "11:00", "16:00", "20:00"]
  /// Κάθε ώρα = ένα sub-goal. Στόχος = ALL ώρες ολοκληρωμένες.
  final List<String>? times;

  const Recurrence({
    this.type = RecurrenceType.daily,
    this.interval = 1,
    this.days,
    this.times,
  });

  // ─── Backwards compat getter ───────────────────────────────
  /// Επιστρέφει την πρώτη ημέρα (για monthly single-day compat)
  int? get dayOfMonth =>
      (type == RecurrenceType.monthly && days != null && days!.isNotEmpty)
          ? days!.first
          : null;

  // ─── Factory constructors ──────────────────────────────────
  factory Recurrence.daily({List<String>? times}) =>
      Recurrence(type: RecurrenceType.daily, times: times);

  factory Recurrence.weekly({List<int>? days}) =>
      Recurrence(type: RecurrenceType.weekly, days: days);

  factory Recurrence.monthly({List<int>? days}) =>
      Recurrence(type: RecurrenceType.monthly, days: days);

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

    // ── Weekly: weekday numbers ──────────────────────────────
    if (type == RecurrenceType.weekly) {
      final daysJson = props['recurrence_days'];
      if (daysJson != null && daysJson.isNotEmpty) {
        try {
          days = (jsonDecode(daysJson) as List).map((e) => e as int).toList();
        } catch (_) {}
      }
    }

    // ── Monthly: day-of-month numbers ────────────────────────
    if (type == RecurrenceType.monthly) {
      final dayStr = props['recurrence_days'];
      if (dayStr != null && dayStr.isNotEmpty) {
        try {
          // Νέα μορφή: JSON array [1, 15]
          days = (jsonDecode(dayStr) as List).map((e) => e as int).toList();
        } catch (_) {
          // Παλιά μορφή: single int string "15" — backwards compat
          final d = int.tryParse(dayStr);
          if (d != null) days = [d];
        }
      }
    }

    // ── Daily / Custom: ώρες ────────────────────────────────
    if (type == RecurrenceType.daily || type == RecurrenceType.custom) {
      final timesStr = props['recurrence_times'];
      if (timesStr != null && timesStr.isNotEmpty) {
        try {
          times =
              (jsonDecode(timesStr) as List).map((e) => e.toString()).toList();
        } catch (_) {}
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
        final startOfWeek = date.subtract(Duration(days: daysSinceMonday));
        if (interval == 1) return startOfWeek;
        final ref = DateTime(1970, 1, 5);
        final weeksSinceRef =
        (startOfWeek.difference(ref).inDays / 7).floor();
        final alignedWeeks = weeksSinceRef - (weeksSinceRef % interval);
        return ref.add(Duration(days: alignedWeeks * 7));
      case RecurrenceType.monthly:
        if (interval == 1) return DateTime(date.year, date.month, 1);
        final totalMonths = date.year * 12 + (date.month - 1);
        final alignedMonths = totalMonths - (totalMonths % interval);
        final year = alignedMonths ~/ 12;
        final month = alignedMonths % 12 + 1;
        return DateTime(year, month, 1);
      case RecurrenceType.custom:
        return DateTime(date.year, date.month, date.day);
    }
  }

  DateTime nextPeriodStart(DateTime periodStart) {
    switch (type) {
      case RecurrenceType.daily:
        return periodStart.add(Duration(days: interval));
      case RecurrenceType.weekly:
        return periodStart.add(Duration(days: interval * 7));
      case RecurrenceType.monthly:
        int nextMonth = periodStart.month + interval;
        int nextYear = periodStart.year;
        nextYear += (nextMonth - 1) ~/ 12;
        nextMonth = (nextMonth - 1) % 12 + 1;
        return DateTime(nextYear, nextMonth, 1);
      case RecurrenceType.custom:
        return periodStart.add(Duration(days: interval));
    }
  }

  bool hasPeriodEnded(DateTime periodStart, DateTime now) {
    final next = nextPeriodStart(periodStart);
    return now.isAfter(next) || now.isAtSameMomentAs(next);
  }

  // ─────────────────────────────────────────────────────────
  // nextOccurrence — για reminder scheduling
  // Επιστρέφει την αμέσως επόμενη εμφάνιση μετά το `from`
  // ─────────────────────────────────────────────────────────
  DateTime? nextOccurrence(DateTime from) {
    DateTime next;

    switch (type) {
      case RecurrenceType.daily:
      case RecurrenceType.custom:
        next = DateTime(from.year, from.month, from.day)
            .add(Duration(days: interval));
        break;

      case RecurrenceType.weekly:
        if (days != null && days!.isNotEmpty) {
          // Βρες την επόμενη προγραμματισμένη μέρα
          DateTime candidate = from.add(const Duration(days: 1));
          int safety = 0;
          while (!days!.contains(candidate.weekday) && safety < 8) {
            candidate = candidate.add(const Duration(days: 1));
            safety++;
          }
          next = candidate;
        } else {
          next = from.add(Duration(days: 7 * interval));
        }
        break;

      case RecurrenceType.monthly:
        if (days != null && days!.isNotEmpty) {
          final sortedDays = [...days!]..sort();
          final today = DateTime(from.year, from.month, from.day);
          DateTime? found;

          // Ψάξε στον τρέχοντα μήνα
          for (final d in sortedDays) {
            final candidate = _safeMonthDay(from.year, from.month, d);
            if (candidate.isAfter(today)) {
              found = candidate;
              break;
            }
          }

          // Αν δεν βρέθηκε → πρώτη μέρα του επόμενου μήνα
          if (found == null) {
            int nextMonth = from.month + interval;
            int nextYear = from.year;
            nextYear += (nextMonth - 1) ~/ 12;
            nextMonth = (nextMonth - 1) % 12 + 1;
            found = _safeMonthDay(nextYear, nextMonth, sortedDays.first);
          }

          next = found;
        } else {
          int nextMonth = from.month + interval;
          int nextYear = from.year;
          nextYear += (nextMonth - 1) ~/ 12;
          nextMonth = (nextMonth - 1) % 12 + 1;
          next = _safeMonthDay(nextYear, nextMonth, from.day);
        }
        break;
    }

    // Διατηρούμε ώρα/λεπτό/δευτερόλεπτο από το from
    return DateTime(
      next.year, next.month, next.day,
      from.hour, from.minute, from.second,
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
        const dayNames = ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
        final daysStr = days!.map((d) => dayNames[d - 1]).join(', ');
        return interval == 1
            ? 'Κάθε εβδομάδα ($daysStr)'
            : 'Κάθε $interval εβδομάδες ($daysStr)';

      case RecurrenceType.monthly:
        if (days != null && days!.isNotEmpty) {
          final sorted = [...days!]..sort();
          final daysStr = sorted.map((d) => '$dη').join(', ');
          return interval == 1
              ? 'Κάθε μήνα ($daysStr)'
              : 'Κάθε $interval μήνες ($daysStr)';
        }
        return interval == 1 ? 'Κάθε μήνα' : 'Κάθε $interval μήνες';

      case RecurrenceType.custom:
        return 'Κάθε $interval ημέρες';
    }
  }

  // ─────────────────────────────────────────────────────────
  // Helper: ασφαλής ημερομηνία (clamp στην τελευταία μέρα μήνα)
  // ─────────────────────────────────────────────────────────
  static DateTime _safeMonthDay(int year, int month, int day) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final safeDayOfMonth = day.clamp(1, lastDayOfMonth);
    return DateTime(year, month, safeDayOfMonth);
  }
}