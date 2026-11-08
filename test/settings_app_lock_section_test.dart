// test/settings_app_lock_section_test.dart
//
// S-24: ατομικό toggle κλειδώματος — κανένα security effect πριν το write.
// Χωρίς Isar: ο writer είναι injectable (appLockSettingsWriterProvider).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/features/settings/settings_app_lock_section.dart';
import 'package:super_note/features/settings/settings_tiles.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/services/app_lock_service.dart';
import 'package:super_note/services/security_service.dart';

AppSettings _base({
  bool enabled = false,
  String? hash,
  int timeoutSeconds = 0,
}) {
  return AppSettings()
    ..appLockEnabled = enabled
    ..appLockPinHash = hash
    ..appLockTimeoutSeconds = timeoutSeconds
    ..appLockPinLength = 6;
}

const _pin = '582964';

/// Πραγματικό hash — το S-04 gate επαληθεύει με verifyPin.
String _realHash() => AppLockService.instance.hashPin(_pin);

AppSettings _lockedSettings() {
  final hash = _realHash();
  return AppSettings()
    ..appLockEnabled = true
    ..appLockPinLength = 6
    ..appLockPinHash = hash;
}

ProviderContainer _container(
  AppLockSettingsWriter writer, {
  Future<AppSettings?> Function()? reader,
}) {
  final container = ProviderContainer(overrides: [
    appLockSettingsWriterProvider.overrideWithValue(writer),
    if (reader != null)
      lockGateSettingsReaderProvider.overrideWithValue(reader),
  ]);
  addTearDown(container.dispose);
  return container;
}

Widget _app(ProviderContainer container, AppSettings settings) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppThemeData.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SettingsAppLockSection(settings: settings),
        ),
      ),
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
    AppLockService.instance.unlock();
  });

  group('SettingsAppLockSection — toggle', () {
    testWidgets('enable (χωρίς PIN) → PIN dialog → write + lock',
        (tester) async {
      final writes = <AppSettings>[];
      final c = _container((updater) async {
        final s = _base();
        updater(s);
        writes.add(s);
        return s;
      });

      await tester.pumpWidget(_app(c, _base()));
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Το dialog ορίσματος PIN εμφανίστηκε (κανένα write ακόμα).
      expect(find.text('Ορισμός PIN'), findsOneWidget);
      expect(writes, isEmpty);

      await tester.enterText(find.byType(TextField).at(0), _pin);
      await tester.enterText(find.byType(TextField).at(1), _pin);
      await tester.pump(); // flush το onChanged/rebuild πριν το tap

      await tester.tap(find.text('Ορισμός'));
      await tester.pumpAndSettle();

      expect(writes, hasLength(1));
      expect(writes.single.appLockEnabled, isTrue);
      expect(writes.single.appLockPinHash, isNotNull);
      expect(writes.single.appLockPinLength, 6);

      // Επιτυχές commit → το gate εφαρμόζει το committed snapshot.
      expect(c.read(lockGateProvider).status, LockGateStatus.ready);
      expect(c.read(appLockStateProvider), isTrue);
      expect(AppLockService.instance.isLocked, isTrue);
    });

    testWidgets('ακύρωση PIN dialog → κανένα write, καμία αλλαγή',
        (tester) async {
      final writes = <AppSettings>[];
      final c = _container((updater) async {
        final s = _base();
        updater(s);
        writes.add(s);
        return s;
      });

      await tester.pumpWidget(_app(c, _base()));
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ακύρωση'));
      await tester.pumpAndSettle();

      expect(writes, isEmpty);
      expect(c.read(appLockStateProvider), isFalse);
      expect(AppLockService.instance.isLocked, isFalse);
    });

    testWidgets('enable: αποτυχία write → snackbar, κανένα security effect',
        (tester) async {
      var calls = 0;
      final c = _container((updater) async {
        calls++;
        return null; // αποτυχία write
      });

      await tester.pumpWidget(_app(c, _base()));
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), _pin);
      await tester.enterText(find.byType(TextField).at(1), _pin);
      await tester.pump(); // flush το onChanged/rebuild πριν το tap

      await tester.tap(find.text('Ορισμός'));
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text(AppErrors.settingsSaveFailed), findsOneWidget);
      expect(c.read(appLockStateProvider), isFalse);
      expect(AppLockService.instance.isLocked, isFalse);
    });

    testWidgets('disable → PIN gate → write(false) + unlock', (tester) async {
      final locked = _lockedSettings();
      final writes = <AppSettings>[];
      final c = _container(
        (updater) async {
          final s = _lockedSettings();
          updater(s);
          writes.add(s);
          return s;
        },
        reader: () async => locked,
      );

      // Προσομοίωση «κλειδωμένης» εφαρμογής πριν το disable.
      AppLockService.instance.lock();
      c.read(appLockStateProvider.notifier).state = true;

      await tester.pumpWidget(_app(c, locked));
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // S-04: απαιτείται PIN πριν το disable.
      expect(find.text('Επιβεβαίωση'), findsOneWidget);
      expect(writes, isEmpty);

      await tester.enterText(find.byType(TextField).first, _pin);
      await tester.pump();
      await tester.tap(find.text('Επαλήθευση'));
      await tester.pumpAndSettle();

      expect(writes, hasLength(1));
      expect(writes.single.appLockEnabled, isFalse);
      expect(writes.single.appLockFailedAttempts, 0);
      expect(writes.single.appLockLockoutDurationSeconds, 0);
      expect(c.read(lockGateProvider).status, LockGateStatus.ready);
      expect(c.read(appLockStateProvider), isFalse);
      expect(AppLockService.instance.isLocked, isFalse);
    });

    testWidgets('disable: λάθος PIN → κανένα write', (tester) async {
      final locked = _lockedSettings();
      final writes = <AppSettings>[];
      final c = _container(
        (updater) async {
          final s = _lockedSettings();
          updater(s);
          writes.add(s);
          return s;
        },
        reader: () async => locked,
      );

      await tester.pumpWidget(_app(c, locked));
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '999999');
      await tester.pump();
      await tester.tap(find.text('Επαλήθευση'));
      await tester.pumpAndSettle();

      // Καταγράφηκε μόνο η αποτυχία (counter) — καμία απενεργοποίηση.
      expect(writes, hasLength(1));
      expect(writes.single.appLockEnabled, isTrue);
      expect(writes.single.appLockFailedAttempts, 1);
      expect(find.text(AppErrors.pinWrong), findsOneWidget);
    });

    testWidgets('disable: αποτυχία write → snackbar, παραμένει κλειδωμένο',
        (tester) async {
      final locked = _lockedSettings();
      final c = _container(
        (updater) async => null,
        reader: () async => locked,
      );

      AppLockService.instance.lock();
      c.read(appLockStateProvider.notifier).state = true;

      await tester.pumpWidget(_app(c, locked));
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, _pin);
      await tester.pump();
      await tester.tap(find.text('Επαλήθευση'));
      await tester.pumpAndSettle();

      expect(find.text(AppErrors.settingsSaveFailed), findsOneWidget);
      expect(c.read(appLockStateProvider), isTrue);
      expect(AppLockService.instance.isLocked, isTrue);
    });

    testWidgets('busy: δεύτερο tap όσο εκκρεμεί write αγνοείται',
        (tester) async {
      final locked = _lockedSettings();
      final pending = Completer<AppSettings?>();
      var calls = 0;
      final c = _container(
        (updater) async {
          calls++;
          return pending.future;
        },
        reader: () async => locked,
      );

      await tester.pumpWidget(_app(c, locked));
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, _pin);
      await tester.pump();
      await tester.tap(find.text('Επαλήθευση'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(calls, 1);

      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      expect(calls, 1);

      pending.complete(_base(enabled: false));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });
  });

  group('SettingsLockTimeoutTile', () {
    testWidgets('αποτυχία write → snackbar, η τιμή μένει στην παλιά',
        (tester) async {
      var calls = 0;
      final c = ProviderContainer(overrides: [
        appLockSettingsWriterProvider.overrideWithValue((updater) async {
          calls++;
          return null;
        }),
      ]);
      addTearDown(c.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppThemeData.light,
            home: const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SettingsLockTimeoutTile(current: 0),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Αμέσως'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 λεπτό').last);
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text(AppErrors.settingsSaveFailed), findsOneWidget);
      // Controlled από το `current` → επιστρέφει στην παλιά τιμή.
      expect(find.text('Αμέσως'), findsOneWidget);
    });
  });
}
