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

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

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
  // PERMISSIONS — Κάλεσε μετά το onboarding
  // ─────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    if (ios != null) {
      return await ios.requestPermissions(
          alert: true, badge: true, sound: true) ??
          false;
    }
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
  }) async {
    await _plugin.show(id, title, body, _details(), payload: payload);
  }

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      _details(),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();

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

  NotificationDetails _details() => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static void _onTap(NotificationResponse r) {
    // TODO: GoRouter navigation με payload (itemId)
    // AppRouter.instance.push('/item/${r.payload}');
  }

  @pragma('vm:entry-point')
  static void _onBackgroundTap(NotificationResponse r) {
    // Ίδιο με foreground
  }
}