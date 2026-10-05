// test/item_type_labels_test.dart
//
// Label SPoT (Φ4a βήμα 7): labelGr == labelFor == itemTypeLabel(name).
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/string_utils.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/item_type_icon.dart';

void main() {
  test('13/13 non-empty', () {
    for (final t in ItemType.values) {
      expect(t.labelGr, isNotEmpty, reason: t.name);
      expect(ItemTypeIcon.labelFor(t), isNotEmpty, reason: t.name);
    }
  });

  test('Ραντεβού με τόνο', () {
    expect(ItemType.appointment.labelGr, 'Ραντεβού');
  });

  test('project == knowledge == Συλλογή', () {
    expect(ItemType.project.labelGr, 'Συλλογή');
    expect(ItemType.knowledge.labelGr, 'Συλλογή');
  });

  test('τριπλή συμφωνία για κάθε type', () {
    for (final t in ItemType.values) {
      expect(ItemTypeIcon.labelFor(t), t.labelGr, reason: t.name);
      expect(AppStringUtils.itemTypeLabel(t.name), t.labelGr, reason: t.name);
    }
  });

  test('unknown String → fallback input', () {
    expect(AppStringUtils.itemTypeLabel('nope'), 'nope');
    expect(AppStringUtils.itemTypeLabel(''), '');
  });
}
