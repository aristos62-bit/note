// test/entry_preview_test.dart
//
// Pure helper entryPreviewValue: byte-identical με το inline _EntryCard.
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/features/collections/collection_entries_screen.dart';
import 'package:super_note/features/collections/collection_fields.dart';
import 'package:super_note/models/models.dart';

ItemProperty _prop(String key, String value) {
  return ItemProperty()
    ..itemId = 1
    ..key = key
    ..value = value;
}

FieldDef _field(String key, FieldType type) {
  return FieldDef(key: key, label: key, type: type);
}

void main() {
  group('entryPreviewValue', () {
    test('text → raw value', () {
      expect(entryPreviewValue(_field('όνομα', FieldType.text), [_prop('όνομα', 'Βαγγέλης')]), 'Βαγγέλης');
    });

    test('text missing → empty', () {
      expect(entryPreviewValue(_field('όνομα', FieldType.text), []), '');
    });

    test('bullet list → count', () {
      expect(entryPreviewValue(_field('λίστα', FieldType.bulletList), [_prop('λίστα', '["a","b","c"]')]), '3 στοιχεία');
    });

    test('bullet list corrupt → empty', () {
      expect(entryPreviewValue(_field('λίστα', FieldType.bulletList), [_prop('λίστα', 'oxi-json')]), '');
    });

    test('attachment 1 → singular', () {
      expect(entryPreviewValue(_field('αρχεία', FieldType.attachment), [_prop('αρχεία', '[5]')]), '1 συνημμένο');
    });

    test('attachment N → plural', () {
      expect(entryPreviewValue(_field('αρχεία', FieldType.attachment), [_prop('αρχεία', '[5,9]')]), '2 συνημμένα');
    });

    test('unknown key → empty', () {
      expect(entryPreviewValue(_field('άγνωστο', FieldType.number), [_prop('άλλο', 'x')]), '');
    });
  });
}
