// test/notification_permission_test.dart
//
// E08 (S284): pure mappers άδειας ειδοποιήσεων (χωρίς platform/DB).
// Κλειδώνει το fail-open: null/άγνωστο → unknown, ΠΟΤΕ denied.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/services/notification_permission.dart';

NotificationsEnabledOptions _darwin({
  required bool enabled,
  required bool provisional,
}) {
  return NotificationsEnabledOptions(
    isEnabled: enabled,
    isSoundEnabled: true,
    isAlertEnabled: true,
    isBadgeEnabled: true,
    isProvisionalEnabled: provisional,
    isCriticalEnabled: false,
  );
}

void main() {
  test('Android: true/false/null → granted/denied/unknown', () {
    expect(
      permissionStateFromAndroid(true),
      NotificationPermissionState.granted,
    );
    expect(
      permissionStateFromAndroid(false),
      NotificationPermissionState.denied,
    );
    expect(
      permissionStateFromAndroid(null),
      NotificationPermissionState.unknown,
    );
  });

  test('Darwin: enabled / provisional / disabled / null', () {
    expect(
      permissionStateFromDarwin(_darwin(enabled: true, provisional: false)),
      NotificationPermissionState.granted,
    );
    // Provisional = παραδίδεται (ήσυχα) → granted.
    expect(
      permissionStateFromDarwin(_darwin(enabled: false, provisional: true)),
      NotificationPermissionState.granted,
    );
    expect(
      permissionStateFromDarwin(_darwin(enabled: false, provisional: false)),
      NotificationPermissionState.denied,
    );
    expect(
      permissionStateFromDarwin(null),
      NotificationPermissionState.unknown,
    );
  });

  test('fail-open: denied ≠ unknown (καμία προειδοποίηση χωρίς στοιχεία)', () {
    expect(
      NotificationPermissionState.denied,
      isNot(NotificationPermissionState.unknown),
    );
    expect(
      NotificationPermissionState.granted,
      isNot(NotificationPermissionState.unknown),
    );
  });
}
