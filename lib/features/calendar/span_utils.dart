// lib/features/calendar/span_utils.dart
//
// E41 — Πολυήμερα συμβάντα: εύρος (`end_date`) + γραμμή στο πλέγμα μήνα
// (`span_color`). Καθαρές συναρτήσεις (χωρίς widgets) → unit-testable.
//
// ΚΑΝΟΝΕΣ (αποφασισμένοι):
//  · `end_date` = date-only, **inclusive**, τοπικό μεσάνυχτα.
//  · Λήξη ≤ έναρξη → άκυρο (μονήμερο)· κανένα write-on-open.
//  · 🎂 γενέθλια: ποτέ εύρος/χρώμα (ο caller τα αγνοεί).
//  · 1 lane: το κελί των 44px δεν χωρά 2η γραμμή (βλ. E41 report).
//  · All-or-nothing ανά εύρος: αν έστω μία μέρα είναι πιασμένη, ολόκληρο
//    το εύρος πέφτει στις τελείες — ποτέ σπασμένη/διάτρητη γραμμή.
//  · Ντετερμινιστικό: sort (έναρξη ↑, διάρκεια ↓, itemId ↑).

import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../helpers/item_color_helper.dart';
import '../../models/models.dart';

/// Πόσες γραμμές χωρά το κελί ημέρας (44px).
/// Κρατείται σταθερό: @140% το κείμενο φτάνει y36 και οι τελείες y39.
const int kSpanMaxLanes = 1;

/// Γεωμετρία μπάρας: 3px χρώμα + 1px halo (πάνω/κάτω) = 5px συνολικό ύψος.
const double kSpanBarHeight = 3.0;
const double kSpanBarHalo = 1.0;
const double kSpanBarTotalHeight = kSpanBarHeight + 2 * kSpanBarHalo;

/// Ελάχιστη αντίθεση (WCAG 1.4.11 — μη-κειμενικό περιεχόμενο).
const double kSpanMinContrast = 3.0;

/// Εύρος πολυήμερου `[start, end]` inclusive, date-only (local midnight).
class SpanRange {
  final DateTime start;
  final DateTime end;

  const SpanRange({required this.start, required this.end});

  /// Ημέρες εύρους — ημερολογιακά (DST-safe, όχι `difference().inDays`).
  int get days {
    final s = DateTime.utc(start.year, start.month, start.day);
    final e = DateTime.utc(end.year, end.month, end.day);
    return e.difference(s).inDays + 1;
  }

  bool containsDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

/// Υποψήφιο εύρος για γραμμή στον τρέχοντα μήνα.
class SpanCandidate {
  final int itemId;
  final SpanRange range;
  final String? colorHex;

  const SpanCandidate({
    required this.itemId,
    required this.range,
    this.colorHex,
  });
}

/// Μία ημέρα γραμμής: ποιο item, τι χρώμα, αν είναι αρχή/τέλος εύρους.
class SpanDay {
  final int itemId;
  final String? colorHex;
  final bool isStart;
  final bool isEnd;

  const SpanDay({
    required this.itemId,
    this.colorHex,
    this.isStart = false,
    this.isEnd = false,
  });
}

/// Διαβάζει το εύρος από properties. `null` = λείπει/μονήμερο/άκυρο.
SpanRange? spanRangeOf(List<ItemProperty> props) {
  DateTime? start;
  DateTime? end;
  for (final p in props) {
    if (p.key == PropertyKeys.startTime) start = p.dateValue;
    if (p.key == PropertyKeys.endDate) end = p.dateValue;
  }
  if (start == null || end == null) return null;

  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  if (!e.isAfter(s)) return null; // ίδια ημέρα ή ανεστραμμένη → μονήμερο
  return SpanRange(start: s, end: e);
}

/// Χρώμα γραμμής από properties (`#RRGGBB`). `null` = default accent.
String? spanColorOf(List<ItemProperty> props) =>
    props.where((p) => p.key == PropertyKeys.spanColor).firstOrNull?.value;

/// Επιφάνεια κελιού όπως πραγματικά φαίνεται: το `surface` token είναι
/// ημιδιαφανές (`ui_tokens.dart:67-68`) → σύνθεση πάνω στο background.
Color spanSurface(Brightness b) =>
    Color.alphaBlend(ColorsUI.getSurface(b), ColorsUI.getBackground(b));

/// Προσαρμόζει το χρώμα ώστε ≥3.0:1 ως προς την επιφάνεια.
/// Το default accent περνά ήδη (3.89 light / 5.90 dark) → αναλλοίωτο.
Color spanBarColor(Color color, Brightness b) {
  final bg = spanSurface(b);
  var c = color;
  for (var i = 0; i < 24; i++) {
    if (ColorsUI.contrastRatio(c, bg) >= kSpanMinContrast) return c;
    c = Color.lerp(c, b == Brightness.light ? Colors.black : Colors.white, 0.1)!;
  }
  return c;
}

/// Default χρώμα γραμμής = accent τύπου event (light `#2E7D32` / dark `#81C784`).
Color spanDefaultColor(Brightness b) =>
    spanBarColor(ColorsUI.itemTypeColor(ItemType.event, b), b);

/// Χρώμα γραμμής για ένα `SpanDay` (default accent αν δεν υπάρχει hex).
Color spanDayColor(SpanDay day, Brightness b) {
  final parsed = ItemColorHelper.parseHex(day.colorHex);
  return spanBarColor(parsed ?? ColorsUI.itemTypeColor(ItemType.event, b), b);
}

/// Χτίζει το map ημέρας → γραμμή για τον ορατό μήνα (clipped στα όρια μήνα).
Map<DateTime, SpanDay> buildSpanBars({
  required List<SpanCandidate> spans,
  required DateTime month,
}) {
  if (spans.isEmpty) return const {};

  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 0);

  final sorted = [...spans]..sort((a, b) {
      final byStart = a.range.start.compareTo(b.range.start);
      if (byStart != 0) return byStart;
      final byDays = b.range.days.compareTo(a.range.days);
      if (byDays != 0) return byDays;
      return a.itemId.compareTo(b.itemId);
    });

  final free = <DateTime>{};
  for (var d = monthStart;
      !d.isAfter(monthEnd);
      d = DateTime(d.year, d.month, d.day + 1)) {
    free.add(d);
  }

  final out = <DateTime, SpanDay>{};
  for (final s in sorted) {
    final days = <DateTime>[];
    for (var i = 0; i < s.range.days; i++) {
      final day =
          DateTime(s.range.start.year, s.range.start.month, s.range.start.day + i);
      if (day.isBefore(monthStart) || day.isAfter(monthEnd)) continue;
      days.add(day);
    }
    if (days.isEmpty) continue;
    if (days.any((d) => !free.contains(d))) continue; // all-or-nothing

    for (final day in days) {
      free.remove(day);
      out[day] = SpanDay(
        itemId: s.itemId,
        colorHex: s.colorHex,
        isStart: day == s.range.start,
        isEnd: day == s.range.end,
      );
    }
  }
  return out;
}
