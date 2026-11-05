// lib/services/share/share_options_sheet.dart
//
// E39 — Choose: «Κείμενο + αρχεία» ή «Μόνο κείμενο», **πριν** το render.
// Το pop γίνεται με sheetCtx (Type B του SafeSheet) — ποτέ blind pop.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../shared/widgets/safe_sheet.dart';
import 'share_content_builder.dart';
import 'share_formatters.dart';
import 'share_models.dart';

class ShareOptionsSheet extends StatelessWidget {
  const ShareOptionsSheet({
    super.key,
    required this.bundle,
    required this.onSelect,
  });

  final ShareBundle bundle;

  /// Καλείται με την επιλογή· το pop το κάνει ο caller (`show`).
  final ValueChanged<ShareMode> onSelect;

  /// Ανοίγει το sheet. `null` = ο χρήστης το έκλεισε (καμία κοινοποίηση).
  static Future<ShareMode?> show(BuildContext context, ShareBundle bundle) {
    return showSafeSheet<ShareMode>(
      context,
      builder: (sheetCtx) => ShareOptionsSheet(
        bundle: bundle,
        onSelect: (mode) => Navigator.pop(sheetCtx, mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canOfferFiles = ShareContentBuilder.canOfferFiles(bundle);
    final skipped = bundle.skippedFiles;

    return SafeSheet(
      title: 'Κοινοποίηση',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.xs),
            child: Text(
              bundle.item.title ?? 'Χωρίς τίτλο',
              style: context.titleMd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(),
          if (canOfferFiles)
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Κείμενο + αρχεία'),
              subtitle: Text(
                _filesSubtitle(bundle),
                style: context.bodySm.withColor(context.cText2),
              ),
              onTap: () => onSelect(ShareMode.textAndFiles),
            ),
          ListTile(
            leading: const Icon(Icons.notes_rounded),
            title: const Text('Μόνο κείμενο'),
            onTap: () => onSelect(ShareMode.textOnly),
          ),
          if (skipped > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.xs, Spacing.lg, Spacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppErrors.oversizeSkipped(skipped),
                  style: context.helper.withColor(context.cText2),
                ),
              ),
            ),
          const SizedBox(height: Spacing.sm),
        ],
      ),
    );
  }

  static String _filesSubtitle(ShareBundle bundle) {
    final count = AppStringUtils.attachmentsCountLabel(bundle.files.length);
    final size = ShareFormatters.humanSize(bundle.totalBytes);
    return '$count • $size';
  }
}