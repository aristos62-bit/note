import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/features/collections/knowledge_entry_nav.dart';
import 'package:super_note/models/models.dart';

ItemProperty _prop(String key, String? value) {
  final p = ItemProperty()
    ..itemId = 1
    ..key = key;
  p.value = value;
  return p;
}

void main() {
  group('collectionIdOf', () {
    test('empty props → null', () {
      expect(collectionIdOf([]), isNull);
    });

    test('missing key → null', () {
      expect(collectionIdOf([_prop('other', '5')]), isNull);
    });

    test('valid collection_id → id', () {
      expect(collectionIdOf([_prop('collection_id', '5')]), 5);
    });

    test('malformed value → null', () {
      expect(collectionIdOf([_prop('collection_id', 'abc')]), isNull);
    });
  });
}
