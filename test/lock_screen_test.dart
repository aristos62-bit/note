// test/lock_screen_test.dart
//
// S-03: LockScreen — persisted lockout UI, unlock-first, 4-6 fallback.
// Χωρίς Isar: reader/writer injectable + mock monotonic channel.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/features/lock/lock_screen.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/services/app_lock_service.dart';
import 'package:super_note/services/security_service.dart';

AppSettings _settings({
  required String pin,
  int pinLength = 6,
  int attempts = 0,
  int duration = 0,
  int monoMs = 0,
  bool biometric = false,
}) {
  return AppSettings()
    ..appLockEnabled = true
    ..appLockPinLength = pinLength
    ..appLockPinHash = AppLockService.instance.hashPin(pin)
    ..appLockFailedAttempts = attempts
    ..appLockLockoutDurationSeconds = duration
    ..appLockLockoutMonoMs = monoMs
    ..biometricEnabled = biometric;
}

ProviderContainer _container(AppSettings settings) {
  final c = ProviderContainer(overrides: [
    lockGateSettingsReaderProvider.overrideWithValue(() async => settings),
    appLockSettingsWriterProvider.overrideWithValue((updater) async {
      updater(settings);
      return settings;
    }),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppThemeData.light,
      home: const LockScreen(),
    ),
  );
}

Future<void> _tapDigits(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('super_note/security');

  setUp(() {
    SecurityService.resetForTest();
    AppLockService.instance.lock();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      if (call.method == 'elapsedRealtime') return 1000000;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
    SecurityService.resetForTest();
    AppLockService.instance.unlock();
  });

  testWidgets('λάθος PIN → μήνυμα, σωστό → ξεκλείδωμα', (tester) async {
    final c = _container(_settings(pin: '123456'));

    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    expect(find.text('Εισάγετε το PIN σας'), findsOneWidget);
    expect(c.read(appLockStateProvider), isTrue);

    await _tapDigits(tester, '999999');
    await tester.pumpAndSettle();
    expect(find.text(AppErrors.pinWrong), findsOneWidget);
    expect(c.read(appLockStateProvider), isTrue);
    expect(AppLockService.instance.isLocked, isTrue);

    await _tapDigits(tester, '123456');
    await tester.pumpAndSettle();
    expect(c.read(appLockStateProvider), isFalse);
    expect(AppLockService.instance.isLocked, isFalse);
  });

  testWidgets('persisted lockout → μήνυμα + μπλοκαρισμένα ψηφία', (tester) async {
    final c = _container(_settings(
      pin: '123456',
      attempts: 5,
      duration: 300,
      monoMs: 1000000,
    ));

    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    expect(find.text(AppErrors.pinLockedOut(300)), findsOneWidget);

    await _tapDigits(tester, '1');
    await tester.pumpAndSettle();
    expect(find.text(AppErrors.pinLockedOut(300)), findsOneWidget);
    expect(c.read(appLockStateProvider), isTrue);
    expect(AppLockService.instance.isLocked, isTrue);
  });

  testWidgets('legacy/κατεστραμμένο pinLength → fallback 4-6', (tester) async {
    final c = _container(_settings(
      pin: '1234',
      pinLength: 3, // untrusted
    ));

    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    // 4 ψηφία δεν κάνουν auto-submit (untrusted) — χειροκίνητο submit.
    await _tapDigits(tester, '1234');
    await tester.pumpAndSettle();
    expect(c.read(appLockStateProvider), isTrue);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(c.read(appLockStateProvider), isFalse);
    expect(AppLockService.instance.isLocked, isFalse);
  });
}
