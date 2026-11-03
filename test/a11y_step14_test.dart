// test/a11y_step14_test.dart
//
// S288 (a11y E01 · Βήμα 14): N5 stats labels + N2 drag-handle semantics.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:super_note/features/home/home_folder_view.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/shared/widgets/widgets.dart';

Folder _folder() => Folder()
  ..id = 1
  ..name = 'Γενικά'
  ..workspaceId = 1
  ..icon = '📁';

List<Item> _notes(int count) => List.generate(
      count,
      (i) => Item()
        ..id = i + 1
        ..title = 'Σημείωση ${i + 1}'
        ..type = ItemType.note
        ..workspaceId = 1
        ..folderId = 1
        ..createdAt = DateTime(2026, 1, 1)
        ..updatedAt = DateTime(2026, 1, 1),
    );

Widget _statsHost(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return ProviderScope(
    overrides: [
      itemsByFolderStreamProvider(1)
          .overrideWith((ref) => Stream.value(_notes(3))),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 800,
          child: HomeFolderView(folder: _folder()),
        ),
      ),
    ),
  );
}

Widget _reorderHost(List<Item> items, void Function(int, int) onReorder) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: ReorderableItemList(
          items: items,
          onReorder: onReorder,
          itemBuilder: (ctx, item, i) => Card(child: Text(item.title ?? '')),
        ),
      ),
    ),
  );
}

List<Semantics> _handles(WidgetTester tester) => tester
    .widgetList<Semantics>(find.ancestor(
      of: find.byType(ReorderHandle),
      matching: find.byType(Semantics),
    ))
    .where((s) => s.properties.label == 'Αναδιάταξη')
    .toList();

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  testWidgets('N5: η γραμμή stats διαβάζεται «3 Σημειώσεις»', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_statsHost(tester));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('3 Σημειώσεις'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('N2: drag handle έχει label + actions, το πρώτο μόνο «κάτω»',
      (tester) async {
    var moved = <int>[];
    await tester.pumpWidget(_reorderHost(
      _notes(3),
      (oldIndex, newIndex) => moved = [oldIndex, newIndex],
    ));
    await tester.pumpAndSettle();

    final handles = _handles(tester);
    expect(handles, hasLength(3));

    final first = handles.first.properties.customSemanticsActions!;
    expect(first.keys.map((a) => a.label), contains('Μετακίνηση κάτω'));
    expect(first.keys.map((a) => a.label), isNot(contains('Μετακίνηση πάνω')));

    first[const CustomSemanticsAction(label: 'Μετακίνηση κάτω')]!();
    expect(moved, [0, 1]);
  });

  testWidgets('N2: το μεσαίο στοιχείο έχει και «πάνω» και «κάτω»',
      (tester) async {
    await tester.pumpWidget(_reorderHost(_notes(3), (_, __) {}));
    await tester.pumpAndSettle();

    final middle = _handles(tester)[1].properties.customSemanticsActions!;
    expect(
      middle.keys.map((a) => a.label),
      containsAll(<String>['Μετακίνηση πάνω', 'Μετακίνηση κάτω']),
    );
  });
}
