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

  /// Μέγιστο lockout (cap) — 1 ώρα.
  static const int kMaxLockoutSeconds = 3600;

  /// Lockout κλίμακα (S-03): 5→30δ, 6→60δ, 7→120δ, 8→240δ, 9-14→5λ,
  /// 15-19→15λ, 20-29→30λ, ≥30→60λ (cap). 0 = κανένα lockout.
  static int nextLockoutSeconds(int failedAttempts) {
    if (failedAttempts < 5) return 0;
    if (failedAttempts == 5) return 30;
    if (failedAttempts == 6) return 60;
    if (failedAttempts == 7) return 120;
    if (failedAttempts == 8) return 240;
    if (failedAttempts < 15) return 300;
    if (failedAttempts < 20) return 900;
    if (failedAttempts < 30) return 1800;
    return kMaxLockoutSeconds;
  }

  /// L1: κλείδωμα στο resumed αν παρήλθε το timeout (timer-fallback).
  ///
  /// S-03: όταν δίνεται `elapsedSeconds` (monotonic) προτιμάται — δεν
  /// παρακάμπτεται με αλλαγή ρολογιού. Χωρίς monotonic (desktop), αρνητική
  /// διαφορά ώρας = ρολόι γύρισε πίσω → fail-closed (κλείδωμα).
  static bool shouldLockOnResume(
    DateTime? pausedAt,
    DateTime now,
    int timeoutSeconds, {
    int? elapsedSeconds,
  }) {
    if (elapsedSeconds != null) {
      final elapsed = elapsedSeconds < 0 ? 0 : elapsedSeconds;
      return elapsed >= timeoutSeconds;
    }
    if (pausedAt == null) return false;
    final diff = now.difference(pausedAt).inSeconds;
    if (diff < 0) return true;
    return diff >= timeoutSeconds;
  }

  // ── S-03: persisted lockout helpers (pure, χωρίς I/O) ─────────

  static int sanitizeAttempts(int value) {
    if (value < 0) return 0;
    return value > 10000 ? 10000 : value;
  }

  static int sanitizeLockoutDuration(int value) {
    if (value <= 0) return 0;
    return value > kMaxLockoutSeconds ? kMaxLockoutSeconds : value;
  }

  /// Υπόλοιπο lockout σε δευτερόλεπτα (0 = ελεύθερο).
  ///
  /// Προτεραιότητα: monotonic (αν έγκυρο για την ίδια boot) → wall.
  /// Αν το ρολόι γύρισε πίσω → fail-closed (πλήρης διάρκεια).
  static int remainingLockoutSeconds({
    required int failedAttempts,
    required int lockoutUntilEpochMs,
    required int lockoutDurationSeconds,
    required int lockoutMonoMs,
    required int lastSeenWallMs,
    int? nowMonoMs,
    int? nowEpochMs,
  }) {
    final attempts = sanitizeAttempts(failedAttempts);
    final duration = sanitizeLockoutDuration(lockoutDurationSeconds);
    if (attempts < 5 || duration == 0) return 0;

    final nowWall = nowEpochMs ?? DateTime.now().millisecondsSinceEpoch;

    // 1) Monotonic — μόνο αν έχουμε άγκυρα και τρέχουσα τιμή ≥ άγκυρας
    //    (μικρότερη = reboot → πέφτουμε στο wall).
    if (nowMonoMs != null && lockoutMonoMs > 0 && nowMonoMs >= lockoutMonoMs) {
      final elapsedSec = (nowMonoMs - lockoutMonoMs) ~/ 1000;
      final left = duration - elapsedSec;
      if (left <= 0) return 0;
      return left > duration ? duration : left;
    }

    // 2) Wall fallback.
    if (lastSeenWallMs > 0 && nowWall < lastSeenWallMs) return duration;
    if (lockoutUntilEpochMs <= 0) return 0;
    final leftMs = lockoutUntilEpochMs - nowWall;
    if (leftMs <= 0) return 0;
    final left = (leftMs + 999) ~/ 1000; // ceil — ποτέ «0 δ» όσο είναι ενεργό
    return left > duration ? duration : left;
  }

  /// S-03: τετριμμένα PIN (000000, 123456, 121212, 123123, ...).
  static bool isWeakPin(String pin) {
    if (pin.length < 4) return true;
    final digits = <int>[];
    for (final code in pin.codeUnits) {
      final d = code - 0x30;
      if (d < 0 || d > 9) return true;
      digits.add(d);
    }

    var allSame = true;
    for (final d in digits) {
      if (d != digits.first) {
        allSame = false;
        break;
      }
    }
    if (allSame) return true;

    var ascending = true;
    var descending = true;
    for (var i = 1; i < digits.length; i++) {
      if (digits[i] != digits[i - 1] + 1) ascending = false;
      if (digits[i] != digits[i - 1] - 1) descending = false;
    }
    if (ascending || descending) return true;

    // Επαναλαμβανόμενο block (121212, 123123, 12341234, ...).
    for (var blockLen = 1; blockLen <= pin.length ~/ 2; blockLen++) {
      if (pin.length % blockLen != 0) continue;
      final block = pin.substring(0, blockLen);
      var repeated = true;
      for (var i = blockLen; i < pin.length; i += blockLen) {
        if (pin.substring(i, i + blockLen) != block) {
          repeated = false;
          break;
        }
      }
      if (repeated) return true;
    }
    return false;
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

  /// true = legacy hash προς αναβάθμιση (χωρίς `$`)· άδειο/νέο → false.
  /// Καλείται ΜΟΝΟ μετά επιτυχές verify (garbage αποκλείεται από το verify).
  static bool shouldUpgradeHash(String? stored) =>
      stored != null && stored.isNotEmpty && !stored.contains('\$');

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
