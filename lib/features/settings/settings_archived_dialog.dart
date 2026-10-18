// lib/features/settings/settings_archived_dialog.dart
//
// S253 (P2): διάλογος αρχειοθετημένων (split από settings_screen.dart).
// S254 (F16): λεπτός wrapper πάνω στο κοινό SelectionListDialog.
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'selection_list_dialog.dart';

Future<void> showArchivedItemsDialog(BuildContext context, WidgetRef ref) async {
  final List<Item> items;
  try {
    items = await ref.read(archivedItemsProvider.future);
  } catch (e) {
    DebugConfig.error('Settings archived items load', e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.loadFailed)),
      );
    }
    return;
  }

  if (!context.mounted) return;

  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppErrors.noArchivedItems)),
    );
    return;
  }

  DebugConfig.nav('Settings: open archived');

  // S251: capture notifier πριν το πρώτο await του dialog.
  final notifier = ref.read(itemNotifierProvider.notifier);

  await showSelectionListDialog<Item>(
    context: context,
    icon: Icons.archive_rounded,
    iconColor: context.cPrimary,
    title: (n) => 'Αρχειοθετημένα ($n)',
    items: items,
    idOf: (item) => item.id,
    rowTitle: (ctx, item) => Text(
      item.title ?? '(χωρίς τίτλο)',
      style: ctx.bodyMd,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    rowSubtitle: (ctx, item) => Row(
      children: [
        Icon(
          ItemTypeIcon.iconDataFor(item.type),
          size: 12,
          color: ctx.cText2,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            ItemTypeIcon.labelFor(item.type),
            style: ctx.bodySm.withColor(ctx.cText2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Flexible(
          child: Text(
            AppDateUtils.formatDateTime(item.updatedAt ?? item.createdAt),
            style: ctx.bodySm.withColor(ctx.cText2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    // Δύο κουμπιά: επαναφορά + διαγραφή
    rowSecondary: (ctx, item, controller) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.unarchive_rounded, color: ctx.cPrimary, size: 20),
          tooltip: 'Επαναφορά',
          onPressed: () async {
            // #2: επαναφορά μέσω SPoT → unarchive + reschedule OS reminders.
            await notifier.toggleArchive(item.id, true);
            // S253: το toggleArchive invalidates εσωτερικά το provider.
            controller.remove({item.id});
          },
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: ctx.cError, size: 20),
          tooltip: 'Μετακίνηση στον κάδο',
          onPressed: () async {
            // #2: διαγραφή μέσω SPoT deleteItem → cascade reminders + cancel OS.
            await notifier.deleteItem(item.id);
            controller.remove(
              {item.id},
              onApplied: () => ref.invalidate(archivedItemsProvider),
            );
          },
        ),
      ],
    ),
    actions: (ctx, controller) {
      final count = controller.selectedCount;
      // Bulk actions — εμφανίζονται μόνο αν υπάρχει επιλογή
      if (count == 0) return const [];
      return [
        FilledButton.tonal(
          onPressed: () async {
            final confirm = await ConfirmDialog.show(
              ctx,
              title: 'Επαναφορά επιλεγμένων;',
              subtitle: 'Τα $count επιλεγμένα στοιχεία θα επαναφερθούν.',
              confirmLabel: 'Επαναφορά',
            );
            if (!confirm) return;
            final ids = controller.selected;
            // S255 (F13): bulk unarchive μέσω SPoT — 1× global reminder pass
            // για όλα τα επιλεγμένα (αντί για 2 global passes ανά item).
            await notifier.unarchiveMany(ids.toList());
            controller.remove(ids);
          },
          child: Text('Επαναφορά ($count)'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ctx.cError,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final confirm = await ConfirmDialog.delete(
              ctx,
              title: 'Διαγραφή επιλεγμένων;',
              subtitle:
                  'Τα $count στοιχεία θα μεταφερθούν στον κάδο ανακύκλωσης.',
              confirmLabel: 'Διαγραφή',
            );
            if (!confirm) return;
            final ids = controller.selected;
            // #2: διαγραφή μέσω SPoT deleteItem → cascade reminders + cancel OS.
            for (final item
                in controller.items.where((i) => ids.contains(i.id))) {
              await notifier.deleteItem(item.id);
            }
            controller.remove(
              ids,
              onApplied: () => ref.invalidate(archivedItemsProvider),
            );
          },
          child: Text('Διαγραφή ($count)'),
        ),
      ];
    },
  );
}
