// lib/core/utils/string_utils.dart
//
// String utilities για SuperNote.
//
// ΧΡΗΣΗ:
//   AppStringUtils.truncate(note.title, 50)
//   AppStringUtils.initials('Βαγγέλης Παπ.')  // "ΒΠ"
//   AppStringUtils.highlight(text, query)       // για search results
//   AppStringUtils.formatCurrency(1250.5)       // "1.250,50 €"
//
import 'package:flutter/material.dart';

class AppStringUtils {

  // ─────────────────────────────────────────────────────────────
  // TRUNCATE
  // ─────────────────────────────────────────────────────────────

  static String truncate(String? text, int maxLength, {String ellipsis = '...'}) {
    if (text == null || text.isEmpty || maxLength <= 0) return '';
    if (text.length <= maxLength) return text;
    if (maxLength <= ellipsis.length) {
      // Δώσε μόνο ellipsis αν δεν χωράει τίποτα άλλο
      return ellipsis.substring(0, maxLength);
    }
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }


  /// Κόβει σε λέξη (δεν κόβει στη μέση λέξης)
  static String truncateWords(String? text, int maxWords) {
    if (text == null || text.isEmpty) return '';
    final words = text.split(' ');
    if (words.length <= maxWords) return text;
    return '${words.take(maxWords).join(' ')}...';
  }

  // ─────────────────────────────────────────────────────────────
  // INITIALS — για avatars contacts
  // ─────────────────────────────────────────────────────────────

  static String initials(String? name, {int maxChars = 2}) {
    if (name == null || name.trim().isEmpty) return '?';

    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      final w = words[0];
      final end = maxChars.clamp(1, w.length);
      return w.substring(0, end).toUpperCase();
    }
    return words
        .take(maxChars)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH HIGHLIGHT — για search results
  // Επιστρέφει TextSpans με highlighted κείμενο
  // ─────────────────────────────────────────────────────────────

  static List<TextSpan> highlight(
      String text,
      String query, {
        TextStyle? normalStyle,
        TextStyle? highlightStyle,
      }) {
    if (text.isEmpty || query.trim().isEmpty) {
      return [TextSpan(text: text, style: normalStyle)];
    }

    final spans = <TextSpan>[];
    final lowerText  = text.toLowerCase();
    final trimmedQuery = query.trim();
    final lowerQuery = trimmedQuery.toLowerCase();

    int start = 0;
    int idx = lowerText.indexOf(lowerQuery);

    while (idx != -1) {
      if (idx > start) {
        spans.add(TextSpan(
          text: text.substring(start, idx),
          style: normalStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + trimmedQuery.length),
        style: highlightStyle ?? const TextStyle(
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0x336750A4),
        ),
      ));
      start = idx + trimmedQuery.length;
      idx = lowerText.indexOf(lowerQuery, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: normalStyle));
    }

    return spans;
  }


  // ─────────────────────────────────────────────────────────────
  // CURRENCY — για finance feature
  // ─────────────────────────────────────────────────────────────

  static String formatCurrency(double amount, {String symbol = '€', int decimals = 2}) {
    final isNegative = amount < 0;
    final abs = amount.abs();
    final parts = abs.toStringAsFixed(decimals).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';

    // Χιλιαδιαία διαχωριστικά
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
    }

    final formatted = decimals > 0
        ? '${buffer.toString()},$decPart $symbol'
        : '${buffer.toString()} $symbol';

    return isNegative ? '-$formatted' : formatted;
  }

  // ─────────────────────────────────────────────────────────────
  // ITEM TYPE LABEL — για labels/badges
  // ─────────────────────────────────────────────────────────────

  static String itemTypeLabel(String type) {
    switch (type) {
      case 'note':      return 'Σημείωση';
      case 'task':      return 'Εργασία';
      case 'event':     return 'Συμβάν';
      case 'contact':   return 'Επαφή';
      case 'habit':     return 'Συνήθεια';
      case 'project':   return 'Έργο';
      case 'goal':      return 'Στόχος';
      case 'finance':   return 'Οικονομικά';
      case 'bookmark':  return 'Σελιδοδείκτης';
      case 'journal':   return 'Ημερολόγιο';
      case 'checklist': return 'Λίστα';
      case 'knowledge': return 'Γνώση';
      default:          return type;
    }
  }

  static String priorityLabel(String priority) {
    switch (priority) {
      case 'none':   return 'Καμία';
      case 'low':    return 'Χαμηλή';
      case 'medium': return 'Μέτρια';
      case 'high':   return 'Υψηλή';
      case 'urgent': return 'Επείγον';
      default:       return priority;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'active':    return 'Ενεργό';
      case 'completed': return 'Ολοκληρωμένο';
      case 'cancelled': return 'Ακυρωμένο';
      case 'archived':  return 'Αρχειοθετημένο';
      default:          return status;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // MISC HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Πρώτο γράμμα κεφαλαίο
  static String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  /// Αφαίρεσε extra whitespace
  static String clean(String? text) =>
      text?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

  /// Είναι URL;
  static bool isUrl(String text) {
    final uri = Uri.tryParse(text.trim());
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  /// Είναι email;
  static bool isEmail(String text) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text.trim());

  /// Είναι τηλέφωνο;
  static bool isPhone(String text) =>
      RegExp(r'^[+\d\s\-()]{7,}$').hasMatch(text);

  /// Word count (για journal/notes)
  static int wordCount(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Εμφάνιση word count
  static String wordCountLabel(String? text) {
    final count = wordCount(text);
    if (count == 1) return '1 λέξη';
    return '$count λέξεις';
  }
}

// ────────────────────────────────────────────────────────────────
// EXTENSIONS
// ────────────────────────────────────────────────────────────────

extension StringX on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  bool get isNotNullOrEmpty => this != null && this!.isNotEmpty;

  String get orEmpty => this ?? '';
  String orDefault(String def) => isNullOrEmpty ? def : this!;

  String truncate(int max) => AppStringUtils.truncate(this, max);
  String get capitalize => AppStringUtils.capitalize(this);
  String get initials => AppStringUtils.initials(this);
  int get wordCount => AppStringUtils.wordCount(this);

  bool get isUrl => this != null && AppStringUtils.isUrl(this!);
  bool get isEmail => this != null && AppStringUtils.isEmail(this!);
  bool get isPhone => this != null && AppStringUtils.isPhone(this!);
}
