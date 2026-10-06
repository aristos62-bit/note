// lib/features/collections/collection_fields.dart
//
// Schema συλλογών: FieldType + FieldDef (extract από collections_screen — Φ4b-22).
// Byte-identical μεταφορά, χρησιμοποιείται από entries/detail/open-entry.
//
import 'dart:convert';
import 'package:flutter/material.dart';

// ── Field types ───────────────────────────────────────────────
enum FieldType {
  text,
  number,
  date,
  select,
  toggle,
  url,
  bulletList,
  numberedList,
  attachment
}

class FieldDef {
  final String key;
  final String label;
  final FieldType type;
  final List<String> options;
  final List<String> allowedExtensions;
  final int maxFiles;

  static const List<String> imagesExt = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
  ];
  static const List<String> documentsExt = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'rtf', 'odt',
  ];

  const FieldDef({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
    this.allowedExtensions = const [],
    this.maxFiles = 0,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.name,
    'options': options,
    if (allowedExtensions.isNotEmpty)
      'allowedExtensions': allowedExtensions,
    if (maxFiles > 0)
      'maxFiles': maxFiles,
  };

  factory FieldDef.fromJson(Map<String, dynamic> j) => FieldDef(
    key: j['key'] as String,
    label: j['label'] as String,
    type: FieldType.values.firstWhere(
          (t) => t.name == j['type'],
      orElse: () => FieldType.text,
    ),
    options: (j['options'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        [],
    allowedExtensions: (j['allowedExtensions'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        [],
    maxFiles: (j['maxFiles'] as int?) ?? 0,
  );

  static List<FieldDef> listFromJson(String json) {
    if (json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => FieldDef.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<FieldDef> fields) =>
      jsonEncode(fields.map((f) => f.toJson()).toList());

  IconData get icon => switch (type) {
    FieldType.text => Icons.text_fields_rounded,
    FieldType.number => Icons.numbers_rounded,
    FieldType.date => Icons.calendar_today_rounded,
    FieldType.select => Icons.list_rounded,
    FieldType.toggle => Icons.toggle_on_rounded,
    FieldType.url => Icons.link_rounded,
    FieldType.bulletList => Icons.format_list_bulleted_rounded,
    FieldType.numberedList => Icons.format_list_numbered_rounded,
    FieldType.attachment => Icons.attach_file_rounded,
  };

  String get typeName => switch (type) {
    FieldType.text => 'Κείμενο',
    FieldType.number => 'Αριθμός',
    FieldType.date => 'Ημερομηνία',
    FieldType.select => 'Επιλογή',
    FieldType.toggle => 'Ναι/Όχι',
    FieldType.url => 'URL',
    FieldType.bulletList => 'Λίστα (κουκκίδες)',
    FieldType.numberedList => 'Λίστα (αρίθμηση)',
    FieldType.attachment => 'Συνημμένο',
  };
}
