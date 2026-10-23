// lib/features/settings/settings_screen.dart
//
// Ρυθμίσεις εφαρμογής: ομαδοποιημένες σε Σύστημα και Βάση.
// ✅ Responsive: single col mobile / 2-col tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ Ομαδοποίηση με ExpansionTile, διαφανής εξωτερική κάρτα
// ✅ Κάθε επιλογή μέσα σε ξεχωριστή κάρτα
// ✅ Επιλογή μεγέθους γραμματοσειράς (Font Scale)
//
// S253 (P2): split σε 9 αρχεία (<500 γρ.) — public symbols + direct imports.
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';
import '../trash/trash_screen.dart';
import 'reminder_diagnostics_screen.dart';
import 'settings_archived_dialog.dart';
import 'settings_backup.dart';
import 'settings_colors.dart';
import 'settings_contacts_flow.dart';
import 'settings_pin_dialogs.dart';
import 'settings_reminders_dialog.dart';
import 'settings_tiles.dart';

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
          _buildCard(SettingsThemeTile(current: widget.settings.theme, ref: widget.ref)),
          const SizedBox(height: Spacing.sm),
          _buildCard(SettingsMaxAttachmentSizeTile(settings: widget.settings, ref: widget.ref)),
          const SizedBox(height: Spacing.sm),
          _buildCard(SettingsActionTile(
            label: 'Εισαγωγή επαφών',
            subtitle: 'Εισαγωγή επαφών από το τηλέφωνο',
            icon: Icons.person_add_rounded,
            onTap: () => importContactsFromDevice(context, widget.ref),
          )),
          const SizedBox(height: Spacing.sm),
          _buildCard(SettingsFontScaleTile(current: widget.settings.fontScale, ref: widget.ref)),
          const SizedBox(height: Spacing.sm),
          _buildCard(SettingsItemTypeColorsTile(
            colorsJson: widget.settings.itemTypeColorsJson,
            ref: widget.ref,
          )),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            SettingsSwitchTile(
              label: 'Ειδοποιήσεις',
              subtitle: 'Reminders και υπενθυμίσεις',
              value: widget.settings.notificationsEnabled,
              onChanged: (v) {
                DebugConfig.provider('Settings: notifications=$v');
                widget.ref.read(settingsNotifierProvider.notifier).toggleNotifications(v);
              },
            ),
          ),
          if (!NotificationService.isSupportedPlatform) ...[
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: context.cText2),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    AppErrors.notificationsUnsupportedWindows,
                    style: context.bodySm.withColor(context.cText2),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Spacing.sm),
          _buildCard(
            SettingsSwitchTile(
              label: 'Ήχος',
              value: widget.settings.soundEnabled,
              enabled: widget.settings.notificationsEnabled,
              onChanged: (v) => widget.ref
                  .read(settingsNotifierProvider.notifier)
                  .setSound(v),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            SettingsSwitchTile(
              label: 'Δόνηση',
              value: widget.settings.vibrationEnabled,
              enabled: widget.settings.notificationsEnabled,
              onChanged: (v) => widget.ref
                  .read(settingsNotifierProvider.notifier)
                  .setVibration(v),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(SettingsActionTile(
            label: 'Διάγνωση Υπενθυμίσεων',
            subtitle: 'Κατάσταση επαναλαμβανόμενων και επόμενες ειδοποιήσεις',
            icon: Icons.fact_check_outlined,
            onTap: () => navigateToReminderDiagnostics(context),
          )),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            Consumer(builder: (_, ref, __) {
              final v = ref.watch(appVersionProvider);
              return SettingsInfoTile(
                label: 'Έκδοση',
                value: v.when(data: (s) => s, loading: () => '...', error: (_, __) => '?'),
              );
            }),
          ),
          const SizedBox(height: Spacing.sm),
          // ── App Lock ───────────────────────────────────────
          _buildCard(
            SettingsSwitchTile(
              label: 'Κλείδωμα εφαρμογής',
              subtitle: 'PIN ή βιομετρικό ξεκλείδωμα',
              value: widget.settings.appLockEnabled,
              onChanged: (v) async {
                if (v && widget.settings.appLockPinHash == null) {
                  final pin = await showSetPinDialog(context, widget.ref);
                  if (pin == null) return;
                  widget.ref.read(settingsNotifierProvider.notifier).updateSettings((s) {
                    s.appLockEnabled = true;
                    s.appLockPinHash = AppLockService.instance.hashPin(pin);
                    s.appLockPinLength = pin.length;
                  });
                } else {
                  widget.ref.read(settingsNotifierProvider.notifier).updateSettings((s) {
                    s.appLockEnabled = v;
                  });
                }
                await SecurityService.setSecure(v);
                if (v && mounted) {
                  AppLockService.instance.lock();
                  widget.ref.read(appLockStateProvider.notifier).state = true;
                }
              },
            ),
          ),
          if (widget.settings.appLockEnabled) ...[
            const SizedBox(height: Spacing.sm),
            _buildCard(
              SettingsActionTile(
                label: widget.settings.appLockPinHash != null ? 'Αλλαγή PIN' : 'Ορισμός PIN',
                subtitle: '4-6ψήφιο PIN ασφαλείας',
                icon: Icons.pin_rounded,
                onTap: () async {
                  if (widget.settings.appLockPinHash != null) {
                    final ok = await showCurrentPinDialog(context, widget.ref);
                    if (!ok || !context.mounted) return;
                  }
                  if (!context.mounted) return;
                  final pin = await showSetPinDialog(context, widget.ref);
                  if (pin != null) {
                    widget.ref.read(settingsNotifierProvider.notifier).updateSettings((s) {
                      s.appLockPinHash = AppLockService.instance.hashPin(pin);
                      s.appLockPinLength = pin.length;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: Spacing.sm),
            _buildCard(
              SettingsSwitchTile(
                label: 'Βιομετρικό ξεκλείδωμα',
                subtitle: 'Αποτύπωμα / Face ID',
                value: widget.settings.biometricEnabled,
                onChanged: (v) async {
                  if (v) {
                    final ok = await AppLockService.instance.authenticate();
                    if (!ok) return;
                  }
                  widget.ref.read(settingsNotifierProvider.notifier).updateSettings((s) {
                    s.biometricEnabled = v;
                  });
                },
              ),
            ),
            const SizedBox(height: Spacing.sm),
            _buildCard(
              SettingsLockTimeoutTile(
                current: widget.settings.appLockTimeoutSeconds,
                ref: widget.ref,
              ),
            ),
          ],

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
            SettingsActionTile(
              label: 'Παρελθούσες υπενθυμίσεις',
              subtitle: 'Διαγραφή υπενθυμίσεων που έχουν ήδη λήξει',
              icon: Icons.delete_sweep_rounded,
              onTap: () => showPastRemindersDialog(context, widget.ref),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            SettingsActionTile(
              label: 'Αρχειοθετημένα',
              subtitle: 'Επαναφορά ή διαγραφή αρχειοθετημένων στοιχείων',
              icon: Icons.archive_rounded,
              onTap: () => showArchivedItemsDialog(context, widget.ref),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            SettingsActionTile(
              label: 'Κάδος Ανακύκλωσης',
              subtitle: 'Επαναφορά ή οριστική διαγραφή',
              icon: Icons.restore_from_trash_rounded,
              onTap: () => navigateToTrash(context),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            SettingsActionTile(
              label: 'Εισαγμένες επαφές',
              subtitle: 'Διαγραφή επαφών που εισήχθησαν από το κινητό',
              icon: Icons.person_remove_rounded,
              onTap: () => showImportedContactsDialog(context, widget.ref),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            SettingsActionTile(
              label: 'Εξαγωγή δεδομένων',
              subtitle: 'Δημιουργία αντιγράφου .zip',
              icon: Icons.upload_rounded,
              onTap: () => exportBackup(context, widget.ref),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            SettingsActionTile(
              label: 'Εισαγωγή δεδομένων',
              subtitle: 'Επαναφορά από αντίγραφο',
              icon: Icons.download_rounded,
              onTap: () => importBackup(context, widget.ref),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            SettingsAutoBackupTile(settings: widget.settings),
          ),
          const SizedBox(height: Spacing.sm),
          _buildCard(
            SettingsActionTile(
              label: 'Διαγραφή όλων των δεδομένων',
              subtitle: 'Μη αναστρέψιμη ενέργεια',
              icon: Icons.delete_forever_rounded,
              color: context.cError,
              onTap: () => clearAllData(context, widget.ref),
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

void navigateToTrash(BuildContext context) {
  Navigator.of(context).push(AppTransitions.slideUpRoute(const TrashScreen()));
}

void navigateToReminderDiagnostics(BuildContext context) {
  Navigator.of(context).push(
    AppTransitions.fadeRoute(const ReminderDiagnosticsScreen()),
  );
}
