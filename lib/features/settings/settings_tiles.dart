// lib/features/settings/settings_tiles.dart
//
// S253 (P2): tiles των Ρυθμίσεων (split από settings_screen.dart).
// Public symbols + direct imports (<500 γρ.).
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';
import 'settings_backup.dart';

// ════════════════════════════════════════════════════════════════
// REUSABLE TILES
// ════════════════════════════════════════════════════════════════

class SettingsSwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const SettingsSwitchTile({
    super.key,
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

class SettingsPreferredFolderTile extends ConsumerWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const SettingsPreferredFolderTile({super.key, required this.settings, required this.ref});

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
    final selectable = folders.where((f) => !f.isSystem).toList();
    final currentId = settings.preferredFolderId;

    showSafeSheet<void>(
      context,
      builder: (sheetCtx) => SafeSheet(
        title: 'Επιλογή προεπιλεγμένου φακέλου',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.home_rounded, color: sheetCtx.cText2),
              title: const Text('Αυτόματος (Γενικά)'),
              trailing: currentId == null ? Icon(Icons.check_rounded, color: sheetCtx.cPrimary) : null,
              onTap: () {
                ref.read(settingsNotifierProvider.notifier).setPreferredFolder(null);
                Navigator.pop(sheetCtx);
              },
            ),
            const Divider(height: 1),
            ...selectable.map((folder) {
              final isSelected = folder.id == currentId;
              return ListTile(
                leading: Text(folder.icon ?? '📁', style: const TextStyle(fontSize: 18)),
                title: Text(folder.name, style: sheetCtx.bodyMd),
                trailing: isSelected ? Icon(Icons.check_rounded, color: sheetCtx.cPrimary) : null,
                onTap: () {
                  ref.read(settingsNotifierProvider.notifier).setPreferredFolder(folder.id);
                  Navigator.pop(sheetCtx);
                  DebugConfig.provider('Settings: set preferred folder id=${folder.id}');
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
  final WidgetRef ref;
  const SettingsLockTimeoutTile({super.key, required this.current, required this.ref});

  static const _options = [
    (0, 'Αμέσως'),
    (30, '30 δευτερόλεπτα'),
    (60, '1 λεπτό'),
    (120, '2 λεπτά'),
    (300, '5 λεπτά'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Χρονικό όριο κλειδώματος', style: context.bodyMd),
          const SizedBox(height: Spacing.sm),
          DropdownButtonFormField<int>(
            initialValue: _options.any((o) => o.$1 == current) ? current : 0,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: AppRadius.inputBR),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm,
              ),
            ),
            items: _options.map((o) => DropdownMenuItem(
              value: o.$1,
              child: Text(o.$2, style: context.bodyMd),
            )).toList(),
            onChanged: (v) {
              if (v != null) {
                ref.read(settingsNotifierProvider.notifier).updateSettings(
                  (s) => s.appLockTimeoutSeconds = v,
                );
              }
            },
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
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = BackupService.instance.listAutoBackups();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = BackupService.instance.listAutoBackups());
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final lastRun = settings.lastAutoBackupAt == null
        ? 'Ποτέ'
        : AppDateUtils.formatDateTime(settings.lastAutoBackupAt!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSwitchTile(
          label: 'Αυτόματο αντίγραφο',
          subtitle: 'Zip κατά την έξοδο (1/24ωρο) · Τελευταίο: $lastRun',
          value: settings.autoBackupEnabled,
          onChanged: (v) {
            ref
                .read(settingsNotifierProvider.notifier)
                .setAutoBackupEnabled(v);
            _reload();
          },
        ),
        if (settings.autoBackupEnabled)
          FutureBuilder<List<String>>(
            future: _future,
            builder: (context, snap) {
              final paths = snap.data ?? const <String>[];
              if (paths.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  for (final pth in paths.take(5))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        pth.split('/').last,
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
              );
            },
          ),
      ],
    );
  }
}
