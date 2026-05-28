// lib/shared/widgets/archive_helper.dart
//
// Κεντρική συνάρτηση για archive/unarchive με συνεπή συμπεριφορά.
//   - Archive: ConfirmDialog → toggleArchive → SnackBar → pop
//   - Unarchive: toggleArchive → SnackBar → stay
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_note/core/core.dart';
import '../../providers/providers.dart';
import 'confirm_dialog.dart';

enum ItemLabel { journal, note, task, habit, event, appointment, contact, entry }

String _label(ItemLabel type) {
  switch (type) {
    case ItemLabel.journal:     return 'καταχώρηση';
    case ItemLabel.note:        return 'σημείωση';
    case ItemLabel.task:        return 'εργασία';
    case ItemLabel.habit:       return 'συνήθεια';
    case ItemLabel.event:       return 'συμβάν';
    case ItemLabel.appointment: return 'ραντεβού';
    case ItemLabel.contact:     return 'επαφή';
    case ItemLabel.entry:       return 'εγγραφή';
  }
}

Future<void> handleArchive({
  required BuildContext context,
  required WidgetRef ref,
  required int itemId,
  required bool isArchived,
  required ItemLabel label,
  bool showPopOnArchive = true,
  bool showPopOnUnarchive = false,
}) async {
  if (isArchived) {
    // ── Unarchive: χωρίς επιβεβαίωση ──
    await ref.read(itemNotifierProvider.notifier).toggleArchive(itemId, isArchived);
    if (!context.mounted) return;
    DebugConfig.db('ArchiveHelper unarchive id=$itemId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Η ${_label(label)} επαναφέρθηκε')),
    );
    if (showPopOnUnarchive) Navigator.of(context).pop();
  } else {
    // ── Archive: με επιβεβαίωση ──
    final ok = await ConfirmDialog.archive(context);
    if (!ok || !context.mounted) return;
    await ref.read(itemNotifierProvider.notifier).toggleArchive(itemId, isArchived);
    if (!context.mounted) return;
    DebugConfig.db('ArchiveHelper archive id=$itemId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Η ${_label(label)} αρχειοθετήθηκε')),
    );
    if (showPopOnArchive) Navigator.of(context).pop();
  }
}