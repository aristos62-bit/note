// test/habit_topup_test.dart
//
// Unit tests για τα pure helpers του habit top-up (χωρίς DB).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/services/habit_service.dart';

void main() {
  group('planTopUp', () {
    final needed = [
      DateTime(2026, 10, 5, 8, 0),
      DateTime(2026, 10, 6, 8, 0),
      DateTime(2026, 10, 7, 8, 0),
    ];

    test('κενό existing → όλα missing', () {
      expect(
          HabitService.planTopUp({}, needed).length, 3);
    });

    test('μερικό existing → μόνο τα λείποντα', () {
      final missing = HabitService.planTopUp(
          {DateTime(2026, 10, 6, 8, 0)}, needed);
      expect(missing, [DateTime(2026, 10, 5, 8, 0), DateTime(2026, 10, 7, 8, 0)]);
    });

    test('πλήρες existing → τίποτα', () {
      expect(HabitService.planTopUp(needed.toSet(), needed), isEmpty);
    });

    test('άδειο needed → τίποτα', () {
      expect(HabitService.planTopUp({DateTime(2026, 10, 5, 8, 0)}, []), isEmpty);
    });
  });

  group('parseHabitTime', () {
    test('έγκυρο HH:MM', () {
      expect(HabitService.parseHabitTime('08:30'),
          const TimeOfDay(hour: 8, minute: 30));
    });

    test('άκυρα → null', () {
      expect(HabitService.parseHabitTime(''), isNull);
      expect(HabitService.parseHabitTime('25:00'), isNull);
      expect(HabitService.parseHabitTime('08:60'), isNull);
      expect(HabitService.parseHabitTime('08'), isNull);
      expect(HabitService.parseHabitTime('aa:bb'), isNull);
    });
  });

  group('weekly/monthly times', () {
    test('factories δέχονται times', () {
      final w = Recurrence.weekly(days: const [1, 3], times: const ['08:00']);
      expect(w.times, ['08:00']);
      final m = Recurrence.monthly(days: const [5], times: const ['10:00']);
      expect(m.times, ['10:00']);
    });

    test('fromProperties διαβάζει times για weekly/monthly', () {
      final w = Recurrence.fromProperties({
        'recurrence_type': 'weekly',
        'recurrence_days': '[1,3]',
        'recurrence_times': '["08:00"]',
      });
      expect(w.times, ['08:00']);
      final m = Recurrence.fromProperties({
        'recurrence_type': 'monthly',
        'recurrence_days': '[5]',
        'recurrence_times': '["10:00"]',
      });
      expect(m.times, ['10:00']);
    });

    test('fromProperties αγνοεί times για yearly', () {
      final y = Recurrence.fromProperties({
        'recurrence_type': 'yearly',
        'recurrence_days': '[5,29]',
        'recurrence_times': '["08:00"]',
      });
      expect(y.times, isNull);
    });

    test('describe δείχνει ώρες', () {
      expect(
          Recurrence.weekly(days: const [1, 3], times: const ['08:00'])
              .describe(),
          contains('08:00'));
      expect(
          Recurrence.monthly(days: const [5], times: const ['10:00'])
              .describe(),
          contains('10:00'));
    });
  });

  // E18: tolerant parsing — corrupt props δεν πετούν, επιστρέφουν null.
  group('fromProperties tolerant parsing (E18)', () {
    test('corrupt weekly days → days null, δεν πετάει', () {
      final w = Recurrence.fromProperties({
        'recurrence_type': 'weekly',
        'recurrence_days': '{not json',
      });
      expect(w.days, isNull);
    });

    test('corrupt yearly days → days null, δεν πετάει', () {
      final y = Recurrence.fromProperties({
        'recurrence_type': 'yearly',
        'recurrence_days': 'oops',
      });
      expect(y.days, isNull);
    });

    test('corrupt times → times null, δεν πετάει', () {
      final d = Recurrence.fromProperties({
        'recurrence_type': 'daily',
        'recurrence_times': 'oops',
      });
      expect(d.times, isNull);
    });

    test('monthly legacy plain int παραμένει υποστηριζόμενο (χωρίς log)', () {
      final m = Recurrence.fromProperties({
        'recurrence_type': 'monthly',
        'recurrence_days': '15',
      });
      expect(m.days, [15]);
    });
  });
}
