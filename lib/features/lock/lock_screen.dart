import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';
import '../../services/app_lock_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _error;
  bool _biometricFailed = false;

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer; // Καθαρίζει το μήνυμα στη λήξη (UI-only, cancel σε dispose).

  int? _pinLength;
  bool _bioEnabled = false;
  String? _pinHash;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Μοναδικό φόρτωμα ρυθμίσεων (αντί 3): μήκος + hash + biometric.
  Future<void> _loadSettings() async {
    try {
      final settings = await ref.read(settingsNotifierProvider.future);
      if (!mounted) return;
      final raw = settings.appLockPinLength;
      final valid = (raw >= 4 && raw <= 6) ? raw : 6;
      if (valid != raw) {
        ref.read(settingsNotifierProvider.notifier).updateSettings((s) {
          s.appLockPinLength = valid;
        });
      }
      _bioEnabled = settings.biometricEnabled;
      _pinHash = settings.appLockPinHash;
      setState(() => _pinLength = valid);
      if (_pin.length == valid) {
        _verifyPin();
      }
      await _tryBiometric();
    } catch (e, s) {
      DebugConfig.error('LockScreen _loadSettings', e, s);
    }
  }

  Future<void> _tryBiometric() async {
    try {
      if (!_bioEnabled) return;
      final ok = await AppLockService.instance.authenticate();
      if (ok && mounted) {
        AppLockService.instance.unlock();
        ref.read(appLockStateProvider.notifier).state = false;
      } else if (mounted) {
        setState(() => _biometricFailed = true);
      }
    } catch (e, s) {
      DebugConfig.error('LockScreen _tryBiometric', e, s);
    }
  }

  void _onDigit(String digit) {
    if (_lockoutRemaining() > 0) {
      setState(() => _error = AppErrors.pinLockedOut(_lockoutRemaining()));
      return;
    }
    final maxLen = _pinLength ?? 6;
    if (_pin.length >= maxLen) return;
    setState(() {
      _error = null;
      _pin += digit;
    });
    if (_pin.length == maxLen) {
      _verifyPin();
    }
  }

  void _onSubmit() {
    if (_pin.length < 4) {
      setState(() => _error = AppErrors.pinTooShort);
      return;
    }
    _verifyPin();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _error = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  /// Προγραμματίζει καθαρισμό του μηνύματος στη λήξη του lockout.
  void _scheduleLockoutClear(int lockSecs) {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer(Duration(seconds: lockSecs), () {
      if (!mounted) return;
      // Μόνο αν όντως έληξε (όχι νεότερο lockout στο μεταξύ).
      if (_lockoutRemaining() == 0) {
        setState(() => _error = null);
      }
    });
  }
  /// Υπόλοιπο lockout σε δευτερόλεπτα (0 = ελεύθερο).
  int _lockoutRemaining() {
    if (_lockoutUntil == null) return 0;
    final left = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return left > 0 ? left : 0;
  }

  Future<void> _verifyPin() async {
    if (_lockoutRemaining() > 0) {
      if (mounted) {
        setState(
            () => _error = AppErrors.pinLockedOut(_lockoutRemaining()));
      }
      return;
    }
    final hash = _pinHash;
    if (hash == null) return;
    if (AppLockService.instance.verifyPin(_pin, hash)) {
      if (AppLockService.shouldUpgradeHash(hash)) {
        final newHash = AppLockService.instance.hashPin(_pin);
        await ref.read(settingsNotifierProvider.notifier).updateSettings(
            (s) => s.appLockPinHash = newHash);
        _pinHash = newHash;
        DebugConfig.notif('AppLock: hash upgraded to v1 (lock)');
      }
      DebugConfig.print('🔓 AppLock: PIN unlock ok');
      _failedAttempts = 0;
      _lockoutUntil = null;
      _lockoutTimer?.cancel();
      AppLockService.instance.unlock();
      ref.read(appLockStateProvider.notifier).state = false;
    } else {
      DebugConfig.print('🔓 AppLock: wrong PIN');
      _failedAttempts++;
      final lockSecs =
          AppLockService.nextLockoutSeconds(_failedAttempts);
      if (lockSecs > 0) {
        _lockoutUntil = DateTime.now().add(Duration(seconds: lockSecs));
        DebugConfig.print(
            '🔒 AppLock: lockout $_failedAttempts fails ($lockSecs s)');
        _scheduleLockoutClear(lockSecs);
      }
      if (!mounted) return;
      setState(() {
        _error = lockSecs > 0
            ? AppErrors.pinLockedOut(lockSecs)
            : AppErrors.pinWrong;
        _pin = '';
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
              children: List.generate(_pinLength ?? 6, (i) {
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
              Text(_error!, style: context.bodySm.withColor(context.cError)),
            ],
            const SizedBox(height: Spacing.xl),
            // PIN pad
            _PinPad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              onSubmit: _onSubmit,
              hasDigits: _pin.isNotEmpty,
              showBiometric: _biometricFailed,
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
