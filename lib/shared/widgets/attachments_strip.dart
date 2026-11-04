// lib/shared/widgets/attachments_strip.dart
//
// Προβολή/προσθήκη/άνοιγμα/διαγραφή συνημμένων note/event.
// SPoT: ένα widget για note_detail + event_detail (αντί 2 inline).
// Επιστρέφει sliver (οι 2 callers είναι CustomScrollView).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/core.dart';
import '../../helpers/super_note_helper.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/attachment_service.dart';
import 'confirm_dialog.dart';

class AttachmentsStrip extends ConsumerWidget {
  final int itemId;

  const AttachmentsStrip({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attsAsync = ref.watch(attachmentsProvider(itemId));
    return SliverToBoxAdapter(
      child: attsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) {
          DebugConfig.error('AttachmentsStrip load', e);
          return const SizedBox.shrink();
        },
        data: (atts) => Padding(
          padding: EdgeInsets.fromLTRB(
            context.responsiveHPadding,
            Spacing.sm,
            context.responsiveHPadding,
            Spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (atts.isEmpty)
                _AddButton(labeled: true, onPressed: () => _add(context))
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Συνημμένα (${atts.length})',
                        style: context.labelMd.withColor(context.cText2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _AddButton(labeled: false, onPressed: () => _add(context)),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    for (final att in atts)
                      _AttachmentCell(
                        attachment: att,
                        onOpen: () => _open(context, att),
                        onDelete: () => _remove(context, att),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Προσθήκη αρχείου (E09): επιλογή → όριο από settings → αποθήκευση.
  /// Το stream ενημερώνει μόνο του το strip (χωρίς invalidate).
  Future<void> _add(BuildContext context) async {
    try {
      final settings = await SuperNoteHelper.instance.settings.get();
      await AttachmentService.instance.pickAndSave(
        itemId: itemId,
        maxSizeBytes: settings.attachmentMaxBytes,
      );
    } on FormatException catch (e) {
      DebugConfig.warning('AttachmentsStrip _add validation: ${e.message}');
      if (context.mounted) _snack(context, e.message);
    } catch (e, stack) {
      DebugConfig.error('AttachmentsStrip _add', e, stack);
      if (context.mounted) _snack(context, AppErrors.attachSaveFailed);
    }
  }

  /// Προβολή: εικόνα → fullscreen dialog, αλλιώς system app.
  /// (pattern collection_entries `_openAttachment`.)
  Future<void> _open(BuildContext context, Attachment attachment) async {
    DebugConfig.db(
        'AttachmentsStrip open id=${attachment.id} file=${AppStringUtils.redact(attachment.fileName, label: 'file')}');
    if (attachment.isImage) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.file(
                    File(attachment.localPath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded,
                              size: 48, color: Colors.white54),
                          SizedBox(height: 8),
                          Text('Αδυναμία προβολής',
                              style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Κλείσιμο',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    try {
      final file = File(attachment.localPath);
      if (!await file.exists()) {
        DebugConfig.db('AttachmentsStrip file not found id=${attachment.id}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppErrors.attachNotFound)),
          );
        }
        return;
      }
      final result = await OpenFilex.open(attachment.localPath);
      if (result.type != ResultType.done && context.mounted) {
        DebugConfig.db(
            'AttachmentsStrip open failed: ${result.type} ${result.message}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppErrors.attachOpenFailed)),
        );
      }
    } catch (e, stack) {
      DebugConfig.error('AttachmentsStrip _open', e, stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppErrors.attachOpenFailed)),
        );
      }
    }
  }

  /// Διαγραφή αρχείου + γραμμής (service: DB-first + disk + ref-guard).
  /// E09: επιβεβαίωση (μη αναστρέψιμη) + ορατό σφάλμα.
  Future<void> _remove(
      BuildContext context, Attachment attachment) async {
    final ok = await ConfirmDialog.delete(
      context,
      title: 'Διαγραφή αρχείου;',
      subtitle: AppErrors.deleteIrreversible,
    );
    if (!ok) return;
    try {
      await AttachmentService.instance.delete(attachment.id);
    } catch (e, stack) {
      DebugConfig.error('AttachmentsStrip _remove', e, stack);
      if (context.mounted) _snack(context, AppErrors.attachDeleteFailed);
    }
  }
}

/// Κουμπί προσθήκης: labeled όταν το strip είναι κενό, icon-only (48 dp)
/// όταν υπάρχει header — αποφεύγει overflow σε 140–200% text scale.
class _AddButton extends StatelessWidget {
  final bool labeled;
  final VoidCallback onPressed;

  const _AddButton({required this.labeled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (!labeled) {
      return IconButton(
        onPressed: onPressed,
        tooltip: 'Προσθήκη αρχείου',
        iconSize: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(Icons.add_rounded, color: context.cText2),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Προσθήκη'),
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          foregroundColor: context.cText2,
        ),
      ),
    );
  }
}

class _AttachmentCell extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _AttachmentCell({
    required this.attachment,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Widget thumb;
    if (attachment.isImage) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: ImageUtils.fileThumb(attachment.localPath, size: 56),
      );
    } else {
      thumb = Icon(
        attachment.isVideo
            ? Icons.movie_rounded
            : attachment.isAudio
                ? Icons.music_note_rounded
                : Icons.insert_drive_file_outlined,
        size: 32,
        color: context.cText2,
      );
    }
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: 72,
        padding: const EdgeInsets.all(Spacing.xs),
        decoration: BoxDecoration(
          color: ColorsUI.getSurface(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(color: ColorsUI.getBorder(context.brightness)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                SizedBox(width: 56, height: 56, child: Center(child: thumb)),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Semantics(
                    container: true,
                    button: true,
                    label: 'Διαγραφή αρχείου',
                    excludeSemantics: true,
                    onTap: onDelete,
                    child: Tooltip(
                      message: 'Διαγραφή αρχείου',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onDelete,
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: Icon(Icons.cancel_rounded,
                                size: 20, color: context.cError),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              attachment.fileName,
              style: context.labelSm.withColor(context.cText2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
