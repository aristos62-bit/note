// lib/features/habits/habit_list_screen.dart
//
// Λίστα συνηθειών: today progress (συνολική πρόοδος), κάρτες με progress bar.
// ✅ Responsive: list mobile / grid tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions + ItemColorHelper
// ✅ DebugConfig: nav, db, provider logs
// ✅ ViewMode toggle (pinned/favorites/all) ενσωματωμένο
// ✅ Αυτόματη επιλογή φακέλου βάσει ρυθμίσεων (προεπιλεγμένος ή "Γενικά")
// ✅ Περιμένει τα settings πριν επιλέξει φάκελο (διορθωμένο)
// ✅ Search, filter tags
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'habit_detail_screen.dart';
import '../../services/reminder_scheduler.dart';
import '../../helpers/item_color_helper.dart';

final _habitSearchQueryProvider = StateProvider<String>((ref) => '');
final _habitTagFilterProvider = StateProvider<Set<String>>((ref) => {});

// ════════════════════════════════════════════════════════════════
// HABIT LIST SCREEN
// ════════════════════════════════════════════════════════════════

class HabitListScreen extends ConsumerStatefulWidget {
  const HabitListScreen({super.key});

  @override
  ConsumerState<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends ConsumerState<HabitListScreen> {
  bool _searchActive = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  int? _selectedFolderId;
  Set<String> _visibleTagNames = {};

  // ✅ Αν ο χρήστης έχει κάνει χειροκίνητη επιλογή, δεν ξαναβάζουμε system folder
  bool _userExplicitlySelected = false;
  bool _autoSelectDone = false;  // ✅ προστέθηκε

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_habitSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _toggleSearch() {
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      ref.read(_habitSearchQueryProvider.notifier).state = '';
      ref.read(_habitTagFilterProvider.notifier).state = {};
    } else {
      Future.microtask(() => _searchFocus.requestFocus());
    }
    DebugConfig.nav('HabitList toggleSearch: $_searchActive');
  }

  Future<void> _createHabit() async {
    if (_selectedFolderId == null) {
      DebugConfig.error('HabitList: createHabit without selected folder');
      return;
    }
    DebugConfig.nav('HabitList: create habit in folder id=$_selectedFolderId');

    final notifier = ref.read(itemNotifierProvider.notifier);
    final item = await notifier.create(
      type: ItemType.habit,
      folderId: _selectedFolderId,
    );
    if (item == null || !mounted) return;

    ref.invalidate(itemNotifierProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HabitDetailScreen(itemId: item.id, isNew: true),
      ),
    );
  }

  void _openDetail(int id) {
    DebugConfig.nav('HabitList → HabitDetail id=$id');
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => HabitDetailScreen(itemId: id, isNew: false)),
    );
  }

  Future<void> _delete(BuildContext context, Item item) async {
    final future = ConfirmDialog.delete(context, title: 'Διαγραφή συνήθειας;');
    final ok = await future;
    if (!ok || !mounted) return;
    await ReminderScheduler.instance.cancelAllForItem(item.id);
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('HabitListScreen build');
    final habitsAsync = ref.watch(itemNotifierProvider);
    final searchQuery = ref.watch(_habitSearchQueryProvider);
    final activeTags = ref.watch(_habitTagFilterProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);

    // ✅ Προσθήκη: περιμένουμε τα settings
    final settingsAsync = ref.watch(settingsNotifierProvider);

    // ✅ Αυτόματη επιλογή φακέλου ΜΟΝΟ όταν φορτώσουν τα settings και οι φάκελοι
    if (!_userExplicitlySelected && !_autoSelectDone && settingsAsync.hasValue && foldersAsync.hasValue) {
      final folders = foldersAsync.value!;
      if (folders.isNotEmpty && mounted && _selectedFolderId == null) {
        final settings = settingsAsync.requireValue;
        final preferredId = settings.preferredFolderId;
        int? targetId = preferredId;
        if (targetId == null || !folders.any((f) => f.id == targetId)) {
          targetId = folders.firstWhere(
                (f) => f.isSystem,
            orElse: () => folders.first,
          ).id;
        }
        _autoSelectDone = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _selectedFolderId = targetId);
            DebugConfig.nav('HabitList: auto-selected folder id=$targetId (preferredId=$preferredId)');
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(),
      floatingActionButton: _selectedFolderId != null
          ? FloatingActionButton(
        onPressed: _createHabit,
        tooltip: 'Νέα συνήθεια',
        child: const Icon(Icons.add_rounded),
      )
          : null,
      body: Column(
        children: [
          if (_searchActive)
            _SearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (value) {
                setState(() {});
                _onSearchChanged(value);
              },
            ),
          foldersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (folders) {
              if (folders.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: FolderChipSelector(
                  folders: folders,
                  selectedFolderId: _selectedFolderId,
                  onSelect: (id) {
                    setState(() {
                      _selectedFolderId = id;
                      _userExplicitlySelected = true;
                    });
                    DebugConfig.nav('HabitList: select folder id=$id');
                  },
                ),
              );
            },
          ),
          if (_visibleTagNames.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.responsiveHPadding,
                    0,
                    context.responsiveHPadding,
                    Spacing.xs,
                  ),
                  child: Text(
                    'Επιλέξτε tag για φιλτράρισμα συνηθειών',
                    style: context.labelSm.withColor(context.cText2),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                        horizontal: context.responsiveHPadding),
                    itemCount: _visibleTagNames.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(width: Spacing.xs),
                    itemBuilder: (_, i) {
                      final name = _visibleTagNames.elementAt(i);
                      final selected = activeTags.contains(name);
                      return TagChip(
                        name: name,
                        color: null,
                        compact: true,
                        selected: selected,
                        onTap: () {
                          final current =
                          ref.read(_habitTagFilterProvider);
                          final newSet = {...current};
                          if (newSet.contains(name)) {
                            newSet.remove(name);
                          } else {
                            newSet.add(name);
                          }
                          ref.read(_habitTagFilterProvider.notifier).state =
                              newSet;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          const ViewModeToggle(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(itemNotifierProvider),
              child: habitsAsync.when(
                loading: () => _LoadingList(),
                error: (e, _) {
                  DebugConfig.error('HabitList load failed', e);
                  return EmptyState.error(
                      onRetry: () => ref.invalidate(itemNotifierProvider));
                },
                data: (items) {
                  var habitsOnly = items
                      .where((it) => it.type == ItemType.habit)
                      .toList();

                  if (_selectedFolderId != null) {
                    habitsOnly = habitsOnly
                        .where((h) => h.folderId == _selectedFolderId)
                        .toList();
                  }

                  final viewMode = ref.watch(listViewModeProvider);
                  switch (viewMode) {
                    case ListViewMode.pinned:
                      habitsOnly =
                          habitsOnly.where((h) => h.pinned).toList();
                      break;
                    case ListViewMode.favorites:
                      habitsOnly =
                          habitsOnly.where((h) => h.favorite).toList();
                      break;
                    case ListViewMode.all:
                      break;
                  }

                  if (searchQuery.isNotEmpty) {
                    final q = searchQuery.toLowerCase();
                    habitsOnly = habitsOnly
                        .where((h) =>
                        (h.title ?? '').toLowerCase().contains(q))
                        .toList();
                  }

                  if (activeTags.isNotEmpty) {
                    habitsOnly = habitsOnly.where((h) {
                      final tagsAsync =
                          ref.watch(itemTagsProvider(h.id)).valueOrNull ?? [];
                      return tagsAsync
                          .any((tag) => activeTags.contains(tag.name));
                    }).toList();
                  }

                  final visibleTagNames = <String>{};
                  for (final h in habitsOnly) {
                    final tagsAsync =
                        ref.watch(itemTagsProvider(h.id)).valueOrNull ?? [];
                    for (final t in tagsAsync) {
                      visibleTagNames.add(t.name);
                    }
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (!const SetEquality<String>()
                        .equals(_visibleTagNames, visibleTagNames)) {
                      setState(() => _visibleTagNames = visibleTagNames);
                    }
                  });

                  if (habitsOnly.isEmpty) {
                    if (searchQuery.isNotEmpty || activeTags.isNotEmpty) {
                      return EmptyState.search(query: searchQuery);
                    }
                    return EmptyState.forType(ItemType.habit,
                        onAction: _createHabit);
                  }

                  return Column(
                    children: [
                      _TodayProgress(habits: habitsOnly),
                      Expanded(
                        child: ResponsiveLayout(
                          mobile: _HabitListMobile(
                            habits: habitsOnly,
                            onTap: _openDetail,
                            onDelete: (item) => _delete(context, item),
                          ),
                          tablet: _HabitGrid(
                            habits: habitsOnly,
                            onTap: _openDetail,
                            onDelete: (item) => _delete(context, item),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: context.cBg,
    elevation: 0,
    scrolledUnderElevation: 1,
    title: const Text('Συνήθειες'),
    actions: [
      IconButton(
        icon: Icon(_searchActive
            ? Icons.search_off_rounded
            : Icons.search_rounded),
        onPressed: _toggleSearch,
        tooltip: _searchActive ? 'Κλείσιμο αναζήτησης' : 'Αναζήτηση',
      ),
      IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () =>
            DebugConfig.nav('HabitList: notifications (TODO)'),
        tooltip: 'Ειδοποιήσεις',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (value) {
          if (value == 'archived') {
            final show = ref.read(showArchivedProvider);
            ref.read(showArchivedProvider.notifier).state = !show;
            ref.invalidate(itemNotifierProvider);
            DebugConfig.nav('HabitList: toggle archived → ${!show}');
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'archived',
            child: Row(children: [
              const Icon(Icons.archive_rounded, size: 18),
              const SizedBox(width: Spacing.sm),
              Text(
                ref.watch(showArchivedProvider)
                    ? 'Απόκρυψη αρχείου'
                    : 'Εμφάνιση αρχείου',
              ),
            ]),
          ),
        ],
      ),
    ],
  );
}

// ──────────────────────────────────────────────────────────────
// Search bar (like others)
// ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cBg,
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding,
        Spacing.sm,
        context.responsiveHPadding,
        Spacing.sm,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: context.bodyMd,
        decoration: InputDecoration(
          hintText: 'Αναζήτηση συνηθειών...',
          hintStyle: context.bodyMd.withColor(context.cDisabled),
          prefixIcon: Icon(Icons.search_rounded, color: context.cText2),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close_rounded, color: context.cText2),
            onPressed: () {
              controller.clear();
              onChanged('');
            },
          )
              : null,
          filled: true,
          fillColor: ColorsUI.getSurface(context.brightness),
          border: OutlineInputBorder(
            borderRadius: AppRadius.inputBR,
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TODAY PROGRESS (aggregated)
// ════════════════════════════════════════════════════════════════

class _TodayProgress extends ConsumerWidget {
  final List<Item> habits;
  const _TodayProgress({required this.habits});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int totalDone = 0;
    int totalGoal = 0;

    for (final h in habits) {
      final stats = ref.watch(habitStatsProvider(h.id)).valueOrNull;
      if (stats != null) {
        totalDone += stats.dailyProgress.clamp(0, stats.goalCount);
        totalGoal += stats.goalCount;
      }
    }

    final progress = totalGoal > 0 ? totalDone / totalGoal : 0.0;
    final isAllDone = totalGoal > 0 && totalDone >= totalGoal;

    return Container(
      margin: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.md,
          context.responsiveHPadding, Spacing.sm),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: ColorsUI.getSurface(context.brightness),
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
              Text('$totalDone / $totalGoal',
                  style: context.titleSm.withColor(context.cPrimary)),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: ColorsUI.getBorder(context.brightness),
              valueColor: AlwaysStoppedAnimation<Color>(
                  isAllDone ? context.cSuccess : context.cPrimary),
            ),
          ),
          if (isAllDone) ...[
            const SizedBox(height: Spacing.sm),
            Row(children: [
              Icon(Icons.celebration_rounded,
                  size: 16, color: context.cSuccess),
              const SizedBox(width: Spacing.xs),
              Text('Όλοι οι στόχοι επιτεύχθηκαν! 🎉',
                  style: context.bodySm.withColor(context.cSuccess)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HABIT CARD (with progress bar)
// ════════════════════════════════════════════════════════════════

class HabitCard extends ConsumerWidget {
  final Item habit;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(habitStatsProvider(habit.id)).valueOrNull;
    final backgroundColor =
    ItemColorHelper.backgroundColorForType(ItemType.habit, context);
    final foregroundColor =
    ItemColorHelper.textColorForBackground(backgroundColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha: 0.7);
    final accentColor =
    ItemColorHelper.iconColorForType(ItemType.habit, context);

    final goal = stats?.goalCount ?? 0;
    final dailyProgress = stats?.dailyProgress ?? 0;
    final unit = stats?.unit ?? '';
    final percent = goal > 0 ? dailyProgress / goal : 0.0;
    final isCompleted = goal > 0 && dailyProgress >= goal;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: AnimatedContainer(
        duration: AppDuration.normal,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.cardBR,
          border: Border.all(
            color: isCompleted
                ? accentColor.withValues(alpha: 0.6)
                : ColorsUI.getBorder(context.brightness),
            width: isCompleted ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.title ?? 'Χωρίς τίτλο',
                style: context.titleSm.copyWith(color: foregroundColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Spacing.xs),
              if (goal > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor: ColorsUI.getBorder(context.brightness),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
              ],
              Row(
                children: [
                  _StatBadge(
                    icon: Icons.local_fire_department_rounded,
                    value: '${stats?.streak ?? 0}',
                    label: 'streak',
                    color: (stats?.streak ?? 0) > 0
                        ? ColorsUI.getWarning(context.brightness)
                        : secondaryForeground,
                    textColor: foregroundColor,
                  ),
                  const SizedBox(width: Spacing.sm),
                  _StatBadge(
                    icon: Icons.emoji_events_rounded,
                    value: '${stats?.bestStreak ?? 0}',
                    label: 'best',
                    color: secondaryForeground,
                    textColor: foregroundColor,
                  ),
                  const Spacer(),
                  if (goal > 0)
                    Text(
                      '$dailyProgress / $goal $unit',
                      style: context.labelSm.copyWith(color: accentColor),
                    ),
                ],
              ),
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
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.cBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Επεξεργασία'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
            ListTile(
              leading:
              Icon(Icons.delete_outline_rounded, color: context.cError),
              title: Text('Διαγραφή', style: TextStyle(color: context.cError)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color textColor;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(value, style: context.labelSm.copyWith(color: color)),
        const SizedBox(width: 2),
        Text(label,
            style: context.labelSm.copyWith(
                color: textColor.withValues(alpha: 0.7))),
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
  final ValueChanged<Item> onDelete;

  const _HabitListMobile({
    required this.habits,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding, vertical: Spacing.xs),
      itemCount: habits.length,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, i) => HabitCard(
        habit: habits[i],
        onTap: () => onTap(habits[i].id),
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
  final ValueChanged<Item> onDelete;

  const _HabitGrid({
    required this.habits,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cols = context.gridColumns;
    return GridView.builder(
      padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding, vertical: Spacing.xs),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        mainAxisExtent: 140,
      ),
      itemCount: habits.length,
      itemBuilder: (_, i) => HabitCard(
        habit: habits[i],
        onTap: () => onTap(habits[i].id),
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
          horizontal: context.responsiveHPadding, vertical: Spacing.sm),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, __) => const ItemCardSkeleton(),
    );
  }
}