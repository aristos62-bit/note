// test/settings_icons_test.dart
//
// Settings 4ος icon-χάρτης (parked βήματος 8): SPoT ItemTypeIcon.iconDataFor.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/item_type_icon.dart';

void main() {
  test('13/13 non-null', () {
    for (final t in ItemType.values) {
      expect(ItemTypeIcon.iconDataFor(t), isA<IconData>());
    }
  });

  test('spot-checks ευθυγράμμισης (βήμα 8 + settings)', () {
    expect(ItemTypeIcon.iconDataFor(ItemType.knowledge), Icons.article_rounded);
    expect(ItemTypeIcon.iconDataFor(ItemType.task),
        Icons.check_circle_outline_rounded);
    expect(ItemTypeIcon.iconDataFor(ItemType.habit), Icons.loop_rounded);
    expect(ItemTypeIcon.iconDataFor(ItemType.appointment).codePoint,
        isNot(0));
  });
}
