// test/recent_items_test.dart
//
// O5/E44: «Πρόσφατα» = πραγματικά πρόσφατα (updatedAt ?? createdAt desc).
// Pure unit tests του selectRecentItems — χωρίς Isar/Riverpod.
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/features/home/home_folder_view.dart';
import 'package:super_note/models/models.dart';

Item _item({
  required int id,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool pinned = false,
  bool favorite = false,
  DateTime? deletedAt,
  bool archived = false,
}) =>
    Item()
      ..id = id
      ..title = 'Item $id'
      ..workspaceId = 1
      ..type = ItemType.note
      ..createdAt = createdAt ?? DateTime(2026, 1, 1)
      ..updatedAt = updatedAt
      ..pinned = pinned
      ..favorite = favorite
      ..deletedAt = deletedAt
      ..archived = archived;

List<int> _ids(List<Item> items) => items.map((i) => i.id).toList();

void main() {
  group('selectRecentItems — σειρά', () {
    test('updatedAt desc (κυρίαρχο κριτήριο)', () {
      final items = [
        _item(id: 1, updatedAt: DateTime(2026, 1, 1)),
        _item(id: 2, updatedAt: DateTime(2026, 3, 1)),
        _item(id: 3, updatedAt: DateTime(2026, 2, 1)),
      ];
      expect(_ids(selectRecentItems(items)), [2, 3, 1]);
    });

    test('fallback createdAt όταν updatedAt == null', () {
      final items = [
        _item(id: 1, createdAt: DateTime(2026, 1, 1)),
        _item(id: 2, createdAt: DateTime(2026, 5, 1)),
      ];
      expect(_ids(selectRecentItems(items)), [2, 1]);
    });

    test('tie (ίδιο timestamp) → id desc (ντετερμινιστικό)', () {
      final t = DateTime(2026, 1, 1);
      final items = [
        _item(id: 7, updatedAt: t),
        _item(id: 3, updatedAt: t),
        _item(id: 9, updatedAt: t),
      ];
      expect(_ids(selectRecentItems(items)), [9, 7, 3]);
    });

    test('regression E44: ίδιο αποτέλεσμα ανεξάρτητα από αρχική σειρά', () {
      final t = DateTime(2026, 1, 1);
      final a = [
        _item(id: 1, updatedAt: t),
        _item(id: 2, updatedAt: t),
        _item(id: 3, updatedAt: t),
      ];
      final b = a.reversed.toList();
      expect(_ids(selectRecentItems(a)), _ids(selectRecentItems(b)));
    });

    test('pinned/favorites ΔΕΝ εξαιρούνται (μόνο η σειρά αλλάζει)', () {
      final items = [
        _item(id: 1, updatedAt: DateTime(2026, 1, 1), pinned: true),
        _item(id: 2, updatedAt: DateTime(2026, 2, 1), favorite: true),
      ];
      expect(_ids(selectRecentItems(items)), [2, 1]);
    });
  });

  group('selectRecentItems — όρια & φίλτρα', () {
    test('limit: επιστρέφει τα 10 νεότερα από 12', () {
      final items = List.generate(
        12,
            (i) => _item(id: i + 1, updatedAt: DateTime(2026, 1, i + 1)),
      );
      final recent = selectRecentItems(items);
      expect(recent.length, 10);
      expect(recent.first.id, 12);
      expect(recent.last.id, 3);
    });

    test('limit <= 0 → κενή λίστα', () {
      final items = [_item(id: 1, updatedAt: DateTime(2026, 1, 1))];
      expect(selectRecentItems(items, limit: 0), isEmpty);
      expect(selectRecentItems(items, limit: -1), isEmpty);
    });

    test('φιλτράρει deletedAt != null και archived', () {
      final items = [
        _item(
          id: 1,
          updatedAt: DateTime(2026, 3, 1),
          deletedAt: DateTime(2026, 3, 2),
        ),
        _item(id: 2, updatedAt: DateTime(2026, 2, 1), archived: true),
        _item(id: 3, updatedAt: DateTime(2026, 1, 1)),
      ];
      expect(_ids(selectRecentItems(items)), [3]);
    });

    test('κενή λίστα → κενή', () {
      expect(selectRecentItems(const []), isEmpty);
    });
  });
}