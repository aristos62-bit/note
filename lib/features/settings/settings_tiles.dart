// lib/features/settings/settings_tiles.dart
//
// S253 (P2): tiles των Ρυθμίσεων (split από settings_screen.dart).
// Public symbols + direct imports (<500 γρ.).
//
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';
import 'settings_backup.dart';
import 'settings_backup_passphrase.dart';

// ════════════════════════════════════════════════════════════════
// REUSABLE TILES
// ════════════════════════════════════════════════════════════════

/// Κάρτα επιλογής — ένα σημείο για το Card styling των Ρυθμίσεων
/// (S-24: αντικαθιστά τα δύο πανομοιότυπα `_buildCard` του settings_screen).
class SettingsCard extends StatelessWidget {
  final Widget child;
  const SettingsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBR,
        side: BorderSide(
          color: ColorsUI.getBorder(context.brightness).withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  /// S-24: όσο αποθηκεύεται ασύγχρονη αλλαγή, το switch μένει ενεργό
  /// (δείχνει τη σωστή τιμή) αλλά μη διαδραστικό — όχι `enabled:false`,
  /// που θα το εμφάνιζε λανθασμένα OFF (`value: enabled ? value : false`).
  final bool busy;
  final ValueChanged<bool> onChanged;
  const SettingsSwitchTile({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    this.enabled = true,
    this.busy = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      title: Text(label, style: context.bodyMd.withColor(enabled ? context.cText : context.cDisabled)),
      subtitle: subtitle != null ? Text(subtitle!, style: context.bodySm.withColor(context.cText2)) : null,
      value: enabled ? value : false,
      onChanged: enabled && !busy ? onChanged : null,
      activeThumbColor: context.cPrimary,
    );
  }
}

class SettingsActionTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const SettingsActionTile({
    super.key,
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

class SettingsInfoTile extends StatelessWidget {
  final String label;
  final String value;
  const SettingsInfoTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      title: Text(label, style: context.bodyMd),
      trailing: Text(value, style: context.bodyMd.withColor(context.cText2)),
    );
  }
}

class SettingsThemeTile extends StatelessWidget {
  final AppTheme current;
  final WidgetRef ref;
  const SettingsThemeTile({super.key, required this.current, required this.ref});

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
              void select() {
                DebugConfig.provider('Settings: theme=${opt.$1.name}');
                ref.read(settingsNotifierProvider.notifier).setTheme(opt.$1);
              }
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: Semantics(
                    button: true,
                    selected: isActive,
                    label: opt.$2,
                    excludeSemantics: true,
                    onTap: select,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: select,
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
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}


class SettingsMaxAttachmentSizeTile extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const SettingsMaxAttachmentSizeTile({super.key, required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final value = settings.maxAttachmentSizeMB;
    final label = value == 0 ? 'Χωρίς όριο' : '$value MB';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      leading: Icon(Icons.file_upload_outlined, color: context.cText2, size: 22),
      title: Text('Ορισμός μέγιστου μεγέθους συνημμένου', style: context.bodyMd),
      subtitle: Text(label, style: context.bodySm.withColor(context.cText2)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.cDisabled),
      onTap: () => _showSizePicker(context, ref),
    );
  }

  void _showSizePicker(BuildContext context, WidgetRef ref) {
    final current = settings.maxAttachmentSizeMB;
    final options = [1, 5, 10, 20, 50, 100, 0];
    DebugConfig.nav('Settings: open size picker');
    showSafeSheet<void>(
      context,
      builder: (ctx) => SafeSheet(
        title: 'Ορισμός μέγιστου μεγέθους συνημμένου',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...options.map((mb) {
              final isActive = current == mb;
              return ListTile(
                leading: Icon(
                  isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: isActive ? ctx.cPrimary : ctx.cText2,
                ),
                title: Text(
                  mb == 0 ? 'Χωρίς όριο' : '$mb MB',
                  style: ctx.bodyMd,
                ),
                onTap: () {
                  DebugConfig.provider('Settings: maxAttachmentSizeMB=$mb');
                  ref.read(settingsNotifierProvider.notifier).updateSettings((s) => s.maxAttachmentSizeMB = mb);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }
}

class SettingsFontScaleTile extends ConsumerWidget {
  final double current;
  final WidgetRef ref;
  const SettingsFontScaleTile({super.key, required this.current, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Μέγεθος γραμματοσειράς', style: context.bodyMd),
          Text('${(current * 100).round()}%', style: context.bodySm.withColor(context.cText2)),
          const SizedBox(height: Spacing.sm),
          Slider(
            value: current,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            label: '${(current * 100).round()}%',
            semanticFormatterCallback: (v) =>
            'Μέγεθος γραμματοσειράς ${(v * 100).round()}%',
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

class SettingsLockTimeoutTile extends ConsumerWidget {
  final int current;
  const SettingsLockTimeoutTile({super.key, required this.current});

  static const _options = [
    (0, 'Αμέσως'),
    (30, '30 δευτερόλεπτα'),
    (60, '1 λεπτό'),
    (120, '2 λεπτά'),
    (300, '5 λεπτά'),
  ];

  Future<void> _onChanged(BuildContext context, WidgetRef ref, int v) async {
    // S-24: write πριν την εμφάνιση — το `current` έρχεται από τα committed
    // settings, άρα σε αποτυχία το dropdown μένει στην παλιά τιμή.
    final updated = await ref
        .read(appLockSettingsWriterProvider)((s) => s.appLockTimeoutSeconds = v);
    if (!context.mounted) return;
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppErrors.settingsSaveFailed),
          backgroundColor: context.cError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = _options.any((o) => o.$1 == current) ? current : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Χρονικό όριο κλειδώματος', style: context.bodyMd),
          const SizedBox(height: Spacing.sm),
          InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: AppRadius.inputBR),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isExpanded: true,
                items: _options.map((o) => DropdownMenuItem(
                  value: o.$1,
                  child: Text(o.$2, style: context.bodyMd),
                )).toList(),
                onChanged: (v) {
                  if (v != null && v != value) _onChanged(context, ref, v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsAutoBackupTile extends ConsumerStatefulWidget {
  final AppSettings settings;
  const SettingsAutoBackupTile({super.key, required this.settings});

  @override
  ConsumerState<SettingsAutoBackupTile> createState() => SettingsAutoBackupTileState();
}

class SettingsAutoBackupTileState extends ConsumerState<SettingsAutoBackupTile> {
  List<String> _paths = const [];

  /// E50: συνολικό μέγεθος των αυτόματων αντιγράφων (υπολογισμένο στην ίδια
  /// ανάγνωση με τη λίστα — κανένα I/O μέσα στο build).
  int _bytes = 0;

  /// S-24 pattern: όσο αποθηκεύεται η αλλαγή, το switch μένει ενεργό αλλά
  /// μη διαδραστικό (όχι `enabled:false`, που θα το έδειχνε λανθασμένα OFF).
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => unawaited(_loadPaths());

  Future<void> _loadPaths() async {
    try {
      final paths = await BackupService.instance.listAutoBackups();
      final bytes = await BackupRotation.totalBytes(paths);
      if (!mounted) return;
      setState(() {
        _paths = paths;
        _bytes = bytes;
      });
    } catch (e, s) {
      DebugConfig.error('SettingsAutoBackupTile.listAutoBackups', e, s);
    }
  }

  /// E50: anti-double-tap + maintenance guard (E33). Το switch δείχνει την
  /// τρέχουσα τιμή· μια αλλαγή τη φορά, ποτέ κατά τη διάρκεια restore/wipe.
  Future<void> _onToggle(bool v) async {
    if (_busy) return;
    if (BackupService.instance.isMaintenanceActive) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.backupBusy)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(settingsNotifierProvider.notifier)
          .setAutoBackupEnabled(v);
      if (!mounted) return;
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // E49: το `lastAutoBackupAt` γράφεται απευθείας στη DB από το
    // `BackupService` (όχι μέσω του notifier) → live stream, με fallback
    // στο snapshot όσο δεν έχει έρθει ακόμη τιμή.
    final settings =
        ref.watch(settingsStreamProvider).valueOrNull ?? widget.settings;
    // Νέο auto-backup (νέο `lastAutoBackupAt`) ⇒ refresh της λίστας.
    ref.listen<AsyncValue<AppSettings?>>(settingsStreamProvider, (prev, next) {
      if (next.valueOrNull?.lastAutoBackupAt !=
          prev?.valueOrNull?.lastAutoBackupAt) {
        _reload();
      }
    });
    final lastRun = settings.lastAutoBackupAt == null
        ? 'Ποτέ'
        : AppDateUtils.formatDateTime(settings.lastAutoBackupAt!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSwitchTile(
          label: 'Αυτόματο αντίγραφο ',
          subtitle:
              'Εάν ενεργοποιηθεί το auto-backup προστατεύει από αστοχίες μέσα στην εφαρμογή (λάθος διαγραφή, '
                  'restore από κακή κατάσταση, update που χάλασε κάτι) — όχι από uninstall/αλλαγή συσκευής/καθαρισμό δεδομένων,'
                  'που καλύπτονται ΜΟΝΟ απο την χειροκίνητη εξαγωγή δεδομένων - '
                  'Κρυπτογραφημένο .snb κατά την έξοδο (Συχνότητα 1 ανά 24ωρο) · Τελευταίο: $lastRun',
          value: settings.autoBackupEnabled,
          busy: _busy,
          onChanged: _onToggle,
        ),
        // E50: τοποθεσία/πλήθος/μέγεθος — μία γραμμή, χωρίς όριο/auto-delete.
        if (settings.autoBackupEnabled && _paths.isNotEmpty)
          SettingsInfoTile(
            label: 'Στη συσκευή',
            value:
                '${_paths.length == 1 ? '1 αντίγραφο' : '${_paths.length} αντίγραφα'}'
                ' · ${ShareFormatters.humanSize(_bytes)}',
          ),
        if (settings.autoBackupEnabled && _paths.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.xs,
            ),
            child: NotificationHintRow(
              icon: Icons.info_outline_rounded,
              text: 'Τα αντίγραφα μένουν στη συσκευή και χάνονται με '
                  'απεγκατάσταση ή διαγραφή δεδομένων.',
              compact: true,
            ),
          ),
        if (settings.autoBackupEnabled && _paths.isNotEmpty)
          Column(
            children: [
              for (final pth in _paths.take(BackupService.maxAutoBackups))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    p.basename(pth),
                    style: context.bodySm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await importBackup(context, ref,
                          fromPath: pth);
                      _reload();
                    },
                    child: const Text('Επαναφορά'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// S-307 (Δ6): «Κλείδωμα αντιγράφου».
///
/// OFF (default) → τα `.snb` χρησιμοποιούν ενσωματωμένο κλειδί (μηδέν
/// κωδικός). ON → ζητείται κωδικός και το `.snb` κρυπτογραφείται με PBKDF2.
class SettingsBackupLockTile extends ConsumerStatefulWidget {
  final AppSettings settings;
  const SettingsBackupLockTile({super.key, required this.settings});

  @override
  ConsumerState<SettingsBackupLockTile> createState() =>
      SettingsBackupLockTileState();
}

class SettingsBackupLockTileState
    extends ConsumerState<SettingsBackupLockTile> {
  bool _busy = false;

  Future<void> _onToggle(bool value) async {
    if (_busy) return;
    if (BackupService.instance.isBusy ||
        BackupService.instance.isMaintenanceActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.backupBusy)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (value) {
        // ON χωρίς κωδικό δεν έχει νόημα — ο κωδικός ζητείται ΠΡΙΝ το save.
        final passphrase = await ensureBackupPassphrase(
          context,
          requireConfirmation: !BackupPassphraseCache.instance.hasPassphrase,
        );
        if (passphrase == null || !mounted) return;
        await ref
            .read(settingsNotifierProvider.notifier)
            .setBackupLockEnabled(true);
      } else {
        await ref
            .read(settingsNotifierProvider.notifier)
            .setBackupLockEnabled(false);
        // Επιστροφή στο ενσωματωμένο κλειδί — ο κωδικός δεν χρειάζεται πια.
        BackupPassphraseCache.instance.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsStreamProvider).valueOrNull ?? widget.settings;
    return SettingsSwitchTile(
      label: 'Κλείδωμα αντιγράφου',
      subtitle: 'Με κωδικό: το αντίγραφο ζητά τον ίδιο κωδικό για επαναφορά. '
          'Χωρίς: αποθηκεύεται και επαναφέρεται χωρίς κωδικό.',
      value: settings.backupLockEnabled,
      busy: _busy,
      onChanged: _onToggle,
    );
  }
}

