// test/notification_fallback_test.dart
//
// Pure-Dart tests για NotificationService.scheduleModeFor (exact-alarm fallback).
// Χωρίς channel mocks (static pure μέθοδος).
// Τρέξιμο: flutter test test/notification_fallback_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/services/notification_service.dart';

void main() {
  group('NotificationService.scheduleModeFor', () {
    test('άδεια granted → exactAllowWhileIdle', () {
      expect(
        NotificationService.scheduleModeFor(true),
        AndroidScheduleMode.exactAllowWhileIdle,
      );
    });

    test('άδεια denied → inexactAllowWhileIdle', () {
      expect(
        NotificationService.scheduleModeFor(false),
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
    });

    test('channel-error (null) → inexactAllowWhileIdle (ασφαλής κατεύθυνση)', () {
      expect(
        NotificationService.scheduleModeFor(null),
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
    });
  });

  group('NotificationService.osAlarmLimit (M3 budget)', () {
    test('τιμές > 0 · host (android) → 450', () {
      expect(NotificationService.osAlarmLimit, 450);
      expect(NotificationService.osAlarmLimit, greaterThan(0));
    });

    test('iOS/macOS → 60 (headroom κάτω από το σκληρό 64)', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(NotificationService.osAlarmLimit, 60);
    });
  });
}
