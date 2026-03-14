// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'helpers/super_note_helper.dart';
import 'models/models.dart';
import 'providers/providers.dart';
import 'services/services.dart';
import 'core/core.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('el');
  DebugConfig.startup('App started');

  await SuperNoteHelper.init();
  DebugConfig.startup('DB initialized');

  await NotificationService.instance.init();
  DebugConfig.startup('Notifications initialized');

  final container = ProviderContainer();
  DebugConfig.startup('ProviderContainer created');

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
    final appTheme = ref
        .watch(settingsStreamProvider)
        .whenData((s) => s?.theme)
        .value ?? AppTheme.system;

    final router = ref.watch(appRouterProvider);

    DebugConfig.provider('SuperNoteApp.build theme=${appTheme.name}');

    return MaterialApp.router(
      title:                     'SuperNote',
      debugShowCheckedModeBanner: false,
      themeMode:                 _toThemeMode(appTheme),
      theme:                     AppThemeData.light,
      darkTheme:                 AppThemeData.dark,
      routerConfig:              router,
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