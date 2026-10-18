// test/selection_list_dialog_test.dart
//
// S254 (F16): widget tests για το κοινό SelectionListDialog shell.
// Pure — χωρίς Isar (πρότυπο safe_shells_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/features/settings/selection_list_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required List<String> items,
    List<Widget> Function(BuildContext, SelectionListController<String>)?
        actions,
    Widget? Function(BuildContext, String)? rowSubtitle,
    Widget? Function(BuildContext, String, SelectionListController<String>)?
        rowSecondary,
    String closeLabel = 'Κλείσιμο',
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSelectionListDialog<String>(
              context: context,
              icon: Icons.warning_amber_rounded,
              title: (n) => 'Λίστα ($n)',
              items: items,
              idOf: (s) => s.codeUnitAt(0),
              rowTitle: (ctx, s) => Text(s),
              rowSubtitle: rowSubtitle,
              rowSecondary: rowSecondary,
              actions: actions ?? (ctx, c) => const [],
              closeLabel: closeLabel,
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  testWidgets('render: title count + rows + close label', (tester) async {
    await open(tester, items: const ['A', 'B', 'C']);
    expect(find.text('Λίστα (3)'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('Επιλογή όλων'), findsOneWidget);
    expect(find.text('Κλείσιμο'), findsOneWidget);
  });

  testWidgets('selection: per-row toggle + select all', (tester) async {
    await open(
      tester,
      items: const ['A', 'B', 'C'],
      actions: (ctx, c) => [Text('sel:${c.selectedCount}')],
    );
    expect(find.text('sel:0'), findsOneWidget);

    await tester.tap(find.text('A'));
    await tester.pump();
    expect(find.text('sel:1'), findsOneWidget);

    await tester.tap(find.text('Επιλογή όλων'));
    await tester.pump();
    expect(find.text('sel:3'), findsOneWidget);
    expect(find.text('Αποεπιλογή όλων'), findsOneWidget);
  });

  testWidgets('closeLabel override', (tester) async {
    await open(tester, items: const ['A'], closeLabel: 'Άκυρο');
    expect(find.text('Άκυρο'), findsOneWidget);
    expect(find.text('Κλείσιμο'), findsNothing);
  });

  testWidgets('rowSubtitle + rowSecondary render', (tester) async {
    await open(
      tester,
      items: const ['A', 'B'],
      rowSubtitle: (ctx, s) => Text('SUB-$s'),
      rowSecondary: (ctx, s, c) => IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => c.remove([s.codeUnitAt(0)]),
      ),
    );
    expect(find.text('SUB-A'), findsOneWidget);
    expect(find.text('SUB-B'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    // remove 1 γραμμή → το dialog ΜΕΝΕΙ ανοιχτό, title ενημερώνεται
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Λίστα (1)'), findsOneWidget);
    expect(find.byType(SelectionListDialog<String>), findsOneWidget);
  });

  testWidgets('remove all → auto-pop', (tester) async {
    await open(
      tester,
      items: const ['A', 'B'],
      actions: (ctx, c) => [
        TextButton(
          onPressed: () => c.remove(c.items.map((s) => s.codeUnitAt(0))),
          child: const Text('REMOVEALL'),
        ),
      ],
    );
    expect(find.byType(SelectionListDialog<String>), findsOneWidget);

    await tester.tap(find.text('REMOVEALL'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionListDialog<String>), findsNothing);
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('toggleAll(false) clears selection', (tester) async {
    await open(
      tester,
      items: const ['A', 'B', 'C'],
      actions: (ctx, c) => [Text('sel:${c.selectedCount}')],
    );
    await tester.tap(find.text('Επιλογή όλων'));
    await tester.pump();
    expect(find.text('sel:3'), findsOneWidget);

    await tester.tap(find.text('Αποεπιλογή όλων'));
    await tester.pump();
    expect(find.text('sel:0'), findsOneWidget);
    expect(find.text('Επιλογή όλων'), findsOneWidget);
  });
}
