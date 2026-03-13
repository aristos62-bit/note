// lib/core/utils/date_utils.dart
//
// Date formatting utilities για SuperNote.
// Όλα τα date formats σε ένα αρχείο.
//
// ΧΡΗΣΗ:
//   AppDateUtils.formatRelative(item.createdAt)  // "πριν 2 ώρες"
//   AppDateUtils.formatDue(task.dueDate)         // "Αύριο" / "Παρ 14 Μαρ"
//   AppDateUtils.formatForJournal(date)          // "Παρασκευή, 14 Μαρτίου 2025"
//
import 'package:intl/intl.dart';

class AppDateUtils {

  // ─────────────────────────────────────────────────────────────
  // RELATIVE — "πριν 2 ώρες", "χθες", "3 μέρες πριν"
  // Χρήση: item lists, last edited timestamps
  // ─────────────────────────────────────────────────────────────

  static String formatRelative(DateTime date) {
    final now  = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60)  return 'μόλις τώρα';
    if (diff.inMinutes < 60)  return 'πριν ${diff.inMinutes} λ.';
    if (diff.inHours < 24)    return 'πριν ${diff.inHours} ω.';
    if (diff.inDays == 1)     return 'χθες';
    if (diff.inDays < 7)      return 'πριν ${diff.inDays} μέρες';
    if (diff.inDays < 30)     return 'πριν ${(diff.inDays / 7).floor()} εβδ.';
    if (diff.inDays < 365)    return 'πριν ${(diff.inDays / 30).floor()} μήνες';
    return 'πριν ${(diff.inDays / 365).floor()} χρόνια';
  }

  // ─────────────────────────────────────────────────────────────
  // DUE DATE — για tasks/events
  // "Ληξιπρόθεσμο", "Σήμερα", "Αύριο", "Παρ 14 Μαρ"
  // ─────────────────────────────────────────────────────────────

  static String formatDue(DateTime? date) {
    if (date == null) return '';

    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    final diff  = d.difference(today).inDays;

    if (diff < 0)  return 'Ληξιπρόθεσμο';
    if (diff == 0) return 'Σήμερα';
    if (diff == 1) return 'Αύριο';
    if (diff < 7)  return DateFormat('EEEE', 'el').format(date); // "Παρασκευή"
    return DateFormat('d MMM', 'el').format(date);               // "14 Μαρ"
  }

  /// Αν η ημερομηνία είναι παρελθόν (ληξιπρόθεσμο)
  static bool isOverdue(DateTime? date) {
    if (date == null) return false;
    return date.isBefore(DateTime.now());
  }

  /// Αν η ημερομηνία είναι σήμερα
  static bool isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Αν η ημερομηνία είναι μέσα στις επόμενες N μέρες
  static bool isDueWithin(DateTime? date, int days) {
    if (date == null) return false;
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    return diff >= 0 && diff <= days;
  }

  // ─────────────────────────────────────────────────────────────
  // JOURNAL FORMAT — "Παρασκευή, 14 Μαρτίου 2025"
  // ─────────────────────────────────────────────────────────────

  static String formatForJournal(DateTime date) =>
      DateFormat('EEEE, d MMMM yyyy', 'el').format(date);

  // ─────────────────────────────────────────────────────────────
  // SHORT — "14 Μαρ 2025"
  // ─────────────────────────────────────────────────────────────

  static String formatShort(DateTime date) =>
      DateFormat('d MMM yyyy', 'el').format(date);

  // ─────────────────────────────────────────────────────────────
  // TIME — "14:30"
  // ─────────────────────────────────────────────────────────────

  static String formatTime(DateTime date) =>
      DateFormat('HH:mm').format(date);

  // ─────────────────────────────────────────────────────────────
  // DATETIME — "14 Μαρ, 14:30"
  // ─────────────────────────────────────────────────────────────

  static String formatDateTime(DateTime date) =>
      '${formatShort(date)}, ${formatTime(date)}';

  // ─────────────────────────────────────────────────────────────
  // HABIT CALENDAR — για το habit streak calendar
  // Επιστρέφει τις ημερομηνίες της τρέχουσας εβδομάδας
  // ─────────────────────────────────────────────────────────────

  static List<DateTime> currentWeekDays() {
    final now   = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  /// Ονόματα ημερών (Δ, Τ, Τ, Π, Π, Σ, Κ)
  static String dayInitial(DateTime date) {
    const initials = ['Δ', 'Τ', 'Τ', 'Π', 'Π', 'Σ', 'Κ'];
    return initials[date.weekday - 1];
  }

  // ─────────────────────────────────────────────────────────────
  // FINANCE — "Μάρτιος 2025"
  // ─────────────────────────────────────────────────────────────

  static String formatMonth(DateTime date) =>
      DateFormat('MMMM yyyy', 'el').format(date);

  // ─────────────────────────────────────────────────────────────
  // GROUPING — group items by date for list headers
  // ─────────────────────────────────────────────────────────────

  static String groupHeader(DateTime date) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    final diff  = today.difference(d).inDays;

    if (diff == 0) return 'Σήμερα';
    if (diff == 1) return 'Χθες';
    if (diff < 7)  return DateFormat('EEEE', 'el').format(date);
    return formatShort(date);
  }

  /// Group a list of items by date header
  static Map<String, List<T>> groupByDate<T>(
      List<T> items,
      DateTime Function(T) getDate,
      ) {
    final map = <String, List<T>>{};
    for (final item in items) {
      final key = groupHeader(getDate(item));
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }
}

// ────────────────────────────────────────────────────────────────
// EXTENSIONS
// ────────────────────────────────────────────────────────────────

extension DateTimeX on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  bool get isOverdue => isBefore(DateTime.now());

  bool get isThisWeek {
    final now   = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end   = start.add(const Duration(days: 6));
    return isAfter(start.subtract(const Duration(days: 1))) &&
        isBefore(end.add(const Duration(days: 1)));
  }

  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay   => DateTime(year, month, day, 23, 59, 59);

  String get relative  => AppDateUtils.formatRelative(this);
  String get due       => AppDateUtils.formatDue(this);
  String get short     => AppDateUtils.formatShort(this);
  String get timeOnly  => AppDateUtils.formatTime(this);
  String get dateTime  => AppDateUtils.formatDateTime(this);
}