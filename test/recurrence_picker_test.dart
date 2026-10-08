// test/recurrence_picker_test.dart
//
// RecurrencePicker SPoT migration (Session 113): hermetic widget tests
// via the public showRecurrencePicker (plain StatefulWidget — no Isar/Riverpod).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/recurrence.dart';
import 'package:super_note/shared/widgets/reminder_section.dart';

void main() {
  testWidgets('weekly flow επιστρέφει Recurrence', (tester) async {
    Recurrence? got;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              got = await showRecurrencePicker(context: ctx);
            },
            child: const Text('Άνοιγμα'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Άνοιγμα'));
    await tester.pumpAndSettle();
    expect(find.text('Επανάληψη υπενθύμισης'), findsOneWidget);
    await tester.tap(find.text('Εβδομαδιαία'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Εφαρμογή'));
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!.type, RecurrenceType.weekly);
  });

  testWidgets('Άκυρο επιστρέφει null', (tester) async {
    Recurrence? got = Recurrence.daily();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              got = await showRecurrencePicker(context: ctx);
            },
            child: const Text('Άνοιγμα'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Άνοιγμα'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Άκυρο'));
    await tester.pumpAndSettle();
    expect(got, isNull);
  });

  testWidgets('κοντό landscape: κυλάει χωρίς overflow', (tester) async {
    // Πραγματικό κοντό viewport (το modal ανοίγει σε overlay — wrapper
    // SizedBox δεν θα περιόριζε τίποτα).
    tester.view.physicalSize = const Size(800, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showRecurrencePicker(context: ctx),
            child: const Text('Άνοιγμα'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Άνοιγμα'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('Εφαρμογή'), findsOneWidget);
  });
}
