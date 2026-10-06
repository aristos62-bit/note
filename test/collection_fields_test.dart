import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/features/collections/collection_fields.dart';

void main() {
  group('FieldDef json', () {
    test('round-trip preserves schema', () {
      const fields = [
        FieldDef(key: 'title', label: 'Τίτλος', type: FieldType.text),
        FieldDef(
          key: 'photo',
          label: 'Φωτό',
          type: FieldType.attachment,
          allowedExtensions: ['jpg'],
          maxFiles: 3,
        ),
      ];
      final restored = FieldDef.listFromJson(FieldDef.listToJson(fields));
      expect(restored.length, 2);
      expect(restored[0].key, 'title');
      expect(restored[0].type, FieldType.text);
      expect(restored[1].allowedExtensions, ['jpg']);
      expect(restored[1].maxFiles, 3);
    });

    test('empty string → []', () {
      expect(FieldDef.listFromJson(''), isEmpty);
    });

    test('malformed json → []', () {
      expect(FieldDef.listFromJson('not-json'), isEmpty);
    });
  });
}
