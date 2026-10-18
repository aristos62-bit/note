// lib/features/settings/settings_reminders_dialog.dart
//
// S253 (P2): διάλογος παρελθουσών υπενθυμίσεων (split από settings_screen.dart).
// S254 (F16): λεπτός wrapper πάνω στο κοινό SelectionListDialog.
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';
import 'selection_list_dialog.dart';

/// S253: ΣΚΟΠΙΜΑ per-row delete (ΟΧΙ deleteReminderThread) — το thread θα
/// έσβηνε το root rrule και την επανάληψη (A1, getPastPending).
Future<void> _deleteReminders(
  WidgetRef ref,
  SelectionListController<Reminder> controller,
  Iterable<int> ids,
) async {
  final idSet = ids.toSet();
  for (final r in controller.items.where((r) => idSet.contains(r.id))) {
    await ReminderScheduler.instance.cancelReminder(r.id);
    await ref.read(dbProvider).reminders.delete(r.id);
  }
  controller.remove(
    idSet,
    onApplied: () => ref.invalidate(pastPendingRemindersProvider),
  );
}

Future<void> showPastRemindersDialog(BuildContext context, WidgetRef ref) async {
  // Φόρτωση απευθείας — τοπική DB, χωρίς loading dialog
  final List<Reminder> reminders;
  try {
    reminders = await ref.read(pastPendingRemindersProvider.future);
  } catch (e) {
    DebugConfig.error('Settings past reminders load', e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.loadFailed)),
      );
    }
    return;
  }

  if (!context.mounted) return;

  if (reminders.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppErrors.noPastReminders)),
    );
    return;
  }

  // Batch τίτλοι γραμμών (1 query αντί για N FutureBuilders).
  final itemTitles = <int, Item>{};
  try {
    final batchItems = await ref.read(dbProvider).items.getByIds(
      [for (final r in reminders) r.itemId],
    );
    for (final i in batchItems) {
      itemTitles[i.id] = i;
    }
    DebugConfig.db('Settings past reminders batch: ${itemTitles.length}/${reminders.length}');
  } catch (e) {
    DebugConfig.error('Settings past reminders batch', e);
  }

  // Κάδος: οι κρατημένες rows δεν φαίνονται εδώ (θα επανέλθουν με restore).
  // Μόνο known-deleted φιλτράρονται — missing items ως πριν (εκτός scope).
  final visible = reminders
      .where((r) => itemTitles[r.itemId]?.isDeleted != true)
      .toList();

  if (!context.mounted) return;

  if (visible.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppErrors.noPastReminders)),
    );
    return;
  }

  DebugConfig.nav('Settings: open past reminders');

  await showSelectionListDialog<Reminder>(
    context: context,
    icon: Icons.warning_amber_rounded,
    title: (n) => 'Παρελθούσες Υπενθυμίσεις ($n)',
    items: visible,
    idOf: (r) => r.id,
    closeLabel: 'Άκυρο',
    rowTitle: (ctx, r) => Text(
      itemTitles[r.itemId]?.title ?? 'Άγνωστο στοιχείο',
      style: ctx.bodyMd,
    ),
    rowSubtitle: (ctx, r) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Τύπος: ${itemTitles[r.itemId]?.type.name ?? 'item'}',
          style: ctx.bodySm.withColor(ctx.cText2),
        ),
        Text(
          'Έληξε: ${AppDateUtils.formatDateTime(r.triggerAt)}',
          style: ctx.bodySm.withColor(ctx.cError),
        ),
      ],
    ),
    rowSecondary: (ctx, r, controller) => IconButton(
      icon: Icon(Icons.delete_outline, color: ctx.cError, size: 20),
      tooltip: 'Διαγραφή',
      onPressed: () => _deleteReminders(ref, controller, {r.id}),
    ),
    actions: (ctx, controller) {
      final count = controller.selectedCount;
      final all = controller.allSelected;
      return [
        // Διαγραφή επιλεγμένων — μόνο αν υπάρχει μερική επιλογή
        if (count > 0 && !all)
          FilledButton.tonal(
            onPressed: () async {
              final confirm = await ConfirmDialog.delete(
                ctx,
                title: 'Διαγραφή επιλεγμένων;',
                subtitle: 'Θα διαγραφούν $count υπενθυμίσεις.',
                confirmLabel: 'Διαγραφή',
              );
              if (!confirm) return;
              await _deleteReminders(ref, controller, controller.selected);
            },
            child: Text('Επιλεγμένες ($count)'),
          ),
        // Διαγραφή όλων
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ctx.cError,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final confirm = await ConfirmDialog.delete(
              ctx,
              title: 'Διαγραφή όλων;',
              subtitle:
                  'Θα διαγραφούν όλες οι ${controller.items.length} παρελθούσες υπενθυμίσεις.',
              confirmLabel: 'Ναι, διαγραφή όλων',
            );
            if (!confirm) return;
            await _deleteReminders(
              ref,
              controller,
              controller.items.map((r) => r.id),
            );
          },
          child: const Text('Διαγραφή όλων'),
        ),
      ];
    },
  );
}
