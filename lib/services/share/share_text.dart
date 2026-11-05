// lib/services/share/share_text.dart
//
// E39 — Render (κείμενο): μορφοποίηση ανά τύπο item.
// Καθαρή συνάρτηση πάνω σε models (χωρίς DB/IO) → unit-testable.
//
// Μεταφέρει τα `share_service._format*` με τις εξής συνειδητές διορθώσεις:
//   • appointment: date/time + contact_* snapshot (D6/D7)
//   • task/checklist: γραμμή κατάστασης (D2)
//   • note: σωστή αρίθμηση numbered blocks (numberedIndexesFor)
//   • event: ενότητα Σημειώσεων
//   • habit: emoji πρόθεμα + πρόγραμμα + στόχος (D3)
//   • generic: dump για τύπους χωρίς ειδικό formatter (D4)

import 'dart:convert';

import '../../core/core.dart';
import '../../models/models.dart';
import 'share_models.dart';

class ShareText {
  ShareText._();

  static const String _noTitle = 'Χωρίς τίτλο';

  /// Ενιαίο σημείο εισόδου: πλήρες κείμενο κοινοποίησης για [item].
  static String forItem(
      Item item, {
        List<ItemBlock> blocks = const [],
        List<ItemProperty> properties = const [],
        List<Item> subtasks = const [],
        List<FieldDef> fields = const [],
        String? collectionName,
      }) {
    final lines = <String>[];
    switch (item.type) {
      case ItemType.note:
        lines.addAll(note(item, blocks));
      case ItemType.task:
      case ItemType.checklist:
        lines.addAll(task(item, properties, subtasks));
      case ItemType.appointment:
        lines.addAll(appointment(item, properties));
      case ItemType.contact:
        lines.addAll(contact(item, properties));
      case ItemType.event:
        lines.addAll(event(item, properties));
      case ItemType.journal:
        lines.addAll(journal(item, blocks));
      case ItemType.habit:
        lines.addAll(habit(item, properties));
      case ItemType.knowledge:
        lines.addAll(collectionEntry(item, properties, fields, collectionName));
      default:
        lines.addAll(generic(item, blocks, properties));
    }
    return _finish(lines);
  }

  // ─────────────────────────────────────────────────────────────
  // NOTE
  // ─────────────────────────────────────────────────────────────

  static List<String> note(Item item, List<ItemBlock> blocks) {
    final lines = <String>[..._boldTitle(item.title ?? _noTitle)];
    final numbered = numberedIndexesFor(blocks);
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      switch (block.type) {
        case BlockType.heading1:
          lines.add('# ${block.text ?? ''}');
        case BlockType.heading2:
          lines.add('## ${block.text ?? ''}');
        case BlockType.heading3:
          lines.add('### ${block.text ?? ''}');
        case BlockType.checklist:
          lines.add('• ${block.checked ? '☑' : '☐'} ${block.text ?? ''}');
        case BlockType.bulletList:
          lines.add('• ${block.text ?? ''}');
        case BlockType.numbered:
          lines.add('  ${numbered[i] + 1}. ${block.text ?? ''}');
        case BlockType.quote:
          lines.add('> ${block.text ?? ''}');
        case BlockType.code:
          lines.add('```\n${block.text ?? ''}\n```');
        case BlockType.divider:
          lines.add('── ──');
        default:
          final text = block.text;
          if (text != null && text.isNotEmpty) lines.add(text);
      }
    }
    return lines;
  }

  // ─────────────────────────────────────────────────────────────
  // TASK / CHECKLIST
  // ─────────────────────────────────────────────────────────────

  static List<String> task(
      Item item,
      List<ItemProperty> properties,
      List<Item> subtasks,
      ) {
    final lines = <String>[..._boldTitle(item.title ?? _noTitle)];

    if (item.priority != ItemPriority.none) {
      lines.add('• 🔴 Προτεραιότητα: ${_priorityLabel(item.priority)}');
    }

    // D2: κατάσταση μόνο για task/checklist (όχι tags).
    lines.add('• 📌 Κατάσταση: ${AppStringUtils.statusLabel(item.status.name)}');

    final dueDate = _date(properties, PropertyKeys.dueDate);
    if (dueDate != null) {
      lines.add('• 📅 Προθεσμία: ${AppDateUtils.formatShort(dueDate)}');
    }

    final notes = _text(properties, PropertyKeys.notes);
    if (notes != null) {
      lines.addAll(_section('Σημειώσεις'));
      lines.add(notes);
    }

    if (subtasks.isNotEmpty) {
      lines.addAll(_section('Υποεργασίες'));
      for (final st in subtasks) {
        final done = st.status == ItemStatus.done;
        lines.add('  ${done ? '✅' : '⬜'} ${st.title ?? ''}');
      }
    }

    return lines;
  }

  // ─────────────────────────────────────────────────────────────
  // APPOINTMENT (D6/D7: date + time + contact_* snapshot)
  // ─────────────────────────────────────────────────────────────

  static List<String> appointment(
      Item item,
      List<ItemProperty> properties,
      ) {
    final lines = <String>[..._boldTitle(item.title ?? _noTitle)];

    final date = _date(properties, PropertyKeys.date);
    final time = _text(properties, PropertyKeys.time);
    if (date != null) {
      final suffix = time != null ? ' — $time' : '';
      lines.add('• 📅 ${AppDateUtils.formatShort(date)}$suffix');
    } else if (time != null) {
      lines.add('• 🕒 $time');
    }

    final location = _text(properties, 'location');
    if (location != null) {
      lines.add('• 📍 $location');
    }

    final contactName = _text(properties, 'contact_name');
    if (contactName != null) {
      lines.add('');
      lines.add('👤 Επαφή: $contactName');
    }
    final phone = _text(properties, 'contact_phone');
    if (phone != null) lines.add('• 📞 $phone');
    final email = _text(properties, 'contact_email');
    if (email != null) lines.add('• 📧 $email');
    final company = _text(properties, 'contact_company');
    if (company != null) lines.add('• 🏢 $company');
    final website = _text(properties, 'contact_website');
    if (website != null) lines.add('• 🌐 $website');
    final address = _text(properties, 'contact_address');
    if (address != null) lines.add('• 📍 $address');

    final contactNotes = _text(properties, 'contact_notes');
    if (contactNotes != null) {
      lines.addAll(_section('Σημειώσεις επαφής'));
      lines.add(contactNotes);
    }

    final notes = _text(properties, PropertyKeys.notes);
    if (notes != null) {
      lines.addAll(_section('Σημειώσεις'));
      lines.add(notes);
    }

    return lines;
  }

  // ─────────────────────────────────────────────────────────────
  // EVENT
  // ─────────────────────────────────────────────────────────────

  static List<String> event(Item item, List<ItemProperty> properties) {
    final lines = <String>[..._boldTitle(item.title ?? _noTitle)];

    final startTime = _date(properties, PropertyKeys.startTime);
    final endTime = _date(properties, PropertyKeys.endTime);
    final endDate = _date(properties, PropertyKeys.endDate);
    if (startTime != null) {
      // E41: πολυήμερο → εύρος (το `end_time` μένει η ώρα της 1ης ημέρας).
      final endDay = endDate != null
          ? DateTime(endDate.year, endDate.month, endDate.day)
          : null;
      final startDay =
      DateTime(startTime.year, startTime.month, startTime.day);
      final multiDay = endDay != null && endDay.isAfter(startDay);
      final timeStr = multiDay
          ? '${AppDateUtils.formatDateTime(startTime)} — ${AppDateUtils.formatShort(endDay)}'
          : endTime != null
          ? '${AppDateUtils.formatDateTime(startTime)} — ${AppDateUtils.formatTime(endTime)}'
          : AppDateUtils.formatDateTime(startTime);
      lines.add('• 📅 $timeStr');
    }

    final location = _text(properties, 'location');
    if (location != null) {
      lines.add('• 📍 $location');
    }

    final notes = _text(properties, PropertyKeys.notes);
    if (notes != null) {
      lines.addAll(_section('Σημειώσεις'));
      lines.add(notes);
    }

    return lines;
  }

  // ─────────────────────────────────────────────────────────────
  // CONTACT
  // ─────────────────────────────────────────────────────────────

  static List<String> contact(Item item, List<ItemProperty> properties) {
    final lines = <String>[..._boldTitle(item.title ?? 'Χωρίς όνομα')];

    final cp = ContactProps.fromProperties(properties);
    for (final phone in cp.phones) {
      lines.add('• 📞 $phone');
    }
    if (cp.phones.isEmpty &&
        cp.phoneFallback != null &&
        cp.phoneFallback!.isNotEmpty) {
      lines.add('• 📞 ${cp.phoneFallback}');
    }

    final email = cp.email;
    if (email != null && email.isNotEmpty) lines.add('• 📧 $email');

    final company = cp.company;
    if (company != null && company.isNotEmpty) lines.add('• 🏢 $company');

    final website = cp.website;
    if (website != null && website.isNotEmpty) lines.add('• 🌐 $website');

    final address = cp.address;
    if (address != null && address.isNotEmpty) lines.add('• 📍 $address');

    final birthdayRaw = cp.birthday;
    final birthday =
    birthdayRaw != null ? DateTime.tryParse(birthdayRaw) : null;
    if (birthday != null) {
      lines.add('• 🎂 ${AppDateUtils.formatShort(birthday)}');
    }

    final notes = cp.notes;
    if (notes != null && notes.isNotEmpty) {
      lines.addAll(_section('Σημειώσεις'));
      lines.add(notes);
    }

    return lines;
  }

  // ─────────────────────────────────────────────────────────────
  // HABIT (D3: emoji πρόθεμα + πρόγραμμα + στόχος)
  // ─────────────────────────────────────────────────────────────

  static List<String> habit(Item item, List<ItemProperty> properties) {
    final title = item.title ?? _noTitle;
    final icon = item.icon;
    final lines = <String>[
      icon != null && icon.isNotEmpty ? '**$icon $title**' : '**$title**',
      '',
    ];

    final byKey = <String, String?>{
      for (final p in properties) p.key: p.value,
    };

    lines.add('• 🔁 ${Recurrence.fromProperties(byKey).describe()}');

    final goalRaw = byKey['goal_per_period'];
    final goal = goalRaw != null
        ? int.tryParse(goalRaw.split('.').first)
        : null;
    if (goal != null && goal > 0) {
      final unit = byKey['unit'];
      final suffix = (unit != null && unit.isNotEmpty) ? ' $unit' : '';
      lines.add('• 🎯 Στόχος: $goal$suffix');
    }

    return lines;
  }

  // ─────────────────────────────────────────────────────────────
  // JOURNAL (D3: emoji πρόθεμα — item.icon ή 📔)
  // ─────────────────────────────────────────────────────────────

  static List<String> journal(Item item, List<ItemBlock> blocks) {
    final title = item.title ?? _noTitle;
    final icon = (item.icon?.isNotEmpty ?? false) ? item.icon! : '📔';
    final lines = <String>[..._boldTitle('$icon $title')];
    for (final block in blocks) {
      final text = block.text;
      if (text != null && text.isNotEmpty) lines.add(text);
    }
    return lines;
  }

  // ─────────────────────────────────────────────────────────────
  // KNOWLEDGE / COLLECTION ENTRY (D5)
  // ─────────────────────────────────────────────────────────────

  static List<String> collectionEntry(
      Item item,
      List<ItemProperty> properties,
      List<FieldDef> fields,
      String? collectionName,
      ) {
    final lines = <String>[..._boldTitle(item.title ?? '(χωρίς τίτλο)')];

    if (collectionName != null && collectionName.isNotEmpty) {
      lines.add('📁 Συλλογή: $collectionName');
      lines.add('');
    }

    for (final f in fields) {
      if (f.key.isEmpty) continue;

      final prop = properties.where((p) => p.key == f.key).firstOrNull;
      final value = prop?.value;
      if (value == null || value.isEmpty) continue;

      switch (f.type) {
        case FieldType.toggle:
          lines.add(
              '• ${f.label}: ${value == 'true' ? '✅ Ναι' : '❌ Όχι'}');
        case FieldType.date:
          final dt = DateTime.tryParse(value);
          final dateStr =
          dt != null ? AppDateUtils.formatShort(dt) : value;
          lines.add('• 📅 ${f.label}: $dateStr');
        case FieldType.bulletList:
          lines.add('• ${f.label}:');
          try {
            final list = jsonDecode(value) as List;
            for (final e in list) {
              lines.add('  • $e');
            }
          } catch (_) {
            lines.add('  $value');
          }
        case FieldType.numberedList:
          lines.add('• ${f.label}:');
          try {
            final list = jsonDecode(value) as List;
            for (var i = 0; i < list.length; i++) {
              lines.add('  ${i + 1}. ${list[i]}');
            }
          } catch (_) {
            lines.add('  $value');
          }
        case FieldType.attachment:
          try {
            final ids = jsonDecode(value) as List;
            if (ids.isNotEmpty) {
              lines.add(
                  '• 📎 ${f.label}: ${AppStringUtils.attachmentsCountLabel(ids.length)}');
            }
          } catch (_) {
            // άκυρο JSON → σιωπή (όπως πριν)
          }
        default:
          lines.add('• ${f.label}: $value');
      }
    }

    return lines;
  }

  // ─────────────────────────────────────────────────────────────
  // GENERIC (D4)
  // ─────────────────────────────────────────────────────────────

  static List<String> generic(
      Item item,
      List<ItemBlock> blocks,
      List<ItemProperty> properties,
      ) {
    final lines = <String>[..._boldTitle(item.title ?? _noTitle)];

    for (final block in blocks) {
      final text = block.text;
      if (text != null && text.isNotEmpty) lines.add(text);
    }

    final extra = properties
        .where((p) => !PropertyKeys.technical.contains(p.key))
        .where((p) => p.value != null && p.value!.isNotEmpty)
        .toList();
    if (extra.isNotEmpty) {
      lines.addAll(_section('Στοιχεία'));
      for (final p in extra) {
        lines.add('• ${p.key}: ${p.value}');
      }
    }

    return lines;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  static List<String> _boldTitle(String title) => ['**$title**', ''];

  static List<String> _section(String label) => ['', '── $label ──', ''];

  static String? _text(List<ItemProperty> props, String key) {
    final value = props.where((p) => p.key == key).firstOrNull?.value;
    return (value == null || value.isEmpty) ? null : value;
  }

  static DateTime? _date(List<ItemProperty> props, String key) =>
      props.where((p) => p.key == key).firstOrNull?.dateValue;

  static String _priorityLabel(ItemPriority p) {
    if (p == ItemPriority.none) return '';
    return AppStringUtils.priorityLabel(p.name);
  }

  static String _finish(List<String> lines) {
    final text = lines.join('\n');
    return text.length > ShareLimits.maxTextChars
        ? AppStringUtils.truncate(text, ShareLimits.maxTextChars)
        : text;
  }
}