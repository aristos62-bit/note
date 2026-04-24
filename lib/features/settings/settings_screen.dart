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

// ── Provider για παρελθούσες pending υπενθυμίσεις ──────────────
final pastPendingRemindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final allReminders = await SuperNoteHelper.instance.reminders.getPending();
  final now = DateTime.now();
  return allReminders.where((r) => r.triggerAt.isBefore(now)).toList();
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
// ΣΥΣΤΗΜΑ GROUP (ExpansionTile, διαφανής εξωτερική κάρτα)
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
        borderRadius: AppRadius.cardBR,
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
        borderRadius: AppRadius.cardBR,
        side: BorderSide(color: ColorsUI.getBorder(context.brightness).withOpacity(0.3)),
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ΒΑΣΗ GROUP (ExpansionTile, διαφανής εξωτερική κάρτα)
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
        side: BorderSide(color: ColorsUI.getBorder(context.brightness).withOpacity(0.3)),
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Βοηθητικές συναρτήσεις (διάλογοι, backup, import)
// ════════════════════════════════════════════════════════════════

Future<void> _showPastRemindersDialog(BuildContext context, WidgetRef ref) async {
  final reminders = await ref.read(pastPendingRemindersProvider.future);
  if (reminders.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Δεν υπάρχουν παρελθούσες υπενθυμίσεις.')),
    );
    return;
  }

  List<Reminder> mutableReminders = List.from(reminders);
  final selectedIds = <int>{};

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: Spacing.sm),
              Text('Παρελθούσες Υπενθυμίσεις (${mutableReminders.length})'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: mutableReminders.length,
              separatorBuilder: (_, __) => const Divider(),
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
                      title: Text(title, style: context.bodyMd),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Τύπος: $type', style: context.bodySm.withColor(context.cText2)),
                          Text('Έπρεπε να εμφανιστεί: ${AppDateUtils.formatDateTime(r.triggerAt)}',
                              style: context.bodySm.withColor(context.cError)),
                        ],
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          await ReminderScheduler.instance.cancelReminder(r.id);
                          await SuperNoteHelper.instance.reminders.delete(r.id);
                          setModal(() {
                            selectedIds.remove(r.id);
                            mutableReminders.remove(r);
                          });
                          ref.invalidate(pastPendingRemindersProvider);
                          if (!context.mounted) return;
                          if (mutableReminders.isEmpty) Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Άκυρο')),
            if (selectedIds.isNotEmpty)
              TextButton(
                onPressed: () async {
                  for (final id in selectedIds.toList()) {
                    await ReminderScheduler.instance.cancelReminder(id);
                    await SuperNoteHelper.instance.reminders.delete(id);
                  }
                  setModal(() {
                    selectedIds.clear();
                    mutableReminders.removeWhere((r) => selectedIds.contains(r.id));
                  });
                  ref.invalidate(pastPendingRemindersProvider);
                  if (!context.mounted) return;
                  if (mutableReminders.isEmpty) Navigator.pop(ctx);
                },
                child: Text('Διαγραφή επιλεγμένων (${selectedIds.length})'),
              ),
            TextButton(
              onPressed: () async {
                final confirm = await ConfirmDialog.show(
                  ctx,
                  title: 'Διαγραφή όλων;',
                  subtitle: 'Θα διαγραφούν όλες οι παρελθούσες υπενθυμίσεις.',
                  confirmLabel: 'Ναι, διαγραφή όλων',
                );
                if (confirm != true) return;
                for (final r in mutableReminders) {
                  await ReminderScheduler.instance.cancelReminder(r.id);
                  await SuperNoteHelper.instance.reminders.delete(r.id);
                }
                ref.invalidate(pastPendingRemindersProvider);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
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
  final future = ConfirmDialog.delete(
    context,
    title: 'Διαγραφή όλων των δεδομένων;',
    subtitle: 'Όλες οι σημειώσεις, εργασίες και ρυθμίσεις θα διαγραφούν οριστικά.',
    confirmLabel: 'Διαγραφή όλων',
  );
  final ok = await future;
  if (!ok || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final errorBg = context.cError;
  DebugConfig.db('Settings: clear all data');
  messenger.showSnackBar(SnackBar(
    content: const Text('Η λειτουργία δεν είναι διαθέσιμη ακόμα.'),
    backgroundColor: errorBg,
  ));
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
                        borderRadius: AppRadius.buttonBR,
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
          title: Text('Προεπιλογή', style: context.bodyMd),
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