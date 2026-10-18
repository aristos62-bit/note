// lib/features/settings/settings_pin_dialogs.dart
//
// S253 (P2): PIN helpers + dialogs (split από settings_screen.dart).
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';

/// Pure PIN validation (testable): null = έγκυρο ζεύγος.
String? validatePinPair(String pin, String confirm) {
  if (pin.length < 4) return AppErrors.pinTooShort;
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
                  labelText: 'Νέο PIN (4-6 ψηφία)',
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

Future<bool> showCurrentPinDialog(BuildContext context, WidgetRef ref) async {
  // Σκόπιμα χωρίς dispose: ο controller πεθαίνει μαζί με το subtree (GC).
  // Πρόωρο dispose (finally/.then) έσκασε σε S120 — use-after-dispose
  // στο pop-animation + keyboard rebuilds.
  final ctrl = TextEditingController();
  bool failed = false;
  DebugConfig.nav('Settings: open current-PIN dialog');

  final result = await showDialog<bool?>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        return AlertDialog(
          scrollable: true,
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded),
              SizedBox(width: Spacing.sm),
              Expanded(child: Text('Τρέχον PIN')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                obscureText: true,
                maxLength: 6,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Εισάγετε το τρέχον PIN',
                  border: OutlineInputBorder(borderRadius: AppRadius.inputBR),
                ),
                onChanged: (_) => setModal(() => failed = false),
              ),
              if (failed)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Text(
                    AppErrors.pinWrong,
                    style: ctx.bodySm.withColor(ctx.cError),
                  ),
                ),
            ],
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ακύρωση'),
            ),
            FilledButton(
              onPressed: () async {
                final settings = await ref.read(settingsProvider.future);
                final hash = settings.appLockPinHash;
                if (hash != null && AppLockService.instance.verifyPin(ctrl.text, hash)) {
                  if (AppLockService.shouldUpgradeHash(hash)) {
                    await ref.read(settingsNotifierProvider.notifier).updateSettings(
                        (s) => s.appLockPinHash =
                            AppLockService.instance.hashPin(ctrl.text));
                    DebugConfig.notif('AppLock: hash upgraded to v1 (settings)');
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                } else {
                  if (!ctx.mounted) return; // S253: το dialog έκλεισε κατά το await
                  setModal(() => failed = true);
                }
              },
              child: const Text('Επαλήθευση'),
            ),
          ],
        );
      },
    ),
  );
  return result ?? false;
}
