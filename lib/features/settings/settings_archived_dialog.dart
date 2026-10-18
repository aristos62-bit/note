// lib/features/settings/settings_archived_dialog.dart
//
// S253 (P2): διάλογος αρχειοθετημένων (split από settings_screen.dart).
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';

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

  List<Item> mutableItems = List.from(items);
  final selectedIds = <int>{};
  DebugConfig.nav('Settings: open archived');

  await showDialog(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        final allSelected =
            mutableItems.isNotEmpty &&
                selectedIds.length == mutableItems.length;

        // ── Βοηθητική: επαναφορά ενός item ────────────────────
        Future<void> restoreSingle(Item item) async {
          // #2: επαναφορά μέσω SPoT → unarchive + reschedule OS reminders.
          await ref.read(itemNotifierProvider.notifier).toggleArchive(item.id, true);
          if (!ctx.mounted) return; // S253: το dialog έκλεισε κατά το await
          setModal(() {
            selectedIds.remove(item.id);
            mutableItems.remove(item);
          });
          if (mutableItems.isEmpty && ctx.mounted) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        }

        // ── Βοηθητική: soft delete ενός item ──────────────────
        Future<void> deleteSingle(Item item) async {
          // #2: διαγραφή μέσω SPoT deleteItem → cascade reminders + cancel OS.
          await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
          if (!ctx.mounted) return; // S253: το dialog έκλεισε κατά το await
          setModal(() {
            selectedIds.remove(item.id);
            mutableItems.remove(item);
          });
          ref.invalidate(archivedItemsProvider);
          if (mutableItems.isEmpty && ctx.mounted) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        }

        // ── Βοηθητική: bulk επαναφορά ─────────────────────────
        Future<void> restoreSelected(Set<int> ids) async {
          final toRestore = mutableItems.where((i) => ids.contains(i.id)).toList();
          for (final item in toRestore) {
            // #2: επαναφορά μέσω SPoT → unarchive + reschedule OS reminders.
            await ref.read(itemNotifierProvider.notifier).toggleArchive(item.id, true);
          }
          if (!ctx.mounted) return; // S253: το dialog έκλεισε κατά το await
          setModal(() {
            mutableItems.removeWhere((i) => ids.contains(i.id));
            selectedIds.clear();
          });
          if (mutableItems.isEmpty && ctx.mounted) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        }

        // ── Βοηθητική: bulk soft delete ───────────────────────
        Future<void> deleteSelected(Set<int> ids) async {
          final toDelete = mutableItems.where((i) => ids.contains(i.id)).toList();
          for (final item in toDelete) {
            // #2: διαγραφή μέσω SPoT deleteItem → cascade reminders + cancel OS.
            await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
          }
          if (!ctx.mounted) return; // S253: το dialog έκλεισε κατά το await
          setModal(() {
            mutableItems.removeWhere((i) => ids.contains(i.id));
            selectedIds.clear();
          });
          ref.invalidate(archivedItemsProvider);
          if (mutableItems.isEmpty && ctx.mounted) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        }

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.archive_rounded, color: ctx.cPrimary),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  'Αρχειοθετημένα (${mutableItems.length})',
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
                        selectedIds.addAll(mutableItems.map((i) => i.id));
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
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: Spacing.xs),
                ),
                const Divider(height: 1),
                // ── Λίστα αρχειοθετημένων ──────────────────────
                Flexible(
                  child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: mutableItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = mutableItems[i];
                      final isSelected = selectedIds.contains(item.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (selected) {
                          setModal(() {
                            if (selected == true) {
                              selectedIds.add(item.id);
                            } else {
                              selectedIds.remove(item.id);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.only(
                          left: Spacing.xs,
                          right: Spacing.xs,
                        ),
                        title: Text(
                          item.title ?? '(χωρίς τίτλο)',
                          style: ctx.bodyMd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
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
                                AppDateUtils.formatDateTime(
                                    item.updatedAt ?? item.createdAt),
                                style: ctx.bodySm.withColor(ctx.cText2),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Δύο κουμπιά: επαναφορά + διαγραφή
                        secondary: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.unarchive_rounded,
                                color: ctx.cPrimary,
                                size: 20,
                              ),
                              tooltip: 'Επαναφορά',
                              onPressed: () => restoreSingle(item),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: ctx.cError,
                                size: 20,
                              ),
                              tooltip: 'Μετακίνηση στον κάδο',
                              onPressed: () => deleteSingle(item),
                            ),
                          ],
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
            // Κλείσιμο
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Κλείσιμο'),
            ),

            // Bulk actions — εμφανίζονται μόνο αν υπάρχει επιλογή
            if (selectedIds.isNotEmpty) ...[
              FilledButton.tonal(
                onPressed: () async {
                  final confirm = await ConfirmDialog.show(
                    ctx,
                    title: 'Επαναφορά επιλεγμένων;',
                    subtitle:
                    'Τα ${selectedIds.length} επιλεγμένα στοιχεία θα επαναφερθούν.',
                    confirmLabel: 'Επαναφορά',
                  );
                  if (confirm != true) return;
                  await restoreSelected(Set.from(selectedIds));
                },
                child: Text('Επαναφορά (${selectedIds.length})'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ctx.cError,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final confirm = await ConfirmDialog.show(
                    ctx,
                    title: 'Διαγραφή επιλεγμένων;',
                    subtitle:
                    'Τα ${selectedIds.length} στοιχεία θα μεταφερθούν στον κάδο ανακύκλωσης.',
                    confirmLabel: 'Διαγραφή',
                  );
                  if (confirm != true) return;
                  await deleteSelected(Set.from(selectedIds));
                },
                child: Text('Διαγραφή (${selectedIds.length})'),
              ),
            ],
          ],
        );
      },
    ),
  );
}
