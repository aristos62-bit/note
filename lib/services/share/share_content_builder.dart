// lib/services/share/share_content_builder.dart
//
// E39 — Render: `ShareData` → `ShareBundle` (κείμενο + αρχεία με όρια D1).
// Καθαρή σύνθεση, χωρίς IO: ό,τι χρειάζεται έχει ήδη φορτωθεί/ελεγχθεί.

import '../../core/core.dart';
import 'share_attachments.dart';
import 'share_formatters.dart';
import 'share_loader.dart';
import 'share_models.dart';
import 'share_text.dart';

class ShareContentBuilder {
  ShareContentBuilder._();

  /// Φορτώνει και χτίζει σε ένα βήμα. `null` αν το item δεν βρέθηκε.
  static Future<ShareBundle?> loadAndBuild(int itemId) async {
    final data = await ShareLoader.load(itemId);
    if (data == null) return null;
    return build(data);
  }

  /// Χτίζει το bundle από ήδη φορτωμένα δεδομένα.
  static ShareBundle build(ShareData data) {
    final text = ShareText.forItem(
      data.item,
      blocks: data.blocks,
      properties: data.properties,
      subtasks: data.subtasks,
      fields: data.fields,
      collectionName: data.collectionName,
    );

    final picked = ShareAttachments.collect(data.attachments);

    return ShareBundle(
      item: data.item,
      text: text,
      files: picked.files,
      skippedFiles: picked.skipped,
    );
  }

  /// Προσφέρεται η επιλογή «Κείμενο + αρχεία»;
  /// Χρειάζεται αρχεία **και** πλατφόρμα που τα υποστηρίζει (Linux → όχι).
  static bool canOfferFiles(ShareBundle bundle) =>
      bundle.hasFiles && ShareAttachments.platformSupportsFiles;

  /// Τελικό κείμενο για το επιλεγμένο mode.
  ///
  /// Με αρχεία → προσθέτει τη λίστα 📎 (καθαρά ονόματα + μέγεθος, D9).
  /// Χωρίς αρχεία → το βασικό κείμενο, αναλλοίωτο.
  static String textForMode(ShareBundle bundle, ShareMode mode) {
    if (mode == ShareMode.textOnly) return bundle.text;

    final section = ShareFormatters.attachmentsSection(bundle.files);
    if (section.isEmpty) return bundle.text;

    final full = '${bundle.text}\n${section.join('\n')}';
    return full.length > ShareLimits.maxTextChars
        ? AppStringUtils.truncate(full, ShareLimits.maxTextChars)
        : full;
  }
}