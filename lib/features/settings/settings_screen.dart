// lib/features/settings/settings_screen.dart
//
// Ρυθμίσεις εφαρμογής: ομαδοποιημένες σε Σύστημα και Βάση.
// ✅ Responsive: single col mobile / 2-col tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ Ομαδοποίηση με ExpansionTile, διαφανής εξωτερική κάρτα
// ✅ Κάθε επιλογή μέσα σε ξεχωριστή κάρτα
// ✅ Επιλογή μεγέθους γραμματοσειράς (Font Scale)
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/backup_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../shared/widgets/widgets.dart';
import '../../helpers/super_note_helper.dart';
import '../../features/trash/trash_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// ── Provider για αρχειοθετημένα items ──────────────────────────
final archivedItemsProvider = FutureProvider<List<Item>>((ref) async {
  final wsId = ref.read(activeWorkspaceIdProvider);
  if (wsId == null) return [];
  final all = await SuperNoteHelper.instance.items.getByWorkspace(
    wsId,
    includeArchived: true,
  );
  return all.where((i) => i.archived && i.deletedAt == null).toList();
});

// ── Provider για παρελθούσες pending υπενθυμίσεις ──────────────
final pastPendingRemindersProvider = FutureProvider<List<Reminder>>((ref) async {
  return SuperNoteHelper.instance.reminders.getPastPending();
});

// ════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ════════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    DebugConfig.provider('SettingsScreen build');

    final settingsAsync = ref.watch(settingsNotifierProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Ρυθμίσεις'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          DebugConfig.error('SettingsScreen load failed', e);
          return EmptyState.error(
            onRetry: () => ref.invalidate(settingsNotifierProvider),
          );
        },
        data: (settings) => ResponsiveLayout(
          mobile: _buildMobile(context, ref, settings),
          tablet: _buildTablet(context, ref, settings),
        ),
      ),
    );
  }

  // ── Mobile — single column ───────────────────────────────────
  Widget _buildMobile(BuildContext context, WidgetRef ref, AppSettings settings) {
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.md,
      ),
      children: [
        _SystemGroup(ref: ref, settings: settings),
        const SizedBox(height: Spacing.lg),
        _DatabaseGroup(ref: ref, settings: settings),
        const SizedBox(height: Spacing.xl),
      ],
    );
  }

  // ── Tablet/Desktop — 2-col ───────────────────────────────────
  Widget _buildTablet(BuildContext context, WidgetRef ref, AppSettings settings) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _SystemGroup(ref: ref, settings: settings)),
          const SizedBox(width: Spacing.lg),
          Expanded(child: _DatabaseGroup(ref: ref, settings: settings)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ΣΥΣΤΗΜΑ GROUP
// ════════════════════════════════════════════════════════════════

class _SystemGroup extends StatefulWidget {
  final WidgetRef ref;
  final AppSettings settings;
  const _SystemGroup({required this.ref, required this.settings});

  @override
  State<_SystemGroup> createState() => _SystemGroupState();
}

class _SystemGroupState extends State<_SystemGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: AppRadius.cardBR, // ✅ απευθείας
      ),
      child: ExpansionTile(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        initiallyExpanded: _expanded,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        leading: Icon(Icons.settings_rounded, color: context.cPrimary),
        title: Text('Σύστημα', style: context.titleMd),
        childrenPadding: const EdgeInsets.all(Spacing.md),
        children: [
          _buildCard(_ThemeTile(current: widget.settings.theme, ref: widget.ref)),
          const SizedBox(height: Spacing.sm),
          _buildCard(_LanguageTile(current: widget.settings.language, ref: widget.ref)),
          const SizedBox(height: Spacing.sm),
          _buildCard(_PreferredFolderTile(settings: widget.settings, ref: widget.ref)),
          const SizedBox(height: Spacing.sm),
          _buildCard(_FontScaleTile(current: widget.settings.fontScale, ref: widget.ref)),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            _SwitchTile(
              label: 'Ειδοποιήσεις',
              subtitle: 'Reminders και υπενθυμίσεις',
              value: widget.settings.notificationsEnabled,
              onChanged: (v) {
                DebugConfig.provider('Settings: notifications=$v');
                widget.ref.read(settingsNotifierProvider.notifier).toggleNotifications(v);
              },
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            _SwitchTile(
              label: 'Ήχος',
              value: widget.settings.soundEnabled,
              enabled: widget.settings.notificationsEnabled,
              onChanged: (v) => widget.ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSettings((s) => s.soundEnabled = v),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            _SwitchTile(
              label: 'Δόνηση',
              value: widget.settings.vibrationEnabled,
              enabled: widget.settings.notificationsEnabled,
              onChanged: (v) => widget.ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSettings((s) => s.vibrationEnabled = v),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(const _InfoTile(label: 'Έκδοση', value: '1.0.0')),
          const SizedBox(height: Spacing.sm),
          _buildCard(const _InfoTile(label: 'Βάση δεδομένων', value: 'Isar 3.1.0')),
        ],
      ),
    );
  }

  Widget _buildCard(Widget child) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBR, // ✅ απευθείας
        side: BorderSide(color: ColorsUI.getBorder(context.brightness).withValues(alpha:0.3)),
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ΒΑΣΗ GROUP
// ════════════════════════════════════════════════════════════════

class _DatabaseGroup extends StatefulWidget {
  final WidgetRef ref;
  final AppSettings settings;
  const _DatabaseGroup({required this.ref, required this.settings});

  @override
  State<_DatabaseGroup> createState() => _DatabaseGroupState();
}

class _DatabaseGroupState extends State<_DatabaseGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: AppRadius.cardBR,
      ),
      child: ExpansionTile(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        initiallyExpanded: _expanded,
        onExpansionChanged: (value) => setState(() => _expanded = value),
        leading: Icon(Icons.storage_rounded, color: context.cPrimary),
        title: Text('Βάση', style: context.titleMd),
        childrenPadding: const EdgeInsets.all(Spacing.md),
        children: [
          _buildCard(
            _ActionTile(
              label: 'Παρελθούσες υπενθυμίσεις',
              subtitle: 'Διαγραφή υπενθυμίσεων που έχουν ήδη λήξει',
              icon: Icons.delete_sweep_rounded,
              onTap: () => _showPastRemindersDialog(context, widget.ref),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            _ActionTile(
              label: 'Αρχειοθετημένα',
              subtitle: 'Επαναφορά ή διαγραφή αρχειοθετημένων στοιχείων',
              icon: Icons.archive_rounded,
              onTap: () => _showArchivedItemsDialog(context, widget.ref),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            _ActionTile(
              label: 'Κάδος Ανακύκλωσης',
              subtitle: 'Επαναφορά ή οριστική διαγραφή',
              icon: Icons.restore_from_trash_rounded,
              onTap: () => _navigateToTrash(context),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            _ActionTile(
              label: 'Εξαγωγή δεδομένων',
              subtitle: 'Δημιουργία αντιγράφου .isar',
              icon: Icons.upload_rounded,
              onTap: () => _exportBackup(context, widget.ref),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            _ActionTile(
              label: 'Εισαγωγή δεδομένων',
              subtitle: 'Επαναφορά από αντίγραφο',
              icon: Icons.download_rounded,
              onTap: () => _importBackup(context, widget.ref),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            _ActionTile(
              label: 'Διαγραφή όλων των δεδομένων',
              subtitle: 'Μη αναστρέψιμη ενέργεια',
              icon: Icons.delete_forever_rounded,
              color: context.cError,
              onTap: () => _clearData(context, widget.ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Widget child) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBR,
        side: BorderSide(color: ColorsUI.getBorder(context.brightness).withValues(alpha:0.3)),
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Βοηθητικές συναρτήσεις (διάλογοι, backup, import)
// ════════════════════════════════════════════════════════════════

Future<void> _showPastRemindersDialog(BuildContext context, WidgetRef ref) async {
  // Φόρτωση απευθείας — τοπική DB, χωρίς loading dialog
  final List<Reminder> reminders;
  try {
    reminders = await ref.read(pastPendingRemindersProvider.future);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Σφάλμα φόρτωσης: $e')),
      );
    }
    return;
  }

  if (!context.mounted) return;

  if (reminders.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Δεν υπάρχουν παρελθούσες υπενθυμίσεις.')),
    );
    return;
  }

  List<Reminder> mutableReminders = List.from(reminders);
  final selectedIds = <int>{};

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
          await ReminderScheduler.instance.cancelReminder(r.id);
          await SuperNoteHelper.instance.reminders.delete(r.id);
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
            await SuperNoteHelper.instance.reminders.delete(r.id);
          }
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
                ConstrainedBox(
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
                      return FutureBuilder<Item?>(
                        future: SuperNoteHelper.instance.items.getById(r.itemId),
                        builder: (_, snapshot) {
                          final item = snapshot.data;
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
                      );
                    },
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

Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
  DebugConfig.db('Settings: export backup');
  final messenger = ScaffoldMessenger.of(context);
  final successBg = context.cSuccess;
  final errorBg = context.cError;
  try {
    final path = await BackupService.instance.export();
    messenger.showSnackBar(SnackBar(
      content: Text('Εξαγωγή επιτυχής:\n$path'),
      backgroundColor: successBg,
      duration: const Duration(seconds: 4),
    ));
  } catch (e) {
    DebugConfig.error('Export failed', e);
    messenger.showSnackBar(SnackBar(
      content: Text('Σφάλμα εξαγωγής: $e'),
      backgroundColor: errorBg,
    ));
  }
}

Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
  final confirm = await ConfirmDialog.show(
    context,
    title: 'Εισαγωγή δεδομένων;',
    subtitle: 'Τα υπάρχοντα δεδομένα θα αντικατασταθούν. '
        'Η εφαρμογή θα τερματιστεί και θα χρειαστεί να την ξανανοίξετε.',
    confirmLabel: 'Εισαγωγή',
    icon: Icons.download_rounded,
  );
  if (!confirm || !context.mounted) return;

  DebugConfig.db('Settings: import backup');
  final messenger = ScaffoldMessenger.of(context);
  final errorBg = context.cError;

  try {
    final success = await BackupService.instance.import();
    if (!context.mounted) return;
    if (success) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Επιτυχής εισαγωγή'),
          content: const Text('Η εφαρμογή θα τερματιστεί τώρα.\n\n'
              'Παρακαλώ ανοίξτε την ξανά για να συνεχίσετε.'),
          actions: [
            TextButton(onPressed: () => exit(0), child: const Text('OK')),
          ],
        ),
      );
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Η εισαγωγή ακυρώθηκε ή απέτυχε')));
    }
  } catch (e) {
    DebugConfig.error('Import failed', e);
    messenger.showSnackBar(SnackBar(
      content: Text('Σφάλμα εισαγωγής: $e'),
      backgroundColor: errorBg,
    ));
  }
}

Future<void> _clearData(BuildContext context, WidgetRef ref) async {
  // Πρώτο βήμα: επιβεβαίωση διαγραφής
  final confirm = await ConfirmDialog.delete(
    context,
    title: 'Διαγραφή όλων των δεδομένων',
    subtitle: 'Όλες οι σημειώσεις, εργασίες, συνήθειες και ρυθμίσεις θα διαγραφούν ΟΡΙΣΤΙΚΑ.\n\nΑυτή η ενέργεια ΔΕΝ μπορεί να αναιρεθεί.',
    confirmLabel: 'Συνέχεια',
  );
  if (!confirm || !context.mounted) return;

  // Δεύτερο βήμα: εισαγωγή επιβεβαιωτικής φράσης
  final controller = TextEditingController();
  final confirmationText = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('ΤΕΛΙΚΗ ΕΠΙΒΕΒΑΙΩΣΗ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Για να συνεχίσετε, πληκτρολογήστε την παρακάτω φράση:',
            style: ctx.bodyMd,
          ),
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: ColorsUI.getSurface(ctx.brightness),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: ctx.cError),
            ),
            child: Text(
              'ΔΙΑΓΡΑΦΗ ΟΛΩΝ',
              style: ctx.titleSm.copyWith(
                color: ctx.cError,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Πληκτρολογήστε εδώ...',
              border: OutlineInputBorder(
                borderRadius: AppRadius.inputBR,
              ),
            ),
            onSubmitted: (_) => Navigator.pop(ctx, controller.text),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('ΑΚΥΡΟ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('ΕΠΙΒΕΒΑΙΩΣΗ'),
        ),
      ],
    ),
  );

  if (confirmationText == null || confirmationText.trim().toUpperCase() != 'ΔΙΑΓΡΑΦΗ ΟΛΩΝ') {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Η φράση επιβεβαίωσης δεν είναι σωστή. Η διαγραφή ακυρώθηκε.')),
      );
    }
    return;
  }

  // Τρίτο βήμα: πραγματική διαγραφή
  if (!context.mounted) return;
  DebugConfig.db('Settings: starting full database wipe');

  try {
    await SuperNoteHelper.instance.close();

    final isarDir = await getApplicationDocumentsDirectory();
    final isarFile = File('${isarDir.path}/super_note_db.isar');
    if (await isarFile.exists()) {
      await isarFile.delete();
      DebugConfig.db('Isar database file deleted');
    }

    // Δεν κάνουμε SuperNoteHelper.init() εδώ – θα γίνει μετά την επανεκκίνηση
    // Εμφανίζουμε dialog και κλείνουμε την εφαρμογή
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Επιτυχής διαγραφή'),
          content: const Text('Όλα τα δεδομένα διαγράφηκαν.\n\nΗ εφαρμογή θα τερματιστεί. Παρακαλώ ανοίξτε την ξανά.'),
          actions: [
            TextButton(
              onPressed: () => exit(0),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // Αν το context δεν είναι mounted, φεύγουμε κατευθείαν
      exit(0);
    }
  } catch (e) {
    DebugConfig.error('Clear all data failed', e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Σφάλμα κατά τη διαγραφή: $e'),
          backgroundColor: context.cError,
        ),
      );
    }
  }
}


// ── Βοηθητικές για τύπους items ────────────────────────────────

IconData _itemTypeIcon(ItemType type) => switch (type) {
  ItemType.note        => Icons.note_rounded,
  ItemType.task        => Icons.check_box_rounded,
  ItemType.event       => Icons.event_rounded,
  ItemType.contact     => Icons.person_rounded,
  ItemType.habit       => Icons.repeat_rounded,
  ItemType.project     => Icons.folder_special_rounded,
  ItemType.goal        => Icons.flag_rounded,
  ItemType.finance     => Icons.attach_money_rounded,
  ItemType.bookmark    => Icons.bookmark_rounded,
  ItemType.journal     => Icons.menu_book_rounded,
  ItemType.appointment => Icons.calendar_today_rounded,
  ItemType.checklist   => Icons.checklist_rounded,
  ItemType.knowledge   => Icons.lightbulb_rounded,
};

String _itemTypeLabel(ItemType type) => switch (type) {
  ItemType.note        => 'Σημείωση',
  ItemType.task        => 'Εργασία',
  ItemType.event       => 'Εκδήλωση',
  ItemType.contact     => 'Επαφή',
  ItemType.habit       => 'Συνήθεια',
  ItemType.project     => 'Project',
  ItemType.goal        => 'Στόχος',
  ItemType.finance     => 'Οικονομικά',
  ItemType.bookmark    => 'Bookmark',
  ItemType.journal     => 'Ημερολόγιο',
  ItemType.appointment => 'Ραντεβού',
  ItemType.checklist   => 'Λίστα',
  ItemType.knowledge   => 'Γνώση',
};

Future<void> _showArchivedItemsDialog(BuildContext context, WidgetRef ref) async {
  final List<Item> items;
  try {
    items = await ref.read(archivedItemsProvider.future);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Σφάλμα φόρτωσης: $e')),
      );
    }
    return;
  }

  if (!context.mounted) return;

  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Δεν υπάρχουν αρχειοθετημένα στοιχεία.')),
    );
    return;
  }

  List<Item> mutableItems = List.from(items);
  final selectedIds = <int>{};

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
          await SuperNoteHelper.instance.items.update(item.id, archived: false);
          setModal(() {
            selectedIds.remove(item.id);
            mutableItems.remove(item);
          });
          ref.invalidate(archivedItemsProvider);
          ref.invalidate(itemNotifierProvider);
          if (mutableItems.isEmpty && ctx.mounted) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        }

        // ── Βοηθητική: soft delete ενός item ──────────────────
        Future<void> deleteSingle(Item item) async {
          await SuperNoteHelper.instance.items.softDelete(item.id);
          setModal(() {
            selectedIds.remove(item.id);
            mutableItems.remove(item);
          });
          ref.invalidate(archivedItemsProvider);
          ref.invalidate(itemNotifierProvider);
          if (mutableItems.isEmpty && ctx.mounted) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        }

        // ── Βοηθητική: bulk επαναφορά ─────────────────────────
        Future<void> restoreSelected(Set<int> ids) async {
          final toRestore = mutableItems.where((i) => ids.contains(i.id)).toList();
          for (final item in toRestore) {
            await SuperNoteHelper.instance.items.update(item.id, archived: false);
          }
          setModal(() {
            mutableItems.removeWhere((i) => ids.contains(i.id));
            selectedIds.clear();
          });
          ref.invalidate(archivedItemsProvider);
          ref.invalidate(itemNotifierProvider);
          if (mutableItems.isEmpty && ctx.mounted) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        }

        // ── Βοηθητική: bulk soft delete ───────────────────────
        Future<void> deleteSelected(Set<int> ids) async {
          final toDelete = mutableItems.where((i) => ids.contains(i.id)).toList();
          for (final item in toDelete) {
            await SuperNoteHelper.instance.items.softDelete(item.id);
          }
          setModal(() {
            mutableItems.removeWhere((i) => ids.contains(i.id));
            selectedIds.clear();
          });
          ref.invalidate(archivedItemsProvider);
          ref.invalidate(itemNotifierProvider);
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
                ConstrainedBox(
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
                              _itemTypeIcon(item.type),
                              size: 12,
                              color: ctx.cText2,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _itemTypeLabel(item.type),
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
void _navigateToTrash(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashScreen()));
}

// ════════════════════════════════════════════════════════════════
// REUSABLE TILES
// ════════════════════════════════════════════════════════════════

class _ThemeTile extends StatelessWidget {
  final AppTheme current;
  final WidgetRef ref;
  const _ThemeTile({required this.current, required this.ref});

  static const _options = [
    (AppTheme.system, 'Σύστημα', Icons.brightness_auto_rounded),
    (AppTheme.light, 'Φωτεινό', Icons.wb_sunny_rounded),
    (AppTheme.dark, 'Σκοτεινό', Icons.nights_stay_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Θέμα', style: context.bodyMd),
          const SizedBox(height: Spacing.sm),
          Row(
            children: _options.map((opt) {
              final isActive = current == opt.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: GestureDetector(
                    onTap: () {
                      DebugConfig.provider('Settings: theme=${opt.$1.name}');
                      ref.read(settingsNotifierProvider.notifier).setTheme(opt.$1);
                    },
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                      decoration: BoxDecoration(
                        color: isActive ? context.cPrimary.withAlpha(30) : ColorsUI.getSurface(context.brightness),
                        borderRadius: AppRadius.buttonBR, // ✅ απευθείας
                        border: Border.all(
                          color: isActive ? context.cPrimary : ColorsUI.getBorder(context.brightness),
                          width: isActive ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(opt.$3, size: 20, color: isActive ? context.cPrimary : context.cText2),
                          const SizedBox(height: 4),
                          Text(opt.$2, style: context.labelSm.withColor(isActive ? context.cPrimary : context.cText2)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final AppLanguage current;
  final WidgetRef ref;
  const _LanguageTile({required this.current, required this.ref});

  static const _options = [
    (AppLanguage.auto, 'Αυτόματα'),
    (AppLanguage.greek, 'Ελληνικά'),
    (AppLanguage.english, 'English'),
  ];

  String get _label => _options.firstWhere((o) => o.$1 == current, orElse: () => _options.first).$2;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      title: Text('Γλώσσα', style: context.bodyMd),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_label, style: context.bodyMd.withColor(context.cText2)),
          const SizedBox(width: Spacing.xs),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.cDisabled),
        ],
      ),
      onTap: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Spacing.sm),
          Text('Γλώσσα', style: context.titleMd),
          const SizedBox(height: Spacing.xs),
          ..._options.map((opt) => ListTile(
            title: Text(opt.$2, style: context.bodyMd),
            trailing: opt.$1 == current ? Icon(Icons.check_rounded, color: context.cPrimary) : null,
            onTap: () {
              DebugConfig.provider('Settings: language=${opt.$1.name}');
              Navigator.pop(context);
              ref.read(settingsNotifierProvider.notifier).setLanguage(opt.$1);
            },
          )),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}

class _PreferredFolderTile extends ConsumerWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _PreferredFolderTile({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef r) {
    final foldersAsync = ref.watch(foldersStreamProvider);
    final preferredId = settings.preferredFolderId;

    String selectedName = 'Αυτόματος (Γενικά)';
    if (preferredId != null) {
      final folders = foldersAsync.valueOrNull ?? [];
      final folder = folders.where((f) => f.id == preferredId).firstOrNull;
      if (folder != null) {
        selectedName = '${folder.icon ?? '📁'} ${folder.name}';
      } else {
        selectedName = 'Μη διαθέσιμος';
      }
    }

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
          leading: Icon(preferredId == null ? Icons.home_rounded : Icons.folder_rounded, color: context.cText2, size: 22),
          title: Text('Προεπιλογή Φακέλου', style: context.bodyMd),
          subtitle: Text(selectedName, style: context.bodySm.withColor(context.cText2)),
          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.cDisabled),
          onTap: () => _showPicker(context, ref),
        ),
        if (preferredId != null)
          TextButton(
            onPressed: () {
              ref.read(settingsNotifierProvider.notifier).setPreferredFolder(null);
              DebugConfig.provider('Settings: reset preferred folder');
            },
            child: Text('Επαναφορά στο "Γενικά"', style: TextStyle(color: context.cPrimary, fontSize: 12)),
          ),
      ],
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.read(foldersStreamProvider);
    final folders = foldersAsync.valueOrNull ?? [];
    final currentId = settings.preferredFolderId;

    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Text('Επιλογή προεπιλεγμένου φακέλου', style: context.titleSm),
            ),
            const SizedBox(height: Spacing.sm),
            ListTile(
              leading: Icon(Icons.home_rounded, color: context.cText2),
              title: const Text('Αυτόματος (Γενικά)'),
              trailing: currentId == null ? Icon(Icons.check_rounded, color: context.cPrimary) : null,
              onTap: () {
                ref.read(settingsNotifierProvider.notifier).setPreferredFolder(null);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: folders.where((f) => !f.isSystem).length,
                itemBuilder: (_, i) {
                  final folder = folders.where((f) => !f.isSystem).toList()[i];
                  final isSelected = folder.id == currentId;
                  return ListTile(
                    leading: Text(folder.icon ?? '📁', style: const TextStyle(fontSize: 18)),
                    title: Text(folder.name, style: context.bodyMd),
                    trailing: isSelected ? Icon(Icons.check_rounded, color: context.cPrimary) : null,
                    onTap: () {
                      ref.read(settingsNotifierProvider.notifier).setPreferredFolder(folder.id);
                      Navigator.pop(context);
                      DebugConfig.provider('Settings: set preferred folder id=${folder.id}');
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }
}

class _FontScaleTile extends ConsumerWidget {
  final double current;
  final WidgetRef ref;
  const _FontScaleTile({required this.current, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Μέγεθος γραμματοσειράς', style: context.bodyMd),
                Text('${(current * 100).round()}%', style: context.bodySm.withColor(context.cText2)),
              ],
            ),
          ),
          Slider(
            value: current,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            label: '${(current * 100).round()}%',
            onChanged: (v) {
              DebugConfig.provider('Settings: fontScale=$v');
              ref.read(settingsNotifierProvider.notifier).updateSettings((s) => s.fontScale = v);
            },
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.label,
    this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      title: Text(label, style: context.bodyMd.withColor(enabled ? context.cText : context.cDisabled)),
      subtitle: subtitle != null ? Text(subtitle!, style: context.bodySm.withColor(context.cText2)) : null,
      value: enabled ? value : false,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: context.cPrimary,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.label,
    this.subtitle,
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.cText;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: context.bodyMd.withColor(c)),
      subtitle: subtitle != null ? Text(subtitle!, style: context.bodySm.withColor(context.cText2)) : null,
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.cDisabled),
      onTap: onTap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      title: Text(label, style: context.bodyMd),
      trailing: Text(value, style: context.bodyMd.withColor(context.cText2)),
    );
  }
}