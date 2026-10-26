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
//  · Επικάλυψη **δεν κρύβει** εύρος: το 1ο (νωρίτερα/μεγαλύτερο) είναι η
//    συμπαγής βάση· κάθε επόμενο ζωγραφίζεται ως **45° hatch overlay** πάνω
//    της, μόνο στις ημέρες που συμπίπτουν. Καμία σπασμένη γραμμή.
//  · Ντετερμινιστικό: sort (έναρξη ↑, διάρκεια ↓, itemId ↑).

import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../helpers/item_color_helper.dart';
import '../../models/models.dart';

/// Πόσες γραμμές χωρά το κελί ημέρας (44px).
/// Κρατείται σταθερό: @140% το κείμενο φτάνει y36 και οι τελείες y39.
const int kSpanMaxLanes = 1;

/// Γεωμετρία μπάρας: 6px χρώμα + 1px halo (πάνω/κάτω) = 8px συνολικό ύψος.
const double kSpanBarHeight = 6.0;
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

/// Μία ημέρα γραμμής: ποιο item είναι η **βάση** (συμπαγές χρώμα), τι χρώμα,
/// αν είναι αρχή/τέλος εύρους, και ποια εύρη την **επικαλύπτουν** (hatch).
class SpanDay {
  final int itemId;
  final String? colorHex;
  final bool isStart;
  final bool isEnd;

  /// Εύρη που συμπίπτουν αυτή την ημέρα → 45° λωρίδες πάνω στη βάση.
  final List<SpanOverlay> overlays;

  SpanDay({
    required this.itemId,
    this.colorHex,
    this.isStart = false,
    this.isEnd = false,
    List<SpanOverlay>? overlays,
  }) : overlays = overlays ?? <SpanOverlay>[];

  bool get hasOverlap => overlays.isNotEmpty;
}

/// Εύρος που επικαλύπτει τη βάση μιας ημέρας (ζωγραφίζεται ως hatch).
class SpanOverlay {
  final int itemId;
  final String? colorHex;
  final bool isStart;
  final bool isEnd;

  const SpanOverlay({
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

/// Χρώμα γραμμής από hex (default accent αν λείπει/είναι άκυρο).
Color spanColorFromHex(String? hex, Brightness b) {
  final parsed = ItemColorHelper.parseHex(hex);
  return spanBarColor(parsed ?? ColorsUI.itemTypeColor(ItemType.event, b), b);
}

/// Χρώμα γραμμής για ένα `SpanDay` (default accent αν δεν υπάρχει hex).
Color spanDayColor(SpanDay day, Brightness b) =>
    spanColorFromHex(day.colorHex, b);

/// Χρώμα λωρίδων ενός overlay.
Color spanOverlayColor(SpanOverlay overlay, Brightness b) =>
    spanColorFromHex(overlay.colorHex, b);

/// Φόντο του hatch: η βάση — **εκτός** αν μοιάζει πολύ με το χρώμα του
/// overlay (π.χ. και τα δύο default accent), οπότε χρησιμοποιείται η
/// επιφάνεια ώστε οι λωρίδες να φαίνονται πάντα.
Color spanOverlapSurface(Color base, Color overlay, Brightness b) =>
    ColorsUI.contrastRatio(base, overlay) >= 1.6 ? base : spanSurface(b);

/// Χτίζει το map ημέρας → γραμμή για τον ορατό μήνα (clipped στα όρια μήνα).
///
/// Κάθε έγκυρο εύρος ζωγραφίζει **συνεχόμενη** γραμμή: το πρώτο (βάσει sort)
/// γίνεται η συμπαγής βάση της ημέρας, τα υπόλοιπα προστίθενται ως `overlays`
/// (45° hatch). Καμία ημέρα δεν μένει χωρίς γραμμή λόγω επικάλυψης.
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

  final out = <DateTime, SpanDay>{};
  for (final s in sorted) {
    for (var i = 0; i < s.range.days; i++) {
      final day = DateTime(
          s.range.start.year, s.range.start.month, s.range.start.day + i);
      if (day.isBefore(monthStart) || day.isAfter(monthEnd)) continue;

      final isStart = day == s.range.start;
      final isEnd = day == s.range.end;
      final base = out[day];
      if (base == null) {
        out[day] = SpanDay(
          itemId: s.itemId,
          colorHex: s.colorHex,
          isStart: isStart,
          isEnd: isEnd,
        );
      } else {
        base.overlays.add(SpanOverlay(
          itemId: s.itemId,
          colorHex: s.colorHex,
          isStart: isStart,
          isEnd: isEnd,
        ));
      }
    }
  }
  return out;
}
