// test/item_card_icons_test.dart
//
// ItemCard icon SPoT (Φ4a βήμα 8): iconFor + shared ItemTypeIcon.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/item_card.dart';
import 'package:super_note/shared/widgets/item_type_icon.dart';
import 'package:super_note/shared/widgets/priority_badge.dart';

Item _item(ItemType type, {ItemPriority priority = ItemPriority.none}) {
  return Item()
    ..workspaceId = 1
    ..type = type
    ..title = 'Τίτλος'
    ..priority = priority;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.light),
    home: Scaffold(body: child),
  );
}

void main() {
  test('iconFor για κάθε priority', () {
    expect(PriorityBadge.iconFor(ItemPriority.urgent), Icons.priority_high_rounded);
    expect(PriorityBadge.iconFor(ItemPriority.high), Icons.keyboard_arrow_up_rounded);
    expect(PriorityBadge.iconFor(ItemPriority.medium), Icons.remove_rounded);
    expect(PriorityBadge.iconFor(ItemPriority.low), Icons.keyboard_arrow_down_rounded);
    expect(PriorityBadge.iconFor(ItemPriority.none), Icons.remove_rounded);
  });

  testWidgets('ItemCard: κάθε type render με SPoT icon', (tester) async {
    for (final type in ItemType.values) {
      await tester.pumpWidget(_wrap(ItemCard(item: _item(type))));
      expect(find.byIcon(ItemTypeIcon.iconDataFor(type)), findsWidgets,
          reason: type.name);
    }
  });

  testWidgets('ItemCard knowledge → article (όχι lightbulb)', (tester) async {
    await tester.pumpWidget(_wrap(ItemCard(item: _item(ItemType.knowledge))));
    expect(find.byIcon(Icons.article_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsNothing);
  });

  testWidgets('ItemCard priority chip icons', (tester) async {
    await tester.pumpWidget(_wrap(ItemCard(
        item: _item(ItemType.task, priority: ItemPriority.urgent))));
    expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
  });
}
