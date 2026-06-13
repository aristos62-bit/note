// lib/services/share_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/core.dart';
import '../helpers/super_note_helper.dart';
import '../models/models.dart';

class ShareService {
  ShareService._();

  static Future<void> shareItem(BuildContext context, int itemId) async {
    try {
      final helper = SuperNoteHelper.instance;
      final item = await helper.items.getById(itemId);
      if (item == null) return;

      List<XFile> shareFiles = [];
      String text;

      if (item.type == ItemType.knowledge) {
        final result = await _buildKnowledgeShare(helper, item);
        text = result.text;
        shareFiles = result.files;
      } else {
        final results = await Future.wait([
          helper.blocks.getByItem(itemId),
          helper.properties.getAll(itemId),
        ]);
        final blocks = results[0] as List<ItemBlock>;
        final properties = results[1] as List<ItemProperty>;

        List<Item> subtasks = [];
        if (item.type == ItemType.task) {
          final allTasks = await helper.items.getByWorkspace(
            item.workspaceId,
            type: ItemType.task,
          );
          for (final t in allTasks) {
            final props = await helper.properties.getAll(t.id);
            final pid = props
                .where((p) => p.key == 'parent_id')
                .firstOrNull
                ?.value;
            if (pid != null && int.tryParse(pid) == itemId) {
              subtasks.add(t);
            }
          }
          subtasks.sort((a, b) => a.id.compareTo(b.id));
        }

        text = _format(item, blocks, properties, subtasks);
      }

      DebugConfig.print('📤 Share itemId=$itemId type=${item.type.name} files=${shareFiles.length}');
      await SharePlus.instance.share(ShareParams(
        text: text,
        subject: item.title ?? '',
        files: shareFiles.isNotEmpty ? shareFiles : null,
      ));
    } catch (e, stack) {
      DebugConfig.error('ShareService.shareItem', e, stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Αποτυχία κοινοποίησης: $e')),
        );
      }
    }
  }

  static String _format(
    Item item,
    List<ItemBlock> blocks,
    List<ItemProperty> properties,
    List<Item> subtasks,
  ) {
    final lines = <String>[];

    switch (item.type) {
      case ItemType.note:
        lines.addAll(_formatNote(item, blocks));
      case ItemType.task:
        lines.addAll(_formatTask(item, properties, subtasks));
      case ItemType.appointment:
        lines.addAll(_formatAppointment(item, properties));
      case ItemType.contact:
        lines.addAll(_formatContact(item, properties));
      case ItemType.event:
        lines.addAll(_formatEvent(item, properties));
      case ItemType.journal:
        lines.addAll(_formatJournal(item, blocks));
      case ItemType.habit:
        lines.addAll(_formatHabit(item));
      case ItemType.knowledge:
        lines.addAll(_boldTitle(item.title ?? ''));
      default:
        lines.addAll(_boldTitle(item.title ?? ''));
    }

    return lines.join('\n');
  }

  static List<String> _boldTitle(String title) => ['**$title**', ''];

  static List<String> _section(String label) => ['', '── $label ──', ''];

  static List<String> _formatNote(Item item, List<ItemBlock> blocks) {
    final lines = <String>[..._boldTitle(item.title ?? 'Χωρίς τίτλο')];
    for (final block in blocks) {
      switch (block.type) {
        case BlockType.heading1:
          lines.add('# ${block.text}');
        case BlockType.heading2:
          lines.add('## ${block.text}');
        case BlockType.heading3:
          lines.add('### ${block.text}');
        case BlockType.checklist:
          lines.add('• ${block.checked ? '☑' : '☐'} ${block.text ?? ''}');
        case BlockType.bulletList:
          lines.add('• ${block.text ?? ''}');
        case BlockType.numbered:
          lines.add('  ${lines.length}. ${block.text ?? ''}');
        case BlockType.quote:
          lines.add('> ${block.text ?? ''}');
        case BlockType.code:
          lines.add('```\n${block.text ?? ''}\n```');
        case BlockType.divider:
          lines.add('── ──');
        default:
          if (block.text != null && block.text!.isNotEmpty) {
            lines.add(block.text!);
          }
      }
    }
    return lines;
  }

  static List<String> _formatTask(
    Item item,
    List<ItemProperty> properties,
    List<Item> subtasks,
  ) {
    final lines = <String>[..._boldTitle(item.title ?? 'Χωρίς τίτλο')];

    if (item.priority != ItemPriority.none) {
      lines.add('• 🔴 Προτεραιότητα: ${_priorityLabel(item.priority)}');
    }

    final dueDate =
        properties.where((p) => p.key == 'due_date').firstOrNull?.dateValue;
    if (dueDate != null) {
      lines.add('• 📅 Προθεσμία: ${AppDateUtils.formatShort(dueDate)}');
    }

    final notes =
        properties.where((p) => p.key == 'notes').firstOrNull?.value;
    if (notes != null && notes.isNotEmpty) {
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

  static List<String> _formatAppointment(
    Item item,
    List<ItemProperty> properties,
  ) {
    final lines = <String>[..._boldTitle(item.title ?? 'Χωρίς τίτλο')];

    final startTime =
        properties.where((p) => p.key == 'start_time').firstOrNull?.dateValue;
    final endTime =
        properties.where((p) => p.key == 'end_time').firstOrNull?.dateValue;
    if (startTime != null) {
      final timeStr = endTime != null
          ? '${AppDateUtils.formatDateTime(startTime)} — ${AppDateUtils.formatTime(endTime)}'
          : AppDateUtils.formatDateTime(startTime);
      lines.add('• 📅 $timeStr');
    }

    final location =
        properties.where((p) => p.key == 'location').firstOrNull?.value;
    if (location != null && location.isNotEmpty) {
      lines.add('• 📍 $location');
    }

    final notes =
        properties.where((p) => p.key == 'notes').firstOrNull?.value;
    if (notes != null && notes.isNotEmpty) {
      lines.addAll(_section('Σημειώσεις'));
      lines.add(notes);
    }

    return lines;
  }

  static List<String> _formatContact(
    Item item,
    List<ItemProperty> properties,
  ) {
    final lines = <String>[..._boldTitle(item.title ?? 'Χωρίς όνομα')];

    final phones =
        properties.where((p) => p.key == 'phones').firstOrNull?.value;
    if (phones != null) {
      try {
        final list = jsonDecode(phones) as List;
        for (final p in list) {
          lines.add('• 📞 ${p['number'] ?? p}');
        }
      } catch (_) {
        lines.add('• 📞 $phones');
      }
    }

    final email =
        properties.where((p) => p.key == 'email').firstOrNull?.value;
    if (email != null && email.isNotEmpty) {
      lines.add('• 📧 $email');
    }

    final company =
        properties.where((p) => p.key == 'company').firstOrNull?.value;
    if (company != null && company.isNotEmpty) {
      lines.add('• 🏢 $company');
    }

    final website =
        properties.where((p) => p.key == 'website').firstOrNull?.value;
    if (website != null && website.isNotEmpty) {
      lines.add('• 🌐 $website');
    }

    final address =
        properties.where((p) => p.key == 'address').firstOrNull?.value;
    if (address != null && address.isNotEmpty) {
      lines.add('• 📍 $address');
    }

    final birthday =
        properties.where((p) => p.key == 'birthday').firstOrNull?.dateValue;
    if (birthday != null) {
      lines.add('• 🎂 ${AppDateUtils.formatShort(birthday)}');
    }

    final notes =
        properties.where((p) => p.key == 'notes').firstOrNull?.value;
    if (notes != null && notes.isNotEmpty) {
      lines.addAll(_section('Σημειώσεις'));
      lines.add(notes);
    }

    return lines;
  }

  static List<String> _formatEvent(
    Item item,
    List<ItemProperty> properties,
  ) {
    final lines = <String>[..._boldTitle(item.title ?? 'Χωρίς τίτλο')];

    final startTime =
        properties.where((p) => p.key == 'start_time').firstOrNull?.dateValue;
    final endTime =
        properties.where((p) => p.key == 'end_time').firstOrNull?.dateValue;
    if (startTime != null) {
      final timeStr = endTime != null
          ? '${AppDateUtils.formatDateTime(startTime)} — ${AppDateUtils.formatTime(endTime)}'
          : AppDateUtils.formatDateTime(startTime);
      lines.add('• 📅 $timeStr');
    }

    final location =
        properties.where((p) => p.key == 'location').firstOrNull?.value;
    if (location != null && location.isNotEmpty) {
      lines.add('• 📍 $location');
    }

    return lines;
  }

  static List<String> _formatJournal(Item item, List<ItemBlock> blocks) {
    final lines = <String>[..._boldTitle(item.title ?? 'Χωρίς τίτλο')];
    for (final block in blocks) {
      if (block.text != null && block.text!.isNotEmpty) {
        lines.add(block.text!);
      }
    }
    return lines;
  }

  static List<String> _formatHabit(Item item) {
    final lines = <String>[..._boldTitle(item.title ?? 'Χωρίς τίτλο')];
    final itemIcon = item.icon;
    if (itemIcon != null && itemIcon.isNotEmpty) {
      lines.add('$itemIcon **${item.title}**');
    }
    return lines;
  }

  /// Προετοιμασία knowledge item για share: φόρτωση schema, fields, attachments.
  static Future<({String text, List<XFile> files})> _buildKnowledgeShare(
    SuperNoteHelper helper,
    Item item,
  ) async {
    final properties = await helper.properties.getAll(item.id);

    // Βρες collection_id
    final collectionIdProp =
        properties.where((p) => p.key == 'collection_id').firstOrNull;
    DebugConfig.print(
        '📤 _buildKnowledgeShare itemId=${item.id} collectionId=${collectionIdProp?.value}');

    if (collectionIdProp?.value == null) {
      return (text: _boldTitle(item.title ?? '').join('\n'), files: <XFile>[]);
    }

    final collectionId = int.tryParse(collectionIdProp!.value!);
    if (collectionId == null) {
      return (text: _boldTitle(item.title ?? '').join('\n'), files: <XFile>[]);
    }

    // Φόρτωσε schema από το parent collection
    final schemaProp = await helper.properties.get(collectionId, 'schema');
    DebugConfig.print('📤 Schema loaded=${schemaProp?.value != null}');

    if (schemaProp?.value == null || schemaProp!.value!.isEmpty) {
      return (text: _boldTitle(item.title ?? '').join('\n'), files: <XFile>[]);
    }

    List<Map<String, dynamic>> fields;
    try {
      final raw = jsonDecode(schemaProp.value!) as List;
      fields = raw.cast<Map<String, dynamic>>();
    } catch (e) {
      DebugConfig.error('📤 Schema parse failed', e);
      return (text: _boldTitle(item.title ?? '').join('\n'), files: <XFile>[]);
    }

    DebugConfig.print('📤 Fields parsed count=${fields.length}');

    // Συλλογή attachment files
    final shareFiles = <XFile>[];
    for (final f in fields) {
      if (f['type'] != 'attachment') continue;
      final key = f['key'] as String? ?? '';
      if (key.isEmpty) continue;

      final prop = properties.where((p) => p.key == key).firstOrNull;
      if (prop?.value == null || prop!.value!.isEmpty) continue;

      try {
        final ids = jsonDecode(prop.value!) as List;
        DebugConfig.print('📤 Attachment field "$key" ids=${ids.length}');
        for (final id in ids) {
          final attachment = await helper.attachments.getById(id as int);
          if (attachment != null) {
            DebugConfig.print(
                '📤  + file id=${attachment.id} "${attachment.fileName}" path="${attachment.localPath}"');
            shareFiles.add(XFile(
              attachment.localPath,
              mimeType: attachment.mimeType,
              name: attachment.fileName,
            ));
          }
        }
      } catch (e) {
        DebugConfig.print('📤  ⚠️ attachment parse error: $e');
      }
    }

    final text = _formatCollectionEntry(item, properties, fields);
    return (text: text, files: shareFiles);
  }

  /// Μορφοποίηση collection entry fields σε plain text.
  static String _formatCollectionEntry(
    Item item,
    List<ItemProperty> properties,
    List<Map<String, dynamic>> fields,
  ) {
    final lines = <String>[..._boldTitle(item.title ?? '(χωρίς τίτλο)')];

    for (final f in fields) {
      final key = f['key'] as String? ?? '';
      final label = f['label'] as String? ?? '';
      final typeName = f['type'] as String? ?? 'text';
      if (key.isEmpty) continue;

      final prop = properties.where((p) => p.key == key).firstOrNull;
      if (prop?.value == null || prop!.value!.isEmpty) continue;

      switch (typeName) {
        case 'toggle':
          lines.add('• $label: ${prop.value == 'true' ? '✅ Ναι' : '❌ Όχι'}');
        case 'date':
          final dt = DateTime.tryParse(prop.value!);
          final dateStr =
              dt != null ? AppDateUtils.formatShort(dt) : prop.value!;
          lines.add('• 📅 $label: $dateStr');
        case 'bulletList':
          lines.add('• $label:');
          try {
            final list = jsonDecode(prop.value!) as List;
            for (final item in list) {
              lines.add('  • $item');
            }
          } catch (_) {
            lines.add('  ${prop.value}');
          }
        case 'numberedList':
          lines.add('• $label:');
          try {
            final list = jsonDecode(prop.value!) as List;
            for (var i = 0; i < list.length; i++) {
              lines.add('  ${i + 1}. ${list[i]}');
            }
          } catch (_) {
            lines.add('  ${prop.value}');
          }
        case 'attachment':
          try {
            final ids = jsonDecode(prop.value!) as List;
            if (ids.isNotEmpty) {
              lines.add(
                  '• 📎 $label: ${ids.length == 1 ? '1 συνημμένο' : '${ids.length} συνημμένα'}');
            }
          } catch (_) {}
        default:
          lines.add('• $label: ${prop.value}');
      }
    }

    return lines.join('\n');
  }

  static String _priorityLabel(ItemPriority p) {
    switch (p) {
      case ItemPriority.urgent:
        return 'Επείγον';
      case ItemPriority.high:
        return 'Υψηλή';
      case ItemPriority.medium:
        return 'Μεσαία';
      case ItemPriority.low:
        return 'Χαμηλή';
      default:
        return '';
    }
  }
}
