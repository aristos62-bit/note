// test/journal_dates_test.dart
//
// Pure helper journalEntryDisplayDate: entry_date → fallback (updatedAt → createdAt).
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/features/journal/journal_list_screen.dart';
import 'package:super_note/models/models.dart';

Item _item(DateTime created) {
  return Item()
    ..id = 1
    ..workspaceId = 1
    ..type = ItemType.journal
    ..createdAt = created;
}

ItemProperty _prop(String value) {
  return ItemProperty()
    ..itemId = 1
    ..key = 'entry_date'
    ..value = value;
}

void main() {
  group('journalEntryDisplayDate', () {
    test('entry_date ok', () {
      final d =
          journalEntryDisplayDate(_item(DateTime(2020)), [_prop('2026-10-05')]);
      expect(d, DateTime(2026, 10, 5));
    });

    test('corrupt → fallback updatedAt', () {
      final item = _item(DateTime(2020))..updatedAt = DateTime(2026, 1, 2, 3, 4);
      expect(journalEntryDisplayDate(item, [_prop('oxi-imerominia')]),
          DateTime(2026, 1, 2, 3, 4));
    });

    test('missing → fallback createdAt', () {
      final created = DateTime(2025, 5, 6);
      expect(journalEntryDisplayDate(_item(created), []), created);
    });
  });
}
