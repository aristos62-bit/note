// test/habit_topup_test.dart
//
// Unit tests για τα pure helpers του habit top-up (χωρίς DB).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
