import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/helpers/item_color_helper.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/services/reminder_text.dart';

Item _item({
  int id = 1,
  ItemType type = ItemType.note,
  String? title,
  String? icon,
}) {
  return Item()
    ..id = id
    ..workspaceId = 1
    ..type = type
    ..title = title
    ..icon = icon;
}

Reminder _reminder({
  int id = 1,
  int itemId = 1,
  String? title,
  String? body,
  DateTime? triggerAt,
}) {
  return Reminder()
    ..id = id
    ..itemId = itemId
    ..triggerAt = triggerAt ?? DateTime(2030, 1, 1, 9)
    ..title = title
    ..body = body
    ..status = ReminderStatus.pending;
}

void main() {
  group('resolveReminderNotificationText', () {
    test('generic bell uses live item title as body', () {
      final text = resolveReminderNotificationText(
        _reminder(title: 'Υπενθύμιση', body: 'Παλιό'),
        _item(title: 'Νέο'),
      );
      expect(text.title, 'Υπενθύμιση');
      expect(text.body, 'Νέο');
    });

    test('event birthday uses live item title as body', () {
      final text = resolveReminderNotificationText(
        _reminder(title: '🎂 Γενέθλια', body: 'Παλιό'),
        _item(type: ItemType.event, icon: ItemColorHelper.kBirthdayIcon, title: 'Νέο'),
      );
      expect(text.title, '🎂 Γενέθλια');
      expect(text.body, 'Νέο');
    });

    test('habit generated row uses live item title in body', () {
      final text = resolveReminderNotificationText(
        _reminder(
          title: habitGeneratedTitle,
          body: 'Υπενθύμιση: Παλιό',
        ),
        _item(type: ItemType.habit, title: 'Νέο'),
      );
      expect(text.title, habitGeneratedTitle);
      expect(text.body, 'Υπενθύμιση: Νέο');
    });

    test('contact birthday updates both title and body', () {
      final text = resolveReminderNotificationText(
        _reminder(title: 'Γενέθλια Παλιό', body: 'Γενέθλια Παλιό'),
        _item(type: ItemType.contact, title: 'Νέο'),
      );
      expect(text.title, 'Γενέθλια Νέο');
      expect(text.body, 'Γενέθλια Νέο');
    });

    test('contact generic bell updates body only', () {
      final text = resolveReminderNotificationText(
        _reminder(title: 'Υπενθύμιση', body: 'Παλιό'),
        _item(type: ItemType.contact, title: 'Νέο'),
      );
      expect(text.title, 'Υπενθύμιση');
      expect(text.body, 'Νέο');
    });

    test('null title stays live from item icon/title', () {
      final reminder = _reminder(title: null, body: 'Σταθερό');
      final text = resolveReminderNotificationText(
        reminder,
        _item(icon: '📝', title: 'Νέο'),
      );
      expect(text.title, '📝 Νέο');
      expect(text.body, 'Σταθερό');
      expect(syncableReminderNotificationText(reminder, _item(icon: '📝', title: 'Νέο')), isNull);
    });

    test('empty item title preserves stored text', () {
      final text = resolveReminderNotificationText(
        _reminder(title: 'Γενέθλια Παλιό', body: 'Γενέθλια Παλιό'),
        _item(type: ItemType.contact, title: ''),
      );
      expect(text.title, 'Γενέθλια Παλιό');
      expect(text.body, 'Γενέθλια Παλιό');
    });

    test('custom title/body stays untouched', () {
      final text = resolveReminderNotificationText(
        _reminder(title: 'Πλύσιμο', body: 'Παλιό'),
        _item(title: 'Νέο'),
      );
      expect(text.title, 'Πλύσιμο');
      expect(text.body, 'Παλιό');
    });

    test('syncable text writes contact birthday but not null-title rows', () {
      final contact = _reminder(title: 'Γενέθλια Παλιό', body: 'Γενέθλια Παλιό');
      expect(
        syncableReminderNotificationText(contact, _item(type: ItemType.contact, title: 'Νέο')),
        isNotNull,
      );
    });
  });
}
