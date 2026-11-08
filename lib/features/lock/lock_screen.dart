import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/app_lock_service.dart';
import '../../shared/widgets/empty_state.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _error;

  /// S-03: τίποτα δεν γίνεται δεκτό πριν διαβαστεί το persisted snapshot.
  bool _ready = false;
  bool _loadFailed = false;
  bool _verifying = false;

  int _pinLength = 6;
  bool _pinLengthTrusted = false;
  bool _bioEnabled = false;

  int _lockoutRemaining = 0;
  Timer? _lockoutTimer; // Καθαρίζει το μήνυμα στη λήξη (UI-only, cancel σε dispose).

  AppLockAttemptsStore get _store => ref.read(appLockAttemptsStoreProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// S-03: persisted snapshot (fail-closed) — χωρίς pre-auth writes.
  Future<void> _load() async {
    AppSettings? settings;
    try {
      settings = await ref.read(lockGateSettingsReaderProvider)();
    } catch (e, s) {
      DebugConfig.error('LockScreen _load', e, s);
      settings = null;
    }
    if (!mounted) return;
    if (settings == null) {
      setState(() {
        _ready = true;
        _loadFailed = true;
        _error = null;
      });
      return;
    }

    final snap = await _store.snapshot(settings: settings);
    if (!mounted) return;
    if (snap == null) {
      setState(() {
        _ready = true;
        _loadFailed = true;
      });
      return;
    }

    _bioEnabled = settings.biometricEnabled;
    _pinLength = snap.pinLength;
    _pinLengthTrusted = snap.pinLengthTrusted;

    setState(() {
      _ready = true;
      _loadFailed = false;
      _lockoutRemaining = snap.remainingSeconds;
      if (_lockoutRemaining > 0) {
        _error = AppErrors.pinLockedOut(_lockoutRemaining);
      }
    });
    if (_lockoutRemaining > 0) _scheduleLockoutClear();

    // Βιομετρικό πάντα διαθέσιμο (και escape από lockout).
    if (_bioEnabled) await _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (!_bioEnabled) return;
    try {
      final ok = await AppLockService.instance.authenticate();
      if (!mounted) return;
      if (ok) {
        AppLockService.instance.unlock();
        ref.read(appLockStateProvider.notifier).state = false;
        // Best-effort: bypass lockout + reset counter.
        unawaited(_store.finishSuccess());
      }
    } catch (e, s) {
      DebugConfig.error('LockScreen _tryBiometric', e, s);
    }
  }

  void _onDigit(String digit) {
    if (!_ready || _verifying) return;
    if (_lockoutRemaining > 0) {
      setState(() => _error = AppErrors.pinLockedOut(_lockoutRemaining));
      return;
    }
    final maxLen = _pinLengthTrusted ? _pinLength : 6;
    if (_pin.length >= maxLen) return;
    setState(() {
      _error = null;
      _pin += digit;
    });
    // Trusted: αυτόματο submit στο ακριβές μήκος. Legacy: μόνο στα 6 (4-5
    // με το κουμπί submit).
    if ((_pinLengthTrusted && _pin.length == _pinLength) ||
        (!_pinLengthTrusted && _pin.length == 6)) {
      _verifyPin();
    }
  }

  void _onSubmit() {
    if (!_ready || _verifying) return;
    if (_lockoutRemaining > 0) {
      setState(() => _error = AppErrors.pinLockedOut(_lockoutRemaining));
      return;
    }
    if (_pin.length < 4) {
      setState(() => _error = AppErrors.pinTooShort);
      return;
    }
    _verifyPin();
  }

  void _onBackspace() {
    if (_verifying || _pin.isEmpty) return;
    setState(() {
      _error = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  /// Προγραμματίζει επανέλεγχο στη λήξη του lockout (persisted snapshot).
  void _scheduleLockoutClear() {
    _lockoutTimer?.cancel();
    if (_lockoutRemaining <= 0) return;
    _lockoutTimer =
        Timer(Duration(seconds: _lockoutRemaining + 1), () async {
      if (!mounted) return;
      final snap = await _store.snapshot();
      if (!mounted) return;
      setState(() {
        _lockoutRemaining = snap?.remainingSeconds ?? 0;
        if (_lockoutRemaining == 0) _error = null;
      });
      if (_lockoutRemaining > 0) _scheduleLockoutClear();
    });
  }

  Future<void> _verifyPin() async {
    if (!_ready || _verifying) return;
    if (_lockoutRemaining > 0) {
      setState(() => _error = AppErrors.pinLockedOut(_lockoutRemaining));
      return;
    }
    final pin = _pin;
    if (pin.length < 4) return;

    setState(() => _verifying = true);
    final result = await _store.verify(pin);
    if (!mounted) return;

    switch (result.status) {
      case PinCheckStatus.ok:
        // Ξεκλείδωμα ΠΡΙΝ από το write· reset/hash-upgrade best-effort.
        DebugConfig.print('🔓 AppLock: PIN unlock ok');
        AppLockService.instance.unlock();
        ref.read(appLockStateProvider.notifier).state = false;
        unawaited(
          _store.finishSuccess(pin: pin, verifiedHash: result.verifiedHash),
        );
      case PinCheckStatus.lockedOut:
      case PinCheckStatus.wrong:
        final remaining = result.remainingSeconds;
        setState(() {
          _verifying = false;
          _pin = '';
          _lockoutRemaining = remaining;
          _error = remaining > 0
              ? AppErrors.pinLockedOut(remaining)
              : AppErrors.pinWrong;
        });
        if (remaining > 0) _scheduleLockoutClear();
      case PinCheckStatus.unavailable:
        setState(() {
          _verifying = false;
          _pin = '';
          _error = AppErrors.sensitiveAuthUnavailable;
        });
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: context.cBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadFailed) {
      return Scaffold(
        backgroundColor: context.cBg,
        body: SafeArea(
          child: EmptyState.error(
            message: AppErrors.lockGateReadFailed,
            onRetry: () {
              setState(() {
                _ready = false;
                _loadFailed = false;
              });
              _load();
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.cBg,
      body: SafeArea(
        // S104-pattern: κεντράρει όταν χωράει, κυλάει σε landscape.
        child: LayoutBuilder(
          builder: (_, constraints) {
            final viewportHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 0.0;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewportHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: context.cPrimary),
            const SizedBox(height: Spacing.md),
            Text('SuperNote', style: context.titleLg),
            const SizedBox(height: Spacing.lg),
            Text(
              'Εισάγετε το PIN σας',
              style: context.bodyMd.withColor(context.cText2),
            ),
            const SizedBox(height: Spacing.lg),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  _pinLengthTrusted ? _pinLength : 6, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? context.cPrimary : context.cText2.withValues(alpha: 0.3),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: Spacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: Text(
                  _error!,
                  style: context.bodySm.withColor(context.cError),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: Spacing.xl),
            // PIN pad
            _PinPad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              onSubmit: _onSubmit,
              hasDigits: _pin.isNotEmpty,
              showBiometric: _bioEnabled,
              onBiometric: _tryBiometric,
            ),
          ],
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

class _PinPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool hasDigits;
  final bool showBiometric;
  final VoidCallback onBiometric;

  const _PinPad({
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.hasDigits,
    required this.showBiometric,
    required this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final d in row)
                  _DigitButton(
                    digit: d,
                    onTap: () => onDigit(d),
                  ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasDigits)
                _ActionButton(
                  icon: Icons.check,
                  onTap: onSubmit,
                )
              else if (showBiometric)
                _ActionButton(
                  icon: Icons.fingerprint,
                  onTap: onBiometric,
                )
              else
                const SizedBox(width: 72),
              _DigitButton(digit: '0', onTap: () => onDigit('0')),
              _ActionButton(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DigitButton extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;

  const _DigitButton({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            child: Text(digit, style: context.titleLg.copyWith(fontSize: 28)),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: context.cText2),
          ),
        ),
      ),
    );
  }
}
