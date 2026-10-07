import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'helpers/super_note_helper.dart';
import 'features/lock/lock.dart';
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
    try {
      DebugConfig.notif('handleNotificationTap: payload=$payload');
      final itemId = int.tryParse(payload);
      if (itemId == null) {
        DebugConfig.notif('handleNotificationTap: invalid payload, skipping');
        return;
      }
      final item = await SuperNoteHelper.instance.items.getById(itemId);
      if (item == null) {
        DebugConfig.notif(
            'handleNotificationTap: item $itemId not found, skipping');
        return;
      }
      DebugConfig.notif(
          'handleNotificationTap: itemId=$itemId type=${item.type.name} archived=${item.archived}');
      final route = AppRoutes.forType(item.type, item.id);
      DebugConfig.notif('handleNotificationTap: route=$route');
      if (route != null) {
        DebugConfig.notif('handleNotificationTap: navigating to $route via go()');
        container.read(appRouterProvider).go(route);
        DebugConfig.notif('handleNotificationTap: go completed');
      } else {
        DebugConfig.notif(
            'handleNotificationTap: no route for type ${item.type.name}');
      }
    } catch (e, stack) {
      DebugConfig.error('handleNotificationTap', e, stack);
    }
  }

  // ✅ Real handler — αντικαθιστά το stub
  NotificationService.onNotificationTap = handleNotificationTap;

  // ✅ Αποθήκευση payload — η πραγματική navigation γίνεται ΜΕΤΑ το runApp (postFrameCallback)
  final deferredNotificationPayload = coldStartPayload ?? pendingNotificationPayload;
  if (deferredNotificationPayload != null) {
    DebugConfig.notif('Deferring notification navigation for after runApp: payload=$deferredNotificationPayload');
  }

  WidgetsBinding.instance.addObserver(
    _AppLifecycleObserver(container),
  );

  try {
    final defaultWs = await container.read(defaultWorkspaceProvider.future);
    if (defaultWs != null) {
      container.read(activeWorkspaceIdProvider.notifier).state = defaultWs.id;
      DebugConfig.startup('Active workspace set id=${defaultWs.id}');
    } else {
      DebugConfig.warning('No default workspace found');
    }
  } catch (e, stack) {
    DebugConfig.error('defaultWorkspace load', e, stack);
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
      await ReminderScheduler.instance.refreshRecurringReminders();
      DebugConfig.startup('Recurring reminders refreshed');
    } catch (e, stack) {
      DebugConfig.error('refreshRecurringReminders failed', e, stack);
    }

    try {
      // Entry-reminder purge (one-shot, idempotent): η καμπάνα αφαιρέθηκε
      // από τα entries — σβήνουμε τυχόν παλιές rows πριν το scheduleAll.
      await ReminderScheduler.instance.purgeKnowledgeReminders();
      DebugConfig.startup('Entry reminders purged');
    } catch (e, stack) {
      DebugConfig.error('purgeKnowledgeReminders failed', e, stack);
    }

    try {
      await ReminderScheduler.instance.scheduleAll();
      DebugConfig.startup('Reminders scheduled');
    } catch (e, stack) {
      DebugConfig.error('scheduleAll failed', e, stack);
    }

    try {
      // Habit native scheduling: one-shot repair + 60d top-up (μετά το
      // scheduleAll για ταχύτερο OS προγραμματισμό — προγραμματίζουν μόνα τους).
      await HabitService.instance.repairLegacyHabitRows();
      await HabitService.instance.topUpHabitReminders();
      DebugConfig.startup('Habit reminders repaired + topped up');
    } catch (e, stack) {
      DebugConfig.error('habit topUp failed', e, stack);
    }

    try {
      // Folder seed (Φ4c-6): προεπιλογή ΜΙΑ φορά στο startup για αποφυγή
      // του null→«Όλοι» flicker — το FolderAutoSelectMixin μένει ως fallback.
      final folders = await container.read(foldersProvider.future);
      if (container.read(selectedFolderIdProvider) == null && folders.isNotEmpty) {
        final preferred =
            container.read(settingsNotifierProvider).valueOrNull?.preferredFolderId;
        final target = (preferred != null && folders.any((f) => f.id == preferred))
            ? preferred
            : folders.firstWhere((f) => f.isSystem, orElse: () => folders.first).id;
        container.read(selectedFolderIdProvider.notifier).state = target;
        DebugConfig.nav('Startup seed folder id=$target (preferredId=$preferred)');
      }
    } catch (e, stack) {
      DebugConfig.error('folder seed failed', e, stack);
    }

    try {
      await SharedIntentService.instance.init();
      DebugConfig.startup('SharedIntent initialized');
    } catch (e, stack) {
      DebugConfig.error('SharedIntent init failed', e, stack);
    }

    try {
      if (deferredNotificationPayload != null) {
        DebugConfig.notif('PostFrameCallback: processing deferred notification payload=$deferredNotificationPayload');
        handleNotificationTap(deferredNotificationPayload);
        DebugConfig.notif('PostFrameCallback: deferred notification navigation done');
      }
    } catch (e, stack) {
      DebugConfig.error('PostFrameCallback: deferred notification navigation failed', e, stack);
    }

    try {
      final settings = await SuperNoteHelper.instance.settings.get();
      if (settings.appLockEnabled) {
        AppLockService.instance.lock();
        container.read(appLockStateProvider.notifier).state = true;
      DebugConfig.print('🔒 AppLock: initial lock on startup');
        }
      } catch (e, stack) {
        DebugConfig.error('PostFrameCallback: app lock check failed', e, stack);
      }

    });
}

class SuperNoteApp extends ConsumerWidget {
  const SuperNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(
      settingsStreamProvider.select((s) => s.value?.theme ?? AppTheme.system),
    );
    final fontScale = ref.watch(
      settingsStreamProvider.select((s) => s.value?.fontScale ?? 1.0),
    );
    final language = ref.watch(
      settingsStreamProvider.select((s) => s.value?.language ?? AppLanguage.auto),
    );
    final locale = _localeFromLanguage(language);
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
        child: Stack(
          children: [
            child!,
            Consumer(
              builder: (context, ref, _) {
                final locked = ref.watch(appLockStateProvider);
                if (!locked) return const SizedBox.shrink();
                return const PopScope(
                  canPop: false,
                  child: LockScreen(),
                );
              },
            ),
          ],
        ),
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
  Timer? _lockTimer;
  DateTime? _lastLifecycleEvent; // 🔍 DEBUG: για εντοπισμό γρήγορων resumed/paused κύκλων

  _AppLifecycleObserver(this.container);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    try {
      final now = DateTime.now();
      if (_lastLifecycleEvent != null) {
        final gapMs = now.difference(_lastLifecycleEvent!).inMilliseconds;
        DebugConfig.print('🔔 [LIFECYCLE] state=$state (+${gapMs}ms)');
        if (gapMs < 2000) {
          DebugConfig.warning(
              '🔔 [LIFECYCLE] ⚠️ RACE RISK — event μέσα σε ${gapMs}ms, '
                  'το debounce refresh timer πιθανόν μόλις ακυρώθηκε πριν προλάβει να τρέξει!');
        }
      } else {
        DebugConfig.print('🔔 [LIFECYCLE] state=$state (πρώτο event)');
      }
      _lastLifecycleEvent = now;

      if (state == AppLifecycleState.paused) {
        final settings = await SuperNoteHelper.instance.settings
            .get()
            .timeout(const Duration(seconds: 5));
        // Auto-backup (fire-and-forget — δεν μπλοκάρει το pause).
        unawaited(BackupService.instance.autoBackup());
        if (settings.appLockEnabled) {
          _lockTimer?.cancel();
          _lockTimer =
              Timer(Duration(seconds: settings.appLockTimeoutSeconds), () {
            try {
              AppLockService.instance.lock();
              container.read(appLockStateProvider.notifier).state = true;
              DebugConfig.print(
                  '🔒 AppLock: auto-lock after ${settings.appLockTimeoutSeconds}s timeout');
            } catch (e, stack) {
              DebugConfig.error('AppLock auto-lock', e, stack);
            }
          });
        }
      }

      if (state == AppLifecycleState.resumed) {
        _lockTimer?.cancel();
        _lockTimer = null;
        DebugConfig.startup(
            'App resumed — debounced refreshing recurring reminders');
        await ReminderScheduler.instance.debouncedRefreshRecurringReminders();
        // Habit top-up (own 10min guard μέσα στη μέθοδο).
        await HabitService.instance.topUpHabitReminders();
      }

      if (!_disposed && state == AppLifecycleState.detached) {
        _disposed = true;
        _lockTimer?.cancel();
        WidgetsBinding.instance.removeObserver(this);
        SharedIntentService.instance.dispose();
        container.dispose();
        DebugConfig.startup('ProviderContainer disposed');
      }
    } catch (e, stack) {
      DebugConfig.error('AppLifecycleObserver.didChangeAppLifecycleState', e, stack);
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
