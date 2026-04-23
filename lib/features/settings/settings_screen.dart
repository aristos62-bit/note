// lib/features/settings/settings_screen.dart
//
// Ρυθμίσεις εφαρμογής: θέμα, γλώσσα, προεπιλεγμένος φάκελος, ειδοποιήσεις, backup/restore.
// ✅ Responsive: single col mobile / 2-col tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: provider, db logs
// ✅ Καθαρισμός παρελθουσών υπενθυμίσεων (pending, triggerAt < now)
// ✅ Επιλογή προεπιλεγμένου φακέλου
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
import 'package:file_picker/file_picker.dart';
import '../../features/trash/trash_screen.dart';

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
        backgroundColor:        context.cBg,
        elevation:              0,
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
          mobile:  _buildMobile(context, ref, settings),
          tablet:  _buildTablet(context, ref, settings),
        ),
      ),
    );
  }

  // ── Mobile — single column ───────────────────────────────────

  Widget _buildMobile(BuildContext context, WidgetRef ref,
      AppSettings settings) {
    return ListView(
      children: _buildSections(context, ref, settings),
    );
  }

  // ── Tablet/Desktop — 2-col ───────────────────────────────────

  Widget _buildTablet(BuildContext context, WidgetRef ref,
      AppSettings settings) {
    final sections = _buildSections(context, ref, settings);
    final mid      = (sections.length / 2).ceil();
    final left     = sections.sublist(0, mid);
    final right    = sections.sublist(mid);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical:   Spacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: left)),
          const SizedBox(width: Spacing.lg),
          Expanded(child: Column(children: right)),
        ],
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context, WidgetRef ref,
      AppSettings settings) {
    return [
      // ── Εμφάνιση ──────────────────────────────────────────
      _SettingsSection(
        title: 'Εμφάνιση',
        icon:  Icons.palette_outlined,
        children: [
          _ThemeTile(current: settings.theme, ref: ref),
          _SettingsDivider(),
          _FontScaleTile(current: settings.fontScale, ref: ref),
        ],
      ),

      // ── Γλώσσα ────────────────────────────────────────────
      _SettingsSection(
        title: 'Γλώσσα',
        icon:  Icons.language_rounded,
        children: [
          _LanguageTile(current: settings.language, ref: ref),
        ],
      ),

      // ✅ ΝΕΟ: Προεπιλεγμένος φάκελος ──────────────────────
      _SettingsSection(
        title: 'Προεπιλεγμένος φάκελος',
        icon:  Icons.folder_open_rounded,
        children: [
          _PreferredFolderTile(settings: settings, ref: ref),
        ],
      ),

      // ── Ειδοποιήσεις ──────────────────────────────────────
      _SettingsSection(
        title: 'Ειδοποιήσεις',
        icon:  Icons.notifications_outlined,
        children: [
          _SwitchTile(
            label:   'Ειδοποιήσεις',
            subtitle: 'Reminders και υπενθυμίσεις',
            value:   settings.notificationsEnabled,
            onChanged: (v) {
              DebugConfig.provider('Settings: notifications=$v');
              ref.read(settingsNotifierProvider.notifier)
                  .toggleNotifications(v);
            },
          ),
          _SettingsDivider(),
          _SwitchTile(
            label:   'Ήχος',
            value:   settings.soundEnabled,
            enabled: settings.notificationsEnabled,
            onChanged: (v) => ref.read(settingsNotifierProvider.notifier)
                .updateSettings((s) => s.soundEnabled = v),
          ),
          _SettingsDivider(),
          _SwitchTile(
            label:   'Δόνηση',
            value:   settings.vibrationEnabled,
            enabled: settings.notificationsEnabled,
            onChanged: (v) => ref.read(settingsNotifierProvider.notifier)
                .updateSettings((s) => s.vibrationEnabled = v),
          ),
        ],
      ),

      // ── Καθαρισμός Υπενθυμίσεων ────────────────────────────
      _SettingsSection(
        title: 'Καθαρισμός Υπενθυμίσεων',
        icon:  Icons.cleaning_services_rounded,
        children: [
          _ActionTile(
            label:    'Παρελθούσες υπενθυμίσεις',
            subtitle: 'Διαγραφή υπενθυμίσεων που έχουν ήδη λήξει',
            icon:     Icons.delete_sweep_rounded,
            onTap:    () => _showPastRemindersDialog(context, ref),
          ),
        ],
      ),

      // ── Κάδος Ανακύκλωσης ───────────────────────────────────
      _SettingsSection(
        title: 'Κάδος Ανακύκλωσης',
        icon:  Icons.delete_outline_rounded,
        children: [
          _ActionTile(
            label:    'Διαγραμμένα στοιχεία',
            subtitle: 'Επαναφορά ή οριστική διαγραφή',
            icon:     Icons.restore_from_trash_rounded,
            onTap:    () => _navigateToTrash(context),
          ),
        ],
      ),

      // ── Δεδομένα & Backup ─────────────────────────────────
      _SettingsSection(
        title: 'Δεδομένα & Backup',
        icon:  Icons.backup_outlined,
        children: [
          _ActionTile(
            label:    'Εξαγωγή δεδομένων',
            subtitle: 'Δημιουργία αντιγράφου .isar',
            icon:     Icons.upload_rounded,
            onTap:    () => _exportBackup(context, ref),
          ),
          _SettingsDivider(),
          _ActionTile(
            label:    'Εισαγωγή δεδομένων',
            subtitle: 'Επαναφορά από αντίγραφο',
            icon:     Icons.download_rounded,
            onTap:    () => _importBackup(context, ref),
          ),
          _SettingsDivider(),
          _ActionTile(
            label:       'Διαγραφή όλων των δεδομένων',
            subtitle:    'Μη αναστρέψιμη ενέργεια',
            icon:        Icons.delete_forever_rounded,
            color:       context.cError,
            onTap:       () => _clearData(context, ref),
          ),
        ],
      ),

      // ── Πληροφορίες ───────────────────────────────────────
      _SettingsSection(
        title: 'Πληροφορίες',
        icon:  Icons.info_outline_rounded,
        children: [
          const _InfoTile(label: 'Έκδοση', value: '1.0.0'),
          _SettingsDivider(),
          const _InfoTile(label: 'Βάση δεδομένων', value: 'Isar 3.1.0'),
        ],
      ),

      const SizedBox(height: Spacing.xl),
    ];
  }

  // ── Διάλογος για παρελθούσες υπενθυμίσεις ──────────────────
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
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
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
                      final title = item?.title ?? 'Αγνωστο στοιχείο';
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Άκυρο'),
              ),
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

  // ── Backup actions ───────────────────────────────────────────

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    DebugConfig.db('Settings: export backup');
    final messenger  = ScaffoldMessenger.of(context);
    final successBg  = context.cSuccess;
    final errorBg    = context.cError;

    try {
      final dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Επιλογή φακέλου για το backup',
      );

      if (dirPath == null) return;

      final path = await BackupService.instance.export(toDirectory: dirPath);

      messenger.showSnackBar(SnackBar(
        content: Text('Εξαγωγή επιτυχής:\n$path'),
        backgroundColor: successBg,
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
    final future = ConfirmDialog.show(
      context,
      title:        'Εισαγωγή δεδομένων;',
      subtitle:     'Τα υπάρχοντα δεδομένα θα αντικατασταθούν. '
          'Η εφαρμογή θα επανεκκινήσει.',
      confirmLabel: 'Εισαγωγή',
      icon:         Icons.download_rounded,
    );
    final ok = await future;
    if (!ok || !context.mounted) return;

    DebugConfig.db('Settings: import backup');
    final messenger = ScaffoldMessenger.of(context);
    final errorBg   = context.cError;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'Επιλογή αρχείου backup (.isar)',
      );

      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;

      if (!filePath.toLowerCase().endsWith('.isar')) {
        messenger.showSnackBar(SnackBar(
          content: const Text('Μη έγκυρο αρχείο backup (πρέπει να είναι .isar)'),
          backgroundColor: errorBg,
        ));
        return;
      }

      await BackupService.instance.import(fromPath: filePath);

      messenger.showSnackBar(
        const SnackBar(content: Text('Εισαγωγή επιτυχής — επανεκκίνηση...')),
      );
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
      title:        'Διαγραφή όλων των δεδομένων;',
      subtitle:     'Όλες οι σημειώσεις, εργασίες και ρυθμίσεις '
          'θα διαγραφούν οριστικά.',
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
}

// ════════════════════════════════════════════════════════════════
// ΠΡΟΕΠΙΛΕΓΜΕΝΟΣ ΦΑΚΕΛΟΣ TILE (ΝΕΟ)
// ════════════════════════════════════════════════════════════════

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
          leading: Icon(
            preferredId == null ? Icons.home_rounded : Icons.folder_rounded,
            color: context.cText2,
            size: 22,
          ),
          title: Text('Προεπιλογή', style: context.bodyMd),
          subtitle: Text(
            selectedName,
            style: context.bodySm.withColor(context.cText2),
          ),
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

// ════════════════════════════════════════════════════════════════
// THEME TILE
// ════════════════════════════════════════════════════════════════

class _ThemeTile extends StatelessWidget {
  final AppTheme current;
  final WidgetRef ref;
  const _ThemeTile({required this.current, required this.ref});

  static const _options = [
    (AppTheme.system, 'Σύστημα',  Icons.brightness_auto_rounded),
    (AppTheme.light,  'Φωτεινό',  Icons.wb_sunny_rounded),
    (AppTheme.dark,   'Σκοτεινό', Icons.nights_stay_rounded),
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
                        color: isActive ? context.cPrimary.withValues(alpha: 0.12) : ColorsUI.getSurface(context.brightness),
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

// ════════════════════════════════════════════════════════════════
// FONT SCALE TILE
// ════════════════════════════════════════════════════════════════

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

// ════════════════════════════════════════════════════════════════
// LANGUAGE TILE
// ════════════════════════════════════════════════════════════════

class _LanguageTile extends StatelessWidget {
  final AppLanguage current;
  final WidgetRef ref;
  const _LanguageTile({required this.current, required this.ref});

  static const _options = [
    (AppLanguage.auto,    'Αυτόματα'),
    (AppLanguage.greek,   'Ελληνικά'),
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
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.cText2),
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

void _navigateToTrash(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashScreen()));
}

// ════════════════════════════════════════════════════════════════
// REUSABLE TILES
// ════════════════════════════════════════════════════════════════

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

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: Spacing.md,
      endIndent: Spacing.md,
      color: ColorsUI.getBorder(context.brightness),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SETTINGS SECTION CARD
// ════════════════════════════════════════════════════════════════

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = context.isMobile ? context.responsiveHPadding : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, Spacing.md, hPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Spacing.sm, bottom: Spacing.xs),
            child: Row(children: [
              Icon(icon, size: 14, color: context.cText2),
              const SizedBox(width: Spacing.xs),
              Text(title, style: context.labelMd.withColor(context.cText2)),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
              color: ColorsUI.getSurface(context.brightness),
              borderRadius: AppRadius.cardBR,
              border: Border.all(color: ColorsUI.getBorder(context.brightness)),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.cardBR,
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}