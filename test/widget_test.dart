// test/widget_test.dart
//
// Smoke test εφαρμογής (αντικαθιστά το παλιό counter test,
// που σήκωνε SuperNoteApp χωρίς ProviderScope/Isar).
// Ερμητικά SPoT widgets — χωρίς DB/Riverpod.
//
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/shared/widgets/sheet_handle.dart';
import 'package:super_note/shared/widgets/search_clear_button.dart';
import 'package:super_note/core/utils/app_errors.dart';

void main() {
  testWidgets('SPoT widgets render', (WidgetTester tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const SheetHandle(),
            SearchClearButton(controller: ctrl),
            const Text(AppErrors.saveFailed),
          ],
        ),
      ),
    ));

    expect(find.byType(SheetHandle), findsOneWidget);
    expect(find.byType(SearchClearButton), findsOneWidget);
    expect(find.text(AppErrors.saveFailed), findsOneWidget);
  });
}
