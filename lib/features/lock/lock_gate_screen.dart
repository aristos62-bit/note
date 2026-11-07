// lib/features/lock/lock_gate_screen.dart
//
// S-17: fail-closed lock gate overlay.
//
// Μπαίνει πάνω από τον Navigator (MaterialApp.builder) και αποφασίζει αν
// το περιεχόμενο επιτρέπεται να φανεί:
//   failed > locked > resolving > child
//
// Δεν ξεκλειδώνει ποτέ μόνο του. Το μόνο write που κάνει είναι το inline
// setup PIN όταν `enabled && pinHash == null` (Q6/4b) — απευθείας μέσω
// repository ώστε τα σφάλματα να μη χάνονται.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import '../../helpers/super_note_helper.dart';
import '../../providers/providers.dart';
import '../../services/app_lock_service.dart';
import '../../shared/widgets/empty_state.dart';
import '../settings/settings_pin_dialogs.dart';
import 'lock_screen.dart';

class LockGateScreen extends ConsumerWidget {
  const LockGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(lockGateProvider);
    final locked = ref.watch(appLockStateProvider);

    if (gate.status == LockGateStatus.failed) {
      if (gate.failure == LockGateFailure.missingPinConfig) {
        return const _PinSetupGate();
      }
      return const _GateFailure();
    }

    if (locked) return const LockScreen();

    if (gate.status == LockGateStatus.resolving) {
      return const _GateResolving();
    }

    return const SizedBox.shrink();
  }
}

/// Καλύπτει το περιεχόμενο όσο διαρκεί έλεγχος (cold/resume/retry).
/// Opaque σκόπιμα: το resume snapshot δεν πρέπει να δείξει περιεχόμενο.
class _GateResolving extends StatelessWidget {
  const _GateResolving();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: context.cPrimary,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'Έλεγχος ασφαλείας…',
                style: context.bodyMd.withColor(context.cText2),
              ),
              const SizedBox(height: Spacing.lg),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Αποτυχία ανάγνωσης/επαλήθευσης: fail-closed με ρητό retry.
class _GateFailure extends ConsumerWidget {
  const _GateFailure();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: SafeArea(
        child: EmptyState.error(
          message: AppErrors.lockGateReadFailed,
          onRetry: () => ref.read(lockGateProvider.notifier).retry(),
        ),
      ),
    );
  }
}

/// `enabled && pinHash == null`: αδύνατο να ξεκλειδώσει — inline setup.
/// (Το `showSetPinDialog` δεν μπορεί να χρησιμοποιηθεί εδώ: ανοίγει στον
/// root Navigator που βρίσκεται *κάτω* από αυτό το overlay.)
class _PinSetupGate extends ConsumerStatefulWidget {
  const _PinSetupGate();

  @override
  ConsumerState<_PinSetupGate> createState() => _PinSetupGateState();
}

class _PinSetupGateState extends ConsumerState<_PinSetupGate> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text;
    final validation = validatePinPair(pin, _confirmCtrl.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final hash = AppLockService.instance.hashPin(pin);
      await SuperNoteHelper.instance.settings.update((s) {
        s.appLockEnabled = true;
        s.appLockPinHash = hash;
        s.appLockPinLength = pin.length;
      });
      if (!mounted) return;
      ref.invalidate(settingsProvider);
      ref.invalidate(settingsNotifierProvider);
      await ref.read(lockGateProvider.notifier).resolveAfterSetup();
    } catch (e, stack) {
      DebugConfig.error('LockGate PIN setup', e, stack);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppErrors.lockGatePinSetupFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, constraints) {
            final viewportHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 0.0;
            final minHeight = viewportHeight > Spacing.xxl
                ? viewportHeight - Spacing.xxl
                : 0.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 48,
                          color: context.cPrimary,
                        ),
                        const SizedBox(height: Spacing.md),
                        Text(
                          'Απαιτείται νέο PIN',
                          style: context.titleLg,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          AppErrors.lockGatePinMissing,
                          style: context.bodyMd.withColor(context.cText2),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Spacing.lg),
                        TextField(
                          controller: _pinCtrl,
                          obscureText: true,
                          maxLength: 6,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Νέο PIN (4-6 ψηφία)',
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.inputBR,
                            ),
                          ),
                          onChanged: (_) {
                            if (_error != null) {
                              setState(() => _error = null);
                            }
                          },
                        ),
                        const SizedBox(height: Spacing.xs),
                        TextField(
                          controller: _confirmCtrl,
                          obscureText: true,
                          maxLength: 6,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Επιβεβαίωση PIN',
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.inputBR,
                            ),
                          ),
                          onSubmitted: (_) {
                            if (!_saving) _submit();
                          },
                          onChanged: (_) {
                            if (_error != null) {
                              setState(() => _error = null);
                            }
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: Spacing.sm),
                          Text(
                            _error!,
                            style: context.bodySm.withColor(context.cError),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: Spacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: Spacing.md,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.buttonBR,
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(AppErrors.lockGateSetupAction),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
