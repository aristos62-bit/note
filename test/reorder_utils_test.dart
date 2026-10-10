import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/reorder_utils.dart';
import 'package:super_note/models/models.dart';

// ΜΟΝΟ ids — workspaceId/type είναι late (item.dart:60-69).
Item _it(int id) => Item()..id = id;
List<int> _ids(List<Item> items) => items.map((i) => i.id).toList();

void main() {
  group('ReorderUtils.moveAndMerge', () {
    test('acceptance [1,2,3] filtered [2,3] drag 3 first → [1,3,2]', () {
      expect(_ids(ReorderUtils.moveAndMerge(
        full: [_it(1), _it(2), _it(3)], filtered: [_it(2), _it(3)],
        oldIndex: 1, newIndex: 0)), [1, 3, 2]);
    });
    test('equal indices → copy', () {
      expect(_ids(ReorderUtils.moveAndMerge(
        full: [_it(1), _it(2)], filtered: [_it(1), _it(2)],
        oldIndex: 0, newIndex: 0)), [1, 2]);
    });
    test('empty filtered → copy of full', () {
      expect(_ids(ReorderUtils.moveAndMerge(
        full: [_it(1), _it(2)], filtered: [],
        oldIndex: 0, newIndex: 0)), [1, 2]);
    });
    test('empty full → []', () {
      expect(ReorderUtils.moveAndMerge(
        full: [], filtered: [_it(2)], oldIndex: 0, newIndex: 0), isEmpty);
    });
    test('stale id ignored, no throw, no resurrection', () {
      expect(_ids(ReorderUtils.moveAndMerge(
        full: [_it(1), _it(2)], filtered: [_it(2), _it(9)],
        oldIndex: 1, newIndex: 0)), [1, 2]);
    });
    test('non-filtered stability', () {
      expect(_ids(ReorderUtils.moveAndMerge(
        full: [_it(1), _it(2), _it(3), _it(4), _it(5), _it(6)],
        filtered: [_it(2), _it(5)], oldIndex: 1, newIndex: 0)),
        [1, 5, 3, 4, 2, 6]);
    });
  });
}
