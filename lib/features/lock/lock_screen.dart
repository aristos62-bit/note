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
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _biometricFailed = false;

  int? _pinLength;

  @override
  void initState() {
    super.initState();
    _loadPinLength();
    _tryBiometric();
  }

  Future<void> _loadPinLength() async {
    final settings = await ref.read(settingsNotifierProvider.future);
    if (!mounted) return;
    final raw = settings.appLockPinLength;
    final valid = (raw >= 4 && raw <= 6) ? raw : 6;
    if (valid != raw) {
      ref.read(settingsNotifierProvider.notifier).updateSettings((s) {
        s.appLockPinLength = valid;
      });
    }
    setState(() => _pinLength = valid);
    if (_pinCtrl.text.length == valid) {
      _verifyPin();
    }
  }

  Future<void> _tryBiometric() async {
    final settings = await ref.read(settingsNotifierProvider.future);
    if (!settings.biometricEnabled) return;
    final ok = await AppLockService.instance.authenticate();
    if (ok && mounted) {
      AppLockService.instance.unlock();
      ref.read(appLockStateProvider.notifier).state = false;
    } else if (mounted) {
      setState(() => _biometricFailed = true);
    }
  }

  void _onDigit(String digit) {
    final maxLen = _pinLength ?? 6;
    if (_pinCtrl.text.length >= maxLen) return;
    setState(() => _error = null);
    _pinCtrl.text += digit;
    if (_pinCtrl.text.length == maxLen) {
      _verifyPin();
    }
  }

  void _onSubmit() {
    final pin = _pinCtrl.text;
    if (pin.length < 4) {
      setState(() => _error = 'Το PIN πρέπει να έχει τουλάχιστον 4 ψηφία');
      return;
    }
    _verifyPin();
  }

  void _onBackspace() {
    if (_pinCtrl.text.isEmpty) return;
    setState(() => _error = null);
    _pinCtrl.text = _pinCtrl.text.substring(0, _pinCtrl.text.length - 1);
  }

  Future<void> _verifyPin() async {
    final settings = await ref.read(settingsNotifierProvider.future);
    final hash = settings.appLockPinHash;
    if (hash == null) return;
    if (AppLockService.instance.verifyPin(_pinCtrl.text, hash)) {
      AppLockService.instance.unlock();
      ref.read(appLockStateProvider.notifier).state = false;
    } else {
      setState(() {
        _error = 'Λάθος PIN';
        _pinCtrl.clear();
      });
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
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
                final filled = i < _pinCtrl.text.length;
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
              hasDigits: _pinCtrl.text.isNotEmpty,
              showBiometric: _biometricFailed,
              onBiometric: _tryBiometric,
            ),
            const Spacer(flex: 3),
          ],
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
