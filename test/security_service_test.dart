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
}
