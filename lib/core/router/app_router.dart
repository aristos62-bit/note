// lib/core/router/app_router.dart
//
// GoRouter setup για SuperNote.
// ✅ ShellRoute — bottom nav (mobile) / NavigationRail (tablet+)
// ✅ Responsive navigation
// ✅ DebugConfig: nav logs
//
// ROUTES:
//   /           → HomeScreen
//   /notes      → NoteListScreen
//   /notes/:id  → NoteDetailScreen
//   /tasks      → TaskListScreen
//   /tasks/:id  → TaskDetailScreen
//   /search     → SearchScreen
//   /settings   → SettingsScreen
//
// ΧΡΗΣΗ:
//   context.go('/notes')
//   context.push('/notes/42')
//   context.push('/notes/new')
//   context.pop()
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core.dart';
import '../../features/home/home.dart';
import '../../features/notes/notes.dart';
import '../../features/tasks/tasks.dart';
import '../../features/settings/settings.dart';
import '../../features/habits/habits.dart';
import '../../features/calendar/calendar.dart';
import '../../features/journal/journal.dart';
import '../../features/contacts/contacts.dart';
import '../../features/collections/collections.dart';
import '../../features/appointments/appointments.dart';
import 'package:flutter/gestures.dart';
import '../../providers/providers.dart';

// ── Route paths ────────────────────────────────────────────────

class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const notes = '/notes';
  static const noteId = '/notes/:id';
  static const tasks = '/tasks';
  static const taskId = '/tasks/:id';
  static const appointments = '/appointments';
  static const settings = '/settings';

  // Βήμα 3 — ετοιμάζουμε για τα advanced features
  static const habits = '/habits';
  static const calendar = '/calendar';
  static const finance = '/finance';
  static const collections = '/collections';
  static const journal = '/journal';
  static const contacts = '/contacts';

  // Helper για dynamic routes
  static String note(int id) => '/notes/$id';
  static String task(int id) => '/tasks/$id';
  static String habit(int id) => '/habits/$id';
  static String finance_(int id) => '/finance/$id';
  static String journal_(int id) => '/journal/$id';
  static String contact(int id) => '/contacts/$id';
  static String collection(int id) => '/collections/$id';
}

// ── Router Provider ────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    observers: [_RouterObserver()],
    routes: [
      // ── Shell route — bottom nav / navigation rail ──────────
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) =>
                AppTransitions.fade(state, const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.notes,
            name: 'notes',
            pageBuilder: (context, state) =>
                AppTransitions.fade(state, const NoteListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'note-detail',
                pageBuilder: (context, state) {
                  final id =
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  DebugConfig.nav('Router → NoteDetail id=$id');
                  return AppTransitions.slideRight(
                      state, NoteDetailScreen(itemId: id));
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.tasks,
            name: 'tasks',
            pageBuilder: (context, state) =>
                AppTransitions.fade(state, const TaskListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'task-detail',
                pageBuilder: (context, state) {
                  final id =
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  DebugConfig.nav('Router → TaskDetail id=$id');
                  return AppTransitions.slideRight(
                      state, TaskDetailScreen(itemId: id));
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.appointments,
            name: 'appointments',
            pageBuilder: (context, state) =>
                AppTransitions.fade(state, const AppointmentListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'appointment-detail',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  return AppTransitions.slideRight(
                      state, AppointmentDetailScreen(itemId: id));
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) =>
                AppTransitions.slideUp(state, const SettingsScreen()),
          ),

          // ── Βήμα 3 — Placeholder routes ────────────────────
          GoRoute(
            path: AppRoutes.habits,
            name: 'habits',
            pageBuilder: (context, state) =>
                AppTransitions.fade(state, const HabitListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'habit-detail',
                pageBuilder: (context, state) {
                  final id =
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  DebugConfig.nav('Router → HabitDetail id=$id');
                  return AppTransitions.slideRight(
                      state, HabitDetailScreen(itemId: id));
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.calendar,
            name: 'calendar',
            pageBuilder: (context, state) =>
                AppTransitions.fade(state, const CalendarScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'event-detail',
                pageBuilder: (context, state) {
                  final id =
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  final isNew = (state.extra as bool?) ?? false;
                  DebugConfig.nav('Router → EventDetail id=$id isNew=\$isNew');
                  return AppTransitions.slideUp(
                      state, EventDetailScreen(itemId: id, isNew: isNew));
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.collections,
            name: 'collections',
            pageBuilder: (context, state) =>
                AppTransitions.fade(state, const CollectionsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'collection-detail',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  return AppTransitions.slideRight(
                      state, CollectionDetailScreen(collectionId: id));
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.journal,
            name: 'journal',
            pageBuilder: (context, state) =>
                AppTransitions.fade(state, const JournalListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'journal-detail',
                pageBuilder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  DebugConfig.nav('Router → JournalDetail id=$id');
                  return AppTransitions.slideRight(
                    state,
                    JournalDetailScreen(itemId: id), // ✔ σωστό
                  );
                },
              ),
            ],
          ),

          GoRoute(
            path: AppRoutes.contacts,
            name: 'contacts',
            pageBuilder: (context, state) =>
                AppTransitions.fade(state, const ContactListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'contact-detail',
                pageBuilder: (context, state) {
                  final id =
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  return AppTransitions.slideRight(
                      state, ContactDetailScreen(itemId: id));
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _RouterErrorScreen(error: state.error),
  );
});

// ════════════════════════════════════════════════════════════════
// APP SHELL — Responsive navigation wrapper
// ════════════════════════════════════════════════════════════════

class _AppShell extends ConsumerWidget {
  final Widget child;
  const _AppShell({required this.child});

  static const _navItems = [
    _NavItem(
      path: AppRoutes.home,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Αρχική',
    ),
    _NavItem(
      path: AppRoutes.notes,
      icon: Icons.note_outlined,
      selectedIcon: Icons.note_rounded,
      label: 'Σημειώσεις',
    ),
    _NavItem(
      path: AppRoutes.tasks,
      icon: Icons.check_circle_outline_rounded,
      selectedIcon: Icons.check_circle_rounded,
      label: 'Εργασίες',
    ),
    _NavItem(
      path: AppRoutes.habits,
      icon: Icons.loop_outlined,
      selectedIcon: Icons.loop_rounded,
      label: 'Συνήθειες',
    ),
    _NavItem(
      path: AppRoutes.calendar,
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      label: 'Συμβάντα',
    ),
    _NavItem(
      path: AppRoutes.journal,
      icon: Icons.auto_stories_outlined,
      selectedIcon: Icons.auto_stories_rounded,
      label: 'Ημερολόγιο',
    ),
    _NavItem(
      path: AppRoutes.contacts,
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      label: 'Επαφές',
    ),
    _NavItem(
      path: AppRoutes.collections,
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: 'Συλλογές',
    ),
    _NavItem(
      path: AppRoutes.appointments,
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today_rounded,
      label: 'Ραντεβού',
    ),
    _NavItem(
      path: AppRoutes.settings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Ρυθμίσεις',
    ),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].path) &&
          (_navItems[i].path != AppRoutes.home || location == AppRoutes.home)) {
        return i;
      }
    }
    return 0;
  }

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    final path = _navItems[index].path;
    DebugConfig.nav('Shell nav → $path');
    context.go(path);
    if (path == AppRoutes.home) {
      ref.read(homeSelectedFolderProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIdx = _selectedIndex(context);
    return ResponsiveLayout(
      mobile: _MobileShell(
        selectedIndex: selectedIdx,
        onTap: (i) => _onTap(context, ref, i),   // <-- περνάμε ref
        navItems: _navItems,
        child: child,
      ),
      tablet: _TabletShell(
        selectedIndex: selectedIdx,
        onTap: (i) => _onTap(context, ref, i),   // <-- περνάμε ref
        navItems: _navItems,
        child: child,
      ),
    );
  }
}

class _SwipePager extends StatefulWidget {
  final int currentIndex;
  final List<_NavItem> navItems;
  final Widget child;

  const _SwipePager({
    required this.currentIndex,
    required this.navItems,
    required this.child,
  });

  @override
  State<_SwipePager> createState() => _SwipePagerState();
}

class _SwipePagerState extends State<_SwipePager> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.currentIndex);
  }

  @override
  void didUpdateWidget(covariant _SwipePager oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentIndex != widget.currentIndex) {
      _controller.jumpToPage(widget.currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.navItems.length,
      onPageChanged: (index) {
        final path = widget.navItems[index].path;
        DebugConfig.nav('Swipe → $path');
        context.go(path);
      },
      itemBuilder: (context, index) {
        // 👉 ΜΟΝΟ η τρέχουσα σελίδα δείχνει content
        if (index == widget.currentIndex) {
          return widget.child;
        }

        // 👉 Οι άλλες είναι placeholders για το animation
        return Container(
          color: context.cBg,
        );
      },
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

// ── Mobile — Scrollable custom bottom nav ─────────────────────────

class _MobileShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> navItems;
  final Widget child;

  const _MobileShell({
    required this.selectedIndex,
    required this.onTap,
    required this.navItems,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _ScrollableBottomNav(
        selectedIndex: selectedIndex,
        onTap: onTap,
        navItems: navItems,
      ),
    );
  }
}

class _ScrollableBottomNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> navItems;

  const _ScrollableBottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.navItems,
  });

  @override
  State<_ScrollableBottomNav> createState() => _ScrollableBottomNavState();
}

class _ScrollableBottomNavState extends State<_ScrollableBottomNav> {
  late final ScrollController _controller;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_handleScroll);

    // Μόλις γίνει layout, υπολογίζουμε αν μπορεί να scrollάρει
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollFlags();
    });
  }

  void _handleScroll() {
    _updateScrollFlags();
  }

  void _updateScrollFlags() {
    if (!_controller.hasClients) return;

    final position = _controller.position;

    // Χρησιμοποιούμε στοχευμένο epsilon
    const epsilon = 1.0;

    final atStart =
        (position.pixels - position.minScrollExtent).abs() < epsilon;
    final atEnd = (position.maxScrollExtent - position.pixels).abs() < epsilon;

    setState(() {
      _canScrollLeft = !atStart;
      _canScrollRight = !atEnd;
    });

    DebugConfig.nav(
      'BOTTOM NAV FLAGS → left=$_canScrollLeft, right=$_canScrollRight, '
      'pixels=${position.pixels.toStringAsFixed(1)}, '
      'min=${position.minScrollExtent.toStringAsFixed(1)}, '
      'max=${position.maxScrollExtent.toStringAsFixed(1)}, '
      'atStart=$atStart, atEnd=$atEnd',
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        // Η υπάρχουσα μπάρα, απλά με controller
        Container(
          decoration: BoxDecoration(
            color: ColorsUI.getSurface(context.brightness),
            border: Border(
              top: BorderSide(
                color: ColorsUI.getBorder(context.brightness),
                width: 1,
              ),
            ),
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: IntrinsicHeight(
                child: Row(
                  children: List.generate(widget.navItems.length, (i) {
                    final item = widget.navItems[i];
                    final isSelected = i == widget.selectedIndex;
                    final color = isSelected ? context.cPrimary : context.cText2;

                    return GestureDetector(
                      onTap: () => widget.onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md,
                          vertical: Spacing.sm,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isSelected
                                  ? context.cPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              color: color,
                              size: 22,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              style: context.labelSm.withColor(color).copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),

        ),

        // Αριστερό arrow (φαίνεται μόνο όταν υπάρχει κρυφό περιεχόμενο αριστερά)
        if (_canScrollLeft)
          Positioned(
            left: 0,
            top: 4,
            bottom: 4,
            child: IgnorePointer(
              child: Container(
                width: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      ColorsUI.getSurface(context.brightness),
                      ColorsUI.getSurface(context.brightness)
                          .withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 12,
                      color: context.cSuccess,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Δεξί arrow (φαίνεται μόνο όταν υπάρχει κρυφό περιεχόμενο δεξιά)
        if (_canScrollRight)
          Positioned(
            right: 0,
            top: 4,
            bottom: 4,
            child: IgnorePointer(
              child: Container(
                width: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      ColorsUI.getSurface(context.brightness),
                      ColorsUI.getSurface(context.brightness)
                          .withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4, top: 2),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: context.cSuccess,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Tablet/Desktop — NavigationRail ──────────────────────────────

class _TabletShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> navItems;
  final Widget child;

  const _TabletShell({
    required this.selectedIndex,
    required this.onTap,
    required this.navItems,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Scrollable NavigationRail για όταν δεν χωράει σε ύψος (Windows κ.λπ.)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 80, maxWidth: 120),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: onTap,
                        backgroundColor:
                            ColorsUI.getSurface(context.brightness),
                        labelType: context.isDesktop
                            ? NavigationRailLabelType.all
                            : NavigationRailLabelType.selected,
                        leading: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: Spacing.md),
                          child: Icon(
                            Icons.note_alt_rounded,
                            color: context.cPrimary,
                            size: 28,
                          ),
                        ),
                        destinations: navItems
                            .map(
                              (item) => NavigationRailDestination(
                                icon: Icon(item.icon),
                                selectedIcon: Icon(item.selectedIcon),
                                label: Text(item.label),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          VerticalDivider(
            width: 1,
            color: ColorsUI.getBorder(context.brightness),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// // ════════════════════════════════════════════════════════════════
// // COMING SOON SCREEN — placeholder για Βήμα 3 features
// // ════════════════════════════════════════════════════════════════
//
// class _ComingSoonScreen extends StatelessWidget {
//   final String title;
//   final IconData icon;
//
//   const _ComingSoonScreen({
//     required this.title,
//     required this.icon,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: context.cBg,
//       appBar: AppBar(
//         backgroundColor: context.cBg,
//         elevation: 0,
//         title: Text(title),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(icon, size: 72, color: context.cDisabled),
//             const SizedBox(height: Spacing.md),
//             Text('Σύντομα διαθέσιμο', style: context.titleMd),
//             const SizedBox(height: Spacing.sm),
//             Text('Αυτή η λειτουργία βρίσκεται\nυπό ανάπτυξη.',
//                 style: context.bodyMd.withColor(context.cText2),
//                 textAlign: TextAlign.center),
//           ],
//         ),
//       ),
//     );
//   }
// }

// ════════════════════════════════════════════════════════════════
// ROUTER ERROR SCREEN
// ════════════════════════════════════════════════════════════════

class _RouterErrorScreen extends StatelessWidget {
  final Exception? error;
  const _RouterErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    DebugConfig.error('Router error', error);
    return Scaffold(
      backgroundColor: context.cBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: context.cError),
            const SizedBox(height: Spacing.md),
            Text('Σφάλμα πλοήγησης', style: context.titleMd),
            const SizedBox(height: Spacing.sm),
            Text(error?.toString() ?? 'Άγνωστο σφάλμα',
                style: context.bodySm.withColor(context.cText2),
                textAlign: TextAlign.center),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Αρχική'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ROUTER OBSERVER — για debug logs
// ════════════════════════════════════════════════════════════════

class _RouterObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    DebugConfig.nav('Router didPush: ${route.settings.name}');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    DebugConfig.nav('Router didPop: ${route.settings.name}');
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    DebugConfig.nav('Router didReplace: ${newRoute?.settings.name}');
  }
}
