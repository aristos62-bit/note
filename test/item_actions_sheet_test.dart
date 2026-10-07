// test/item_actions_sheet_test.dart
//
// ItemActionsSheet SPoT: tiles, pop+callback, conditional title/divider.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/archive_helper.dart';
import 'package:super_note/shared/widgets/item_actions_sheet.dart';
import 'package:super_note/shared/widgets/priority_badge.dart';

Item _testItem() => Item()
  ..workspaceId = 1
  ..type = ItemType.note
  ..title = 'Τίτλος';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.light),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('δείχνει τίτλο + όλα τα tiles και καλεί callbacks', (tester) async {
    var pin = 0, fav = 0, arch = 0, del = 0, edit = 0;
    await tester.pumpWidget(_wrap(ItemActionsSheet(
      item: _testItem(),
      onEdit: () => edit++,
      onPin: () => pin++,
      onFav: () => fav++,
      onArchive: () => arch++,
      onDelete: () => del++,
    )));
    expect(find.text('Τίτλος'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    await tester.tap(find.text('Επεξεργασία'));
    await tester.tap(find.text('Καρφίτσωμα'));
    await tester.tap(find.text('Αγαπημένο'));
    await tester.tap(find.text('Αρχειοθέτηση'));
    await tester.tap(find.text('Διαγραφή'));
    expect([edit, pin, fav, arch, del], [1, 1, 1, 1, 1]);
  });

  testWidgets('showTitle=false κρύβει τίτλο + Divider', (tester) async {
    await tester.pumpWidget(_wrap(ItemActionsSheet(
      item: _testItem(),
      showTitle: false,
      onDelete: () {},
    )));
    expect(find.text('Τίτλος'), findsNothing);
    expect(find.byType(Divider), findsNothing);
    expect(find.text('Διαγραφή'), findsOneWidget);
  });

  testWidgets('archived=true δείχνει Επαναφορά, pinned/fav ετικέτες', (tester) async {
    final item = _testItem()
      ..archived = true
      ..pinned = true
      ..favorite = true
      ..priority = ItemPriority.high;
    await tester.pumpWidget(_wrap(ItemActionsSheet(
      item: item,
      showPriority: true,
      onPin: () {},
      onFav: () {},
      onArchive: () {},
    )));
    expect(find.text('Επαναφορά'), findsOneWidget);
    expect(find.text('Αποκαρφίτσωμα'), findsOneWidget);
    expect(find.text('Αφαίρεση από αγαπημένα'), findsOneWidget);
    expect(find.byType(PriorityBadge), findsOneWidget);
  });

  testWidgets('null callbacks κρύβουν tiles', (tester) async {
    await tester.pumpWidget(_wrap(ItemActionsSheet(
      item: _testItem(),
      showTitle: false,
      onDelete: () {},
    )));
    expect(find.text('Επεξεργασία'), findsNothing);
    expect(find.text('Καρφίτσωμα'), findsNothing);
    expect(find.text('Διαγραφή'), findsOneWidget);
  });

  testWidgets('ItemLabelX.fromType χαρτογραφεί σωστά', (tester) async {
    expect(ItemLabelX.fromType(ItemType.task), ItemLabel.task);
    expect(ItemLabelX.fromType(ItemType.knowledge), ItemLabel.entry);
    expect(ItemLabelX.fromType(ItemType.appointment), ItemLabel.appointment);
  });

  testWidgets('κοντό landscape: 7 actions κάνουν scroll χωρίς overflow',
      (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 200,
      child: ItemActionsSheet(
        item: _testItem(),
        onEdit: () {},
        onOpen: () {},
        onPin: () {},
        onFav: () {},
        onShare: () {},
        onArchive: () {},
        onDelete: () {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('Διαγραφή'), findsOneWidget);
  });
}
