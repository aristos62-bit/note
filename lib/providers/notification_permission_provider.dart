// lib/providers/notification_permission_provider.dart
//
// E08 (S284): κατάσταση άδειας ειδοποιήσεων του OS (read-only).
// Mirror του appVersionProvider: 1 FutureProvider, χωρίς autoDispose —
// 1 cached τιμή. Ανανεώνεται με invalidate όταν αλλάζει το OS
// (main.dart: μετά το requestPermission + σε κάθε resumed).
//
import 'package:riverpod/riverpod.dart';
import '../services/notification_permission.dart';
import '../services/notification_service.dart';

final notificationPermissionProvider =
    FutureProvider<NotificationPermissionState>((ref) {
  return NotificationService.instance.permissionStatus();
});
