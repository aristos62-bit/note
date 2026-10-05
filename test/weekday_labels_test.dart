// test/weekday_labels_test.dart
//
// Weekday/month SPoT (Φ4a βήμα 6): λίστες Δευτέρα-πρώτα, 0-based, χωρίς dummies.
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/date_utils.dart';

void main() {
  test('μήκη λιστών', () {
    expect(AppDateUtils.weekdayNames.length, 7);
    expect(AppDateUtils.weekdayInitials.length, 7);
    expect(AppDateUtils.weekdayFullNames.length, 7);
    expect(AppDateUtils.monthNames.length, 12);
    expect(AppDateUtils.monthFullNames.length, 12);
  });

  test('Δευτέρα-πρώτα + 0 dummies', () {
    expect(AppDateUtils.weekdayNames.first, 'Δευ');
    expect(AppDateUtils.weekdayNames.last, 'Κυρ');
    expect(AppDateUtils.weekdayFullNames.first, 'Δευτέρα');
    expect(AppDateUtils.monthNames.first, 'Ιαν');
    expect(AppDateUtils.monthFullNames.first, 'Ιανουάριος');
    expect(AppDateUtils.monthFullNames.last, 'Δεκέμβριος');
    expect(AppDateUtils.weekdayNames, isNot(contains('')));
    expect(AppDateUtils.monthNames, isNot(contains('')));
  });

  test('dayInitial == weekdayInitials[weekday-1] για όλη την εβδομάδα', () {
    // 2026-10-05 = Δευτέρα
    final monday = DateTime(2026, 10, 5);
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      expect(AppDateUtils.dayInitial(day), AppDateUtils.weekdayInitials[i]);
    }
    expect(AppDateUtils.dayInitial(monday), 'Δ');
    expect(AppDateUtils.dayInitial(monday.add(const Duration(days: 6))), 'Κ');
  });

  test('mapping γνωστών ημερομηνιών', () {
    final monday = DateTime(2026, 10, 5); // Δευτέρα
    expect(AppDateUtils.weekdayNames[monday.weekday - 1], 'Δευ');
    expect(AppDateUtils.weekdayFullNames[monday.weekday - 1], 'Δευτέρα');
    expect(AppDateUtils.monthFullNames[monday.month - 1], 'Οκτώβριος');
    expect(AppDateUtils.monthNames[monday.month - 1], 'Οκτ');
    final sunday = DateTime(2026, 10, 11); // Κυριακή
    expect(AppDateUtils.weekdayNames[sunday.weekday - 1], 'Κυρ');
  });
}
