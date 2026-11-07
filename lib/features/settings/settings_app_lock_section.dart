// lib/features/settings/settings_app_lock_section.dart
//
// S-24: ατομικό toggle κλειδώματος εφαρμογής.
// Κανόνας: κανένα security effect (FLAG_SECURE / lock) πριν επιβεβαιωθεί
// το write. Σε αποτυχία: μήνυμα και αναλλοίωτη κατάσταση.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import 'settings_pin_dialogs.dart';
import 'settings_tiles.dart';

class SettingsAppLockSection extends ConsumerStatefulWidget {
  final AppSettings settings;
  const SettingsAppLockSection({super.key, required this.settings});

  @override
  ConsumerState<SettingsAppLockSection> createState() =>
      _SettingsAppLockSectionState();
}

class _SettingsAppLockSectionState extends ConsumerState<SettingsAppLockSection> {
  /// Serialize το toggle: μπλοκάρει διπλό tap/διπλό write.
  bool _busy = false;

  AppSettings get _s => widget.settings;

  Future<AppSettings?> _write(void Function(AppSettings) updater) {
    return ref.read(appLockSettingsWriterProvider)(updater);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.cError,
      ),
    );
  }

  /// Ρεαλιστική αποτυχία: restore/wipe κρατούν τη βάση κλειστή
  /// (`BackupService.isMaintenanceActive`). Άμεσο, καθαρό μήνυμα.
  void _showMaintenanceBusy() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(AppErrors.backupBusy),
        backgroundColor: context.cError,
      ),
    );
  }

  Future<void> _toggle(bool v) async {
    if (_busy) return;

    if (BackupService.instance.isMaintenanceActive) {
      _showMaintenanceBusy();
      return;
    }

    // Πρώτο enable χωρίς PIN → setup. Ακύρωση = καμία αλλαγή.
    String? pin;
    if (v && _s.appLockPinHash == null) {
      pin = await showSetPinDialog(context, ref);
      if (pin == null || !mounted) return;
    }

    setState(() => _busy = true);
    final updated = await _write((s) {
      s.appLockEnabled = v;
      if (pin != null) {
        s.appLockPinHash = AppLockService.instance.hashPin(pin);
        s.appLockPinLength = pin.length;
      }
    });
    if (!mounted) return;

    if (updated == null) {
      setState(() => _busy = false);
      _showError(AppErrors.settingsSaveFailed);
      return;
    }

    // Επιτυχές commit → το gate εφαρμόζει το committed snapshot
    // (FLAG_SECURE + lock/unlock) χωρίς δεύτερη ανάγνωση DB.
    await ref.read(lockGateProvider.notifier).applySettings(updated);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _changePin() async {
    if (_busy) return;
    if (_s.appLockPinHash != null) {
      final ok = await showCurrentPinDialog(context, ref);
      if (!ok || !mounted) return;
    }
    final pin = await showSetPinDialog(context, ref);
    if (pin == null || !mounted) return;

    setState(() => _busy = true);
    final updated = await _write((s) {
      s.appLockPinHash = AppLockService.instance.hashPin(pin);
      s.appLockPinLength = pin.length;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (updated == null) {
      _showError(AppErrors.lockGatePinSetupFailed);
    }
  }

  Future<void> _toggleBiometric(bool v) async {
    if (_busy) return;
    if (v) {
      final ok = await AppLockService.instance.authenticate();
      if (!ok || !mounted) return;
    }

    setState(() => _busy = true);
    final updated = await _write((s) => s.biometricEnabled = v);
    if (!mounted) return;
    setState(() => _busy = false);
    if (updated == null) _showError(AppErrors.settingsSaveFailed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsCard(
          child: SettingsSwitchTile(
            label: 'Κλείδωμα εφαρμογής',
            subtitle: 'PIN ή βιομετρικό ξεκλείδωμα',
            value: _s.appLockEnabled,
            busy: _busy,
            onChanged: _toggle,
          ),
        ),
        if (_s.appLockEnabled) ...[
          const SizedBox(height: Spacing.sm),
          SettingsCard(
            child: SettingsActionTile(
              label: _s.appLockPinHash != null ? 'Αλλαγή PIN' : 'Ορισμός PIN',
              subtitle: '4-6ψήφιο PIN ασφαλείας',
              icon: Icons.pin_rounded,
              onTap: _changePin,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          SettingsCard(
            child: SettingsSwitchTile(
              label: 'Βιομετρικό ξεκλείδωμα',
              subtitle: 'Αποτύπωμα / Face ID',
              value: _s.biometricEnabled,
              busy: _busy,
              onChanged: _toggleBiometric,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          SettingsCard(
            child: SettingsLockTimeoutTile(
              current: _s.appLockTimeoutSeconds,
            ),
          ),
        ],
      ],
    );
  }
}
