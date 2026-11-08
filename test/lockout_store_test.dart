// test/lockout_store_test.dart
//
// S-03: persisted lockout store — verify/lockout/finishSuccess χωρίς Isar
// (reader/writer injectable) και με mock monotonic channel.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/services/app_lock_service.dart';
import 'package:super_note/services/security_service.dart';

const _pin = '123456';

AppSettings _settings({
  String? hash,
  int attempts = 0,
  int duration = 0,
  int untilMs = 0,
  int monoMs = 0,
  int lastSeenMs = 0,
}) {
  return AppSettings()
    ..appLockEnabled = true
    ..appLockPinLength = 6
    ..appLockPinHash = hash
    ..appLockFailedAttempts = attempts
    ..appLockLockoutDurationSeconds = duration
    ..appLockLockoutUntilEpochMs = untilMs
    ..appLockLockoutMonoMs = monoMs
    ..appLockLastSeenWallMs = lastSeenMs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('super_note/security');

  late AppSettings state;
  late int writes;
  late int monoNow;

  ProviderContainer container(AppSettings initial) {
    state = initial;
    writes = 0;
    final c = ProviderContainer(overrides: [
      lockGateSettingsReaderProvider.overrideWithValue(() async => state),
      appLockSettingsWriterProvider.overrideWithValue((updater) async {
        writes++;
        updater(state);
        return state;
      }),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    monoNow = 1000000;
    SecurityService.resetForTest();
    AppLockService.instance.unlock();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      if (call.method == 'elapsedRealtime') return monoNow;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
    SecurityService.resetForTest();
    AppLockService.instance.unlock();
  });

  group('snapshot', () {
    test('διαβάζει attempts + remaining (monotonic)', () async {
      final c = container(_settings(
        attempts: 5,
        duration: 300,
        monoMs: 1000000,
      ));
      final snap = await c.read(appLockAttemptsStoreProvider).snapshot();

      expect(snap, isNotNull);
      expect(snap!.failedAttempts, 5);
      expect(snap.remainingSeconds, 300);
      expect(snap.isLockedOut, isTrue);
      expect(snap.pinLength, 6);
      expect(snap.pinLengthTrusted, isTrue);
    });

    test('αφαιρεί τον monotonic χρόνο που πέρασε', () async {
      monoNow = 1120000; // +120s
      final c = container(_settings(
        attempts: 5,
        duration: 300,
        monoMs: 1000000,
      ));
      final snap = await c.read(appLockAttemptsStoreProvider).snapshot();
      expect(snap!.remainingSeconds, 180);
    });

    test('μη έμπιστο pinLength → trusted=false + fallback 6', () async {
      final c = container(_settings(attempts: 0));
      state.appLockPinLength = 2;
      final snap = await c.read(appLockAttemptsStoreProvider).snapshot();
      expect(snap!.pinLengthTrusted, isFalse);
      expect(snap.pinLength, 6);
    });

    test('reader null → null (fail-closed)', () async {
      final c = ProviderContainer(overrides: [
        lockGateSettingsReaderProvider.overrideWithValue(() async => null),
      ]);
      addTearDown(c.dispose);
      expect(await c.read(appLockAttemptsStoreProvider).snapshot(), isNull);
    });
  });

  group('verify', () {
    test('ενεργό lockout → lockedOut, χωρίς write', () async {
      final c = container(_settings(
        hash: AppLockService.instance.hashPin(_pin),
        attempts: 5,
        duration: 300,
        monoMs: 1000000,
      ));

      final r = await c.read(appLockAttemptsStoreProvider).verify(_pin);
      expect(r.status, PinCheckStatus.lockedOut);
      expect(r.remainingSeconds, 300);
      expect(writes, 0);
    });

    test('σωστό PIN → ok + verifiedHash, χωρίς write', () async {
      final hash = AppLockService.instance.hashPin(_pin);
      final c = container(_settings(hash: hash));

      final r = await c.read(appLockAttemptsStoreProvider).verify(_pin);
      expect(r.status, PinCheckStatus.ok);
      expect(r.verifiedHash, hash);
      expect(writes, 0);
    });

    test('λάθος PIN (κάτω από το tier) → wrong, καμία lockout', () async {
      final c = container(
        _settings(hash: AppLockService.instance.hashPin(_pin)),
      );

      final r = await c.read(appLockAttemptsStoreProvider).verify('999999');
      expect(r.status, PinCheckStatus.wrong);
      expect(r.remainingSeconds, 0);
      expect(writes, 1);
      expect(state.appLockFailedAttempts, 1);
      expect(state.appLockLockoutDurationSeconds, 0);
      expect(state.appLockLockoutMonoMs, 0);
    });

    test('5η αποτυχία → 30δ lockout persisted (wall + mono)', () async {
      final c = container(_settings(
        hash: AppLockService.instance.hashPin(_pin),
        attempts: 4,
      ));

      final before = DateTime.now().millisecondsSinceEpoch;
      final r = await c.read(appLockAttemptsStoreProvider).verify('999999');
      expect(r.status, PinCheckStatus.wrong);
      expect(r.remainingSeconds, 30);

      expect(writes, 1);
      expect(state.appLockFailedAttempts, 5);
      expect(state.appLockLockoutDurationSeconds, 30);
      expect(state.appLockLockoutMonoMs, 1000000);
      expect(state.appLockLastSeenWallMs, greaterThanOrEqualTo(before));
      expect(
        state.appLockLockoutUntilEpochMs,
        greaterThanOrEqualTo(before + 29000),
      );
    });

    test('χωρίς hash → unavailable, χωρίς write', () async {
      final c = container(_settings());

      final r = await c.read(appLockAttemptsStoreProvider).verify(_pin);
      expect(r.status, PinCheckStatus.unavailable);
      expect(writes, 0);
    });
  });

  group('finishSuccess', () {
    test('μηδενίζει μετρητές όταν χρειάζεται', () async {
      final c = container(_settings(
        hash: AppLockService.instance.hashPin(_pin),
        attempts: 3,
      ));

      await c.read(appLockAttemptsStoreProvider).finishSuccess();
      expect(writes, 1);
      expect(state.appLockFailedAttempts, 0);
      expect(state.appLockLockoutDurationSeconds, 0);
      expect(state.appLockLockoutUntilEpochMs, 0);
      expect(state.appLockLockoutMonoMs, 0);
    });

    test('no-op όταν είναι ήδη καθαρό', () async {
      final c = container(_settings(
        hash: AppLockService.instance.hashPin(_pin),
      ));

      await c.read(appLockAttemptsStoreProvider).finishSuccess();
      expect(writes, 0);
    });

    test('legacy hash → upgrade μόνο μετά από verified hash', () async {
      final legacy = AppLockService.instance.hashPinLegacy(_pin);
      final c = container(_settings(hash: legacy, attempts: 0));

      final r = await c.read(appLockAttemptsStoreProvider).verify(_pin);
      expect(r.status, PinCheckStatus.ok);
      expect(r.verifiedHash, legacy);

      await c
          .read(appLockAttemptsStoreProvider)
          .finishSuccess(pin: _pin, verifiedHash: r.verifiedHash);
      expect(writes, 1);
      expect(state.appLockPinHash, isNot(legacy));
      expect(
        AppLockService.instance.verifyPin(_pin, state.appLockPinHash!),
        isTrue,
      );
    });
  });
}
