// test/security_service_test.dart
//
// FLAG_SECURE (Session 165): mock MethodChannel — args + no-throw.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/services/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('super_note/security');

  test('setSecure(true) στέλνει secure=true', () async {
    MethodCall? got;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      got = call;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null));
    expect(await SecurityService.setSecure(true), isTrue);
    expect(got!.method, 'setSecure');
    expect(got!.arguments, {'secure': true});
  });

  test('missing plugin → false, χωρίς throw', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
    expect(await SecurityService.setSecure(false), isFalse);
  });
}
