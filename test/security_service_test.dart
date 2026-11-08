// test/security_service_test.dart
//
// FLAG_SECURE (S165) + S-17 idempotency: mock MethodChannel — args,
// skip-on-same-value, no-throw, failures not cached.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/services/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('super_note/security');

  var calls = 0;

  void mockSuccess() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      calls++;
      return null;
    });
  }

  setUp(() {
    SecurityService.resetForTest();
    calls = 0;
    mockSuccess();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
    SecurityService.resetForTest();
  });

  test('setSecure(true) στέλνει secure=true', () async {
    MethodCall? got;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      got = call;
      calls++;
      return null;
    });
    expect(await SecurityService.setSecure(true), isTrue);
    expect(got!.method, 'setSecure');
    expect(got!.arguments, {'secure': true});
    expect(calls, 1);
  });

  test('missing plugin → false, χωρίς throw', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
    expect(await SecurityService.setSecure(false), isFalse);
  });

  test('idempotent: ίδια τιμή → κανένα δεύτερο channel call', () async {
    expect(await SecurityService.setSecure(true), isTrue);
    expect(await SecurityService.setSecure(true), isTrue);
    expect(calls, 1);

    expect(await SecurityService.setSecure(false), isTrue);
    expect(calls, 2);
  });

  test('αποτυχία ΔΕΝ cache-άρεται — το retry ξαναστέλνει', () async {
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      attempts++;
      if (attempts == 1) {
        throw PlatformException(code: 'boom');
      }
      return null;
    });

    expect(await SecurityService.setSecure(true), isFalse);
    expect(await SecurityService.setSecure(true), isTrue);
    expect(attempts, 2);
  });

  group('elapsedRealtimeMs (S-03)', () {
    test('επιστρέφει την τιμή και cache-άρει ~1s', () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (call) async {
        if (call.method == 'elapsedRealtime') {
          calls++;
          return 123456;
        }
        return null;
      });

      expect(await SecurityService.elapsedRealtimeMs(), 123456);
      expect(await SecurityService.elapsedRealtimeMs(), 123456);
      expect(calls, 1);

      // force → νέα κλήση ακόμη και μέσα στο παράθυρο cache.
      expect(await SecurityService.elapsedRealtimeMs(force: true), 123456);
      expect(calls, 2);
    });

    test('missing plugin → null, χωρίς throw', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, null);
      expect(await SecurityService.elapsedRealtimeMs(), isNull);
    });

    test('σφάλμα channel → null, χωρίς throw', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (call) async {
        throw PlatformException(code: 'boom');
      });
      expect(await SecurityService.elapsedRealtimeMs(), isNull);
    });

    test('null/αρνητική τιμή → null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (call) async => null);
      expect(await SecurityService.elapsedRealtimeMs(), isNull);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (call) async => -1);
      expect(await SecurityService.elapsedRealtimeMs(), isNull);
    });

    test('resetForTest καθαρίζει το cache', () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (call) async {
        calls++;
        return 5000;
      });

      expect(await SecurityService.elapsedRealtimeMs(), 5000);
      SecurityService.resetForTest();
      expect(await SecurityService.elapsedRealtimeMs(), 5000);
      expect(calls, 2);
    });
  });
}
