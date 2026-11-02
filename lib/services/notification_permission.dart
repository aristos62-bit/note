// lib/services/notification_permission.dart
//
// E08 (S284): καθαρή λογική μετάφρασης της άδειας ειδοποιήσεων του OS σε
// ένα μόνο tri-state. SPoT: 1 ορισμός enum + 2 pure mappers, χωρίς platform
// calls (unit-testable).
//
// ΚΑΝΟΝΑΣ (fail-open): null/άγνωστο → unknown. ΠΟΤΕ δεν συμπεραίνουμε
// «denied» από απουσία πληροφορίας — το UI δεν δείχνει προειδοποίηση.
//
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum NotificationPermissionState { granted, denied, unknown }

/// Android: `areNotificationsEnabled()` (ποτέ null στο Android — μόνο σε
/// σφάλμα καναλιού). Σε SDK < 33 επιστρέφει true αν ο χρήστης δεν μπλόκαρε
/// τις ειδοποιήσεις της εφαρμογής από τις ρυθμίσεις συστήματος.
NotificationPermissionState permissionStateFromAndroid(bool? enabled) {
  if (enabled == null) return NotificationPermissionState.unknown;
  return enabled
      ? NotificationPermissionState.granted
      : NotificationPermissionState.denied;
}

/// iOS/macOS: `checkPermissions()`. Το provisional μετρά ως granted — η
/// ειδοποίηση παραδίδεται (απλώς ήσυχα, χωρίς banner).
NotificationPermissionState permissionStateFromDarwin(
    NotificationsEnabledOptions? options) {
  if (options == null) return NotificationPermissionState.unknown;
  return options.isEnabled || options.isProvisionalEnabled
      ? NotificationPermissionState.granted
      : NotificationPermissionState.denied;
}
