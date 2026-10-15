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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // PlatformException (retry exact→inexact)
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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

  /// SPoT: πλατφόρμες με OS ειδοποιήσεις — μοναδική πηγή (scheduler + UI).
  static bool get isSupportedPlatform => const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ].contains(defaultTargetPlatform);

  /// SPoT: λειτουργικό όριο OS alarms (με headroom κάτω από το σκληρό:
  /// Android ~500/app, iOS/macOS 64). Χρησιμοποιείται για budget (cap) +
  /// display (diagnostics header). Deterministic: oldest-first.
  static int get osAlarmLimit {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 60;
      default:
        return 450;
    }
  }

  bool _initialized = false;

  // ─────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();
      try {
        final String iana = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(iana));
        DebugConfig.notif('NotificationService.init: tz.local=$iana');
      } catch (e, stack) {
        DebugConfig.warning(
            'NotificationService.init: timezone fallback UTC ($e)');
        DebugConfig.error('NotificationService.init timezone', e, stack);
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
    } catch (e, stack) {
      DebugConfig.error('NotificationService.init', e, stack);
    }
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
    } catch (e, stack) {
      DebugConfig.error('NotificationService.getLaunchPayload', e, stack);
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // DIAGNOSTICS — λίστα notifications ΠΡΑΓΜΑΤΙΚΑ προγραμματισμένων
  // στο OS αυτή τη στιγμή (όχι απλά καταχωρημένων στη βάση)
  // ─────────────────────────────────────────────────────────

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e, stack) {
      DebugConfig.error('NotificationService.getPendingNotifications', e, stack);
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────
  // PERMISSIONS — Κάλεσε μετά το onboarding
  // ─────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    DebugConfig.notif('NotificationService.requestPermission: called');
    try {
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
    } catch (e, stack) {
      DebugConfig.error('NotificationService.requestPermission', e, stack);
      return false;
    }
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
    try {
      await _plugin.show(
        id, title, body,
        _details(sound: sound, vibration: vibration),
        payload: payload,
      );
    } catch (e, stack) {
      DebugConfig.error('NotificationService.showImmediate', e, stack);
    }
  }

  /// Batch-resolve του schedule mode (1 platform-call ανά batch αντί για
  /// 1/alarm). Μεταφορά as-is της παρακάτω λογικής — singles συνεχίζουν
  /// per-call (σπάνιες κλήσεις, πάντα φρέσκο).
  Future<AndroidScheduleMode> resolveScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;
    try {
      final mode =
          scheduleModeFor(await android.canScheduleExactNotifications());
      if (mode == AndroidScheduleMode.inexactAllowWhileIdle) {
        DebugConfig.warning(
          'NotificationService.resolveScheduleMode: exact alarm χωρίς άδεια '
          '— fallback σε inexact (πιθανή καθυστέρηση Doze)',
        );
      }
      return mode;
    } catch (e) {
      DebugConfig.notif(
          'NotificationService.resolveScheduleMode: check failed: $e — fallback σε inexact');
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  /// Επιστρέφει true ΜΟΝΟ αν το OS δέχτηκε το alarm — οι callers ΔΕΝ
  /// πρέπει να λογίζουν SUCCESS από μόνα τους (το ψευδές-SUCCESS ήταν το
  /// S231-παράδοξο: ERR + SUCCESS για το ίδιο id από μία κλήση).
  Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
    bool sound     = true,
    bool vibration = true,
    AndroidScheduleMode? mode, // batch-override· null = resolve per-call (ως πριν)
  }) async {
    if (!_initialized) return false;
    try {
      // 🔍 DEBUG: έλεγχος exact-alarm permission πριν το scheduling.
      // Σε Android 12+ το OS μπορεί να ανακαλέσει αυτή την άδεια σιωπηλά
      // (π.χ. aggressive battery optimization σε Xiaomi/Samsung/Huawei),
      // οπότε το zonedSchedule μπορεί να μην πυροδοτηθεί ποτέ χωρίς exception.
      // (Λεπτομέρειες check: βλ. resolveScheduleMode — batch 1×, singles per-call.)
      var scheduleMode = mode ?? await resolveScheduleMode();

      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledAt, tz.local),
          _details(sound: sound, vibration: vibration),
          payload: payload,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
        );
      } on PlatformException catch (e) {
        // Native Java ExactAlarmPermissionException → code
        // 'exact_alarms_not_permitted' (πηγαία 17.2.4): revoke ενδιάμεσα
        // → 1× inexact, όχι απώλεια· οτιδήποτε άλλο → rethrow (outer log).
        if (e.code == 'exact_alarms_not_permitted' &&
            scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
          DebugConfig.warning(
              'NotificationService.schedule: exact revoked id=$id — retry inexact');
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            tz.TZDateTime.from(scheduledAt, tz.local),
            _details(sound: sound, vibration: vibration),
            payload: payload,
            androidScheduleMode: scheduleMode,
            uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
          );
        } else {
          rethrow;
        }
      }
      DebugConfig.notif(
          'NotificationService.schedule: ✅ zonedSchedule OK id=$id at $scheduledAt mode=$scheduleMode');
      return true;
    } catch (e, stack) {
      DebugConfig.error('NotificationService.schedule', e, stack);
      return false;
    }
  }

  /// Pure: exact ΜΟΝΟ με ρητή άδεια· `false`/`null` (channel-error)
  /// → inexact (ασφαλής κατεύθυνση — χτυπά αντί να χάνεται).
  static AndroidScheduleMode scheduleModeFor(bool? canScheduleExact) =>
      canScheduleExact == true
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

  Future<void> cancel(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id);
    } catch (e, stack) {
      DebugConfig.error('NotificationService.cancel', e, stack);
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e, stack) {
      DebugConfig.error('NotificationService.cancelAll', e, stack);
    }
  }

  // ─────────────────────────────────────────────────────────
  // PRIVATE
  // ─────────────────────────────────────────────────────────

  Future<void> _createAndroidChannel() async {
    try {
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
    } catch (e, stack) {
      DebugConfig.error('NotificationService._createAndroidChannel', e, stack);
    }
  }

  /// Ξαναφτιάχνει το κανάλι με το τρέχον vibration pref — ΜΟΝΟ στο toggle,
  /// ποτέ στο init (το delete θα έσβηνε manual OS ρυθμίσεις του χρήστη).
  /// Το Android κλειδώνει vibration στο κανάλι μετά τη δημιουργία, οπότε τα
  /// per-notification flags αγνοούνται. Ίδιο id → χωρίς reschedule.
  Future<void> syncChannel({required bool vibration}) async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      await android.deleteNotificationChannel(_channelId);
      final channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        enableVibration: vibration,
      );
      await android.createNotificationChannel(channel);
      DebugConfig.notif('NotificationService.syncChannel: vibration=$vibration');
    } catch (e, stack) {
      DebugConfig.error('NotificationService.syncChannel', e, stack);
    }
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
    try {
      DebugConfig.notif('NotificationService._onTap: payload=${r.payload}');
      if (r.payload != null && onNotificationTap != null) {
        onNotificationTap!(r.payload!);
      }
    } catch (e, stack) {
      DebugConfig.error('NotificationService._onTap', e, stack);
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundTap(NotificationResponse r) {
    // Background tap: το payload θα πιαστεί από getLaunchPayload() στο cold start.
    // Δεν καλούμε onNotificationTap εδώ (background isolate, δεν έχει UI).
    DebugConfig.notif(
        'NotificationService._onBackgroundTap: payload=${r.payload}');
  }
}