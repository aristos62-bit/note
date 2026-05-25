import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'helpers/super_note_helper.dart';
import 'models/models.dart';
import 'providers/providers.dart';
import 'services/services.dart';
import 'core/core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    runApp(const _WebNotSupportedApp());
    return;
  }

  await initializeDateFormatting();
  DebugConfig.startup('App started');

  // ✅ Cold start: έλεγχος πριν το init() αν το app ξεκίνησε από notification
  final coldStartPayload = await NotificationService.instance.getLaunchPayload();
  if (coldStartPayload != null) {
    DebugConfig.notif('Cold start notification payload: $coldStartPayload');
  }

  // ✅ Stub: πιάνει notification taps που έρχονται ΚΑΤΑ την init (σε περίπτωση που
  //    το onDidReceiveNotificationResponse πυροδοτηθεί)
  String? pendingNotificationPayload;
  NotificationService.onNotificationTap = (payload) {
    DebugConfig.notif('onNotificationTap (stub): payload=$payload');
    pendingNotificationPayload = payload;
  };

  // ✅ Παράλληλη εκτέλεση με error handling
  try {
    await Future.wait([
      SuperNoteHelper.init(),
      NotificationService.instance.init(),
    ]);
    DebugConfig.startup('DB and Notifications initialized');
  } catch (e, stack) {
    DebugConfig.error('Init failed', e, stack);
  }

  // ❌ Αν απέτυχε η DB, δείχνουμε error screen
  if (!SuperNoteHelper.isInitialized) {
    runApp(const _InitErrorApp());
    return;
  }

  final container = ProviderContainer();
  DebugConfig.startup('ProviderContainer created');

  // ✅ Η πραγματική υλοποίηση navigation
  Future<void> handleNotificationTap(String payload) async {
    DebugConfig.notif('handleNotificationTap: payload=$payload');
    final itemId = int.tryParse(payload);
    if (itemId == null) {
      DebugConfig.notif('handleNotificationTap: invalid payload, skipping');
      return;
    }
    final item = await SuperNoteHelper.instance.items.getById(itemId);
    if (item == null) {
      DebugConfig.notif('handleNotificationTap: item $itemId not found, skipping');
      return;
    }
    DebugConfig.notif('handleNotificationTap: itemId=$itemId type=${item.type.name}');
    final route = switch (item.type) {
      ItemType.note        => AppRoutes.note(item.id),
      ItemType.task        => AppRoutes.task(item.id),
      ItemType.habit       => AppRoutes.habit(item.id),
      ItemType.event       => AppRoutes.event(item.id),
      ItemType.appointment => AppRoutes.appointment(item.id),
      ItemType.journal     => AppRoutes.journal_(item.id),
      ItemType.contact     => AppRoutes.contact(item.id),
      _ => null,
    };
    DebugConfig.notif('handleNotificationTap: route=$route');
    if (route != null) {
      DebugConfig.notif('handleNotificationTap: pushing $route');
      await container.read(appRouterProvider).push(route);
      DebugConfig.notif('handleNotificationTap: push completed');
    } else {
      DebugConfig.notif('handleNotificationTap: no route for type ${item.type.name}');
    }
  }

  // ✅ Real handler — αντικαθιστά το stub
  NotificationService.onNotificationTap = handleNotificationTap;

  // ✅ Επεξεργασία payload: cold start > stub > τίποτα
  final effectivePayload = coldStartPayload ?? pendingNotificationPayload;
  if (effectivePayload != null) {
    DebugConfig.notif('Processing notification payload: $effectivePayload');
    handleNotificationTap(effectivePayload);
  }

  WidgetsBinding.instance.addObserver(
    _AppLifecycleObserver(container),
  );

  final defaultWs = await container.read(defaultWorkspaceProvider.future);
  if (defaultWs != null) {
    container.read(activeWorkspaceIdProvider.notifier).state = defaultWs.id;
    DebugConfig.startup('Active workspace set id=${defaultWs.id}');
  } else {
    DebugConfig.warning('No default workspace found');
  }

  DebugConfig.startup('runApp');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SuperNoteApp(),
    ),
  );

  // ✅ Βαριές εργασίες ΜΕΤΑ το runApp
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final hasPermission =
          await NotificationService.instance.requestPermission();
      DebugConfig.startup('Notifications requestPermission -> $hasPermission');
    } catch (e, stack) {
      DebugConfig.error('requestPermission failed', e, stack);
    }
    try {
      await ReminderScheduler.instance.scheduleAll();
      DebugConfig.startup('Reminders scheduled');
    } catch (e, stack) {
      DebugConfig.error('scheduleAll failed', e, stack);
    }

    try {
      await ReminderScheduler.instance.refreshRecurringReminders();
      DebugConfig.startup('Recurring reminders refreshed');
    } catch (e, stack) {
      DebugConfig.error('refreshRecurringReminders failed', e, stack);
    }
  });
}

class SuperNoteApp extends ConsumerWidget {
  const SuperNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStreamProvider);
    final appTheme  = settings.value?.theme     ?? AppTheme.system;
    final fontScale = settings.value?.fontScale ?? 1.0;
    final locale    = _localeFromLanguage(settings.value?.language ?? AppLanguage.auto);
    final router = ref.watch(appRouterProvider);

    DebugConfig.provider('SuperNoteApp.build theme=${appTheme.name}');

    return MaterialApp.router(
      title: 'SuperNote',
      debugShowCheckedModeBanner: false,
      themeMode: _toThemeMode(appTheme),
      theme: AppThemeData.light,
      darkTheme: AppThemeData.dark,
      themeAnimationDuration:
          Duration.zero, // ✅ instant switch, μηδέν animation frames
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(fontScale),
        ),
        child: child!,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('el'),
      ],
      locale: locale,
    );
  }

  ThemeMode _toThemeMode(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.system:
        return ThemeMode.system;
    }
  }
}

Locale? _localeFromLanguage(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.greek:   return const Locale('el');
    case AppLanguage.english: return const Locale('en');
    case AppLanguage.auto:    return null;
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final ProviderContainer container;
  bool _disposed = false;

  _AppLifecycleObserver(this.container);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    DebugConfig.print('🔔 [LIFECYCLE] state=$state');
    if (state == AppLifecycleState.resumed) {
      DebugConfig.startup(
          'App resumed — debounced refreshing recurring reminders');
      // Debounced version to avoid multiple rapid calls
      await ReminderScheduler.instance.debouncedRefreshRecurringReminders();
    }

    if (!_disposed && state == AppLifecycleState.detached) {
      _disposed = true;
      WidgetsBinding.instance.removeObserver(this);
      container.dispose();
      DebugConfig.startup('ProviderContainer disposed');
    }
  }
}

/// Fallback error screen όταν αποτυγχάνει η αρχικοποίηση της DB.
class _InitErrorApp extends StatelessWidget {
  const _InitErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF1E1E2E),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 64, color: Colors.redAccent),
                SizedBox(height: 24),
                Text(
                  'Σφάλμα εκκίνησης',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Η εφαρμογή δεν μπόρεσε να αρχικοποιηθεί.\n'
                  'Παρακαλώ δοκιμάστε ξανά ή επικοινωνήστε με την υποστήριξη.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _WebNotSupportedApp extends StatelessWidget {
  const _WebNotSupportedApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF1E1E2E),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language_outlined,
                    size: 64, color: Colors.orangeAccent),
                SizedBox(height: 24),
                Text(
                  'Web δεν υποστηρίζεται',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Η SuperNote απαιτεί τοπική βάση δεδομένων (Isar)\n'
                      'και δεν λειτουργεί σε web browser προς το παρόν.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
