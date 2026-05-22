// lib/services/notification_service.dart
//
// ═══════════════════════════════════════════════════════════════
// ΟΔΗΓΙΕΣ ΠΡΟΣΑΡΜΟΓΗΣ
// ═══════════════════════════════════════════════════════════════
//
// 1. ANDROID — android/app/src/main/AndroidManifest.xml
//    Πρόσθεσε μέσα στο <manifest>:
//
//    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//    <uses-permission android:name="android.permission.VIBRATE"/>
//    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
//    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//
//    Πρόσθεσε μέσα στο <application>:
//
//    <receiver android:exported="false"
//        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
//    <receiver android:exported="false"
//        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
//      <intent-filter>
//        <action android:name="android.intent.action.BOOT_COMPLETED"/>
//        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
//      </intent-filter>
//    </receiver>
//
// 2. IOS — ios/Runner/AppDelegate.swift
//    Αντικατέστησε με:
//
//    import UIKit
//    import Flutter
//    @UIApplicationMain
//    @objc class AppDelegate: FlutterAppDelegate {
//      override func application(
//        _ application: UIApplication,
//        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//      ) -> Bool {
//        if #available(iOS 10.0, *) {
//          UNUserNotificationCenter.current().delegate = self
//        }
//        GeneratedPluginRegistrant.register(with: self)
//        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//      }
//    }
//
// 3. ΚΑΛΕΣΕ στο main.dart ΠΡΙΝ το runApp:
//    await NotificationService.instance.init();
//
// ═══════════════════════════════════════════════════════════════

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:super_note/core/utils/debug_config.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();
  static void Function(String payload)? onNotificationTap;
  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const String _channelId    = 'super_note_reminders';
  static const String _channelName  = 'Υπενθυμίσεις';
  static const String _channelDesc  = 'Notifications για υπενθυμίσεις SuperNote';

  bool _initialized = false;

  // ─────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final localTimezone = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(localTimezone));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );

    await _createAndroidChannel();
    _initialized = true;
  }

  // ─────────────────────────────────────────────────────────
  // COLD START — Έλεγχος αν το app ξεκίνησε από notification tap
  // ─────────────────────────────────────────────────────────

  Future<String?> getLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        return details?.notificationResponse?.payload;
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // PERMISSIONS — Κάλεσε μετά το onboarding
  // ─────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    DebugConfig.notif('NotificationService.requestPermission: called');

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (android != null) {
      DebugConfig.notif('NotificationService.requestPermission: android impl found');
      final result = await android.requestNotificationsPermission() ?? false;
      DebugConfig.notif(
        'NotificationService.requestPermission: android result=$result',
      );
      return result;
    }

    if (ios != null) {
      DebugConfig.notif('NotificationService.requestPermission: iOS impl found');
      final result = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ??
          false;
      DebugConfig.notif(
        'NotificationService.requestPermission: iOS result=$result',
      );
      return result;
    }

    DebugConfig.notif(
      'NotificationService.requestPermission: no platform-specific impl, returning false',
    );
    return false;
  }


  // ─────────────────────────────────────────────────────────
  // SHOW / SCHEDULE / CANCEL
  // ─────────────────────────────────────────────────────────

  Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool sound     = true,
    bool vibration = true,
  }) async {
    if (!_initialized) return;
    await _plugin.show(
      id, title, body,
      _details(sound: sound, vibration: vibration),
      payload: payload,
    );
  }

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
    bool sound     = true,
    bool vibration = true,
  }) async {
    if (!_initialized) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      _details(sound: sound, vibration: vibration),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }


  // ─────────────────────────────────────────────────────────
  // PRIVATE
  // ─────────────────────────────────────────────────────────

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId, _channelName,
      description: _channelDesc,
      importance: Importance.high,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  NotificationDetails _details({
    bool sound     = true,
    bool vibration = true,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance:      Importance.high,
      priority:        Priority.high,
      enableVibration: vibration,
      playSound:       sound,
      silent:          !sound,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: sound,
    ),
  );

  static void _onTap(NotificationResponse r) {
    DebugConfig.notif('NotificationService._onTap: payload=${r.payload}');
    if (r.payload != null && onNotificationTap != null) {
      onNotificationTap!(r.payload!);
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundTap(NotificationResponse r) {
    // Ίδιο με foreground
  }
}