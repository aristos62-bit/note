import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import '../core/utils/debug_config.dart';

class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  final LocalAuthentication _auth = LocalAuthentication();

  bool _locked = false;
  bool get isLocked => _locked;

  String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  bool verifyPin(String pin, String hash) {
    return hashPin(pin) == hash;
  }

  void lock() {
    _locked = true;
    DebugConfig.print('🔒 AppLock: locked');
  }

  void unlock() {
    _locked = false;
    DebugConfig.print('🔓 AppLock: unlocked');
  }

  Future<bool> authenticate({String? reason}) async {
    try {
      final available = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!available) return false;
      return await _auth.authenticate(
        localizedReason: reason ?? 'Ξεκλείδωμα εφαρμογής',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e, s) {
      DebugConfig.error('AppLockService.authenticate', e, s);
      return false;
    }
  }

  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e, s) {
      DebugConfig.error('AppLockService.isDeviceSupported', e, s);
      return false;
    }
  }
}
