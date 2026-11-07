// test/lock_gate_test.dart
//
// S-17: fail-closed lock gate — state machine + overlay contract.
// Χωρίς Isar: ο reader είναι injectable (lockGateSettingsReaderProvider).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/features/lock/lock_gate_screen.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/services/app_lock_service.dart';
import 'package:super_note/services/security_service.dart';

AppSettings _settings({
  bool enabled = false,
  String? hash = 'v1\$1\$x\$y',
  int timeoutSeconds = 0,
}) {
  return AppSettings()
    ..appLockEnabled = enabled
    ..appLockPinHash = hash
    ..appLockTimeoutSeconds = timeoutSeconds;
}

ProviderContainer _containerWith(
  Future<AppSettings?> Function() reader, {
  LockGateTimeouts timeouts = const LockGateTimeouts(),
}) {
  final container = ProviderContainer(overrides: [
    lockGateSettingsReaderProvider.overrideWithValue(reader),
    lockGateTimeoutsProvider.overrideWithValue(timeouts),
  ]);
  addTearDown(container.dispose);
  return container;
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppThemeData.light,
      home: const LockGateScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('super_note/security');

  setUp(() {
    AppLockService.instance.unlock();
    SecurityService.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
    SecurityService.resetForTest();
  });

  group('LockGateController', () {
    test('enabled + hash → ready & locked', () async {
      final c = _containerWith(() async => _settings(enabled: true));
      await c.read(lockGateProvider.notifier).resolveCold();

      final state = c.read(lockGateProvider);
      expect(state.status, LockGateStatus.ready);
      expect(state.enabled, isTrue);
      expect(c.read(appLockStateProvider), isTrue);
      expect(AppLockService.instance.isLocked, isTrue);
    });

    test('enabled χωρίς PIN → failed(missingPinConfig) & locked', () async {
      final c = _containerWith(() async => _settings(enabled: true, hash: null));
      await c.read(lockGateProvider.notifier).resolveCold();

      final state = c.read(lockGateProvider);
      expect(state.status, LockGateStatus.failed);
      expect(state.failure, LockGateFailure.missingPinConfig);
      expect(c.read(appLockStateProvider), isTrue);
    });

    test('null γραμμή settings → failed(missingPinConfig)', () async {
      final c = _containerWith(() async => null);
      await c.read(lockGateProvider.notifier).resolveCold();

      final state = c.read(lockGateProvider);
      expect(state.status, LockGateStatus.failed);
      expect(state.failure, LockGateFailure.missingPinConfig);
    });

    test('σφάλμα ανάγνωσης → failed(readFailed) & locked', () async {
      final c = _containerWith(() async => throw StateError('db'));
      await c.read(lockGateProvider.notifier).resolveCold();

      final state = c.read(lockGateProvider);
      expect(state.status, LockGateStatus.failed);
      expect(state.failure, LockGateFailure.readFailed);
      expect(c.read(appLockStateProvider), isTrue);
    });

    test('disabled → ready, enabled=false, χωρίς lock', () async {
      final c = _containerWith(() async => _settings(enabled: false));
      await c.read(lockGateProvider.notifier).resolveCold();

      final state = c.read(lockGateProvider);
      expect(state.status, LockGateStatus.ready);
      expect(state.enabled, isFalse);
      expect(c.read(appLockStateProvider), isFalse);
      expect(AppLockService.instance.isLocked, isFalse);
    });

    test('failure lock → retry disabled → ξεκλειδώνει (reconciliation)',
        () async {
      var calls = 0;
      final c = _containerWith(() async {
        calls++;
        if (calls == 1) throw StateError('transient db');
        return _settings(enabled: false);
      });

      await c.read(lockGateProvider.notifier).resolveCold();
      expect(c.read(appLockStateProvider), isTrue);

      await c.read(lockGateProvider.notifier).retry();
      expect(c.read(lockGateProvider).status, LockGateStatus.ready);
      expect(c.read(appLockStateProvider), isFalse);
      expect(AppLockService.instance.isLocked, isFalse);
    });

    test('timeout → failed(readFailed) (fail-closed)', () async {
      final never = Completer<AppSettings?>();
      final c = _containerWith(
        () => never.future,
        timeouts: const LockGateTimeouts(
          cold: Duration(milliseconds: 20),
          resume: Duration(milliseconds: 20),
          retry: Duration(milliseconds: 20),
        ),
      );

      await c.read(lockGateProvider.notifier).resolveCold();
      expect(c.read(lockGateProvider).failure, LockGateFailure.readFailed);
      expect(c.read(appLockStateProvider), isTrue);
    });

    test('resume πριν το timeout → μένει ξεκλείδωτο', () async {
      final c = _containerWith(
        () async => _settings(enabled: true, timeoutSeconds: 60),
      );
      await c.read(lockGateProvider.notifier).resolveCold();
      AppLockService.instance.unlock();
      c.read(appLockStateProvider.notifier).state = false;

      await c.read(lockGateProvider.notifier).resolveResume(
            DateTime.now().subtract(const Duration(seconds: 5)),
          );

      expect(c.read(lockGateProvider).status, LockGateStatus.ready);
      expect(c.read(appLockStateProvider), isFalse);
    });

    test('resume μετά το timeout → ξανακλειδώνει (L1)', () async {
      final c = _containerWith(
        () async => _settings(enabled: true, timeoutSeconds: 60),
      );
      await c.read(lockGateProvider.notifier).resolveCold();
      AppLockService.instance.unlock();
      c.read(appLockStateProvider.notifier).state = false;

      await c.read(lockGateProvider.notifier).resolveResume(
            DateTime.now().subtract(const Duration(hours: 1)),
          );

      expect(c.read(lockGateProvider).status, LockGateStatus.ready);
      expect(c.read(appLockStateProvider), isTrue);
      expect(AppLockService.instance.isLocked, isTrue);
    });

    test('resume: unlock όσο τρέχει το resolve ΔΕΝ ξανακλειδώνει', () async {
      final pending = Completer<AppSettings?>();
      var calls = 0;
      final c = _containerWith(() {
        calls++;
        if (calls == 1) {
          return Future.value(_settings(enabled: true, timeoutSeconds: 60));
        }
        return pending.future;
      });

      await c.read(lockGateProvider.notifier).resolveCold();
      expect(c.read(appLockStateProvider), isTrue);

      final inFlight = c.read(lockGateProvider.notifier).resolveResume(
            DateTime.now().subtract(const Duration(hours: 1)),
          );

      // Νόμιμο unlock (PIN/biometric) όσο το gate περιμένει τη DB.
      AppLockService.instance.unlock();
      c.read(appLockStateProvider.notifier).state = false;

      pending.complete(_settings(enabled: true, timeoutSeconds: 60));
      await inFlight;

      expect(c.read(lockGateProvider).status, LockGateStatus.ready);
      expect(c.read(appLockStateProvider), isFalse);
      expect(AppLockService.instance.isLocked, isFalse);
    });

    test('Q8: resolveResume(null) δεν αλλάζει τίποτα', () async {
      final c = _containerWith(() async => _settings(enabled: false));
      await c.read(lockGateProvider.notifier).resolveCold();
      await c.read(lockGateProvider.notifier).resolveResume(null);

      expect(c.read(lockGateProvider).status, LockGateStatus.ready);
      expect(c.read(appLockStateProvider), isFalse);
    });

    test('markPaused ακυρώνει in-flight resolve', () async {
      final pending = Completer<AppSettings?>();
      final c = _containerWith(() => pending.future);
      final inFlight = c.read(lockGateProvider.notifier).resolveCold();
      c.read(lockGateProvider.notifier).markPaused();
      pending.complete(_settings(enabled: false));
      await inFlight;

      // Το αποτέλεσμα αγνοήθηκε → παραμένει resolving (blocked).
      expect(c.read(lockGateProvider).status, LockGateStatus.resolving);
      expect(c.read(appContentBlockedProvider), isTrue);
    });

    test('appContentBlocked: resolving/failed → true, ready → ανάλογα', () async {
      final c = _containerWith(() async => _settings(enabled: false));
      expect(c.read(appContentBlockedProvider), isTrue);

      await c.read(lockGateProvider.notifier).resolveCold();
      expect(c.read(appContentBlockedProvider), isFalse);

      c.read(appLockStateProvider.notifier).state = true;
      expect(c.read(appContentBlockedProvider), isTrue);
    });

    test('default timeouts: cold 5s / resume 2s / retry 5s', () {
      const t = LockGateTimeouts();
      expect(t.cold, const Duration(seconds: 5));
      expect(t.resume, const Duration(seconds: 2));
      expect(t.retry, const Duration(seconds: 5));
    });
  });

  group('LockGateScreen overlay', () {
    testWidgets('resolving → opaque «Έλεγχος ασφαλείας…»', (tester) async {
      final never = Completer<AppSettings?>();
      final c = _containerWith(() => never.future);

      await tester.pumpWidget(_app(c));
      await tester.pump();

      expect(find.text('Έλεγχος ασφαλείας…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('readFailed → μήνυμα + retry', (tester) async {
      var calls = 0;
      final c = _containerWith(() async {
        calls++;
        if (calls == 1) throw StateError('db');
        return _settings(enabled: false);
      });
      await c.read(lockGateProvider.notifier).resolveCold();

      await tester.pumpWidget(_app(c));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(AppErrors.lockGateReadFailed), findsOneWidget);

      await tester.tap(find.text('Δοκίμασε ξανά'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(c.read(lockGateProvider).status, LockGateStatus.ready);
      expect(find.byType(Scaffold), findsNothing);
    });

    testWidgets('missingPinConfig → inline φόρμα (2 πεδία)', (tester) async {
      final c = _containerWith(() async => _settings(enabled: true, hash: null));
      await c.read(lockGateProvider.notifier).resolveCold();

      await tester.pumpWidget(_app(c));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Απαιτείται νέο PIN'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text(AppErrors.lockGateSetupAction), findsOneWidget);
    });

    testWidgets('ready + unlocked → καθαρό child (SizedBox.shrink)',
        (tester) async {
      final c = _containerWith(() async => _settings(enabled: false));
      await c.read(lockGateProvider.notifier).resolveCold();

      await tester.pumpWidget(_app(c));
      await tester.pump();

      expect(find.byType(Scaffold), findsNothing);
    });
  });
}
