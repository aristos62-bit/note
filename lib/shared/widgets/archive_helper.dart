// lib/shared/widgets/archive_helper.dart
//
// Κεντρική συνάρτηση για archive/unarchive με συνεπή συμπεριφορά.
//   - Archive: ConfirmDialog → toggleArchive → SnackBar → pop
//   - Unarchive: toggleArchive → SnackBar → stay
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_note/core/core.dart';
import '../../models/models.dart';
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

/// SPoT mapping ItemType → ItemLabel (ενοποιεί τα διπλά `_labelForType`
/// σε item_list_screen/item_list_embedded).
extension ItemLabelX on ItemLabel {
  static ItemLabel fromType(ItemType type) {
    switch (type) {
      case ItemType.note:        return ItemLabel.note;
      case ItemType.task:        return ItemLabel.task;
      case ItemType.event:       return ItemLabel.event;
      case ItemType.contact:     return ItemLabel.contact;
      case ItemType.habit:       return ItemLabel.habit;
      case ItemType.journal:     return ItemLabel.journal;
      case ItemType.appointment: return ItemLabel.appointment;
      case ItemType.knowledge:   return ItemLabel.entry;
      default:                   return ItemLabel.note;
    }
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
  DebugConfig.db('ArchiveHelper ENTER id=$itemId isArchived=$isArchived label=$label');
  if (isArchived) {
    // ── Unarchive: χωρίς επιβεβαίωση ──
    DebugConfig.db('ArchiveHelper BEFORE toggleArchive id=$itemId (unarchive)');
    await ref.read(itemNotifierProvider.notifier).toggleArchive(itemId, isArchived);
    DebugConfig.db('ArchiveHelper AFTER toggleArchive id=$itemId (unarchive)');
    if (!context.mounted) return;
    DebugConfig.db('ArchiveHelper unarchive id=$itemId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppErrors.restored(_label(label)))),
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
      SnackBar(content: Text(AppErrors.archived(_label(label)))),
    );
    if (showPopOnArchive) Navigator.of(context).pop();
  }
}

/// State-dependent archive toggle για AppBar menus.
///
/// Single source of truth για το label/icon/onPressed που επαναλαμβανόταν
/// σε 7 list screens. Το `Flexible` κρατά το label μέσα στο menu πλάτος.
class ArchivedMenuButton extends ConsumerWidget {
  const ArchivedMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showArchived = ref.watch(showArchivedProvider);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        if (value == 'archived') {
          ref.read(showArchivedProvider.notifier).state =
              !ref.read(showArchivedProvider);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'archived',
          child: Row(children: [
            Icon(
              showArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
              size: 18,
            ),
            const SizedBox(width: Spacing.sm),
            Flexible(
              child: Text(
                showArchived
                    ? 'Απόκρυψη αρχειοθετημένων'
                    : 'Εμφάνιση αρχειοθετημένων',
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

/// State-dependent inline archive toggle για το calendar.
///
/// Ο caller το τοποθετεί σε bounded πλάτος (π.χ. `Align`), ώστε το
/// εσωτερικό `Flexible` του `TextButton.icon` να μην παίρνει unbounded
/// constraints.
class ArchivedInlineButton extends ConsumerWidget {
  const ArchivedInlineButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showArchived = ref.watch(showArchivedProvider);
    return TextButton.icon(
      onPressed: () {
        ref.read(showArchivedProvider.notifier).state =
            !ref.read(showArchivedProvider);
      },
      icon: Icon(
        showArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
        size: 18,
      ),
      label: Text(
        showArchived
            ? 'Απόκρυψη αρχειοθετημένων'
            : 'Εμφάνιση αρχειοθετημένων',
        style: context.labelSm,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}