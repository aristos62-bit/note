// lib/features/habits/habit_list_screen.dart
//
// Λίστα συνηθειών με today progress, streak badge, mark done.
// ✅ Responsive: list mobile / grid tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/habit_service.dart';
import '../../shared/widgets/widgets.dart';

// ── Local providers ───────────────────────────────────────────────

final _habitStatsProvider =
FutureProvider.family<HabitStats, int>((ref, habitId) async {
  DebugConfig.db('_habitStatsProvider id=$habitId');
  return HabitService.instance.getStats(habitId);
});

// ════════════════════════════════════════════════════════════════
// HABIT LIST SCREEN
// ════════════════════════════════════════════════════════════════

class HabitListScreen extends ConsumerStatefulWidget {
  const HabitListScreen({super.key});

  @override
  ConsumerState<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends ConsumerState<HabitListScreen> {

  @override
  void initState() {
    super.initState();
    // Όταν μπαίνουμε στη λίστα συνηθειών, φιλτράρουμε global σε habits
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeItemTypeFilterProvider.notifier).state = ItemType.habit;
    });
  }

  Future<void> _createHabit() async {
    DebugConfig.nav('HabitList: create habit');
    final item = await ref.read(itemNotifierProvider.notifier)
        .create(type: ItemType.habit);
    if (item == null || !mounted) return;
    // Δεν χρειάζεται invalidate: create() κάνει ref.invalidateSelf()
    context.push(AppRoutes.habit(item.id));
  }

  Future<void> _markDone(int habitId) async {
    DebugConfig.db('HabitList: markDone id=$habitId');
    await HabitService.instance.markCompleted(habitId);
    ref.invalidate(_habitStatsProvider(habitId));
    // Αν το HabitService αλλάζει και το Item (π.χ. κάποιο flag),
    // μπορείς προαιρετικά:
    // ref.invalidate(itemNotifierProvider);
  }

  Future<void> _delete(BuildContext context, Item item) async {
    final future = ConfirmDialog.delete(
        context, title: 'Διαγραφή συνήθειας;');
    final ok = await future;
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    // Δεν χρειάζεται invalidate: deleteItem() κάνει ref.invalidateSelf()
  }


  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('HabitListScreen build');
    final habitsAsync = ref.watch(itemNotifierProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor:        context.cBg,
        elevation:              0,
        scrolledUnderElevation: 1,
        title: const Text('Συνήθειες'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _createHabit,
            tooltip: 'Νέα συνήθεια',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createHabit,
        tooltip: 'Νέα συνήθεια',
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(itemNotifierProvider),
        child: habitsAsync.when(
          loading: () => _LoadingList(),
          error: (e, _) {
            DebugConfig.error('HabitList load failed', e);
            return EmptyState.error(
                onRetry: () => ref.invalidate(itemNotifierProvider));
          },
          data: (habits) {
            if (habits.isEmpty) {
              return EmptyState.forType(
                  ItemType.habit, onAction: _createHabit);
            }

            // Σήμερα progress header
            return Column(
              children: [
                _TodayProgress(habits: habits),
                Expanded(
                  child: ResponsiveLayout(
                    mobile:  _HabitListMobile(
                      habits:   habits,
                      onTap:    (id) => context.push(AppRoutes.habit(id)),
                      onDone:   _markDone,
                      onDelete: (item) => _delete(context, item),
                    ),
                    tablet: _HabitGrid(
                      habits:   habits,
                      onTap:    (id) => context.push(AppRoutes.habit(id)),
                      onDone:   _markDone,
                      onDelete: (item) => _delete(context, item),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TODAY PROGRESS HEADER
// ════════════════════════════════════════════════════════════════

class _TodayProgress extends ConsumerWidget {
  final List<Item> habits;
  const _TodayProgress({required this.habits});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Μετράμε πόσες έχουν γίνει σήμερα
    int doneCount = 0;
    for (final h in habits) {
      final stats = ref.watch(_habitStatsProvider(h.id)).valueOrNull;
      if (stats?.completedToday == true) doneCount++;
    }

    final total    = habits.length;
    final progress = total > 0 ? doneCount / total : 0.0;

    return Container(
      margin: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.md,
        context.responsiveHPadding, Spacing.sm,
      ),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color:        ColorsUI.getSurface(context.brightness),
        borderRadius: AppRadius.cardBR,
        border: Border.all(color: ColorsUI.getBorder(context.brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Σήμερα', style: context.titleSm),
              Text('$doneCount / $total',
                  style: context.titleSm.withColor(context.cPrimary)),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            progress,
              minHeight:        8,
              backgroundColor:  ColorsUI.getBorder(context.brightness),
              valueColor:       AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? context.cSuccess : context.cPrimary,
              ),
            ),
          ),
          if (progress >= 1.0) ...[
            const SizedBox(height: Spacing.sm),
            Row(children: [
              Icon(Icons.celebration_rounded,
                  size: 16, color: context.cSuccess),
              const SizedBox(width: Spacing.xs),
              Text('Όλες οι συνήθειες ολοκληρώθηκαν! 🎉',
                  style: context.bodySm.withColor(context.cSuccess)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HABIT CARD
// ════════════════════════════════════════════════════════════════

class HabitCard extends ConsumerWidget {
  final Item habit;
  final VoidCallback onTap;
  final VoidCallback onDone;
  final VoidCallback onDelete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onTap,
    required this.onDone,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_habitStatsProvider(habit.id));
    final stats      = statsAsync.valueOrNull;
    final isDoneToday = stats?.completedToday ?? false;
    final color = ColorsUI.itemTypeColor(ItemType.habit, context.brightness);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: AnimatedContainer(
        duration: AppDuration.normal,
        decoration: BoxDecoration(
          color: isDoneToday
              ? color.withValues(alpha: 0.08)
              : ColorsUI.getCard(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(
            color: isDoneToday
                ? color.withValues(alpha: 0.4)
                : ColorsUI.getBorder(context.brightness),
            width: isDoneToday ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Row(
                children: [
                  // Done button
                  GestureDetector(
                    onTap: isDoneToday ? null : onDone,
                    child: AnimatedContainer(
                      duration: AppDuration.normal,
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: isDoneToday
                            ? color
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDoneToday
                              ? color
                              : ColorsUI.getBorder(context.brightness),
                          width: 2,
                        ),
                      ),
                      child: isDoneToday
                          ? Icon(Icons.check_rounded, size: 18,
                          color: ColorsUI.getAccessibleTextColor(color))
                          : Icon(Icons.loop_rounded, size: 16,
                          color: context.cText2),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      habit.title ?? 'Χωρίς τίτλο',
                      style: context.titleSm.copyWith(
                        decoration: isDoneToday
                            ? TextDecoration.none : null,
                        color: isDoneToday ? color : context.cText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: Spacing.sm),

              // ── Stats row ────────────────────────────────────
              if (stats != null)
                Row(
                  children: [
                    // Streak
                    _StatBadge(
                      icon:  Icons.local_fire_department_rounded,
                      value: '${stats.streak}',
                      label: 'streak',
                      color: stats.streak > 0
                          ? ColorsUI.getWarning(context.brightness)
                          : context.cDisabled,
                    ),
                    const SizedBox(width: Spacing.sm),
                    // Best streak
                    _StatBadge(
                      icon:  Icons.emoji_events_rounded,
                      value: '${stats.bestStreak}',
                      label: 'best',
                      color: context.cText2,
                    ),
                    const SizedBox(width: Spacing.sm),
                    // Total completions
                    _StatBadge(
                      icon:  Icons.check_circle_outline_rounded,
                      value: '${stats.completedCount}',
                      label: 'σύνολο',
                      color: context.cText2,
                    ),
                    const Spacer(),
                    // Progress vs goal
                    if (stats.goalCount > 0)
                      Text(
                        '${stats.completedCount}/${stats.goalCount}',
                        style: context.labelSm.withColor(color),
                      ),
                  ],
                )
              else
                Row(children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.cDisabled),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text('Φόρτωση...',
                      style: context.labelSm.withColor(context.cDisabled)),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.cBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title:   const Text('Επεξεργασία'),
              onTap: () { Navigator.pop(context); onTap(); },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: context.cError),
              title: Text('Διαγραφή',
                  style: TextStyle(color: context.cError)),
              onTap: () { Navigator.pop(context); onDelete(); },
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

// ── Stat badge ────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(value, style: context.labelSm.withColor(color)),
        const SizedBox(width: 2),
        Text(label, style: context.labelSm.withColor(context.cDisabled)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MOBILE LIST
// ════════════════════════════════════════════════════════════════

class _HabitListMobile extends StatelessWidget {
  final List<Item> habits;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onDone;
  final ValueChanged<Item> onDelete;

  const _HabitListMobile({
    required this.habits,
    required this.onTap,
    required this.onDone,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical:   Spacing.xs,
      ),
      itemCount:        habits.length,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, i) => HabitCard(
        habit:    habits[i],
        onTap:    () => onTap(habits[i].id),
        onDone:   () => onDone(habits[i].id),
        onDelete: () => onDelete(habits[i]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TABLET GRID
// ════════════════════════════════════════════════════════════════

class _HabitGrid extends StatelessWidget {
  final List<Item> habits;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onDone;
  final ValueChanged<Item> onDelete;

  const _HabitGrid({
    required this.habits,
    required this.onTap,
    required this.onDone,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cols = context.gridColumns;
    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical:   Spacing.xs,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   cols,
        mainAxisSpacing:  Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        mainAxisExtent:   140,
      ),
      itemCount: habits.length,
      itemBuilder: (_, i) => HabitCard(
        habit:    habits[i],
        onTap:    () => onTap(habits[i].id),
        onDone:   () => onDone(habits[i].id),
        onDelete: () => onDelete(habits[i]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// LOADING LIST
// ════════════════════════════════════════════════════════════════

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical:   Spacing.sm,
      ),
      itemCount:        4,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder:      (_, __) => const ItemCardSkeleton(),
    );
  }
}