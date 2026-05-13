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
  await initializeDateFormatting('el');
  DebugConfig.startup('App started');

  // ✅ Παράλληλη εκτέλεση — Isar και Notifications μαζί
  await Future.wait([
    SuperNoteHelper.init(),
    NotificationService.instance.init(),
  ]);
  DebugConfig.startup('DB and Notifications initialized');

  final container = ProviderContainer();
  DebugConfig.startup('ProviderContainer created');

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

  // ✅ Βαριές εργασίες ΜΕΤΑ το runApp — ο χρήστης βλέπει UI αμέσως
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Άδειες notifications (εμφανίζεται dialog — δεν πρέπει να μπλοκάρει startup)
    final hasPermission = await NotificationService.instance.requestPermission();
    DebugConfig.startup('Notifications requestPermission -> $hasPermission');

    // Προγραμματισμός reminders
    await ReminderScheduler.instance.scheduleAll();
    DebugConfig.startup('Reminders scheduled');

    await ReminderScheduler.instance.refreshRecurringReminders();
    DebugConfig.startup('Recurring reminders refreshed');
  });
}

class SuperNoteApp extends ConsumerWidget {
  const SuperNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStreamProvider);
    final appTheme  = settings.value?.theme     ?? AppTheme.system;
    final fontScale = settings.value?.fontScale ?? 1.0;
    final router = ref.watch(appRouterProvider);

    DebugConfig.provider('SuperNoteApp.build theme=${appTheme.name}');

    return MaterialApp.router(
      title: 'SuperNote',
      debugShowCheckedModeBanner: false,
      themeMode: _toThemeMode(appTheme),
      theme: AppThemeData.light,
      darkTheme: AppThemeData.dark,
      themeAnimationDuration: Duration.zero,  // ✅ instant switch, μηδέν animation frames
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
      locale: const Locale('el'),
    );
  }

  ThemeMode _toThemeMode(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:  return ThemeMode.light;
      case AppTheme.dark:   return ThemeMode.dark;
      case AppTheme.system: return ThemeMode.system;
    }
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
      DebugConfig.startup('App resumed — debounced refreshing recurring reminders');
      // Debounced version to avoid multiple rapid calls
      await ReminderScheduler.instance.debouncedRefreshRecurringReminders();
    }

    if (!_disposed && state == AppLifecycleState.detached) {
      _disposed = true;
      container.dispose();
      DebugConfig.startup('ProviderContainer disposed');
    }
  }
}