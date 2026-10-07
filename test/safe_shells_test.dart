// test/safe_shells_test.dart
//
// Tests για τα SPoT shells Φάσης 2 (Sessions 109):
// SafeSheet + showSafeSheet + SafeDialogBody.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/shared/widgets/widgets.dart';

void main() {
  testWidgets('SafeSheet renders title, child and actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SafeSheet(
          title: 'Επέλεξε',
          actions: [Text('A1'), Text('A2')],
          child: Text('Περιεχόμενο'),
        ),
      ),
    ));
    expect(find.text('Επέλεξε'), findsOneWidget);
    expect(find.text('Περιεχόμενο'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('A2'), findsOneWidget);
  });

  testWidgets('SafeSheet without title/actions renders child only',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SafeSheet(child: Text('Μόνο')),
      ),
    ));
    expect(find.text('Μόνο'), findsOneWidget);
    expect(find.byType(Expanded), findsNothing);
  });

  testWidgets('SafeDialogBody renders child inside scroll', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SafeDialogBody(child: Text('Διάλογος')),
      ),
    ));
    expect(find.text('Διάλογος'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('showSafeSheet opens and returns sheet-ctx popped value',
      (tester) async {
    String? got;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              got = await showSafeSheet<String>(
                ctx,
                child: SafeSheet(
                  title: 'Επέλεξε',
                  child: Builder(
                    builder: (sheetCtx) => TextButton(
                      onPressed: () => Navigator.pop(sheetCtx, 'τιμή'),
                      child: const Text('Διάλεξε'),
                    ),
                  ),
                ),
              );
            },
            child: const Text('Άνοιγμα'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Άνοιγμα'));
    await tester.pumpAndSettle();
    expect(find.text('Επέλεξε'), findsOneWidget);
    await tester.tap(find.text('Διάλεξε'));
    await tester.pumpAndSettle();
    expect(find.text('Επέλεξε'), findsNothing);
    expect(got, 'τιμή');
  });
}
