// test/picker_bounds_test.dart
//
// Ο7 — E20/E41: επιβεβαιώνει με το πραγματικό SDK ότι το showDatePicker
// πετάει assert όταν το initialDate είναι εκτός [firstDate, lastDate], και
// ότι το clampToRange (E41 pattern) το αποτρέπει. Χωρίς Isar/locale init.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/date_utils.dart';

final DateTime _first = DateTime(AppDateUtils.earliestYear);
final DateTime _last = DateTime(2026, 10, 28);

/// Ανοίγει τον picker μέσα από tap (πραγματική ροή UI) και επιστρέφει το
/// context του scaffold.
Future<void> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () {
              showDatePicker(
                context: ctx,
                initialDate: AppDateUtils.clampToRange(
                    DateTime(1950, 5, 20), _first, _last),
                firstDate: _first,
                lastDate: _last,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('χωρίς clamp: initialDate 1850 → AssertionError του SDK',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
      ),
    );
    // date_picker.dart:235 — initialDate must be on or after firstDate.
    expect(
      () => showDatePicker(
        context: ctx,
        initialDate: DateTime(1850, 5, 20),
        firstDate: _first,
        lastDate: _last,
      ),
      throwsAssertionError,
    );
  });

  testWidgets('χωρίς clamp: initialDate 2099 → AssertionError του SDK',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
      ),
    );
    // date_picker.dart:239 — initialDate must be on or before lastDate.
    expect(
      () => showDatePicker(
        context: ctx,
        initialDate: DateTime(2099, 1, 1),
        firstDate: _first,
        lastDate: _last,
      ),
      throwsAssertionError,
    );
  });

  testWidgets('με clamp: γενέθλια 1950 ανοίγουν κανονικά (E20)', (tester) async {
    await _pumpHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('με clamp: μελλοντική τιμή 2099 πέφτει στο lastDate',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () {
                showDatePicker(
                  context: ctx,
                  initialDate: AppDateUtils.clampToRange(
                      DateTime(2099, 1, 1), _first, _last),
                  firstDate: _first,
                  lastDate: _last,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
