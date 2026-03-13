// lib/main.dart
// TEST
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'helpers/super_note_helper.dart';
import 'models/models.dart';
import 'providers/providers.dart';
import 'services/services.dart';
import 'core/core.dart';
import 'features/notes/notes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DebugConfig.startup('App started');

  // ─── 1. Database ────────────────────────────────────────
  await SuperNoteHelper.init();
  DebugConfig.startup('DB initialized');

  // ─── 2. Notifications ───────────────────────────────────
  await NotificationService.instance.init();
  DebugConfig.startup('Notifications initialized');

  // ─── 3. Riverpod Container ──────────────────────────────
  final container = ProviderContainer();
  DebugConfig.startup('ProviderContainer created');

  // ─── 4. Default Workspace ───────────────────────────────
  final defaultWs = await container.read(defaultWorkspaceProvider.future);
  if (defaultWs != null) {
    container.read(activeWorkspaceIdProvider.notifier).state = defaultWs.id;
    DebugConfig.startup('Active workspace set id=${defaultWs.id}');
  } else {
    DebugConfig.warning('No default workspace found');
  }

  // ─── 5. Schedule pending reminders ──────────────────────
  await ReminderScheduler.instance.scheduleAll();
  DebugConfig.startup('Reminders scheduled');

  // ─── 6. Run App ─────────────────────────────────────────
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

    DebugConfig.provider('SuperNoteApp.build theme=${appTheme.name}');

    return MaterialApp(
      title: 'SuperNote',
      debugShowCheckedModeBanner: false,
      themeMode: _toThemeMode(appTheme),
      theme:     AppThemeData.light,
      darkTheme: AppThemeData.dark,
      home: const NoteListScreen(),
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