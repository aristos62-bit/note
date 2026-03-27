// lib/main.dart
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

  await SuperNoteHelper.init();
  DebugConfig.startup('DB initialized');

  await NotificationService.instance.init();
  DebugConfig.startup('Notifications initialized');

  await NotificationService.instance.requestPermission();
  DebugConfig.startup('Notifications requestPermission');

  final container = ProviderContainer();
  DebugConfig.startup('ProviderContainer created');

// Dispose όταν κλείσει το app (καλό practice)
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

  await ReminderScheduler.instance.scheduleAll();
  DebugConfig.startup('Reminders scheduled');

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

    DebugConfig.provider(
      'SuperNoteApp.build theme=${appTheme.name}',
    );

    return MaterialApp.router(
      title:                     'SuperNote',
      debugShowCheckedModeBanner: false,
      themeMode:                 _toThemeMode(appTheme),
      theme:                     AppThemeData.light,
      darkTheme:                 AppThemeData.dark,
      routerConfig:              router,

      // Εφαρμογή fontScale από ρυθμίσεις
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(fontScale),
        ),
        child: child!,
      ),

      // Localization για Material / Cupertino / Widgets
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

  _AppLifecycleObserver(this.container);

  bool _disposed = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      DebugConfig.startup('App resumed — scheduling reminders');
      await ReminderScheduler.instance.scheduleAll();
    }

    if (!_disposed && state == AppLifecycleState.detached) {
      _disposed = true;
      container.dispose();
      DebugConfig.startup('ProviderContainer disposed');
    }
  }
}