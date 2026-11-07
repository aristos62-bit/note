// lib/services/share/share_attachments.dart
//
// E39 — Collect: από τα `Attachment` rows στα `ShareFile` που θα σταλούν.
// Εφαρμόζει τα όρια D1 (πλήθος / συνολικό μέγεθος) και φιλτράρει αρχεία που
// δεν υπάρχουν πλέον στο δίσκο. Καμία εγγραφή, κανένα αντίγραφο (D9).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart' show XFile;

import '../../core/core.dart';
import '../../models/attachment.dart';
import 'share_formatters.dart';
import 'share_models.dart';

class ShareAttachments {
  ShareAttachments._();

  /// Η πλατφόρμα υποστηρίζει κοινοποίηση αρχείων;
  ///
  /// Linux → **όχι** (το plugin πετά `UnimplementedError`). Τα παλιά Windows
  /// (pre-RS5) δεν ανιχνεύονται εδώ — πιάνονται στο runtime fallback του
  /// orchestrator (`UnimplementedError` → retry text-only).
  static bool get platformSupportsFiles =>
      defaultTargetPlatform != TargetPlatform.linux;

  /// Φιλτράρισμα + όρια D1.
  ///
  /// Επιστρέφει τα αρχεία που θα σταλούν (με σειρά φόρτωσης) και πόσα
  /// κόπηκαν (λείπουν από το δίσκο / πλήθος / συνολικό μέγεθος).
  static ({List<ShareFile> files, int skipped}) collect(
      List<Attachment> attachments, {
        int maxFiles = ShareLimits.maxFiles,
        int maxTotalBytes = ShareLimits.maxTotalBytes,
      }) {
    final files = <ShareFile>[];
    var skipped = 0;
    var totalBytes = 0;

    for (final attachment in attachments) {
      if (files.length >= maxFiles) {
        skipped++;
        continue;
      }

      final path = AttachmentPathGuard.resolve(attachment.localPath);
      if (path == null) {
        skipped++;
        DebugConfig.warning(
            'ShareAttachments: outside attachments root id=${attachment.id}');
        continue;
      }
      if (!_exists(path)) {
        skipped++;
        DebugConfig.warning(
            'ShareAttachments: missing file id=${attachment.id}');
        continue;
      }

      final size = attachment.fileSize > 0
          ? attachment.fileSize
          : _safeLength(path);

      if (size > 0 && totalBytes + size > maxTotalBytes) {
        skipped++;
        continue;
      }

      files.add(ShareFile(
        path: path,
        displayName: ShareFormatters.displayName(
          fileName: attachment.fileName,
          path: path,
        ),
        mimeType: attachment.mimeType,
        sizeBytes: size,
      ));
      totalBytes += size;
    }

    return (files: files, skipped: skipped);
  }

  /// `ShareFile` → `XFile` για το `ShareParams.files`.
  ///
  /// Δεν περνάμε `name`: σε path-backed αρχεία το `share_plus` το αγνοεί (D9).
  /// Κενό mime → `null`, ώστε το plugin να κάνει `lookupMimeType(path)`.
  static List<XFile> toXFiles(List<ShareFile> files) => [
    for (final file in files)
      XFile(
        file.path,
        mimeType: (file.mimeType == null || file.mimeType!.isEmpty)
            ? null
            : file.mimeType,
      ),
  ];

  static bool _exists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  static int _safeLength(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }
}