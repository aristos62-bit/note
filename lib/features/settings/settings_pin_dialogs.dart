// lib/features/settings/settings_pin_dialogs.dart
//
// S253 (P2): PIN helpers + dialogs (split από settings_screen.dart).
//
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

/// Pure PIN validation (testable): null = έγκυρο ζεύγος.
/// S-03: νέο PIN = τουλάχιστον 6 ψηφία + όχι τετριμμένο.
String? validatePinPair(String pin, String confirm) {
  if (pin.length < 6) return AppErrors.pinTooShort;
  if (AppLockService.isWeakPin(pin)) return AppErrors.pinTooWeak;
  if (pin != confirm) return AppErrors.pinMismatch;
  return null;
}

Future<String?> showSetPinDialog(BuildContext context, WidgetRef ref) async {
  // Σκόπιμα χωρίς dispose: οι controllers πεθαίνουν μαζί με το subtree (GC).
  // Πρόωρο dispose (finally/.then) έσκασε σε S120 — use-after-dispose
  // στο pop-animation + keyboard rebuilds.
  final pinCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? error;
  DebugConfig.nav('Settings: open set-PIN dialog');

  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        final pin = pinCtrl.text;
        final confirm = confirmCtrl.text;

        return AlertDialog(
          scrollable: true,
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded),
              SizedBox(width: Spacing.sm),
              Expanded(child: Text('Ορισμός PIN')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinCtrl,
                obscureText: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Νέο PIN (6 ψηφία)',
                  border: OutlineInputBorder(borderRadius: AppRadius.inputBR),
                ),
                onChanged: (_) => setModal(() => error = null),
              ),
              const SizedBox(height: Spacing.sm),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Επιβεβαίωση PIN',
                  border: OutlineInputBorder(borderRadius: AppRadius.inputBR),
                ),
                onChanged: (_) => setModal(() => error = null),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Text(error!, style: ctx.bodySm.withColor(ctx.cError)),
                ),
            ],
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Ακύρωση'),
            ),
            FilledButton(
              onPressed: () {
                final validationError = validatePinPair(pin, confirm);
                if (validationError != null) {
                  setModal(() => error = validationError);
                  return;
                }
                Navigator.pop(ctx, pin);
              },
              child: const Text('Ορισμός'),
            ),
          ],
        );
      },
    ),
  );
}

/// S-03: κοινή πύλη επαλήθευσης τρέχοντος PIN (settings + ευαίσθητες ενέργειες).
///
/// • Διαβάζει lockout snapshot από την persisted store (fail-closed).
/// • Αν είναι σε lockout → ενημερώνει και δεν ανοίγει dialog.
/// • `pinLength` από τις ρυθμίσεις μόνο όταν είναι έμπιστο (4-6)· αλλιώς
///   δέχεται 4-6 (legacy/κατεστραμμένο).
/// • Σε επιτυχία: pop(true) αμέσως και best-effort reset/hash-upgrade.
Future<bool> showCurrentPinDialog(
  BuildContext context,
  WidgetRef ref, {
  String? subtitle,
}) async {
  final store = ref.read(appLockAttemptsStoreProvider);
  final snap = await store.snapshot();
  if (!context.mounted) return false;

  if (snap == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppErrors.sensitiveAuthUnavailable)),
    );
    return false;
  }
  if (snap.isLockedOut) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppErrors.pinLockedOut(snap.remainingSeconds))),
    );
    return false;
  }

  // Σκόπιμα χωρίς dispose: ο controller πεθαίνει μαζί με το subtree (GC).
  // Πρόωρο dispose (finally/.then) έσκασε σε S120 — use-after-dispose
  // στο pop-animation + keyboard rebuilds.
  final ctrl = TextEditingController();
  final expectedLen = snap.pinLengthTrusted ? snap.pinLength : 0;
  String? message;
  var busy = false;
  DebugConfig.nav('Settings: open current-PIN dialog');

  Future<void> submit(
    BuildContext ctx,
    void Function(void Function()) setModal,
  ) async {
    final pin = ctrl.text;
    setModal(() => busy = true);
    final r = await store.verify(pin);
    if (!ctx.mounted) return;

    switch (r.status) {
      case PinCheckStatus.ok:
        Navigator.pop(ctx, true);
        unawaited(store.finishSuccess(pin: pin, verifiedHash: r.verifiedHash));
      case PinCheckStatus.lockedOut:
      case PinCheckStatus.wrong:
        ctrl.clear();
        setModal(() {
          busy = false;
          message = r.remainingSeconds > 0
              ? AppErrors.pinLockedOut(r.remainingSeconds)
              : AppErrors.pinWrong;
        });
      case PinCheckStatus.unavailable:
        setModal(() {
          busy = false;
          message = AppErrors.sensitiveAuthUnavailable;
        });
    }
  }

  final result = await showDialog<bool?>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        final canSubmit =
            !busy && ctrl.text.length >= (expectedLen > 0 ? expectedLen : 4);

        return AlertDialog(
          scrollable: true,
          title: Row(
            children: [
              const Icon(Icons.lock_outline_rounded),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(subtitle == null ? 'Τρέχον PIN' : 'Επιβεβαίωση'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle != null) ...[
                Text(subtitle, style: ctx.bodyMd),
                const SizedBox(height: Spacing.md),
              ],
              TextField(
                controller: ctrl,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: expectedLen > 0
                      ? 'Εισάγετε το PIN ($expectedLen ψηφία)'
                      : 'Εισάγετε το PIN',
                  border: OutlineInputBorder(borderRadius: AppRadius.inputBR),
                ),
                onChanged: (_) => setModal(() => message = null),
                onSubmitted: (_) {
                  if (canSubmit) unawaited(submit(ctx, setModal));
                },
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Text(
                    message!,
                    style: ctx.bodySm.withColor(ctx.cError),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx, false),
              child: const Text('Ακύρωση'),
            ),
            FilledButton(
              onPressed: !canSubmit
                  ? null
                  : () => unawaited(submit(ctx, setModal)),
              child: const Text('Επαλήθευση'),
            ),
          ],
        );
      },
    ),
  );
  return result ?? false;
}

/// S-04: πύλη για ευαίσθητες ενέργειες (export/import/wipe/disable).
///
/// Σειρά: βιομετρικό (αν ενεργό) → PIN. Αν το lock είναι ανενεργό (ή δεν
/// υπάρχει hash) δεν απαιτείται τίποτα. Fail-closed σε αδυναμία ανάγνωσης.
Future<bool> confirmSensitiveAction(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  final store = ref.read(appLockAttemptsStoreProvider);

  AppSettings? settings;
  try {
    settings = await ref.read(lockGateSettingsReaderProvider)();
  } catch (e, s) {
    DebugConfig.error('confirmSensitiveAction.read', e, s);
    settings = null;
  }
  if (!context.mounted) return false;

  if (settings == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppErrors.sensitiveAuthUnavailable)),
    );
    return false;
  }
  if (!settings.appLockEnabled || settings.appLockPinHash == null) return true;

  // 1) Βιομετρικό — παρακάμπτει το PIN lockout (το ξεκλειδώνει κιόλας).
  if (settings.biometricEnabled) {
    final ok = await AppLockService.instance.authenticate(reason: reason);
    if (ok) {
      await store.finishSuccess();
      return true;
    }
    if (!context.mounted) return false;
  }

  // 2) PIN (με έλεγχο lockout μέσα στο dialog).
  final snap = await store.snapshot(settings: settings);
  if (!context.mounted) return false;
  if (snap == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppErrors.sensitiveAuthUnavailable)),
    );
    return false;
  }
  if (snap.isLockedOut) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppErrors.pinLockedOut(snap.remainingSeconds))),
    );
    return false;
  }
  return showCurrentPinDialog(context, ref, subtitle: reason);
}
