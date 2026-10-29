// test/date_utils_numeric_test.dart
//
// Unit tests για τα νέα intl-free numeric formats (Ο7 — E22) και το clamp
// των date pickers (E20/E41). Καθαρό Dart: χωρίς Isar, χωρίς locale init
// (δεν καλείται initializeDateFormatting εδώ — γι' αυτό τα formats πρέπει
// να είναι intl-free).
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/date_utils.dart';

void main() {
  group('AppDateUtils.formatNumeric', () {
    test('zero-pads day/month → dd/MM/yyyy', () {
      expect(AppDateUtils.formatNumeric(DateTime(2025, 3, 4)), '04/03/2025');
      expect(AppDateUtils.formatNumeric(DateTime(1998, 12, 25)), '25/12/1998');
    });

    test('κρατά 4ψήφιο έτος (1900, 2100)', () {
      expect(AppDateUtils.formatNumeric(DateTime(1900, 1, 1)), '01/01/1900');
      expect(AppDateUtils.formatNumeric(DateTime(2100, 6, 30)), '30/06/2100');
    });

    test('intl-free: δουλεύει χωρίς initializeDateFormatting()', () {
      // Αν χρησιμοποιούσε DateFormat(..., 'el') θα πετούσε
      // LocaleDataException σε αυτό το test (δεν έγινε init).
      expect(AppDateUtils.formatNumeric(DateTime(2026, 10, 28)), '28/10/2026');
    });

    test('formatNumericDateTime → dd/MM/yyyy HH:mm (24h, zero-padded)', () {
      expect(
          AppDateUtils.formatNumericDateTime(DateTime(2026, 10, 28, 9, 5)),
          '28/10/2026 09:05');
      expect(
          AppDateUtils.formatNumericDateTime(DateTime(2026, 1, 2, 23, 59)),
          '02/01/2026 23:59');
    });

    test('getters numeric / numericDateTime', () {
      final d = DateTime(2026, 10, 28, 7, 3);
      expect(d.numeric, '28/10/2026');
      expect(d.numericDateTime, '28/10/2026 07:03');
    });
  });

  group('AppDateUtils.clampToRange (E20/E41)', () {
    final first = DateTime(1900, 1, 1);
    final last = DateTime(2026, 10, 28);

    test('πριν το firstDate → firstDate', () {
      expect(AppDateUtils.clampToRange(DateTime(1850, 5, 20), first, last),
          first);
    });

    test('μετά το lastDate → lastDate', () {
      expect(
          AppDateUtils.clampToRange(DateTime(2099, 1, 1), first, last), last);
    });

    test('εντός ορίων → αμετάβλητο (διατηρεί την ώρα)', () {
      final value = DateTime(1998, 4, 12, 14, 30);
      expect(AppDateUtils.clampToRange(value, first, last), value);
    });

    test('στα άκρα → αμετάβλητο', () {
      expect(AppDateUtils.clampToRange(first, first, last), first);
      expect(AppDateUtils.clampToRange(last, first, last), last);
    });

    test('earliestYear = 1900 (E20: γενέθλια / παλιά events / ραντεβού)', () {
      expect(AppDateUtils.earliestYear, 1900);
    });
  });
}
