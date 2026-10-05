// test/item_card_skeleton_test.dart
//
// ItemCardSkeleton SPoT (Φ4a βήμα 14): shimmer placeholder (collections loading).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/shared/widgets/item_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('renders shimmer container', (tester) async {
    await tester.pumpWidget(_wrap(const ItemCardSkeleton()));
    expect(find.byType(ItemCardSkeleton), findsOneWidget);
    expect(find.byType(AnimatedBuilder), findsWidgets);
  });

  testWidgets('compact variant renders', (tester) async {
    await tester.pumpWidget(
        _wrap(const ItemCardSkeleton(compact: true)));
    expect(find.byType(ItemCardSkeleton), findsOneWidget);
  });
}
