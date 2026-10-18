// lib/features/settings/settings_reminders_dialog.dart
//
// S253 (P2): διάλογος παρελθουσών υπενθυμίσεων (split από settings_screen.dart).
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';

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

  List<Reminder> mutableReminders = List.from(reminders);
  final selectedIds = <int>{};

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
  mutableReminders = List.from(mutableReminders.where(
      (r) => itemTitles[r.itemId]?.isDeleted != true));

  if (!context.mounted) return;

  if (mutableReminders.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppErrors.noPastReminders)),
    );
    return;
  }

  await showDialog(
    context: context,
    useRootNavigator: true, // ✅ ρητά — αποφεύγουμε GoRouter confusion
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        final allSelected =
            mutableReminders.isNotEmpty &&
                selectedIds.length == mutableReminders.length;

        // ── Βοηθητική: διαγραφή μιας υπενθύμισης ──────────────
        Future<void> deleteSingle(Reminder r) async {
          // S253: ΣΚΟΠΙΜΑ per-row delete (ΟΧΙ deleteReminderThread) — το thread
          // θα έσβηνε το root rrule και την επανάληψη (A1, getPastPending).
          await ReminderScheduler.instance.cancelReminder(r.id);
          await ref.read(dbProvider).reminders.delete(r.id);
          if (!ctx.mounted) return; // S253: το dialog έκλεισε κατά το await
          setModal(() {
            selectedIds.remove(r.id);
            mutableReminders.remove(r);
          });
          ref.invalidate(pastPendingRemindersProvider);
          if (mutableReminders.isEmpty && ctx.mounted) {
            Navigator.of(ctx, rootNavigator: true).pop(); // ✅
          }
        }

        // ── Βοηθητική: διαγραφή συνόλου ids ───────────────────
        Future<void> deleteSelected(Set<int> ids) async {
          final toDelete = mutableReminders
              .where((r) => ids.contains(r.id))
              .toList();
          for (final r in toDelete) {
            await ReminderScheduler.instance.cancelReminder(r.id);
            await ref.read(dbProvider).reminders.delete(r.id);
          }
          if (!ctx.mounted) return; // S253: το dialog έκλεισε κατά το await
          setModal(() {
            mutableReminders.removeWhere((r) => ids.contains(r.id));
            selectedIds.clear();
          });
          ref.invalidate(pastPendingRemindersProvider);
          if (mutableReminders.isEmpty && ctx.mounted) {
            Navigator.of(ctx, rootNavigator: true).pop(); // ✅
          }
        }

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  'Παρελθούσες Υπενθυμίσεις (${mutableReminders.length})',
                  style: ctx.titleMd,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── "Επιλογή όλων" header ───────────────────────
                CheckboxListTile(
                  value: allSelected,
                  tristate: false,
                  onChanged: (v) {
                    setModal(() {
                      if (v == true) {
                        selectedIds.addAll(mutableReminders.map((r) => r.id));
                      } else {
                        selectedIds.clear();
                      }
                    });
                  },
                  title: Text(
                    allSelected ? 'Αποεπιλογή όλων' : 'Επιλογή όλων',
                    style: ctx.bodyMd.copyWith(fontWeight: FontWeight.bold),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                ),
                const Divider(height: 1),
                // ── Λίστα υπενθυμίσεων ─────────────────────────
                Flexible(
                  child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: mutableReminders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = mutableReminders[i];
                      final isSelected = selectedIds.contains(r.id);
                      final item = itemTitles[r.itemId];
                      final title = item?.title ?? 'Άγνωστο στοιχείο';
                      final type = item?.type.name ?? 'item';
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (selected) {
                          setModal(() {
                            if (selected == true) {
                              selectedIds.add(r.id);
                            } else {
                              selectedIds.remove(r.id);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.only(
                          left: Spacing.xs,
                          right: Spacing.xs,
                        ),
                        title: Text(title, style: ctx.bodyMd),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Τύπος: $type',
                              style: ctx.bodySm.withColor(ctx.cText2),
                            ),
                            Text(
                              'Έληξε: ${AppDateUtils.formatDateTime(r.triggerAt)}',
                              style: ctx.bodySm.withColor(ctx.cError),
                            ),
                          ],
                        ),
                        secondary: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: ctx.cError,
                            size: 20,
                          ),
                          tooltip: 'Διαγραφή',
                          onPressed: () => deleteSingle(r),
                        ),
                      );
                    },
                  ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Άκυρο
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), // ✅
              child: const Text('Άκυρο'),
            ),

            // Διαγραφή επιλεγμένων — μόνο αν υπάρχει μερική επιλογή
            if (selectedIds.isNotEmpty && !allSelected)
              FilledButton.tonal(
                onPressed: () async {
                  final confirm = await ConfirmDialog.show(
                    ctx,
                    title: 'Διαγραφή επιλεγμένων;',
                    subtitle: 'Θα διαγραφούν ${selectedIds.length} υπενθυμίσεις.',
                    confirmLabel: 'Διαγραφή',
                  );
                  if (confirm != true) return;
                  await deleteSelected(Set.from(selectedIds));
                },
                child: Text('Επιλεγμένες (${selectedIds.length})'),
              ),

            // Διαγραφή όλων
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ctx.cError,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final confirm = await ConfirmDialog.show(
                  ctx,
                  title: 'Διαγραφή όλων;',
                  subtitle:
                  'Θα διαγραφούν όλες οι ${mutableReminders.length} παρελθούσες υπενθυμίσεις.',
                  confirmLabel: 'Ναι, διαγραφή όλων',
                );
                if (confirm != true) return;
                await deleteSelected(
                  mutableReminders.map((r) => r.id).toSet(),
                );
              },
              child: const Text('Διαγραφή όλων'),
            ),
          ],
        );
      },
    ),
  );
}
