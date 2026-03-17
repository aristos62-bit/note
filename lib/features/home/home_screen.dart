// lib/features/home/home_screen.dart
//
// Dashboard: greeting, stats, pinned items, today tasks, recent notes.
// ✅ Responsive: single col mobile / 2-col tablet / 3-col desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
//
// ΚΑΝΟΝΑΣ SLIVERS:
//   Μέσα στο slivers:[] του CustomScrollView ΟΛΑ πρέπει να είναι Sliver widgets.
//   Plain widgets (Padding, Container κλπ) → SliverToBoxAdapter(child: ...)
//   Sliver widgets (SliverList, SliverGrid, SliverAppBar) → απευθείας
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import '../notes/note_detail_screen.dart';
import '../notes/note_list_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../tasks/task_list_screen.dart';
import '../search/search.dart';
import '../settings/settings.dart';

// ── Local providers (με autoDispose για να μην ξανατρέχουν άσκοπα) ─────

final _todayTasksProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  DebugConfig.provider('_todayTasksProvider BUILD');
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) {
    DebugConfig.warning('_todayTasksProvider workspace NULL');
    return [];
  }
  DebugConfig.db('_todayTasksProvider wsId=$wsId');
  final tasks = await db.items.getByWorkspace(wsId, type: ItemType.task);
  DebugConfig.db('_todayTasksProvider loaded ${tasks.length} tasks');
  return tasks;
});

final _recentItemsProvider =
Provider.autoDispose<List<Item>>((ref) {
  // Παίρνουμε ΟΛΑ τα items από το ItemNotifier
  final itemsAsync = ref.watch(itemNotifierProvider);

  return itemsAsync.maybeWhen(
    data: (items) {
      // Φιλτράρουμε: χωρίς archived
      final active = items.where((i) => !i.archived).toList();

      // Ταξινόμηση κατά updatedAt ?? createdAt (φθίνουσα)
      active.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt;
        final bDate = b.updatedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

      // Top 8
      return active.take(8).toList();
    },
    orElse: () => const [],
  );
});


final _statsProvider = FutureProvider.autoDispose<Map<ItemType, int>>((ref) async {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return {};
  DebugConfig.db('_statsProvider wsId=$wsId');
  DebugConfig.provider('_statsProvider BUILD');
  final counts = <ItemType, int>{};
  for (final type in [
    ItemType.note, ItemType.task, ItemType.event,
    ItemType.habit, ItemType.project, ItemType.goal,
  ]) {
    final count = await db.items.count(workspaceId: wsId, type: type);
    DebugConfig.db('stats $type = $count');
    counts[type] = count;
  }
  return counts;
});

// ════════════════════════════════════════════════════════════════
// HOME SCREEN
// ════════════════════════════════════════════════════════════════

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    DebugConfig.provider('HomeScreen build');   // ← τώρα μόνο 1 φορά!

    return Scaffold(
      backgroundColor: context.cBg,
      body: RefreshIndicator(
        onRefresh: () async {
          DebugConfig.provider('Home refresh triggered');
          ref.invalidate(pinnedItemsProvider);
          ref.invalidate(_todayTasksProvider);
          ref.invalidate(_statsProvider);
          DebugConfig.provider('Home providers invalidated');
        },
        child: ResponsiveLayout(
          mobile: _buildScrollView(context, ref, isTablet: false),
          tablet: _buildScrollView(context, ref, isTablet: true),
        ),
      ),
    );
  }

  // ── Shared CustomScrollView ──────────────────────────────────
  Widget _buildScrollView(
      BuildContext context,
      WidgetRef ref, {
        required bool isTablet,
      }) {
    return CustomScrollView(
      slivers: [
        const _HomeAppBar(),

        SliverToBoxAdapter(child: _GreetingSection()),

        // Stats – μόνο αυτό το section rebuild
        SliverToBoxAdapter(
          child: Consumer(
            builder: (context, ref, _) {
              final statsAsync = ref.watch(_statsProvider);
              return statsAsync.when(
                loading: () => const _StatsRowSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => _StatsRow(stats: stats),
              );
            },
          ),
        ),

        SliverToBoxAdapter(
          child: _QuickActions(
            onNewNote: () => _createAndOpenNote(context, ref),
            onNewTask: () => _createAndOpenTask(context, ref),
          ),
        ),

        // Pinned – μόνο αυτό το section rebuild
        Consumer(
          builder: (context, ref, _) {
            final pinnedAsync = ref.watch(pinnedItemsProvider);
            return pinnedAsync.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (pinned) => pinned.isEmpty
                  ? const SliverToBoxAdapter(child: SizedBox.shrink())
                  : _PinnedSection(items: pinned),
            );
          },
        ),

        if (!isTablet) ..._buildMobileSections(context, ref),
        if (isTablet) _buildTabletSection(context, ref),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // ── Mobile sections ──────────────────────────────────────────
  List<Widget> _buildMobileSections(BuildContext context, WidgetRef ref) {
    return [
      SliverToBoxAdapter(
        child: _SectionTitle(
          title: 'Σήμερα',
          icon: Icons.today_rounded,
          onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskListScreen())),
        ),
      ),
      Consumer(
        builder: (context, ref, _) {
          final todayAsync = ref.watch(_todayTasksProvider);
          return todayAsync.when(
            loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: ItemCardSkeleton(),
                )),
            error: (e, _) {
              DebugConfig.error('HomeScreen todayTasks', e);
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            },
            data: (tasks) => _TodayTasksSliver(
              tasks: tasks,
              onTap: (id) => _openTask(Navigator.of(context), id),
              onToggle: (item) => _toggleDone(ref, item),
            ),
          );
        },
      ),

      SliverToBoxAdapter(
        child: _SectionTitle(
          title: 'Πρόσφατα',
          icon: Icons.history_rounded,
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoteListScreen()),
          ),
        ),
      ),
      Consumer(
        builder: (context, ref, _) {
          final recentItems = ref.watch(_recentItemsProvider);

          // Loading state: όταν το ItemNotifier είναι σε φόρτωση
          final itemsAsync = ref.watch(itemNotifierProvider);
          if (itemsAsync.isLoading) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: Spacing.md),
                child: ItemCardSkeleton(),
              ),
            );
          }

          return _RecentItemsSliver(
            items: recentItems,
            onTap: (item) {
              final nav = Navigator.of(context);
              if (item.type == ItemType.task) {
                _openTask(nav, item.id);
              } else {
                _openNote(nav, item.id);
              }
            },
          );
        },
      ),
    ];
  }

  // ── Tablet section — 2-col Row ───────────────────────────────
  Widget _buildTabletSection(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical: Spacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    title: 'Σήμερα',
                    icon: Icons.today_rounded,
                    onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskListScreen())),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final todayAsync = ref.watch(_todayTasksProvider);
                      return todayAsync.when(
                        loading: () => const ItemCardSkeleton(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (tasks) => _TodayTasksColumn(
                          tasks: tasks,
                          onTap: (id) => _openTask(Navigator.of(context), id),
                          onToggle: (item) => _toggleDone(ref, item),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    title: 'Πρόσφατα',
                    icon: Icons.history_rounded,
                    onSeeAll: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NoteListScreen()),
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final recentItems = ref.watch(_recentItemsProvider);

                      final itemsAsync = ref.watch(itemNotifierProvider);
                      if (itemsAsync.isLoading) {
                        return const ItemCardSkeleton();
                      }

                      return _RecentItemsColumn(
                        items: recentItems,
                        onTap: (item) {
                          final nav = Navigator.of(context);
                          if (item.type == ItemType.task) {
                            _openTask(nav, item.id);
                          } else {
                            _openNote(nav, item.id);
                          }
                        },
                      );
                    },
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Navigation helpers ───────────────────────────────────────
  void _openNote(NavigatorState nav, int id) {
    DebugConfig.nav('Home → NoteDetail id=$id');
    nav.push(MaterialPageRoute(builder: (_) => NoteDetailScreen(itemId: id)));
  }

  void _openTask(NavigatorState nav, int id) {
    DebugConfig.nav('Home → TaskDetail id=$id');
    nav.push(MaterialPageRoute(builder: (_) => TaskDetailScreen(itemId: id)));
  }

  Future<void> _createAndOpenNote(BuildContext context, WidgetRef ref) async {
    DebugConfig.nav('Home: createNote');
    final nav = Navigator.of(context);
    final item = await ref.read(itemNotifierProvider.notifier)
        .create(type: ItemType.note);
    DebugConfig.db('note created id=${item?.id}');
    if (item == null) return;
    _openNote(nav, item.id);
  }


  Future<void> _createAndOpenTask(BuildContext context, WidgetRef ref) async {
    DebugConfig.nav('Home: createTask');
    final nav = Navigator.of(context);
    final item = await ref.read(itemNotifierProvider.notifier).create(type: ItemType.task);
    DebugConfig.db('task created id=${item?.id}');
    if (item == null) return;
    ref.invalidate(_todayTasksProvider);
    _openTask(nav, item.id);
  }

  Future<void> _toggleDone(WidgetRef ref, Item item) async {
    final next = item.status == ItemStatus.done ? ItemStatus.active : ItemStatus.done;
    DebugConfig.db('Home toggleDone id=${item.id} ${item.status.name} -> ${next.name}');
    await ref.read(itemNotifierProvider.notifier).updateItem(item.id, status: next);
    DebugConfig.provider('invalidate todayTasks + stats');
    ref.invalidate(_todayTasksProvider);
    ref.invalidate(_statsProvider);
  }
}

// ════════════════════════════════════════════════════════════════
// HOME APP BAR — ConsumerWidget (χωρίς παράμετρο)
// ════════════════════════════════════════════════════════════════

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(defaultWorkspaceProvider);
    final wsName = workspaceAsync.valueOrNull?.name ?? 'SuperNote';

    return SliverAppBar(
      backgroundColor: context.cBg,
      surfaceTintColor: Colors.transparent,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Text(wsName, style: context.titleLg),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: context.cText2),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          tooltip: 'Αναζήτηση',
        ),
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: context.cText2),
          onPressed: () => DebugConfig.nav('Home: notifications (TODO)'),
          tooltip: 'Ειδοποιήσεις',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// GREETING — plain Widget (χρησιμοποιείται μέσα σε SliverToBoxAdapter)
// ════════════════════════════════════════════════════════════════

class _GreetingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now  = DateTime.now();
    final hour = now.hour;

    final String greeting;
    final IconData greetIcon;
    if (hour < 12) {
      greeting  = 'Καλημέρα!';
      greetIcon = Icons.wb_sunny_rounded;
    } else if (hour < 18) {
      greeting  = 'Καλό απόγευμα!';
      greetIcon = Icons.wb_cloudy_rounded;
    } else {
      greeting  = 'Καλησπέρα!';
      greetIcon = Icons.nights_stay_rounded;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.md,
        context.responsiveHPadding, Spacing.sm,
      ),
      child: Row(
        children: [
          Icon(greetIcon, size: 22,
              color: ColorsUI.getWarning(context.brightness)),
          const SizedBox(width: Spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: context.titleLg),
              Text(now.dateTime,
                  style: context.bodySm.withColor(context.cText2)),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATS ROW — plain Widget
// ════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final Map<ItemType, int> stats;
  const _StatsRow({required this.stats});

  static const _shown = [
    ItemType.note, ItemType.task, ItemType.habit, ItemType.project,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical:   Spacing.xs,
        ),
        itemCount:        _shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (_, i) => _StatChip(
          type:  _shown[i],
          count: stats[_shown[i]] ?? 0,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final ItemType type;
  final int count;
  const _StatChip({required this.type, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = ColorsUI.itemTypeColor(type, context.brightness);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: AppRadius.cardBR,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ItemTypeIcon(type, size: 18, color: color),
          const SizedBox(width: Spacing.xs),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$count', style: context.titleMd.withColor(color)),
              Text(ItemTypeIcon.labelFor(type),
                  style: context.labelSm.withColor(context.cText2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical:   Spacing.xs,
        ),
        itemCount:        4,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (_, __) => Container(
          width: 100,
          decoration: BoxDecoration(
            color: ColorsUI.getBorder(context.brightness)
                .withValues(alpha: 0.4),
            borderRadius: AppRadius.cardBR,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// QUICK ACTIONS — plain Widget
// ════════════════════════════════════════════════════════════════

class _QuickActions extends StatelessWidget {
  final VoidCallback onNewNote;
  final VoidCallback onNewTask;
  const _QuickActions({required this.onNewNote, required this.onNewTask});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.sm,
        context.responsiveHPadding, Spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: _QuickActionBtn(
            icon:  Icons.note_add_rounded,
            label: 'Νέα Σημείωση',
            color: ColorsUI.itemTypeColor(ItemType.note, context.brightness),
            onTap: onNewNote,
          )),
          const SizedBox(width: Spacing.sm),
          Expanded(child: _QuickActionBtn(
            icon:  Icons.add_task_rounded,
            label: 'Νέα Εργασία',
            color: ColorsUI.itemTypeColor(ItemType.task, context.brightness),
            onTap: onNewTask,
          )),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: Spacing.sm + 2, horizontal: Spacing.md),
        decoration: BoxDecoration(
          color:        ColorsUI.getSurface(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(color: ColorsUI.getBorder(context.brightness)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: Spacing.xs),
            Text(label, style: context.labelMd.withColor(context.cText)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SECTION TITLE — plain Widget (ΟΧΙ sliver)
// Χρησιμοποιείται:
//   - Mobile: μέσα σε SliverToBoxAdapter(child: _SectionTitle())
//   - Tablet:  απευθείας μέσα σε Column (plain layout)
// ════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onSeeAll;

  const _SectionTitle({
    required this.title,
    required this.icon,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    // Επιστρέφει ΠΑΝΤΑ plain Padding — ποτέ SliverToBoxAdapter
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.lg,
        context.responsiveHPadding, Spacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: context.cText2),
            const SizedBox(width: Spacing.xs),
            Text(title, style: context.titleSm),
          ]),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text('Όλα',
                  style: context.labelMd.withColor(context.cPrimary)),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PINNED SECTION — SliverMainAxisGroup (sliver)
// ════════════════════════════════════════════════════════════════

class _PinnedSection extends StatelessWidget {
  final List<Item> items;
  const _PinnedSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.responsiveHPadding, Spacing.lg,
            context.responsiveHPadding, Spacing.sm,
          ),
          child: Row(children: [
            Icon(Icons.push_pin_rounded, size: 16, color: context.cText2),
            const SizedBox(width: Spacing.xs),
            Text('Καρφιτσωμένα', style: context.titleSm),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
                horizontal: context.responsiveHPadding),
            itemCount:        items.length,
            separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
            itemBuilder: (_, i) => SizedBox(
              width: context.responsive(mobile: 220.0, tablet: 260.0),
              child: _PinnedCard(item: items[i]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _PinnedCard extends StatelessWidget {
  final Item item;
  const _PinnedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = ColorsUI.itemTypeColor(item.type, context.brightness);
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color:        ColorsUI.getCard(context.brightness),
        borderRadius: AppRadius.cardBR,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ItemTypeIcon(item.type, size: 14, color: color),
            const SizedBox(width: Spacing.xs),
            Text(ItemTypeIcon.labelFor(item.type),
                style: context.labelSm.withColor(color)),
            const Spacer(),
            Icon(Icons.push_pin_rounded, size: 12, color: context.cDisabled),
          ]),
          const SizedBox(height: Spacing.xs),
          Expanded(
            child: Text(
              item.title ?? 'Χωρίς τίτλο',
              style: context.bodyMd,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TODAY TASKS SLIVER — επιστρέφει sliver (για mobile CustomScrollView)
// ════════════════════════════════════════════════════════════════

class _TodayTasksSliver extends ConsumerWidget {
  final List<Item> tasks;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onToggle;

  const _TodayTasksSliver({
    required this.tasks,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayTasks = _filterToday(ref, tasks);

    if (todayTasks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsiveHPadding,
            vertical:   Spacing.sm,
          ),
          child: _AllDoneMessage(),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical:   Spacing.xs,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: _TodayTaskTile(
              task:     todayTasks[i],
              onTap:    () => onTap(todayTasks[i].id),
              onToggle: () => onToggle(todayTasks[i]),
            ),
          ),
          childCount: todayTasks.take(5).length,
        ),
      ),
    );
  }

  List<Item> _filterToday(WidgetRef ref, List<Item> tasks) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <Item>[];
    for (final task in tasks) {
      if (task.status == ItemStatus.done) continue;
      final due = ref.watch(dueDateProvider(task.id)).valueOrNull;
      if (due == null) continue;
      if (!DateTime(due.year, due.month, due.day).isAfter(today)) {
        result.add(task);
      }
    }
    return result;
  }
}

// ════════════════════════════════════════════════════════════════
// TODAY TASKS COLUMN — plain Widget (για tablet Row)
// ════════════════════════════════════════════════════════════════

class _TodayTasksColumn extends ConsumerWidget {
  final List<Item> tasks;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onToggle;

  const _TodayTasksColumn({
    required this.tasks,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTasks = tasks.where((t) {
      if (t.status == ItemStatus.done) return false;
      final due = ref.watch(dueDateProvider(t.id)).valueOrNull;
      if (due == null) return false;
      return !DateTime(due.year, due.month, due.day).isAfter(today);
    }).take(5).toList();

    if (todayTasks.isEmpty) return _AllDoneMessage();

    return Column(
      children: todayTasks.map((t) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: _TodayTaskTile(
          task:     t,
          onTap:    () => onTap(t.id),
          onToggle: () => onToggle(t),
        ),
      )).toList(),
    );
  }
}

// ── All done message ──────────────────────────────────────────────

class _AllDoneMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color:        ColorsUI.getSurface(context.brightness),
        borderRadius: AppRadius.cardBR,
      ),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, color: context.cSuccess, size: 20),
        const SizedBox(width: Spacing.sm),
        Text('Όλα έτοιμα για σήμερα! 🎉', style: context.bodyMd),
      ]),
    );
  }
}

// ── Today task tile ───────────────────────────────────────────────

class _TodayTaskTile extends StatelessWidget {
  final Item task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _TodayTaskTile({
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == ItemStatus.done;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color:        ColorsUI.getSurface(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(color: ColorsUI.getBorder(context.brightness)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: AppDuration.fast,
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: isDone ? context.cPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(
                  color: isDone ? context.cPrimary
                      : ColorsUI.getBorder(context.brightness),
                  width: 2,
                ),
              ),
              child: isDone
                  ? Icon(Icons.check_rounded, size: 14,
                  color: ColorsUI.getAccessibleTextColor(context.cPrimary))
                  : null,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              task.title ?? 'Χωρίς τίτλο',
              style: context.bodyMd.copyWith(
                decoration:      isDone ? TextDecoration.lineThrough : null,
                decorationColor: context.cDisabled,
                color: isDone ? context.cDisabled : context.cText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (task.priority != ItemPriority.none) ...[
            const SizedBox(width: Spacing.xs),
            PriorityBadge.dot(priority: task.priority),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RECENT NOTES SLIVER — επιστρέφει sliver (για mobile)
// ════════════════════════════════════════════════════════════════

class _RecentNotesSliver extends StatelessWidget {
  final List<Item> notes;
  final ValueChanged<int> onTap;
  const _RecentNotesSliver({required this.notes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHPadding),
          child: EmptyState.forType(ItemType.note, compact: true),
        ),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical:   Spacing.xs,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: ItemCard(
              item:    notes[i],
              compact: true,
              onTap:   () => onTap(notes[i].id),
            ),
          ),
          childCount: notes.length,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RECENT NOTES COLUMN — plain Widget (για tablet)
// ════════════════════════════════════════════════════════════════

class _RecentNotesColumn extends StatelessWidget {
  final List<Item> notes;
  final ValueChanged<int> onTap;
  const _RecentNotesColumn({required this.notes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return EmptyState.forType(ItemType.note, compact: true);
    }
    return Column(
      children: notes.map((n) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: ItemCard(
          item:    n,
          compact: true,
          onTap:   () => onTap(n.id),
        ),
      )).toList(),
    );
  }
}

// RECENT ITEMS SLIVER — για mobile
class _RecentItemsSliver extends StatelessWidget {
  final List<Item> items;
  final ValueChanged<Item> onTap;

  const _RecentItemsSliver({
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsiveHPadding,
          ),
          child: EmptyState.forType(
            ItemType.note,
            compact: true,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.xs,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: ItemCard(
              item: items[i],
              compact: true,
              onTap: () => onTap(items[i]),
            ),
          ),
          childCount: items.length,
        ),
      ),
    );
  }
}

// RECENT ITEMS COLUMN — για tablet
class _RecentItemsColumn extends StatelessWidget {
  final List<Item> items;
  final ValueChanged<Item> onTap;

  const _RecentItemsColumn({
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState.forType(
        ItemType.note,
        compact: true,
      );
    }

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: ItemCard(
            item: item,
            compact: true,
            onTap: () => onTap(item),
          ),
        );
      }).toList(),
    );
  }
}
