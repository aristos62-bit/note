// test/share_text_test.dart
//
// E39 — Render (κείμενο): ShareText.forItem ανά τύπο item (D2–D7).
// Καθαρή συνάρτηση πάνω σε models → unit tests χωρίς DB/IO.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:super_note/core/utils/collection_fields.dart';
import 'package:super_note/core/utils/date_utils.dart';
import 'package:super_note/core/utils/property_keys.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/services/share/share_models.dart';
import 'package:super_note/services/share/share_text.dart';

Item _item(
  ItemType type, {
  String? title = 'Τίτλος',
  String? icon,
  ItemPriority priority = ItemPriority.none,
  ItemStatus status = ItemStatus.active,
}) =>
    Item()
      ..workspaceId = 1
      ..type = type
      ..title = title
      ..icon = icon
      ..priority = priority
      ..status = status;

ItemProperty _p(String key, String? value,
        {PropertyType type = PropertyType.text}) =>
    ItemProperty()
      ..itemId = 1
      ..key = key
      ..value = value
      ..type = type;

ItemBlock _b(BlockType type, {String? text, bool checked = false}) => ItemBlock()
  ..itemId = 1
  ..type = type
  ..text = text
  ..checked = checked;

void main() {
  setUpAll(() async {
    // Το `AppDateUtils.formatShort` χρησιμοποιεί DateFormat('d MMM yyyy','el').
    await initializeDateFormatting();
  });

  group('note', () {
    test('τίτλος + headings/checklist/αρίθμηση/quote', () {
      final text = ShareText.forItem(
        _item(ItemType.note, title: 'Σημείωση'),
        blocks: [
          _b(BlockType.heading1, text: 'Επικεφαλίδα'),
          _b(BlockType.text, text: 'Πρώτη παράγραφος'),
          _b(BlockType.checklist, text: 'Αγορά', checked: true),
          _b(BlockType.numbered, text: 'ένα'),
          _b(BlockType.numbered, text: 'δύο'),
          _b(BlockType.quote, text: 'ρήση'),
        ],
      );

      expect(text, startsWith('**Σημείωση**\n'));
      expect(text, contains('# Επικεφαλίδα'));
      expect(text, contains('Πρώτη παράγραφος'));
      expect(text, contains('• ☑ Αγορά'));
      expect(text, contains('  1. ένα'));
      expect(text, contains('  2. δύο'));
      expect(text, contains('> ρήση'));
    });

    test('χωρίς τίτλο → «Χωρίς τίτλο»', () {
      final text = ShareText.forItem(_item(ItemType.note, title: null));
      expect(text, startsWith('**Χωρίς τίτλο**'));
    });

    test('truncation στο όριο maxTextChars', () {
      final text = ShareText.forItem(
        _item(ItemType.note, title: 'Μεγάλο'),
        blocks: [_b(BlockType.text, text: 'a' * (ShareLimits.maxTextChars + 500))],
      );
      expect(text.length, ShareLimits.maxTextChars);
      expect(text, endsWith('...'));
    });
  });

  group('task / checklist', () {
    test('προτεραιότητα, κατάσταση, προθεσμία, σημειώσεις, υποεργασίες', () {
      final due = DateTime(2026, 3, 14);
      final text = ShareText.forItem(
        _item(
          ItemType.task,
          title: 'Εργασία',
          priority: ItemPriority.high,
          status: ItemStatus.inProgress,
        ),
        properties: [
          _p(PropertyKeys.dueDate, due.toIso8601String(),
              type: PropertyType.date),
          _p(PropertyKeys.notes, 'Σημείωση εργασίας'),
        ],
        subtasks: [
          _item(ItemType.task, title: 'Υπο-1', status: ItemStatus.done),
          _item(ItemType.task, title: 'Υπο-2'),
        ],
      );

      expect(text, startsWith('**Εργασία**'));
      expect(text, contains('• 🔴 Προτεραιότητα: Υψηλή'));
      expect(text, contains('• 📌 Κατάσταση: Σε εξέλιξη'));
      expect(text, contains('• 📅 Προθεσμία: ${AppDateUtils.formatShort(due)}'));
      expect(text, contains('── Σημειώσεις ──'));
      expect(text, contains('Σημείωση εργασίας'));
      expect(text, contains('── Υποεργασίες ──'));
      expect(text, contains('  ✅ Υπο-1'));
      expect(text, contains('  ⬜ Υπο-2'));
    });

    test('χωρίς προτεραιότητα/προθεσμία → μόνο κατάσταση', () {
      final text = ShareText.forItem(_item(ItemType.task, title: 'Απλή'));
      expect(text, contains('• 📌 Κατάσταση: Ενεργό'));
      expect(text, isNot(contains('Προτεραιότητα')));
      expect(text, isNot(contains('Προθεσμία')));
      expect(text, isNot(contains('Υποεργασίες')));
    });

    test('checklist χρησιμοποιεί τον ίδιο formatter με task', () {
      final text = ShareText.forItem(
        _item(ItemType.checklist, title: 'Λίστα', status: ItemStatus.done),
      );
      expect(text, contains('• 📌 Κατάσταση: Ολοκληρωμένο'));
    });
  });

  group('appointment', () {
    test('ημερομηνία + ώρα + location + contact_* snapshot (D6/D7)', () {
      final date = DateTime(2026, 11, 5);
      final text = ShareText.forItem(
        _item(ItemType.appointment, title: 'Ραντεβού'),
        properties: [
          _p(PropertyKeys.date, date.toIso8601String(),
              type: PropertyType.date),
          _p(PropertyKeys.time, '10:30'),
          _p('location', 'Ιατρείο'),
          _p('contact_name', 'Γιάννης'),
          _p('contact_phone', '6900000000'),
          _p('contact_email', 'a@b.gr'),
          _p('contact_company', 'Εταιρεία'),
          _p('contact_website', 'https://x.gr'),
          _p('contact_address', 'Οδός 1'),
          _p('contact_notes', 'Σημείωση επαφής'),
          _p(PropertyKeys.notes, 'Γενικές σημειώσεις'),
        ],
      );

      expect(text,
          contains('• 📅 ${AppDateUtils.formatShort(date)} — 10:30'));
      expect(text, contains('• 📍 Ιατρείο'));
      expect(text, contains('👤 Επαφή: Γιάννης'));
      expect(text, contains('• 📞 6900000000'));
      expect(text, contains('• 📧 a@b.gr'));
      expect(text, contains('• 🏢 Εταιρεία'));
      expect(text, contains('• 🌐 https://x.gr'));
      expect(text, contains('• 📍 Οδός 1'));
      expect(text, contains('── Σημειώσεις επαφής ──'));
      expect(text, contains('── Σημειώσεις ──'));
    });

    test('μόνο ώρα (χωρίς ημερομηνία) → 🕒', () {
      final text = ShareText.forItem(
        _item(ItemType.appointment, title: 'Τηλέφωνο'),
        properties: [_p(PropertyKeys.time, '18:00')],
      );
      expect(text, contains('• 🕒 18:00'));
      expect(text, isNot(contains('• 📅')));
    });
  });

  group('event', () {
    test('μονήμερο → ημερομηνία + εύρος ώρας', () {
      final start = DateTime(2026, 3, 14, 9, 0);
      final end = DateTime(2026, 3, 14, 11, 0);
      final text = ShareText.forItem(
        _item(ItemType.event, title: 'Συνάντηση'),
        properties: [
          _p(PropertyKeys.startTime, start.toIso8601String()),
          _p(PropertyKeys.endTime, end.toIso8601String()),
          _p('location', 'Γραφείο'),
          _p(PropertyKeys.notes, 'Να φέρω laptop'),
        ],
      );

      expect(
        text,
        contains('• 📅 ${AppDateUtils.formatDateTime(start)} — '
            '${AppDateUtils.formatTime(end)}'),
      );
      expect(text, contains('• 📍 Γραφείο'));
      expect(text, contains('Να φέρω laptop'));
    });

    test('πολυήμερο (end_date) → εύρος ημερομηνιών', () {
      final start = DateTime(2026, 3, 14, 9, 0);
      final endDay = DateTime(2026, 3, 16);
      final text = ShareText.forItem(
        _item(ItemType.event, title: 'Ταξίδι'),
        properties: [
          _p(PropertyKeys.startTime, start.toIso8601String()),
          _p(PropertyKeys.endDate, endDay.toIso8601String()),
        ],
      );

      expect(
        text,
        contains('• 📅 ${AppDateUtils.formatDateTime(start)} — '
            '${AppDateUtils.formatShort(endDay)}'),
      );
    });
  });

  group('contact', () {
    test('phones λίστα + email/company/website/address/birthday/notes', () {
      final text = ShareText.forItem(
        _item(ItemType.contact, title: 'Μαρία'),
        properties: [
          _p('phones', '["6900000001","6900000002"]'),
          _p('email', 'maria@x.gr'),
          _p('company', 'Εταιρεία'),
          _p('website', 'https://maria.gr'),
          _p('address', 'Οδός 2'),
          _p('birthday', '1990-05-01'),
          _p('notes', 'Σημείωση επαφής'),
        ],
      );

      expect(text, startsWith('**Μαρία**'));
      expect(text, contains('• 📞 6900000001'));
      expect(text, contains('• 📞 6900000002'));
      expect(text, contains('• 📧 maria@x.gr'));
      expect(text, contains('• 🏢 Εταιρεία'));
      expect(text, contains('• 🌐 https://maria.gr'));
      expect(text, contains('• 📍 Οδός 2'));
      expect(
        text,
        contains('• 🎂 ${AppDateUtils.formatShort(DateTime(1990, 5, 1))}'),
      );
      expect(text, contains('── Σημειώσεις ──'));
    });

    test('χωρίς phones → fallback στο phone', () {
      final text = ShareText.forItem(
        _item(ItemType.contact, title: 'Πέτρος'),
        properties: [_p('phone', '6980000000')],
      );
      expect(text, contains('• 📞 6980000000'));
    });

    test('χωρίς τίτλο → «Χωρίς όνομα»', () {
      final text = ShareText.forItem(_item(ItemType.contact, title: null));
      expect(text, startsWith('**Χωρίς όνομα**'));
    });
  });

  group('journal (D3)', () {
    test('χωρίς icon → πρόθεμα 📔', () {
      final text = ShareText.forItem(
        _item(ItemType.journal, title: 'Ημέρα'),
        blocks: [_b(BlockType.text, text: 'Περιεχόμενο ημέρας')],
      );
      expect(text, startsWith('**📔 Ημέρα**'));
      expect(text, contains('Περιεχόμενο ημέρας'));
    });

    test('με icon → κρατά το icon', () {
      final text = ShareText.forItem(
        _item(ItemType.journal, title: 'Ημέρα', icon: '🌙'),
      );
      expect(text, startsWith('**🌙 Ημέρα**'));
    });
  });

  group('habit (D3)', () {
    test('icon + πρόγραμμα + στόχος', () {
      final text = ShareText.forItem(
        _item(ItemType.habit, title: 'Γυμναστική', icon: '🏃'),
        properties: [
          _p('goal_per_period', '3'),
          _p('unit', 'φορές'),
        ],
      );

      expect(text, startsWith('**🏃 Γυμναστική**'));
      expect(text, contains('• 🔁 '));
      expect(text, contains('• 🎯 Στόχος: 3 φορές'));
    });

    test('χωρίς icon → χωρίς emoji πρόθεμα', () {
      final text = ShareText.forItem(_item(ItemType.habit, title: 'Διάβασμα'));
      expect(text, startsWith('**Διάβασμα**'));
    });

    test('στόχος 0 ή δεκαδικό → μόνο ακέραιο μέρος / καμία γραμμή', () {
      final zero = ShareText.forItem(
        _item(ItemType.habit, title: 'Νερό'),
        properties: [_p('goal_per_period', '0')],
      );
      expect(zero, isNot(contains('🎯')));

      final decimal = ShareText.forItem(
        _item(ItemType.habit, title: 'Νερό'),
        properties: [_p('goal_per_period', '2.0')],
      );
      expect(decimal, contains('• 🎯 Στόχος: 2'));
    });
  });

  group('knowledge / collection entry (D5)', () {
    final fields = [
      const FieldDef(key: 'status', label: 'Κατάσταση', type: FieldType.text),
      const FieldDef(key: 'done', label: 'Διαθέσιμο', type: FieldType.toggle),
      const FieldDef(key: 'date', label: 'Ημ/νία', type: FieldType.date),
      const FieldDef(key: 'list', label: 'Λίστα', type: FieldType.bulletList),
      const FieldDef(key: 'steps', label: 'Βήματα', type: FieldType.numberedList),
      const FieldDef(key: 'files', label: 'Αρχεία', type: FieldType.attachment),
      const FieldDef(key: 'empty', label: 'Κενό', type: FieldType.text),
    ];

    test('συλλογή + render ανά τύπο field + skip κενών', () {
      final date = DateTime(2026, 1, 20);
      final text = ShareText.forItem(
        _item(ItemType.knowledge, title: 'Βιβλίο 1'),
        properties: [
          _p('status', 'Διαθέσιμο'),
          _p('done', 'true'),
          _p('date', date.toIso8601String(), type: PropertyType.date),
          _p('list', '["α","β"]'),
          _p('steps', '["α","β"]'),
          _p('files', '[1,2,3]'),
          _p('empty', ''),
        ],
        fields: fields,
        collectionName: 'Βιβλία',
      );

      expect(text, startsWith('**Βιβλίο 1**'));
      expect(text, contains('📁 Συλλογή: Βιβλία'));
      expect(text, contains('• Κατάσταση: Διαθέσιμο'));
      expect(text, contains('• Διαθέσιμο: ✅ Ναι'));
      expect(text, contains('• 📅 Ημ/νία: ${AppDateUtils.formatShort(date)}'));
      expect(text, contains('• Λίστα:'));
      expect(text, contains('  • α'));
      expect(text, contains('  • β'));
      expect(text, contains('• Βήματα:'));
      expect(text, contains('  1. α'));
      expect(text, contains('  2. β'));
      expect(text, contains('• 📎 Αρχεία: 3 συνημμένα'));
      expect(text, isNot(contains('Κενό')));
    });

    test('toggle false → ❌ Όχι', () {
      final text = ShareText.forItem(
        _item(ItemType.knowledge, title: 'Βιβλίο 2'),
        properties: [_p('done', 'false')],
        fields: fields,
      );
      expect(text, contains('• Διαθέσιμο: ❌ Όχι'));
      expect(text, isNot(contains('📁 Συλλογή')));
    });

    test('χωρίς τίτλο → «(χωρίς τίτλο)»', () {
      final text = ShareText.forItem(_item(ItemType.knowledge, title: null));
      expect(text, startsWith('**(χωρίς τίτλο)**'));
    });
  });

  group('generic (D4)', () {
    test('blocks + properties χωρίς technical keys', () {
      final text = ShareText.forItem(
        _item(ItemType.bookmark, title: 'Σελίδα'),
        blocks: [_b(BlockType.text, text: 'Περιεχόμενο')],
        properties: [
          _p('url', 'https://x.gr'),
          _p(PropertyKeys.spanColor, '#FF0000'),
          _p('empty', ''),
        ],
      );

      expect(text, startsWith('**Σελίδα**'));
      expect(text, contains('Περιεχόμενο'));
      expect(text, contains('── Στοιχεία ──'));
      expect(text, contains('• url: https://x.gr'));
      expect(text, isNot(contains('span_color')));
      expect(text, isNot(contains('#FF0000')));
      expect(text, isNot(contains('empty')));
    });
  });
}
