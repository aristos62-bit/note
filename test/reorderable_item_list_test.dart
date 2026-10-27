// test/reorderable_item_list_test.dart
//
// O5/E27: autoScroll ακολουθεί το physics· dragEnabled ελέγχει το drag.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reorderable_grid/reorderable_grid.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/widgets.dart';

List<Item> _items(int n) => List.generate(
  n,
      (i) => Item()
    ..id = i + 1
    ..title = 'Στοιχείο ${i + 1}'
    ..workspaceId = 1
    ..type = ItemType.note,
);

Widget _host({
  required List<Item> items,
  ScrollPhysics? physics,
  bool dragEnabled = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        // 800 dp ≥ 600 → grid path (2 cols). Εκεί ζει το autoScroll.
        width: 800,
        height: 600,
        child: ReorderableItemList(
          items: items,
          physics: physics,
          dragEnabled: dragEnabled,
          onReorder: (_, __) {},
          itemBuilder: (ctx, item, i) => Card(child: Text(item.title ?? '')),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

SliverReorderableGrid _grid(WidgetTester tester) =>
    tester.widget<SliverReorderableGrid>(find.byType(SliverReorderableGrid));

void main() {
  testWidgets('grid: default physics → autoScroll true (E27)', (tester) async {
    await _pump(tester, _host(items: _items(12)));
    expect(_grid(tester).autoScroll, isTrue);
  });

  testWidgets('grid: NeverScrollableScrollPhysics → autoScroll false (tasks)',
          (tester) async {
        await _pump(
          tester,
          _host(items: _items(12), physics: const NeverScrollableScrollPhysics()),
        );
        expect(_grid(tester).autoScroll, isFalse);
      });

  testWidgets('dragEnabled: false → κανένα handle, τίποτα draggable',
          (tester) async {
        await _pump(tester, _host(items: _items(12), dragEnabled: false));
        expect(find.byType(ReorderHandle), findsNothing);
        final grid = _grid(tester);
        for (var i = 0; i < 12; i++) {
          expect(grid.itemDragEnable(i), isFalse, reason: 'index $i');
        }
      });

  testWidgets('default policy: pinned ΟΧΙ draggable, ελεύθερο ΝΑΙ',
          (tester) async {
        final items = _items(4);
        items[0].pinned = true;
        await _pump(tester, _host(items: items));
        final grid = _grid(tester);
        expect(grid.itemDragEnable(0), isFalse); // pinned
        expect(grid.itemDragEnable(1), isTrue);  // ελεύθερο
      });
}