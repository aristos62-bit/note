// test/recurrence_weekly_test.dart
//
// Pure-Dart tests για weekly interval>1 + BYDAY (Session 54).
// Τρέξιμο: flutter test test/recurrence_weekly_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/recurrence.dart';
import 'package:super_note/core/utils/recurrence_utils.dart';

void main() {
  group('isValidWeeklyDay', () {
    // Δευτέρα 05/10/2026, anchor ίδια μέρα.
    final anchor = DateTime(2026, 10, 5, 9, 0);
    const days = [DateTime.monday];

    test('interval=1: κάθε Δευτέρα έγκυρη', () {
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 5), days, 1, anchor), isTrue);
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 12), days, 1, anchor), isTrue);
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 6), days, 1, anchor), isFalse);
    });

    test('interval=2: μόνο ανά 2η εβδομάδα', () {
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 5), days, 2, anchor), isTrue);
      // 12/10 = επόμενη εβδομάδα → άκυρη
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 12), days, 2, anchor), isFalse);
      // 19/10 = μεθεπόμενη → έγκυρη
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 19), days, 2, anchor), isTrue);
      // Τρίτη έγκυρης εβδομάδας → άκυρη (λάθος weekday)
      expect(Recurrence.isValidWeeklyDay(DateTime(2026, 10, 20), days, 2, anchor), isFalse);
    });

    test('anchor στο μέλλον → week 0, δεν κολλάει', () {
      final futureAnchor = DateTime(2027, 1, 4);
      expect(
          Recurrence.isValidWeeklyDay(
              DateTime(2026, 10, 5), days, 2, futureAnchor),
          isTrue);
    });
  });

  group('nextOccurrence weekly', () {
    test('interval=2 Δευτέρα από 5/10 → 19/10 (όχι 12/10)', () {
      const r = Recurrence(type: RecurrenceType.weekly, interval: 2, days: [DateTime.monday]);
      final from = DateTime(2026, 10, 5, 9, 0);
      final next = r.nextOccurrence(from, anchor: DateTime(2026, 10, 5, 9, 0))!;
      expect(next.year, 2026);
      expect(next.month, 10);
      expect(next.day, 19);
      expect(next.weekday, DateTime.monday);
      // Ώρα διατηρείται από from.
      expect(next.hour, 9);
    });

    test('legacy path (χωρίς anchor) = παλιά συμπεριφορά', () {
      const r = Recurrence(type: RecurrenceType.weekly, interval: 2, days: [DateTime.monday]);
      final next = r.nextOccurrence(DateTime(2026, 10, 5, 9, 0))!;
      expect(next.day, 12); // παλιά (λανθασμένη) συμπεριφορά διατηρείται
    });

    test('interval=1 αμετάβλητο', () {
      const r = Recurrence(type: RecurrenceType.weekly, days: [DateTime.monday]);
      final next = r.nextOccurrence(DateTime(2026, 10, 6, 9, 0), anchor: DateTime(2026, 10, 5))!;
      expect(next.day, 12);
    });
  });

  group('anchor divergence — documented decision (epoch vs root)', () {
    const days = [DateTime.monday];
    final mon0 = Recurrence.epochMonday;
    final mon1 = mon0.add(const Duration(days: 7));
    final mon2 = mon0.add(const Duration(days: 14));

    test('epoch: mon0 ON, mon1 OFF, mon2 ON', () {
      expect(Recurrence.isValidWeeklyDay(mon0, days, 2, Recurrence.epochMonday), isTrue);
      expect(Recurrence.isValidWeeklyDay(mon1, days, 2, Recurrence.epochMonday), isFalse);
      expect(Recurrence.isValidWeeklyDay(mon2, days, 2, Recurrence.epochMonday), isTrue);
    });

    test('root σε off-epoch εβδομάδα: αντίστροφα (mirror)', () {
      expect(Recurrence.isValidWeeklyDay(mon1, days, 2, mon1), isTrue);
      expect(Recurrence.isValidWeeklyDay(mon2, days, 2, mon1), isFalse);
      expect(Recurrence.isValidWeeklyDay(mon0, days, 2, mon1), isTrue);
    });

    test('native agreement: periodStart = valid boundary', () {
      const r = Recurrence(type: RecurrenceType.weekly, interval: 2, days: [DateTime.monday]);
      expect(r.getPeriodStart(DateTime(1970, 1, 14)), DateTime(1970, 1, 5));
      expect(Recurrence.isValidWeeklyDay(DateTime(1970, 1, 5), days, 2, Recurrence.epochMonday), isTrue);
      expect(Recurrence.isValidWeeklyDay(DateTime(1970, 1, 12), days, 2, Recurrence.epochMonday), isFalse);
      expect(Recurrence.isValidWeeklyDay(DateTime(1970, 1, 19), days, 2, Recurrence.epochMonday), isTrue);
    });
  });

  group('yearly interval (P1: keep interval on save-sync)', () {
    test('toRRULE keeps INTERVAL=2 with BYMONTH/BYMONTHDAY', () {
      const r = Recurrence(type: RecurrenceType.yearly, interval: 2, days: [5, 15]);
      expect(r.toRRULE(), 'FREQ=YEARLY;INTERVAL=2;BYMONTH=5;BYMONTHDAY=15');
    });

    test('nextOccurrence yearly interval=2 skips one year', () {
      const r = Recurrence(type: RecurrenceType.yearly, interval: 2, days: [5, 15]);
      final next = r.nextOccurrence(DateTime(2026, 5, 15, 10, 0), anchor: DateTime(2026, 5, 15, 10, 0))!;
      expect(next.year, 2028);
      expect(next.month, 5);
      expect(next.day, 15);
      expect(next.hour, 10);
    });
  });

  group('monthly clamp (Φεβ) + anti-drift', () {
    test('days [31]: Φεβ → 28 (όχι άλμα Μαρτίου)', () {
      const r = Recurrence(
          type: RecurrenceType.monthly, interval: 1, days: [31]);
      final next = r.nextOccurrence(DateTime(2026, 2, 1, 10, 0))!;
      expect(next.year, 2026);
      expect(next.month, 2);
      expect(next.day, 28);
      expect(next.hour, 10);
    });

    test('no-days anti-drift: Ιαν31 → Φεβ28 → Μαρ31', () {
      const r = Recurrence(type: RecurrenceType.monthly, interval: 1);
      final anchor = DateTime(2026, 1, 31, 10, 0);
      final feb = r.nextOccurrence(anchor, anchor: anchor)!;
      expect([feb.year, feb.month, feb.day], [2026, 2, 28]);
      final mar = r.nextOccurrence(feb, anchor: anchor)!;
      expect([mar.year, mar.month, mar.day], [2026, 3, 31]);
    });

    test('yearly 29/2: μη-δίσεκτο → 28/2', () {
      const r = Recurrence(
          type: RecurrenceType.yearly, interval: 1, days: [2, 29]);
      final next = r.nextOccurrence(DateTime(2026, 2, 1, 10, 0))!;
      expect([next.year, next.month, next.day], [2026, 2, 28]);
    });

    test('yearly no-days 29/2: μη-δίσεκτο → 28/2 (όχι 1/3)', () {
      const r = Recurrence(type: RecurrenceType.yearly, interval: 1);
      final next = r.nextOccurrence(DateTime(2024, 2, 29, 10, 0))!;
      expect([next.year, next.month, next.day], [2025, 2, 28]);
    });

    test('yearly no-days 29/2 interval=2 → 28/2/2026 (interval κρατιέται)', () {
      const r = Recurrence(type: RecurrenceType.yearly, interval: 2);
      final next = r.nextOccurrence(DateTime(2024, 2, 29, 10, 0))!;
      expect([next.year, next.month, next.day], [2026, 2, 28]);
    });
  });

  group('yearlyOccurrenceDay (ημερολόγιο μελλοντικά έτη)', () {
    const rrule = 'FREQ=YEARLY;INTERVAL=1;BYMONTH=5;BYMONTHDAY=10';
    final root = DateTime(2026, 5, 10, 9, 0);

    test('ίδιος μήνας/μελλοντικό έτος → day', () {
      expect(yearlyOccurrenceDay(rrule, root, 2027, 5), 10);
    });

    test('interval=2: άρτιο έτος ναι, μονό όχι', () {
      const r2 = 'FREQ=YEARLY;INTERVAL=2;BYMONTH=5;BYMONTHDAY=10';
      expect(yearlyOccurrenceDay(r2, root, 2028, 5), 10);
      expect(yearlyOccurrenceDay(r2, root, 2027, 5), isNull);
    });

    test('Feb29 → 28 σε μη-δίσεκτο', () {
      const r29 = 'FREQ=YEARLY;INTERVAL=1;BYMONTH=2;BYMONTHDAY=29';
      expect(yearlyOccurrenceDay(r29, DateTime(2024, 2, 29), 2026, 2), 28);
    });

    test('λάθος μήνας / έτος πριν το root / non-yearly → null', () {
      expect(yearlyOccurrenceDay(rrule, root, 2027, 6), isNull);
      expect(yearlyOccurrenceDay(rrule, root, 2025, 5), isNull);
      expect(
          yearlyOccurrenceDay(
              'FREQ=MONTHLY;INTERVAL=1;BYMONTHDAY=10', root, 2027, 5),
          isNull);
    });
  });

  group('contactBirthdayDay (γενέθλια επαφών στο ημερολόγιο)', () {
    test('ίδιος μήνας κάθε έτος → day', () {
      expect(contactBirthdayDay(DateTime(1990, 10, 18), 2026, 10), 18);
      expect(contactBirthdayDay(DateTime(1990, 10, 18), 2030, 10), 18);
    });

    test('λάθος μήνας → null', () {
      expect(contactBirthdayDay(DateTime(1990, 10, 18), 2026, 11), isNull);
    });

    test('Feb29 → 28 σε μη-δίσεκτο', () {
      expect(contactBirthdayDay(DateTime(2000, 2, 29), 2026, 2), 28);
      expect(contactBirthdayDay(DateTime(2000, 2, 29), 2028, 2), 29);
    });

    test('ίδια μέρα-μήνας, άλλο έτος γέννησης → day', () {
      expect(contactBirthdayDay(DateTime(2020, 5, 10), 2026, 5), 10);
    });
  });

  group('DST weekly (Europe/Athens — η σουίτα τρέχει σε Athens TZ)', () {
    // Άνοιξη 2026: μετάβαση Κυριακή 29/03.
    test('interval=2: 06/04/2026 = 13η εβδομάδα (όχι 12η)', () {
      final anchor = DateTime(2026, 1, 5, 9, 0);
      expect(
          Recurrence.isValidWeeklyDay(
              DateTime(2026, 4, 6), [DateTime.monday], 2, anchor),
          isFalse);
      expect(
          Recurrence.isValidWeeklyDay(
              DateTime(2026, 4, 13), [DateTime.monday], 2, anchor),
          isTrue);
    });

    test('getPeriodStart: 08/04/2026 → Δευτέρα 30/03 (aligned περίοδος)', () {
      const r = Recurrence(type: RecurrenceType.weekly, interval: 2, days: [DateTime.monday]);
      final start = r.getPeriodStart(DateTime(2026, 4, 8, 12, 0));
      expect([start.year, start.month, start.day], [2026, 3, 30]);
      expect(start.weekday, DateTime.monday);
    });

    // S215: το ref(1970, χειμερινή ώρα)+N·168ω έδινε 01:00 στη θερινή ώρα →
    // το πλήρες DateTime (όχι μόνο y/m/d) πρέπει να είναι μεσάνυχτα.
    test('getPeriodStart interval=2: 08/04/2026 → ακριβώς 30/03 00:00', () {
      const r = Recurrence(type: RecurrenceType.weekly, interval: 2, days: [DateTime.monday]);
      expect(r.getPeriodStart(DateTime(2026, 4, 8, 12, 0)), DateTime(2026, 3, 30));
    });

    test('getPeriodStart interval=2: 15/07/2026 (καλοκαίρι) → ακριβώς 06/07 00:00', () {
      const r = Recurrence(type: RecurrenceType.weekly, interval: 2, days: [DateTime.monday]);
      expect(r.getPeriodStart(DateTime(2026, 7, 15, 10, 0)), DateTime(2026, 7, 6));
    });

    test('getPeriodStart interval=1: Τρί 24/03 23:30 → Δευτέρα 23/03 00:00 (όχι 23:30)', () {
      const r = Recurrence(type: RecurrenceType.weekly, days: [DateTime.monday]);
      expect(r.getPeriodStart(DateTime(2026, 3, 24, 23, 30)), DateTime(2026, 3, 23));
    });

    test('scan Σαβ-23:30 προ-αλλαγής → Κυριακή (όχι Δευτέρα)', () {
      const r = Recurrence(type: RecurrenceType.weekly, days: [DateTime.sunday]);
      final next = r.nextOccurrence(DateTime(2026, 3, 28, 23, 30))!;
      expect([next.year, next.month, next.day], [2026, 3, 29]);
      expect(next.weekday, DateTime.sunday);
      expect([next.hour, next.minute], [23, 30]);
    });
  });
}
