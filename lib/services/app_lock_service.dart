import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import '../core/utils/debug_config.dart';

class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  /// Iterations iterated-SHA256 (κόστος/brute-force· σπάνιο op).
  static const int kHashIterations = 100000;

  /// Lockout κλίμακα: 5→30δ, διπλασιασμός, cap 5λ. 0 = κανένα lockout.
  static int nextLockoutSeconds(int failedAttempts) {
    if (failedAttempts < 5) return 0;
    var secs = 30 * (1 << (failedAttempts - 5));
    if (secs > 300) secs = 300;
    return secs;
  }

  /// L1: κλείδωμα στο resumed αν παρήλθε το timeout (timer-fallback).
  static bool shouldLockOnResume(
      DateTime? pausedAt, DateTime now, int timeoutSeconds) {
    if (pausedAt == null) return false;
    return now.difference(pausedAt).inSeconds >= timeoutSeconds;
  }

  final LocalAuthentication _auth = LocalAuthentication();

  bool _locked = false;
  bool get isLocked => _locked;

  /// Format `v1$iterations$saltB64$hashB64` — salt+iterations, ίδιο πεδίο
  /// (χωρίς migration). Legacy (64 hex, χωρίς `$`) επαληθεύεται παλιά.
  String hashPin(String pin) {
    final salt =
        List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final hash = _stretch(utf8.encode(pin), salt, kHashIterations);
    return 'v1\$$kHashIterations\$${base64Encode(salt)}\$${base64Encode(hash)}';
  }

  bool verifyPin(String pin, String hash) {
    if (!hash.contains('\$')) {
      // Legacy pre-salt — επαληθεύεται παλιά (αναβάθμιση στο επόμενο set).
      return hashPinLegacy(pin) == hash;
    }
    try {
      final parts = hash.split('\$');
      if (parts.length != 4 || parts[0] != 'v1') return false;
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 1) return false;
      final salt = base64Decode(parts[2]);
      final expected = base64Decode(parts[3]);
      final actual = _stretch(utf8.encode(pin), salt, iterations);
      return _constantTimeEquals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  /// Legacy SHA-256 (προ-salt) — μόνο για επαλήθευση παλιών hashes.
  String hashPinLegacy(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  List<int> _stretch(List<int> pin, List<int> salt, int iterations) {
    var current = <int>[...pin, ...salt];
    for (var i = 0; i < iterations; i++) {
      current = sha256.convert(current).bytes;
    }
    return current;
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
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
