// test/lock_security_test.dart
//
// Lock-πακέτο (Session 161): pure tests — salted hash, shouldLockOnResume,
// nextLockoutSeconds. Χωρίς Isar/channels (οι pure statics δεν τα αγγίζουν).
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/crypto/pin_kdf.dart';
import 'package:super_note/services/app_lock_service.dart';

/// S-323: παράγει hash της **legacy** μορφής v1 (iterated SHA-256), όπως το
/// έγραφε η 1.3.x — για να ελεγχθεί η ανάγνωση + auto-upgrade.
String _v1Hash(String pin) {
  final salt = List<int>.generate(16, (i) => i);
  var current = <int>[...utf8.encode(pin), ...salt];
  for (var i = 0; i < AppLockService.kHashIterations; i++) {
    current = sha256.convert(current).bytes;
  }
  return 'v1\$${AppLockService.kHashIterations}\$'
      '${base64Encode(salt)}\$${base64Encode(current)}';
}

void main() {
  group('PIN KDF v2 (L2/S-323)', () {
    test('format v2\$pbkdf2-sha256\$iter\$salt\$hash', () async {
      final h =
          await AppLockService.instance.hashPin('1234', useIsolate: false);
      final parts = h.split('\$');
      expect(parts.length, 5);
      expect(parts[0], 'v2');
      expect(parts[1], PinKdf.scheme);
      expect(parts[2], '${PinKdf.defaultIterations}');
      expect(base64Decode(parts[3]).length, PinKdf.saltLength);
      expect(base64Decode(parts[4]).length, PinKdf.hashLengthBytes);
    });

    test('roundtrip + salts διαφέρουν', () async {
      final a =
          await AppLockService.instance.hashPin('1234', useIsolate: false);
      final b =
          await AppLockService.instance.hashPin('1234', useIsolate: false);
      expect(a == b, isFalse);
      expect(await AppLockService.instance.verifyPin('1234', a),
          PinVerifyOutcome.ok);
      expect(await AppLockService.instance.verifyPin('1234', b),
          PinVerifyOutcome.ok);
    });

    test('λάθος PIN απορρίπτεται', () async {
      final h =
          await AppLockService.instance.hashPin('1234', useIsolate: false);
      expect(await AppLockService.instance.verifyPin('0000', h),
          PinVerifyOutcome.mismatch);
    });

    test('v1 (iterated SHA-256) επαληθεύεται + θέλει upgrade', () async {
      final v1 = _v1Hash('1234');
      expect(await AppLockService.instance.verifyPin('1234', v1),
          PinVerifyOutcome.ok);
      expect(await AppLockService.instance.verifyPin('0000', v1),
          PinVerifyOutcome.mismatch);
      expect(AppLockService.shouldUpgradeHash(v1), isTrue);
    });

    test('legacy (64 hex) επαληθεύεται + θέλει upgrade', () async {
      final legacy = AppLockService.instance.hashPinLegacy('1234');
      expect(legacy.length, 64);
      expect(await AppLockService.instance.verifyPin('1234', legacy),
          PinVerifyOutcome.ok);
      expect(await AppLockService.instance.verifyPin('0000', legacy),
          PinVerifyOutcome.mismatch);
      expect(AppLockService.shouldUpgradeHash(legacy), isTrue);
    });

    test('πειραγμένο/άκυρο hash → mismatch (όχι exception)', () async {
      for (final bad in [
        'v1\$x',
        'v2\$pbkdf2-sha256\$1000\$aa\$bb', // κάτω από το min iterations
        'v2\$pbkdf2-sha256\$120000\$!!\$!!', // μη έγκυρο base64
        'v2\$argon2id\$120000\$aa\$bb', // άγνωστο σχήμα
        'garbage',
        '',
      ]) {
        expect(
          await AppLockService.instance.verifyPin('1234', bad),
          PinVerifyOutcome.mismatch,
          reason: bad,
        );
      }
    });

    test('άγνωστη μορφή vN → unsupported (όχι λάθος PIN)', () async {
      expect(
        await AppLockService.instance
            .verifyPin('1234', 'v3\$argon2id\$x\$y\$z'),
        PinVerifyOutcome.unsupported,
      );
    });
  });

  group('shouldLockOnResume (L1)', () {
    test('null paused → ποτέ', () {
      expect(
          AppLockService.shouldLockOnResume(
              null, DateTime(2026, 1, 1, 12, 0, 31), 30),
          isFalse);
    });

    test('πριν το timeout → όχι, στο/μετά → ναι', () {
      final paused = DateTime(2026, 1, 1, 12, 0, 0);
      expect(
          AppLockService.shouldLockOnResume(
              paused, paused.add(const Duration(seconds: 29)), 30),
          isFalse);
      expect(
          AppLockService.shouldLockOnResume(
              paused, paused.add(const Duration(seconds: 30)), 30),
          isTrue);
      expect(
          AppLockService.shouldLockOnResume(
              paused, paused.add(const Duration(hours: 2)), 30),
          isTrue);
    });

    test('timeout 0 → πάντα (όπως Timer-0)', () {
      final paused = DateTime(2026, 1, 1, 12, 0, 0);
      expect(AppLockService.shouldLockOnResume(paused, paused, 0), isTrue);
    });

    test('S-03: αρνητική διαφορά ώρας (rollback) → fail-closed', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final paused = now.add(const Duration(minutes: 5));
      expect(AppLockService.shouldLockOnResume(paused, now, 300), isTrue);
    });

    test('S-03: monotonic elapsedSeconds προτιμάται του wall', () {
      final paused = DateTime(2026, 1, 1, 12, 0, 0);
      // Wall λέει 1 ώρα, monotonic λέει 10δ → κερδίζει το monotonic.
      expect(
          AppLockService.shouldLockOnResume(
            paused,
            paused.add(const Duration(hours: 1)),
            60,
            elapsedSeconds: 10,
          ),
          isFalse);
      // Monotonic πάνω από το timeout → κλείδωμα.
      expect(
          AppLockService.shouldLockOnResume(
            paused,
            paused,
            60,
            elapsedSeconds: 60,
          ),
          isTrue);
      // Αρνητικό elapsed (προστασία) → 0 → όχι κλείδωμα.
      expect(
          AppLockService.shouldLockOnResume(
            paused,
            paused,
            60,
            elapsedSeconds: -5,
          ),
          isFalse);
    });
  });

  group('nextLockoutSeconds (L3/S-03)', () {
    test('κλίμακα: 0-4→0, 5→30, 6→60, 7→120, 8→240', () {
      expect(AppLockService.nextLockoutSeconds(0), 0);
      expect(AppLockService.nextLockoutSeconds(4), 0);
      expect(AppLockService.nextLockoutSeconds(5), 30);
      expect(AppLockService.nextLockoutSeconds(6), 60);
      expect(AppLockService.nextLockoutSeconds(7), 120);
      expect(AppLockService.nextLockoutSeconds(8), 240);
    });

    test('κλιμάκια: 9-14→300, 15-19→900, 20-29→1800, ≥30→3600', () {
      expect(AppLockService.nextLockoutSeconds(9), 300);
      expect(AppLockService.nextLockoutSeconds(14), 300);
      expect(AppLockService.nextLockoutSeconds(15), 900);
      expect(AppLockService.nextLockoutSeconds(19), 900);
      expect(AppLockService.nextLockoutSeconds(20), 1800);
      expect(AppLockService.nextLockoutSeconds(29), 1800);
      expect(AppLockService.nextLockoutSeconds(30), 3600);
      expect(AppLockService.nextLockoutSeconds(100), 3600);
      expect(AppLockService.nextLockoutSeconds(100),
          AppLockService.kMaxLockoutSeconds);
    });
  });

  group('sanitize (persisted πεδία)', () {
    test('attempts: <0→0, >10000→10000', () {
      expect(AppLockService.sanitizeAttempts(-3), 0);
      expect(AppLockService.sanitizeAttempts(0), 0);
      expect(AppLockService.sanitizeAttempts(42), 42);
      expect(AppLockService.sanitizeAttempts(99999), 10000);
    });

    test('lockout duration: ≤0→0, cap 3600', () {
      expect(AppLockService.sanitizeLockoutDuration(-1), 0);
      expect(AppLockService.sanitizeLockoutDuration(0), 0);
      expect(AppLockService.sanitizeLockoutDuration(120), 120);
      expect(AppLockService.sanitizeLockoutDuration(99999), 3600);
    });
  });

  group('remainingLockoutSeconds (S-03)', () {
    test('χωρίς ενεργό lockout → 0', () {
      expect(
          AppLockService.remainingLockoutSeconds(
            failedAttempts: 0,
            lockoutUntilEpochMs: 0,
            lockoutDurationSeconds: 0,
            lockoutMonoMs: 0,
            lastSeenWallMs: 0,
            nowEpochMs: 1000000,
          ),
          0);
      expect(
          AppLockService.remainingLockoutSeconds(
            failedAttempts: 5,
            lockoutUntilEpochMs: 0,
            lockoutDurationSeconds: 0,
            lockoutMonoMs: 0,
            lastSeenWallMs: 0,
            nowEpochMs: 1000000,
          ),
          0);
    });

    test('monotonic: αφαιρεί τον χρόνο που πέρασε', () {
      expect(
          AppLockService.remainingLockoutSeconds(
            failedAttempts: 5,
            lockoutUntilEpochMs: 0,
            lockoutDurationSeconds: 300,
            lockoutMonoMs: 1000000,
            lastSeenWallMs: 0,
            nowMonoMs: 1000000 + 120000,
            nowEpochMs: 999999999,
          ),
          180);
    });

    test('monotonic: λήξη → 0', () {
      expect(
          AppLockService.remainingLockoutSeconds(
            failedAttempts: 5,
            lockoutUntilEpochMs: 0,
            lockoutDurationSeconds: 300,
            lockoutMonoMs: 1000000,
            lastSeenWallMs: 0,
            nowMonoMs: 1000000 + 300000,
            nowEpochMs: 999999999,
          ),
          0);
    });

    test('reboot (mono < anchor) → πέφτει στο wall', () {
      expect(
          AppLockService.remainingLockoutSeconds(
            failedAttempts: 5,
            lockoutUntilEpochMs: 1300000,
            lockoutDurationSeconds: 300,
            lockoutMonoMs: 1000000,
            lastSeenWallMs: 1000000,
            nowMonoMs: 500,
            nowEpochMs: 1200000,
          ),
          100);
    });

    test('wall: στρογγυλοποίηση προς τα πάνω (ποτέ 0 όσο ενεργό)', () {
      expect(
          AppLockService.remainingLockoutSeconds(
            failedAttempts: 5,
            lockoutUntilEpochMs: 1000001,
            lockoutDurationSeconds: 300,
            lockoutMonoMs: 0,
            lastSeenWallMs: 0,
            nowEpochMs: 1000000,
          ),
          1);
    });

    test('ρολόι γύρισε πίσω → πλήρης διάρκεια (fail-closed)', () {
      expect(
          AppLockService.remainingLockoutSeconds(
            failedAttempts: 5,
            lockoutUntilEpochMs: 5000000,
            lockoutDurationSeconds: 300,
            lockoutMonoMs: 0,
            lastSeenWallMs: 2000000,
            nowEpochMs: 1000000,
          ),
          300);
    });

    test('clamp: ποτέ πάνω από τη διάρκεια', () {
      expect(
          AppLockService.remainingLockoutSeconds(
            failedAttempts: 5,
            lockoutUntilEpochMs: 9999999999,
            lockoutDurationSeconds: 60,
            lockoutMonoMs: 0,
            lastSeenWallMs: 0,
            nowEpochMs: 1000000,
          ),
          60);
    });
  });

  group('isWeakPin (S-03)', () {
    test('τετριμμένα → true', () {
      for (final pin in [
        '000000',
        '111111',
        '123456',
        '654321',
        '121212',
        '123123',
        '12341234',
        '12',
        '12a456',
      ]) {
        expect(AppLockService.isWeakPin(pin), isTrue, reason: pin);
      }
    });

    test('μη τετριμμένα 6ψήφια → false', () {
      for (final pin in ['582964', '934718', '206483']) {
        expect(AppLockService.isWeakPin(pin), isFalse, reason: pin);
      }
    });
  });

  group('shouldUpgradeHash (KDF v2 ratchet)', () {
    test('legacy/v1 → true· v2/άδειο/null/άγνωστο → false', () async {
      final legacy = AppLockService.instance.hashPinLegacy('1234');
      expect(AppLockService.shouldUpgradeHash(legacy), isTrue);
      expect(AppLockService.shouldUpgradeHash(_v1Hash('1234')), isTrue);
      final fresh =
          await AppLockService.instance.hashPin('1234', useIsolate: false);
      expect(AppLockService.shouldUpgradeHash(fresh), isFalse);
      expect(AppLockService.shouldUpgradeHash(''), isFalse);
      expect(AppLockService.shouldUpgradeHash(null), isFalse);
      expect(AppLockService.shouldUpgradeHash('v3\$argon2id\$x\$y\$z'),
          isFalse);
    });
  });
}
