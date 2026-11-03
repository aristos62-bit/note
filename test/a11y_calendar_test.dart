// test/a11y_calendar_test.dart
//
// S288 (a11y E01 · Βήμα 1): semantics κελιού ημέρας στο MonthGrid.
// Καλύπτει: ημερομηνία (γενική πτώση), σήμερα, επιλεγμένη, σημάνσεις,
// πολυήμερο και την εξαίρεση της επικεφαλίδας ημερών.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/features/calendar/calendar_screen.dart';
import 'package:super_note/features/calendar/span_utils.dart';
import 'package:super_note/models/models.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

MonthGrid _grid({
  required DateTime selectedDay,
  DateTime? today,
  Map<DateTime, List<Item>> dayEvents = const <DateTime, List<Item>>{},
  Map<DateTime, SpanDay> spanBars = const <DateTime, SpanDay>{},
}) {
  return MonthGrid(
    focusedMonth: DateTime(2026, 10),
    selectedDay: selectedDay,
    today: today,
    dayEvents: dayEvents,
    spanBars: spanBars,
    onDayTap: (_) {},
  );
}

SemanticsNode _dayNode(WidgetTester tester, DateTime date) {
  return tester.getSemantics(find.byKey(ValueKey(
      'calendar-day-${date.year}-${date.month}-${date.day}')));
}

void main() {
  setUpAll(() async {
    // Parity με main.dart: χωρίς αυτό το DateFormat('…', 'el') πετά.
    await initializeDateFormatting();
  });

  testWidgets('ημέρα: ημερομηνία + σήμερα + επιλεγμένη', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(_grid(
      selectedDay: DateTime(2026, 10, 19),
      today: DateTime(2026, 10, 19),
    )));

    expect(
      _dayNode(tester, DateTime(2026, 10, 19)),
      isSemantics(
        label: '19 Οκτωβρίου 2026, σήμερα, επιλεγμένη',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('ημέρα: σημάνσεις από dayEvents', (tester) async {
    final handle = tester.ensureSemantics();
    final event = Item()
      ..type = ItemType.event
      ..title = 'Συνάντηση';

    await tester.pumpWidget(_wrap(_grid(
      selectedDay: DateTime(2026, 10, 18),
      today: DateTime(2026, 10, 19),
      dayEvents: <DateTime, List<Item>>{
        DateTime(2026, 10, 19): [event],
      },
    )));

    expect(
      _dayNode(tester, DateTime(2026, 10, 19)),
      isSemantics(
        label: '19 Οκτωβρίου 2026, σήμερα, σημάνσεις: συμβάν',
        isButton: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('ημέρα: πολυήμερο συμβάν, αρχή', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(_grid(
      selectedDay: DateTime(2026, 10, 18),
      today: DateTime(2026, 10, 18),
      spanBars: <DateTime, SpanDay>{
        DateTime(2026, 10, 20): SpanDay(itemId: 1, isStart: true),
      },
    )));

    expect(
      _dayNode(tester, DateTime(2026, 10, 20)),
      isSemantics(
        label: '20 Οκτωβρίου 2026, πολυήμερο συμβάν, αρχή',
        isButton: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('ημέρα: απλή ημέρα → μόνο ημερομηνία', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(_grid(
      selectedDay: DateTime(2026, 10, 18),
      today: DateTime(2026, 10, 18),
    )));

    expect(
      _dayNode(tester, DateTime(2026, 10, 21)),
      isSemantics(
        label: '21 Οκτωβρίου 2026',
        isButton: true,
        isSelected: false,
      ),
    );

    handle.dispose();
  });

  testWidgets('επικεφαλίδα ημερών: χωρίς semantics nodes', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(_grid(
      selectedDay: DateTime(2026, 10, 19),
      today: DateTime(2026, 10, 19),
    )));

    for (final initial in AppDateUtils.weekdayInitials) {
      expect(find.semantics.byLabel(initial), findsNothing);
    }

    handle.dispose();
  });

  testWidgets('tap στο κελί καλεί onDayTap', (tester) async {
    DateTime? tapped;
    await tester.pumpWidget(_wrap(MonthGrid(
      focusedMonth: DateTime(2026, 10),
      selectedDay: DateTime(2026, 10, 19),
      today: DateTime(2026, 10, 19),
      dayEvents: const <DateTime, List<Item>>{},
      spanBars: const <DateTime, SpanDay>{},
      onDayTap: (d) => tapped = d,
    )));

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-10-19')));
    await tester.pump();

    expect(tapped, DateTime(2026, 10, 19));
  });
}
