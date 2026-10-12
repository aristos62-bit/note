// test/lock_security_test.dart
//
// Lock-πακέτο (Session 161): pure tests — salted hash, shouldLockOnResume,
// nextLockoutSeconds. Χωρίς Isar/channels (οι pure statics δεν τα αγγίζουν).
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/services/app_lock_service.dart';

void main() {
  group('salted hash (L2)', () {
    test('format v1\$iter\$salt\$hash', () {
      final h = AppLockService.instance.hashPin('1234');
      final parts = h.split('\$');
      expect(parts.length, 4);
      expect(parts[0], 'v1');
      expect(parts[1], '${AppLockService.kHashIterations}');
    });

    test('roundtrip + salts διαφέρουν', () {
      final a = AppLockService.instance.hashPin('1234');
      final b = AppLockService.instance.hashPin('1234');
      expect(a == b, isFalse);
      expect(AppLockService.instance.verifyPin('1234', a), isTrue);
      expect(AppLockService.instance.verifyPin('1234', b), isTrue);
    });

    test('λάθος PIN απορρίπτεται', () {
      final h = AppLockService.instance.hashPin('1234');
      expect(AppLockService.instance.verifyPin('0000', h), isFalse);
    });

    test('legacy (64 hex) επαληθεύεται παλιά', () {
      final legacy = AppLockService.instance.hashPinLegacy('1234');
      expect(legacy.length, 64);
      expect(AppLockService.instance.verifyPin('1234', legacy), isTrue);
      expect(AppLockService.instance.verifyPin('0000', legacy), isFalse);
    });

    test('πειραγμένο hash απορρίπτεται', () {
      expect(AppLockService.instance.verifyPin('1234', 'v1\$x'), isFalse);
      expect(AppLockService.instance.verifyPin('1234', 'garbage'), isFalse);
      expect(AppLockService.instance.verifyPin('1234', ''), isFalse);
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
  });

  group('nextLockoutSeconds (L3)', () {
    test('<5 → 0, 5 → 30, διπλασιασμός, cap 300', () {
      expect(AppLockService.nextLockoutSeconds(0), 0);
      expect(AppLockService.nextLockoutSeconds(4), 0);
      expect(AppLockService.nextLockoutSeconds(5), 30);
      expect(AppLockService.nextLockoutSeconds(6), 60);
      expect(AppLockService.nextLockoutSeconds(7), 120);
      expect(AppLockService.nextLockoutSeconds(20), 300);
    });
  });
}
