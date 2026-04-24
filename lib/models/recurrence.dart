// lib/models/recurrence.dart
import 'dart:convert';

enum RecurrenceType { daily, weekly, monthly, custom }

class Recurrence {
  final RecurrenceType type;
  final int interval;
  final List<int>? days;        // 1 = Monday ... 7 = Sunday
  final int? dayOfMonth;

  const Recurrence({
    this.type = RecurrenceType.daily,
    this.interval = 1,
    this.days,
    this.dayOfMonth,
  });

  factory Recurrence.daily() => const Recurrence(type: RecurrenceType.daily);
  factory Recurrence.weekly({List<int>? days}) => Recurrence(type: RecurrenceType.weekly, days: days);
  factory Recurrence.monthly({int? dayOfMonth}) => Recurrence(type: RecurrenceType.monthly, dayOfMonth: dayOfMonth);

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
      dayOfMonth: json['dayOfMonth'],
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'interval': interval,
    if (days != null) 'days': days,
    if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
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
    if (type == RecurrenceType.weekly) {
      final daysJson = props['recurrence_days'];
      if (daysJson != null && daysJson.isNotEmpty) {
        days = (jsonDecode(daysJson) as List).map((e) => e as int).toList();
      }
    }
    int? dayOfMonth;
    if (type == RecurrenceType.monthly) {
      final dayStr = props['recurrence_days'];
      dayOfMonth = int.tryParse(dayStr ?? '');
    }
    return Recurrence(
      type: type,
      interval: interval,
      days: days,
      dayOfMonth: dayOfMonth,
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
        final weeksSinceRef = (startOfWeek.difference(ref).inDays / 7).floor();
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
        return DateTime(periodStart.year, periodStart.month + interval, 1);
      case RecurrenceType.custom:
        return periodStart.add(Duration(days: interval));
    }
  }

  bool hasPeriodEnded(DateTime periodStart, DateTime now) {
    final nextPeriodStart = this.nextPeriodStart(periodStart);
    return now.isAfter(nextPeriodStart) || now.isAtSameMomentAs(nextPeriodStart);
  }

  // ─────────────────────────────────────────────────────────
  // Υπολογισμός επόμενης ημερομηνίας για reminders
  // ─────────────────────────────────────────────────────────

  /// Υπολογίζει την επόμενη ημερομηνία που συμβαίνει η επανάληψη,
  /// ξεκινώντας από το `from` (συνήθως DateTime.now()).
  /// Διατηρεί την ίδια ώρα, λεπτό, δευτερόλεπτο με το `from`.
  /// Επιστρέφει null αν δεν μπορεί να υπολογιστεί (δεν αναμένεται).
  DateTime? nextOccurrence(DateTime from) {
    DateTime next = from; // αρχικοποίηση για να αποφύγουμε το error

    switch (type) {
      case RecurrenceType.daily:
        next = DateTime(from.year, from.month, from.day).add(Duration(days: interval));
        break;

      case RecurrenceType.weekly:
        if (days != null && days!.isNotEmpty) {
          bool found = false;
          for (int i = 1; i <= 7; i++) {
            final candidate = from.add(Duration(days: i));
            if (days!.contains(candidate.weekday)) {
              next = candidate;
              found = true;
              break;
            }
          }
          if (!found) {
            next = from.add(const Duration(days: 7));
          }
        } else {
          next = from.add(Duration(days: 7 * interval));
        }
        break;

      case RecurrenceType.monthly:
        if (dayOfMonth != null) {
          int targetDay = dayOfMonth!;
          DateTime firstTry = DateTime(from.year, from.month, targetDay);
          if (firstTry.isAfter(from)) {
            next = firstTry;
          } else {
            int nextMonth = from.month + interval;
            int nextYear = from.year;
            if (nextMonth > 12) {
              nextYear++;
              nextMonth -= 12;
            }
            next = DateTime(nextYear, nextMonth, targetDay);
          }
        } else {
          next = DateTime(from.year, from.month + interval, from.day);
        }
        break;

      case RecurrenceType.custom:
        next = from.add(Duration(days: interval));
        break;
    }

    // Διατηρούμε την ώρα, λεπτό, δευτερόλεπτο από το αρχικό triggerAt
    return DateTime(
      next.year, next.month, next.day,
      from.hour, from.minute, from.second,
    );
  }

  // ─────────────────────────────────────────────────────────
  // RRULE conversion (για ReminderSection)
  // ─────────────────────────────────────────────────────────
  String toRRULE() {
    switch (type) {
      case RecurrenceType.daily:
        return 'FREQ=DAILY;INTERVAL=$interval';
      case RecurrenceType.weekly:
        if (days != null && days!.isNotEmpty) {
          const wd = ['MO','TU','WE','TH','FR','SA','SU'];
          final byday = days!.map((d) => wd[d-1]).join(',');
          return 'FREQ=WEEKLY;INTERVAL=$interval;BYDAY=$byday';
        } else {
          return 'FREQ=WEEKLY;INTERVAL=$interval';
        }
      case RecurrenceType.monthly:
        if (dayOfMonth != null) {
          return 'FREQ=MONTHLY;INTERVAL=$interval;BYMONTHDAY=$dayOfMonth';
        } else {
          return 'FREQ=MONTHLY;INTERVAL=$interval';
        }
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
        return interval == 1 ? 'Καθημερινά' : 'Κάθε $interval ημέρες';
      case RecurrenceType.weekly:
        if (days == null || days!.isEmpty) {
          return interval == 1 ? 'Κάθε εβδομάδα' : 'Κάθε $interval εβδομάδες';
        }
        const dayNames = ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
        final daysStr = days!.map((d) => dayNames[d - 1]).join(', ');
        return interval == 1
            ? 'Κάθε εβδομάδα ($daysStr)'
            : 'Κάθε $interval εβδομάδες ($daysStr)';
      case RecurrenceType.monthly:
        if (dayOfMonth != null) {
          return interval == 1
              ? 'Κάθε μήνα, ημέρα $dayOfMonth'
              : 'Κάθε $interval μήνες, ημέρα $dayOfMonth';
        }
        return interval == 1 ? 'Κάθε μήνα' : 'Κάθε $interval μήνες';
      case RecurrenceType.custom:
        return 'Κάθε $interval ημέρες';
    }
  }
}