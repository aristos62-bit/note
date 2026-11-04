// test/item_card_attachment_badge_test.dart
//
// E09: badge συνημμένων στο ItemCard.
// - default attachmentCount = 0 → κανένα badge (backwards compat)
// - >0 → inline εικονίδιο + αριθμός
// - >1.3 text scale → μόνο εικονίδιο, αριθμός στο Semantics label
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/item_card.dart';

Item _item() => Item()
  ..workspaceId = 1
  ..type = ItemType.note
  ..title = 'Σημείωση με συνημμένα';

Widget _wrap(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('χωρίς συνημμένα → κανένα badge (default 0)', (tester) async {
    await tester.pumpWidget(_wrap(ItemCard(item: _item())));

    expect(find.byIcon(Icons.attach_file_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('3 συνημμένα → εικονίδιο + αριθμός', (tester) async {
    await tester.pumpWidget(
        _wrap(ItemCard(item: _item(), attachmentCount: 3)));

    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1 συνημμένο → εικονίδιο + 1', (tester) async {
    await tester.pumpWidget(
        _wrap(ItemCard(item: _item(), attachmentCount: 1)));

    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('120% text scale → αριθμός ορατός', (tester) async {
    await tester.pumpWidget(_wrap(
      ItemCard(item: _item(), attachmentCount: 2),
      textScale: 1.2,
    ));

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('200% text scale → μόνο εικονίδιο, αριθμός στο Semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(
      ItemCard(item: _item(), attachmentCount: 5),
      textScale: 2.0,
    ));

    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    expect(find.text('5'), findsNothing);
    expect(find.bySemanticsLabel('5 συνημμένα'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
