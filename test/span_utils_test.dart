// test/span_utils_test.dart
//
// E41 — Πολυήμερα συμβάντα: εύρος (`end_date`), lanes γραμμής, αντίθεση.
// Καθαρές συναρτήσεις → unit tests χωρίς widgets/Isar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/features/calendar/span_utils.dart';
import 'package:super_note/models/models.dart';

ItemProperty _prop(String key, String value) => ItemProperty()
  ..key = key
  ..value = value;

List<ItemProperty> _props(String start, {String? end, String? color}) => [
      _prop(PropertyKeys.startTime, start),
      if (end != null) _prop(PropertyKeys.endDate, end),
      if (color != null) _prop(PropertyKeys.spanColor, color),
    ];

SpanCandidate _candidate(int id, DateTime start, DateTime end,
        {String? color}) =>
    SpanCandidate(
      itemId: id,
      range: SpanRange(start: start, end: end),
      colorHex: color,
    );

void main() {
  group('spanRangeOf', () {
    test('χωρίς end_date → null (μονήμερο)', () {
      expect(spanRangeOf(_props('2026-03-10T09:00:00.000')), isNull);
    });

    test('ίδια ημέρα → null (άκυρο, χωρίς write)', () {
      expect(
        spanRangeOf(_props('2026-03-10T09:00:00.000',
            end: '2026-03-10T00:00:00.000')),
        isNull,
      );
    });

    test('ανεστραμμένη λήξη → null', () {
      expect(
        spanRangeOf(_props('2026-03-10T09:00:00.000',
            end: '2026-03-08T00:00:00.000')),
        isNull,
      );
    });

    test('έγκυρο εύρος → date-only κανονικοποίηση (ώρες μηδενίζονται)', () {
      final r = spanRangeOf(
          _props('2026-03-10T09:00:00.000', end: '2026-03-12T23:30:00.000'));
      expect(r, isNotNull);
      expect(r!.start, DateTime(2026, 3, 10));
      expect(r.end, DateTime(2026, 3, 12));
      expect(r.days, 3);
    });

    test('χωρίς start_time → null', () {
      expect(
        spanRangeOf([_prop(PropertyKeys.endDate, '2026-03-12T00:00:00.000')]),
        isNull,
      );
    });
  });

  group('SpanRange.days', () {
    test('DST (Ελλάδα 29/03/2026) δεν χάνει ημέρα', () {
      final r = SpanRange(
          start: DateTime(2026, 3, 28), end: DateTime(2026, 3, 30));
      expect(r.days, 3);
    });

    test('μεγάλο εύρος', () {
      final r = SpanRange(
          start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31));
      expect(r.days, 365);
    });

    test('containsDay', () {
      final r = SpanRange(
          start: DateTime(2026, 3, 10), end: DateTime(2026, 3, 12));
      expect(r.containsDay(DateTime(2026, 3, 9, 23, 59)), isFalse);
      expect(r.containsDay(DateTime(2026, 3, 10, 22)), isTrue);
      expect(r.containsDay(DateTime(2026, 3, 12)), isTrue);
      expect(r.containsDay(DateTime(2026, 3, 13)), isFalse);
    });
  });

  group('buildSpanBars', () {
    final month = DateTime(2026, 3);

    test('εύρος μέσα στον μήνα → μία γραμμή/ημέρα + άκρα', () {
      final bars = buildSpanBars(
        spans: [_candidate(7, DateTime(2026, 3, 10), DateTime(2026, 3, 12))],
        month: month,
      );
      expect(bars.length, 3);
      expect(bars[DateTime(2026, 3, 10)]!.isStart, isTrue);
      expect(bars[DateTime(2026, 3, 10)]!.isEnd, isFalse);
      expect(bars[DateTime(2026, 3, 11)]!.isStart, isFalse);
      expect(bars[DateTime(2026, 3, 12)]!.isEnd, isTrue);
      expect(bars.values.every((d) => d.itemId == 7), isTrue);
    });

    test('clipping στα όρια μήνα (τέλος εκτός μήνα → isEnd=false)', () {
      final bars = buildSpanBars(
        spans: [_candidate(1, DateTime(2026, 3, 30), DateTime(2026, 4, 2))],
        month: month,
      );
      expect(bars.length, 2);
      expect(bars[DateTime(2026, 3, 30)]!.isStart, isTrue);
      expect(bars[DateTime(2026, 3, 31)]!.isEnd, isFalse);
    });

    test('έναρξη πριν τον μήνα → isStart=false την 1η', () {
      final bars = buildSpanBars(
        spans: [_candidate(2, DateTime(2026, 2, 25), DateTime(2026, 3, 2))],
        month: month,
      );
      expect(bars.length, 2);
      expect(bars[DateTime(2026, 3, 1)]!.isStart, isFalse);
      expect(bars[DateTime(2026, 3, 2)]!.isEnd, isTrue);
    });

    test('εύρος εκτός μήνα → κενό', () {
      final bars = buildSpanBars(
        spans: [_candidate(3, DateTime(2026, 5, 1), DateTime(2026, 5, 4))],
        month: month,
      );
      expect(bars, isEmpty);
    });

    test('επικάλυψη → base + hatch overlay, καμία χαμένη ημέρα', () {
      final bars = buildSpanBars(
        spans: [
          _candidate(20, DateTime(2026, 3, 11), DateTime(2026, 3, 13)),
          _candidate(10, DateTime(2026, 3, 10), DateTime(2026, 3, 12)),
        ],
        month: month,
      );
      // 10-12: βάση το 10 (ξεκινά νωρίτερα)· 11-12: hatch overlay το 20·
      // 13: μένει μόνο το 20 → συμπαγής βάση (καμία σπασμένη γραμμή).
      expect(bars.length, 4);
      expect(bars[DateTime(2026, 3, 10)]!.itemId, 10);
      expect(bars[DateTime(2026, 3, 10)]!.hasOverlap, isFalse);
      expect(bars[DateTime(2026, 3, 11)]!.itemId, 10);
      expect(bars[DateTime(2026, 3, 11)]!.overlays.single.itemId, 20);
      expect(bars[DateTime(2026, 3, 12)]!.overlays.single.itemId, 20);
      expect(bars[DateTime(2026, 3, 13)]!.itemId, 20);
      expect(bars[DateTime(2026, 3, 13)]!.hasOverlap, isFalse);
    });

    test('overlay κρατά τα άκρα του δικού του εύρους', () {
      final bars = buildSpanBars(
        spans: [
          _candidate(10, DateTime(2026, 3, 10), DateTime(2026, 3, 14)),
          _candidate(20, DateTime(2026, 3, 12), DateTime(2026, 3, 13)),
        ],
        month: month,
      );
      final o1 = bars[DateTime(2026, 3, 12)]!.overlays.single;
      final o2 = bars[DateTime(2026, 3, 13)]!.overlays.single;
      expect(o1.isStart, isTrue);
      expect(o1.isEnd, isFalse);
      expect(o2.isStart, isFalse);
      expect(o2.isEnd, isTrue);
    });

    test('3 εύρη στην ίδια ημέρα → βάση + 2 overlays (σειρά sort)', () {
      final bars = buildSpanBars(
        spans: [
          _candidate(3, DateTime(2026, 3, 10), DateTime(2026, 3, 12)),
          _candidate(1, DateTime(2026, 3, 10), DateTime(2026, 3, 12)),
          _candidate(2, DateTime(2026, 3, 10), DateTime(2026, 3, 12)),
        ],
        month: month,
      );
      final day = bars[DateTime(2026, 3, 10)]!;
      expect(day.itemId, 1);
      expect(day.overlays.map((o) => o.itemId).toList(), [2, 3]);
    });

    test('ίδια έναρξη → μεγαλύτερη διάρκεια κερδίζει', () {
      final bars = buildSpanBars(
        spans: [
          _candidate(5, DateTime(2026, 3, 10), DateTime(2026, 3, 11)),
          _candidate(6, DateTime(2026, 3, 10), DateTime(2026, 3, 14)),
        ],
        month: month,
      );
      expect(bars[DateTime(2026, 3, 10)]!.itemId, 6);
      expect(bars[DateTime(2026, 3, 14)]!.itemId, 6);
    });

    test('ντετερμινιστικό (shuffle → ίδιο αποτέλεσμα)', () {
      final spans = [
        _candidate(1, DateTime(2026, 3, 2), DateTime(2026, 3, 4)),
        _candidate(2, DateTime(2026, 3, 3), DateTime(2026, 3, 6)),
        _candidate(3, DateTime(2026, 3, 5), DateTime(2026, 3, 8)),
        _candidate(4, DateTime(2026, 3, 1), DateTime(2026, 3, 1)),
      ];
      final first = buildSpanBars(spans: spans, month: month);
      final second = buildSpanBars(spans: spans.reversed.toList(), month: month);
      expect(first.length, second.length);
      for (final e in first.entries) {
        expect(second[e.key]?.itemId, e.value.itemId);
      }
    });

    test('χρώμα hex περνά αυτούσιο στο SpanDay', () {
      final bars = buildSpanBars(
        spans: [
          _candidate(1, DateTime(2026, 3, 10), DateTime(2026, 3, 11),
              color: '#ED6C02')
        ],
        month: month,
      );
      expect(bars[DateTime(2026, 3, 10)]!.colorHex, '#ED6C02');
    });
  });

  group('αντίθεση γραμμής', () {
    test('default accent περνά ≥3.0 και στα δύο themes', () {
      for (final b in Brightness.values) {
        final c = spanDefaultColor(b);
        expect(ColorsUI.contrastRatio(c, spanSurface(b)),
            greaterThanOrEqualTo(kSpanMinContrast));
      }
    });

    test('πολύ ανοιχτό χρώμα προσαρμόζεται σε ≥3.0 (light)', () {
      final c = spanBarColor(const Color(0xFFFFF59D), Brightness.light);
      expect(ColorsUI.contrastRatio(c, spanSurface(Brightness.light)),
          greaterThanOrEqualTo(kSpanMinContrast));
    });

    test('πολύ σκούρο χρώμα προσαρμόζεται σε ≥3.0 (dark)', () {
      final c = spanBarColor(const Color(0xFF1B5E20), Brightness.dark);
      expect(ColorsUI.contrastRatio(c, spanSurface(Brightness.dark)),
          greaterThanOrEqualTo(kSpanMinContrast));
    });

    test('χρώμα που περνά ήδη μένει αναλλοίωτο', () {
      const hex = Color(0xFF2E7D32);
      expect(spanBarColor(hex, Brightness.light), hex);
    });

    test('spanDayColor: invalid hex → fallback accent (χωρίς exception)', () {
      final day = SpanDay(itemId: 1, colorHex: 'not-a-hex');
      final c = spanDayColor(day, Brightness.light);
      expect(ColorsUI.contrastRatio(c, spanSurface(Brightness.light)),
          greaterThanOrEqualTo(kSpanMinContrast));
    });

    test('spanOverlapSurface: ίδιο χρώμα → επιφάνεια, διαφορετικό → βάση', () {
      const green = Color(0xFF2E7D32);
      const b = Brightness.light;
      expect(spanOverlapSurface(green, green, b), spanSurface(b));
      expect(spanOverlapSurface(green, Colors.white, b), green);
    });
  });

  group('σταθερές / keys', () {
    test('1 lane + γεωμετρία 6px + 2×1px halo', () {
      expect(kSpanMaxLanes, 1);
      expect(kSpanBarHeight, 6);
      expect(kSpanBarHalo, 1);
      expect(kSpanBarTotalHeight, 8);
    });

    test('τεχνικά keys εκτός αναζήτησης', () {
      expect(PropertyKeys.technical.contains(PropertyKeys.endDate), isTrue);
      expect(PropertyKeys.technical.contains(PropertyKeys.spanColor), isTrue);
      expect(PropertyKeys.technical.length, 2);
    });

    test('calendar keys = 4 (version bump)', () {
      expect(PropertyKeys.calendar.length, 4);
      expect(PropertyKeys.calendar.contains(PropertyKeys.endDate), isTrue);
      expect(PropertyKeys.calendar.contains(PropertyKeys.spanColor), isTrue);
    });
  });
}
