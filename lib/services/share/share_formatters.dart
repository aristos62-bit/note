// lib/services/share/share_formatters.dart
//
// E39 — μικρά, καθαρά format helpers για το share pipeline.
// Καμία εξάρτηση από DB/Flutter widgets → unit-testable.

import '../../core/core.dart';
import 'share_models.dart';

class ShareFormatters {
  ShareFormatters._();

  /// Ανθρώπινο μέγεθος αρχείου — **ίδια μορφή** με το
  /// `Attachment.readableSize` (B / KB / MB / GB, 1 δεκαδικό).
  static String humanSize(int bytes) {
    if (bytes <= 0) return '0B';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  /// Καθαρό όνομα για εμφάνιση στο κείμενο.
  ///
  /// Προτεραιότητα: [fileName] (όπως το έδωσε ο χρήστης) → basename του
  /// [path] → `'αρχείο'`. Το OS θα δείξει το basename του path (D9), γι' αυτό
  /// το κείμενο κρατά το «καθαρό» όνομα.
  static String displayName({
    required String fileName,
    required String path,
  }) {
    final clean = fileName.trim();
    if (clean.isNotEmpty) return clean;

    final parts = path.split(RegExp(r'[\\/]'));
    final base = parts.isEmpty ? '' : parts.last;
    if (base.isEmpty) return 'αρχείο';
    return base;
  }

  /// Ενότητα «📎 Συνημμένα» για το τέλος του κειμένου.
  /// Κενή λίστα → κενή ενότητα (καμία κενή γραμμή).
  static List<String> attachmentsSection(List<ShareFile> files) {
    if (files.isEmpty) return const [];

    final lines = <String>[
      '',
      '📎 Συνημμένα: ${AppStringUtils.attachmentsCountLabel(files.length)}',
    ];
    for (final file in files) {
      final size = file.sizeBytes > 0 ? ' (${humanSize(file.sizeBytes)})' : '';
      lines.add('  • ${file.displayName}$size');
    }
    return lines;
  }
}