import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'helpers/super_note_helper.dart';
import 'models/models.dart';
import 'providers/providers.dart';
import 'services/services.dart';
import 'core/core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('el');
  DebugConfig.startup('App started');

  // Αρχικοποίηση timezone (απαραίτητη για notifications)
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Athens'));

  await SuperNoteHelper.init();
  DebugConfig.startup('DB initialized');

  await NotificationService.instance.init();
  DebugConfig.startup('Notifications initialized');

  final hasPermission = await NotificationService.instance.requestPermission();
  DebugConfig.startup('Notifications requestPermission -> $hasPermission');

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

  // Προγραμματισμός όλων των υπαρχόντων pending reminders
  await ReminderScheduler.instance.scheduleAll();
  DebugConfig.startup('Reminders scheduled');

  // Ανανέωση επαναλαμβανόμενων reminders (δημιουργία επόμενων εμφανίσεων)
  await ReminderScheduler.instance.refreshRecurringReminders();
  DebugConfig.startup('Recurring reminders refreshed');

  DebugConfig.startup('runApp');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SuperNoteApp(),
    ),
  );
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
      DebugConfig.startup('App resumed — refreshing recurring reminders');
      // Μόνο refreshRecurringReminders() αρκεί, γιατί ήδη καλεί scheduleReminder για κάθε νέο child
      await ReminderScheduler.instance.refreshRecurringReminders();
    }

    if (!_disposed && state == AppLifecycleState.detached) {
      _disposed = true;
      container.dispose();
      DebugConfig.startup('ProviderContainer disposed');
    }
  }
}