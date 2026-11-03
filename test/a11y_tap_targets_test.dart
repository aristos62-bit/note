// test/a11y_tap_targets_test.dart
//
// S288 (a11y E01 · Βήμα 10): 48×48 tap targets στα διορθωμένα components.
// Component-level (όχι full-app) — βλ. a11y.md §5 Βήμα 10 «Tests».
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:super_note/features/calendar/calendar_screen.dart';
import 'package:super_note/features/calendar/span_utils.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/item_card.dart';
import 'package:super_note/shared/widgets/view_mode_toggle.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(brightness: Brightness.light),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  testWidgets('CircleToggleButton: hit area 48×48', (tester) async {
    await tester.pumpWidget(_wrap(CircleToggleButton(
      icon: Icons.star_rounded,
      tooltip: 'Αγαπημένα',
      isSelected: false,
      activeColor: Colors.amber,
      onTap: () {},
    )));

    final size = tester.getSize(find.byType(CircleToggleButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('ItemCard: checkbox & share ≥48', (tester) async {
    final handle = tester.ensureSemantics();
    final task = Item()
      ..type = ItemType.task
      ..title = 'Δοκιμή';

    await tester.pumpWidget(_wrap(SizedBox(
      width: 320,
      child: ItemCard(
        item: task,
        compact: true,
        onCheckboxChanged: (_) {},
        onShare: () {},
      ),
    )));

    for (final label in ['Ολοκλήρωση εργασίας', 'Κοινοποίηση']) {
      final size = tester.getSize(find.bySemanticsLabel(label));
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }

    handle.dispose();
  });

  testWidgets('MonthGrid: κελί ημέρας 48 ύψος', (tester) async {
    await tester.pumpWidget(_wrap(MonthGrid(
      focusedMonth: DateTime(2026, 10),
      selectedDay: DateTime(2026, 10, 19),
      today: DateTime(2026, 10, 19),
      dayEvents: const <DateTime, List<Item>>{},
      spanBars: const <DateTime, SpanDay>{},
      onDayTap: (_) {},
    )));

    final size = tester.getSize(
        find.byKey(const ValueKey('calendar-day-2026-10-19')));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
