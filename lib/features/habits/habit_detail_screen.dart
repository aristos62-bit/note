// lib/features/habits/habit_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/habit_service.dart';
import '../../services/reminder_scheduler.dart';
import '../../shared/widgets/widgets.dart';

// ════════════════════════════════════════════════════════════════
// HABIT DETAIL SCREEN
// ════════════════════════════════════════════════════════════════

class HabitDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  final bool isNew;

  const HabitDetailScreen({
    super.key,
    required this.itemId,
    this.isNew = false,
  });

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  late final TextEditingController _titleCtrl;
  Timer? _titleDebounce;
  bool _isSaving = false;
  bool _isEditingTitle = false;
  String _lastSavedTitle = '';
  bool _isPinned = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    DebugConfig.nav('HabitDetailScreen init id=${widget.itemId}');
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    _isEditingTitle = true;
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 600), () {
      _saveTitle(value.trim());
    });
  }

  Future<void> _saveTitle(String title) async {
    if (!mounted) return;
    if (title == _lastSavedTitle) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(itemNotifierProvider.notifier)
          .updateItem(widget.itemId, title: title.isEmpty ? null : title);
      _lastSavedTitle = title;
    } catch (e) {
      DebugConfig.error('HabitDetail _saveTitle', e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Αποθηκεύει αν υπάρχει τίτλος, αλλιώς διαγράφει τη συνήθεια.
  Future<void> _saveOrDelete() async {
    final title = _titleCtrl.text.trim();

    if (title.isEmpty) {
      // Κενός τίτλος → διαγραφή μόνο αν isNew
      if (widget.isNew) {
        DebugConfig.db('HabitDetail delete empty new habit id=${widget.itemId}');
        try {
          await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
        } catch (e) {
          DebugConfig.error('HabitDetail _saveOrDelete delete', e);
        }
      }
      return;
    }

    // Έχει τίτλο → αποθήκευση (ακυρώνουμε τυχόν εκκρεμές debounce)
    _titleDebounce?.cancel();
    try {
      await _saveTitle(title);
    } catch (e) {
      DebugConfig.error('HabitDetail _saveOrDelete save', e);
    }
  }

  Future<void> _incrementProgress() async {
    await HabitService.instance.incrementProgress(widget.itemId);
    if (!mounted) return;
    ref.invalidate(habitStatsProvider(widget.itemId));
  }

  Future<void> _decrementProgress() async {
    await HabitService.instance.decrementProgress(widget.itemId);
    if (!mounted) return;
    ref.invalidate(habitStatsProvider(widget.itemId));
  }

  Future<void> _incrementByTime(String time) async {
    await HabitService.instance.incrementByTime(widget.itemId, time);
    if (!mounted) return;
    ref.invalidate(habitStatsProvider(widget.itemId));
  }

  Future<void> _decrementByTime(String time) async {
    await HabitService.instance.decrementByTime(widget.itemId, time);
    if (!mounted) return;
    ref.invalidate(habitStatsProvider(widget.itemId));
  }

  Future<void> _delete(BuildContext context) async {
    final ok =
        await ConfirmDialog.delete(context, title: 'Διαγραφή συνήθειας;');
    if (!ok || !mounted) return;
    await ReminderScheduler.instance.deleteAllRemindersForItem(widget.itemId);
    if (!mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _togglePin(Item item) async {
    await ref
        .read(itemNotifierProvider.notifier)
        .togglePin(item.id, item.pinned);
    setState(() => _isPinned = !item.pinned);
  }

  Future<void> _toggleFav(Item item) async {
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleFavorite(item.id, item.favorite);
    setState(() => _isFavorite = !item.favorite);
  }

  Future<void> _toggleArchive(Item item) async {
    await handleArchive(
      context: context,
      ref: ref,
      itemId: item.id,
      isArchived: item.archived,
      label: ItemLabel.habit,
    );
  }

  Future<void> _showReminderDialog() async {
    final title =
        _titleCtrl.text.trim().isEmpty ? 'Συνήθεια' : _titleCtrl.text.trim();
    await showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: ReminderSection(
          itemId: widget.itemId,
          itemTitle: title,
          defaultStartTime: null,
        ),
      ),
    );
    await ReminderScheduler.instance.refreshRecurringReminders();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) => _buildError(),
      data: (item) {
        if (item == null) return _buildNotFound();

        final itemTitle = item.title ?? '';
        if (_lastSavedTitle.isEmpty && itemTitle.isNotEmpty) {
          _lastSavedTitle = itemTitle;
        }
        if (!_isEditingTitle && _titleCtrl.text != itemTitle) {
          _titleCtrl.text = itemTitle;
          _titleCtrl.selection =
              TextSelection.collapsed(offset: _titleCtrl.text.length);
        }

        _isPinned = item.pinned;
        _isFavorite = item.favorite;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (_isSaving) return;
            final nav = Navigator.of(context);
            await _saveOrDelete();
            if (mounted) nav.pop();
          },
          child: ResponsiveLayout(
            mobile: _buildMobile(context, item),
            tablet: _buildTablet(context, item),
          ),
        );
      },
    );
  }

  Widget _buildMobile(BuildContext context, Item item) => Scaffold(
        backgroundColor: context.cBg,
        appBar: _buildAppBar(context, item),
        body: _HabitBody(
          item: item,
          titleCtrl: _titleCtrl,
          isSaving: _isSaving,
          onTitleChange: _onTitleChanged,
          onIncrement: _incrementProgress,
          onDecrement: _decrementProgress,
          onIncrementByTime: _incrementByTime,
          onDecrementByTime: _decrementByTime,
          onDelete: () => _delete(context),
        ),
      );

  Widget _buildTablet(BuildContext context, Item item) => Scaffold(
        backgroundColor: context.cBg,
        appBar: _buildAppBar(context, item),
        body: Row(
          children: [
            SizedBox(
              width: context.isDesktop ? 300 : 260,
              child: _StatsPanel(habitId: item.id),
            ),
            VerticalDivider(
                width: 1, color: ColorsUI.getBorder(context.brightness)),
            Expanded(
              child: _HabitBody(
                item: item,
                titleCtrl: _titleCtrl,
                isSaving: _isSaving,
                onTitleChange: _onTitleChanged,
                onIncrement: _incrementProgress,
                onDecrement: _decrementProgress,
                onIncrementByTime: _incrementByTime,
                onDecrementByTime: _decrementByTime,
                onDelete: () => _delete(context),
                hideStats: true,
              ),
            ),
          ],
        ),
      );

  AppBar _buildAppBar(BuildContext context, Item item) => AppBar(
        backgroundColor: context.cBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        title: _isSaving
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: context.cText2),
                ),
                const SizedBox(width: Spacing.xs),
                Text('',
                    style: context.bodySm.withColor(context.cText2)),
              ])
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.save_rounded, color: context.cPrimary, size: 20),
            tooltip: 'Αποθήκευση',
            onPressed: _isSaving
                ? null
                : () async {
              if (_titleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Παρακαλώ προσθέστε τίτλο')),
                );
                return;
              }
              _titleDebounce?.cancel();
              final nav = Navigator.of(context);
              setState(() => _isSaving = true);
              try {
                await _saveTitle(_titleCtrl.text.trim());
                if (mounted) nav.pop();
              } catch (e) {
                DebugConfig.error('HabitDetail save button', e);
                if (mounted) {
                  setState(() => _isSaving = false);
                  if (!context.mounted)return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Σφάλμα αποθήκευσης: ${e.toString()}')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications_none_rounded,
                color: context.cText2, size: 20),
            onPressed: _showReminderDialog,
            tooltip: 'Υπενθύμιση',
          ),
          IconButton(
            icon: Icon(
                _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: _isPinned ? context.cPrimary : context.cText2,
                size: 20),
            onPressed: () => _togglePin(item),
          ),
          IconButton(
            icon: Icon(
                _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _isFavorite
                    ? ColorsUI.getWarning(context.brightness)
                    : context.cText2,
                size: 20),
            onPressed: () => _toggleFav(item),
          ),
          IconButton(
            icon: Icon(
                item.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
                color: context.cText2,
                size: 20),
            onPressed: () => _toggleArchive(item),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: context.cError, size: 20),
            onPressed: () => _delete(context),
          ),
        ],
      );

  Widget _buildLoading() => Scaffold(
        backgroundColor: context.cBg,
        appBar: AppBar(backgroundColor: context.cBg),
        body: const Center(child: CircularProgressIndicator()),
      );

  Widget _buildError() => Scaffold(
        backgroundColor: context.cBg,
        appBar: AppBar(backgroundColor: context.cBg),
        body: EmptyState.error(
            onRetry: () => ref.invalidate(itemStreamProvider(widget.itemId))),
      );

  Widget _buildNotFound() => Scaffold(
        backgroundColor: context.cBg,
        appBar: AppBar(backgroundColor: context.cBg),
        body: const EmptyState(
            icon: Icons.loop_rounded, title: 'Η συνήθεια δεν βρέθηκε'),
      );
}

// ════════════════════════════════════════════════════════════════
// HABIT BODY
// ════════════════════════════════════════════════════════════════

class _HabitBody extends ConsumerWidget {
  final Item item;
  final TextEditingController titleCtrl;
  final bool isSaving;
  final ValueChanged<String> onTitleChange;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<String> onIncrementByTime;
  final ValueChanged<String> onDecrementByTime;
  final VoidCallback onDelete;
  final bool hideStats;

  const _HabitBody({
    required this.item,
    required this.titleCtrl,
    required this.isSaving,
    required this.onTitleChange,
    required this.onIncrement,
    required this.onDecrement,
    required this.onIncrementByTime,
    required this.onDecrementByTime,
    required this.onDelete,
    this.hideStats = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(habitStatsProvider(item.id)).valueOrNull;
    final color = ColorsUI.itemTypeColor(ItemType.habit, context.brightness);
    final hasTimes = stats != null &&
        stats.recurrence.type == RecurrenceType.daily &&
        stats.recurrence.times != null &&
        stats.recurrence.times!.isNotEmpty;

    return CustomScrollView(
      slivers: [
        // Τίτλος
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.lg,
                context.responsiveHPadding, Spacing.xs),
            child: TextField(
              controller: titleCtrl,
              onChanged: onTitleChange,
              style: context.h2.copyWith(fontWeight: FontWeight.w600),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Τίτλος συνήθειας...',
                hintStyle: context.h2.withColor(context.cDisabled),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),

        // Progress Section
        SliverToBoxAdapter(
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
            child: hasTimes
                ? _TimeProgressSection(
                    stats: stats,
                    color: color,
                    onIncrementByTime: onIncrementByTime,
                    onDecrementByTime: onDecrementByTime,
                  )
                : _ProgressSection(
                    stats: stats,
                    color: color,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement,
                  ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: Spacing.sm)),

        // Period Status (εβδομαδιαία με μέρες)
        if (stats != null)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
              child: _PeriodStatus(stats: stats, color: color),
            ),
          ),

        // Stats Row (mobile)
        if (!hideStats && stats != null)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
              child: _StatsRow(stats: stats, color: color),
            ),
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
            child: Divider(color: ColorsUI.getBorder(context.brightness)),
          ),
        ),

        // Heatmap
        // Heatmap – εμφανίζεται μόνο αν έχουμε stats
        if (stats != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.md,
                  context.responsiveHPadding, Spacing.sm),
              child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 16, color: context.cText2),
                  const SizedBox(width: Spacing.xs),
                  Text('Ιστορικό', style: context.titleSm),
                ]),
                const SizedBox(height: Spacing.md),
                _HeatmapCalendar(
                    completions: stats.completions,
                    color: color,
                    recurrence: stats.recurrence,
                    goalCount: stats.goalCount),
              ]),
            ),
          ),

        // Settings
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.md,
                context.responsiveHPadding, Spacing.sm),
            child: _HabitSettings(habitId: item.id),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROGRESS SECTION — γενικό (χωρίς ώρες)
// ════════════════════════════════════════════════════════════════

class _ProgressSection extends StatelessWidget {
  final HabitStats? stats;
  final Color color;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ProgressSection({
    required this.stats,
    required this.color,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final recurrence = stats!.recurrence;
    final completions = stats!.completions;
    final completionDays =
        completions.map((d) => DateTime(d.year, d.month, d.day)).toSet();

    int completedDaysPeriod = 0;
    int totalDaysPeriod = 0;
    double periodProgress = 0.0;

    // Αν είναι weekly με συγκεκριμένες ημέρες
    if (recurrence.type == RecurrenceType.weekly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      final now = DateTime.now();
      final periodStart = recurrence.getPeriodStart(now);
      totalDaysPeriod = recurrence.days!.length;
      for (int i = 0; i < 7; i++) {
        final day =
            DateTime(periodStart.year, periodStart.month, periodStart.day + i);
        if (recurrence.days!.contains(day.weekday)) {
          if (completionDays.contains(day)) {
            completedDaysPeriod++;
          }
        }
      }
      periodProgress =
          totalDaysPeriod > 0 ? completedDaysPeriod / totalDaysPeriod : 0.0;
    } else {
      // Παλιά λογική (ημερήσια)
      completedDaysPeriod = stats!.dailyProgress;
      totalDaysPeriod = stats!.goalCount;
      periodProgress =
          totalDaysPeriod > 0 ? stats!.dailyProgress / totalDaysPeriod : 0.0;
    }

    final isAllDone =
        totalDaysPeriod > 0 && completedDaysPeriod >= totalDaysPeriod;
    final unit = stats!.unit;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: periodProgress,
            minHeight: 12,
            backgroundColor: ColorsUI.getBorder(context.brightness),
            valueColor: AlwaysStoppedAnimation<Color>(
                isAllDone ? context.cSuccess : color),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$completedDaysPeriod / $totalDaysPeriod${unit.isNotEmpty ? ' $unit' : ''}',
              style: context.bodyMd
                  .withColor(isAllDone ? context.cSuccess : context.cText),
            ),
            if (isAllDone)
              Row(children: [
                Icon(Icons.celebration_rounded,
                    size: 16, color: context.cSuccess),
                const SizedBox(width: 4),
                Text('Στόχος εβδομάδας επιτεύχθηκε!',
                    style: context.bodySm.withColor(context.cSuccess)),
              ]),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: stats!.dailyProgress <= 0 ? null : onDecrement,
              icon: const Icon(Icons.remove_circle_outline),
              color:
                  stats!.dailyProgress > 0 ? context.cText2 : context.cDisabled,
            ),
            const SizedBox(width: Spacing.md),
            IconButton(
              onPressed: isAllDone ? null : onIncrement,
              icon: const Icon(Icons.add_circle_outline),
              color: !isAllDone ? context.cPrimary : context.cDisabled,
            ),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TIME PROGRESS SECTION — για daily habits με ώρες
// Δείχνει κάθε ώρα ως ξεχωριστό checkbox/button
// ════════════════════════════════════════════════════════════════

class _TimeProgressSection extends StatelessWidget {
  final HabitStats stats;
  final Color color;
  final ValueChanged<String> onIncrementByTime;
  final ValueChanged<String> onDecrementByTime;

  const _TimeProgressSection({
    required this.stats,
    required this.color,
    required this.onIncrementByTime,
    required this.onDecrementByTime,
  });

  @override
  Widget build(BuildContext context) {
    final times = stats.recurrence.times ?? [];
    final timeProgress = stats.todayTimeProgress;
    final completedCount = timeProgress.values.where((v) => v).length;
    final totalCount = times.length;
    final isAllDone = stats.completedToday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: totalCount > 0 ? completedCount / totalCount : 0.0,
            minHeight: 12,
            backgroundColor: ColorsUI.getBorder(context.brightness),
            valueColor: AlwaysStoppedAnimation<Color>(
                isAllDone ? context.cSuccess : color),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$completedCount / $totalCount ώρες',
              style: context.bodyMd
                  .withColor(isAllDone ? context.cSuccess : context.cText),
            ),
            if (isAllDone)
              Row(children: [
                Icon(Icons.celebration_rounded,
                    size: 16, color: context.cSuccess),
                const SizedBox(width: 4),
                Text('Όλες ολοκληρώθηκαν!',
                    style: context.bodySm.withColor(context.cSuccess)),
              ]),
          ],
        ),
        const SizedBox(height: Spacing.md),

        // Κάθε ώρα ως row με checkbox
        ...times.map((time) {
          final isDone = timeProgress[time] == true;
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: InkWell(
              onTap: () =>
                  isDone ? onDecrementByTime(time) : onIncrementByTime(time),
              borderRadius: AppRadius.cardBR,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: Spacing.sm),
                decoration: BoxDecoration(
                  color: isDone
                      ? context.cSuccess.withValues(alpha: 0.1)
                      : ColorsUI.getSurface(context.brightness),
                  borderRadius: AppRadius.cardBR,
                  border: Border.all(
                    color: isDone
                        ? context.cSuccess
                        : ColorsUI.getBorder(context.brightness),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isDone ? context.cSuccess : context.cDisabled,
                      size: 22,
                    ),
                    const SizedBox(width: Spacing.md),
                    Text(
                      time,
                      style: context.titleMd
                          .withColor(isDone ? context.cSuccess : context.cText),
                    ),
                    const Spacer(),
                    if (isDone)
                      Text('✓',
                          style: context.bodyMd.withColor(context.cSuccess)),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PERIOD STATUS — εβδομαδιαία/μηνιαία με συγκεκριμένες μέρες
// ════════════════════════════════════════════════════════════════

class _PeriodStatus extends StatelessWidget {
  final HabitStats stats;
  final Color color;

  const _PeriodStatus({required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    final recurrence = stats.recurrence;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completionDays =
        stats.completions.map((d) => DateTime(d.year, d.month, d.day)).toSet();

    // Εβδομαδιαία με συγκεκριμένες μέρες
    if (recurrence.type == RecurrenceType.weekly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      final daysSinceMonday = (now.weekday - 1) % 7;
      final weekStart = today.subtract(Duration(days: daysSinceMonday));
      const dayNames = ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
      final scheduledDays = [...recurrence.days!]..sort();

      return _periodStatusCard(
        context: context,
        title: 'Αυτή την εβδομάδα',
        children: scheduledDays.map((dayNum) {
          final dayDate = weekStart.add(Duration(days: dayNum - 1));
          final isDone = completionDays.contains(dayDate);
          final isFuture = dayDate.isAfter(today);
          return _DayDot(
            label: dayNames[dayNum - 1],
            isDone: isDone,
            isFuture: isFuture,
          );
        }).toList(),
      );
    }

    // Μηνιαία με συγκεκριμένες ημέρες
    if (recurrence.type == RecurrenceType.monthly &&
        recurrence.days != null &&
        recurrence.days!.isNotEmpty) {
      final sortedDays = [...recurrence.days!]..sort();

      return _periodStatusCard(
        context: context,
        title: 'Αυτόν τον μήνα',
        children: sortedDays.map((d) {
          final targetDay = DateTime(now.year, now.month, d);
          final isDone = completionDays.contains(targetDay);
          final isFuture = targetDay.isAfter(today);
          return _DayDot(
            label: '$dη',
            isDone: isDone,
            isFuture: isFuture,
          );
        }).toList(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _periodStatusCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: ColorsUI.getSurface(context.brightness),
        borderRadius: AppRadius.cardBR,
        border: Border.all(color: ColorsUI.getBorder(context.brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.labelMd.withColor(context.cText2)),
          const SizedBox(height: Spacing.xs),
          Wrap(spacing: Spacing.sm, runSpacing: Spacing.xs, children: children),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isFuture;

  const _DayDot({
    required this.label,
    required this.isDone,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    if (isDone) {
      dotColor = context.cSuccess;
    } else if (isFuture) {
      dotColor = context.cDisabled;
    } else {
      dotColor = context.cError;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone
              ? Icons.check_circle_rounded
              : isFuture
                  ? Icons.radio_button_unchecked_rounded
                  : Icons.cancel_rounded,
          size: 18,
          color: dotColor,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.labelSm
              .withColor(isFuture ? context.cDisabled : context.cText),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATS ROW
// ════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final HabitStats stats;
  final Color color;
  const _StatsRow({required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.local_fire_department_rounded,
              value: '${stats.streak}',
              label: 'Σερί',
              color: stats.streak > 0
                  ? ColorsUI.getWarning(context.brightness)
                  : context.cDisabled,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: _StatCard(
              icon: Icons.emoji_events_rounded,
              value: '${stats.bestStreak}',
              label: 'Καλύτερο',
              color: color,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: _StatCard(
              icon: Icons.check_circle_outline_rounded,
              value: '${stats.completedCount}',
              label: 'Περίοδοι',
              color: context.cText2,
            ),
          ),
          if (stats.goalCount > 0) ...[
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: _StatCard(
                icon: Icons.flag_rounded,
                value: '${stats.progressPercent.toInt()}%',
                label: 'Σήμερα',
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: Spacing.sm, horizontal: Spacing.xs),
      decoration: BoxDecoration(
        color: ColorsUI.getSurface(context.brightness),
        borderRadius: AppRadius.cardBR,
        border: Border.all(color: ColorsUI.getBorder(context.brightness)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value, style: context.titleMd.withColor(color)),
          Text(label, style: context.labelSm.withColor(context.cText2)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HEATMAP CALENDAR
// ════════════════════════════════════════════════════════════════

class _HeatmapCalendar extends StatelessWidget {
  final List<DateTime> completions;
  final Color color;
  final Recurrence recurrence;
  final int goalCount;

  const _HeatmapCalendar({
    required this.completions,
    required this.color,
    required this.recurrence,
    required this.goalCount,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completionDays =
        completions.map((d) => DateTime(d.year, d.month, d.day)).toSet();

    // Υπολογισμός ημερών προς εμφάνιση (τελευταίες 12 εβδομάδες)
    const weeks = 12;
    const days = weeks * 7;
    final start = today.subtract(const Duration(days: days - 1));
    final allDays = List.generate(days, (i) => start.add(Duration(days: i)));

    final cellSize =
        context.responsive<double>(mobile: 16, tablet: 20, desktop: 22);

    // Για daily, η ημέρα θεωρείται ολοκληρωμένη μόνο αν πιάστηκε ο στόχος
    bool isDayComplete(DateTime day) {
      if (recurrence.type == RecurrenceType.daily ||
          recurrence.days == null ||
          recurrence.days!.isEmpty) {
        // daily ή χωρίς specific days
        return completionDays.contains(day);
      } else {
        // weekly ή monthly με specific days
        // Αν η ημέρα δεν είναι προγραμματισμένη, δεν την χρωματίζουμε καθόλου
        if (recurrence.type == RecurrenceType.weekly &&
            !recurrence.days!.contains(day.weekday)) {
          return false;
        }
        if (recurrence.type == RecurrenceType.monthly &&
            !recurrence.days!.contains(day.day)) {
          return false;
        }

        // Ελέγχουμε αν ολοκληρώθηκε μεμονωμένα (πορτοκαλί)
        final individuallyDone = completionDays.contains(day);
        if (!individuallyDone) return false;

        // Ελέγχουμε αν όλες οι προγραμματισμένες ημέρες της ίδιας περιόδου έχουν ολοκληρωθεί
        final periodStart = recurrence.getPeriodStart(day);
        final periodEnd = recurrence
            .nextPeriodStart(periodStart)
            .subtract(const Duration(days: 1));
        bool allScheduledCompleted = true;
        for (final scheduledDay in recurrence.days!) {
          DateTime targetDate;
          if (recurrence.type == RecurrenceType.weekly) {
            final diff = scheduledDay - periodStart.weekday;
            targetDate = periodStart.add(Duration(days: diff));
          } else {
            // monthly
            targetDate =
                DateTime(periodStart.year, periodStart.month, scheduledDay);
            if (targetDate.isBefore(periodStart) ||
                targetDate.isAfter(periodEnd)) { continue;}
          }
          if (!completionDays.contains(targetDate)) {
            allScheduledCompleted = false;
            break;
          }
        }
        // Αν όλες ολοκληρωμένες, η ημέρα θεωρείται "πλήρης" (πράσινη)
        return allScheduledCompleted;
      }
    }

    // Χρώμα για κάθε ημέρα
    Color getDayColor(DateTime day) {
      final isFuture = day.isAfter(today);
      if (isFuture) return Colors.transparent;

      final isComplete = isDayComplete(day);
      if (isComplete) return context.cSuccess; // πράσινο

      // Αν είναι προγραμματισμένη ημέρα (weekly/monthly) και ολοκληρώθηκε μεμονωμένα αλλά όχι πλήρης περίοδος
      if (recurrence.type != RecurrenceType.daily &&
          recurrence.days != null &&
          recurrence.days!.isNotEmpty) {
        final individuallyDone = completionDays.contains(day);
        if (individuallyDone) return color; // πορτοκαλί
      }

      // Δεν ολοκληρώθηκε καθόλου
      return ColorsUI.getBorder(context.brightness).withValues(alpha: 0.5);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: ['Δ', 'Τ', 'Τ', 'Π', 'Π', 'Σ', 'Κ']
              .map((d) => SizedBox(
                    width: cellSize + 3,
                    child: Text(d,
                        style: context.labelSm.withColor(context.cDisabled),
                        textAlign: TextAlign.center),
                  ))
              .toList(),
        ),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: allDays.map((day) {
            final isToday = day == today;
            final dayColor = getDayColor(day);
            return Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: dayColor,
                borderRadius: BorderRadius.circular(3),
                border: isToday ? Border.all(color: color, width: 2) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: Spacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.check_circle, size: 12, color: context.cSuccess),
            const SizedBox(width: 4),
            Text('Πλήρης επιτυχία',
                style: context.labelSm.withColor(context.cText2)),
            const SizedBox(width: 12),
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 4),
            Text('Μερική επιτυχία',
                style: context.labelSm.withColor(context.cText2)),
            const SizedBox(width: 12),
            Icon(Icons.circle,
                size: 12,
                color: ColorsUI.getBorder(context.brightness)
                    .withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text('Αποτυχία', style: context.labelSm.withColor(context.cText2)),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATS PANEL (tablet)
// ════════════════════════════════════════════════════════════════

class _StatsPanel extends ConsumerWidget {
  final int habitId;
  const _StatsPanel({required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(habitStatsProvider(habitId));
    final color = ColorsUI.itemTypeColor(ItemType.habit, context.brightness);

    return Container(
      color: ColorsUI.getSurface(context.brightness),
      padding: const EdgeInsets.all(Spacing.md),
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (stats) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Στατιστικά', style: context.titleSm),
              const SizedBox(height: Spacing.md),
              _PeriodStatus(stats: stats, color: color),
              _StatCard(
                icon: Icons.local_fire_department_rounded,
                value: '${stats.streak}',
                label: 'Τρέχον Σερί',
                color: stats.streak > 0
                    ? ColorsUI.getWarning(context.brightness)
                    : context.cDisabled,
              ),
              const SizedBox(height: Spacing.sm),
              _StatCard(
                icon: Icons.emoji_events_rounded,
                value: '${stats.bestStreak}',
                label: 'Καλύτερο Σερί',
                color: color,
              ),
              const SizedBox(height: Spacing.sm),
              _StatCard(
                icon: Icons.check_circle_outline_rounded,
                value: '${stats.completedCount}',
                label: 'Ολοκληρωμένες Περίοδοι',
                color: context.cText2,
              ),
              if (stats.goalCount > 0) ...[
                const SizedBox(height: Spacing.sm),
                _StatCard(
                  icon: Icons.flag_rounded,
                  value: '${stats.progressPercent.toInt()}%',
                  label: 'Πρόοδος σήμερα',
                  color: color,
                ),
              ],
              if (stats.lastCompleted != null) ...[
                const Divider(height: Spacing.xl),
                Text('Τελευταία ολοκλήρωση',
                    style: context.labelMd.withColor(context.cText2)),
                const SizedBox(height: Spacing.xs),
                Text(stats.lastCompleted!.relative, style: context.bodyMd),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HABIT SETTINGS
// ════════════════════════════════════════════════════════════════

class _HabitSettings extends ConsumerWidget {
  final int habitId;
  const _HabitSettings({required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(habitId));
    final props = propsAsync.valueOrNull ?? [];

    final allProps = <String, String?>{};
    for (final p in props) {
      allProps[p.key] = p.value;
    }

    final goalCount = allProps['goal_per_period'] ?? '0';
    final unit = allProps['unit'] ?? '';
    final currentRecurrence = Recurrence.fromProperties(allProps);

    String recurrenceLabel;
    if (allProps['recurrence_type'] == null ||
        allProps['recurrence_type']!.isEmpty) {
      recurrenceLabel = 'Καμία (μία φορά)';
    } else {
      recurrenceLabel = currentRecurrence.describe();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.settings_rounded, size: 16, color: context.cText2),
          const SizedBox(width: Spacing.xs),
          Text('Ρυθμίσεις', style: context.titleSm),
        ]),
        const SizedBox(height: Spacing.sm),
        Container(
          decoration: BoxDecoration(
            color: ColorsUI.getSurface(context.brightness),
            borderRadius: AppRadius.cardBR,
            border: Border.all(color: ColorsUI.getBorder(context.brightness)),
          ),
          child: Column(
            children: [
              // Στόχος: κρύβεται αν υπάρχουν ώρες (auto-goal)
              if (currentRecurrence.times == null ||
                  currentRecurrence.times!.isEmpty)
                _SettingsRow(
                  icon: Icons.flag_rounded,
                  label: 'Στόχος',
                  value: goalCount == '0' ? 'Χωρίς στόχο' : '$goalCount φορές',
                  onTap: () => _editGoal(context, ref, goalCount),
                ),
              if (currentRecurrence.times == null ||
                  currentRecurrence.times!.isEmpty)
                Divider(
                    height: 1, color: ColorsUI.getBorder(context.brightness)),
              _SettingsRow(
                icon: Icons.straighten_rounded,
                label: 'Μονάδα',
                value: unit.isEmpty ? 'Χωρίς μονάδα' : unit,
                onTap: () => _editUnit(context, ref, unit),
              ),
              Divider(height: 1, color: ColorsUI.getBorder(context.brightness)),
              _SettingsRow(
                icon: Icons.repeat_rounded,
                label: '',
                value: recurrenceLabel,
                onTap: () =>
                    _editRecurrence(context, ref, allProps, currentRecurrence),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editGoal(BuildContext context, WidgetRef ref, String current) {
    _showTextEditor(
      context: context,
      title: 'Στόχος (αριθμός φορών)',
      initial: current == '0' ? '' : current,
      keyboardType: TextInputType.number,
      onSave: (value) async {
        final goal = int.tryParse(value) ?? 0;
        await HabitService.instance.setGoal(habitId, goal);
        ref.invalidate(itemPropertiesProvider(habitId));
        ref.invalidate(habitStatsProvider(habitId));
      },
    );
  }

  void _editUnit(BuildContext context, WidgetRef ref, String current) {
    _showTextEditor(
      context: context,
      title: 'Μονάδα μέτρησης',
      initial: current,
      onSave: (value) async {
        await HabitService.instance.setUnit(habitId, value);
        ref.invalidate(itemPropertiesProvider(habitId));
        ref.invalidate(habitStatsProvider(habitId));
      },
    );
  }

  Future<void> _editRecurrence(
    BuildContext context,
    WidgetRef ref,
    Map<String, String?> allProps,
    Recurrence currentRecurrence,
  ) async {
    final options = ['Καθημερινά', 'Εβδομαδιαία', 'Μηνιαία', 'Καμία'];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => SafeArea(
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
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.xs),
              child: Text('Επιλογή επανάληψης', style: context.titleSm),
            ),
            ...options.map((o) => ListTile(
                  title: Text(o),
                  trailing: _recurrenceMatchesOption(currentRecurrence, o)
                      ? Icon(Icons.check_rounded, color: context.cPrimary)
                      : null,
                  onTap: () => Navigator.pop(ctx, o),
                )),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );

    if (selected == null || !context.mounted) return;

    Recurrence? newRecurrence;

    switch (selected) {
      case 'Καθημερινά':
        // Άνοιγμα time picker για επιλογή ωρών
        final times = await _showTimePicker(context, currentRecurrence);
        if (!context.mounted) return;
        newRecurrence = Recurrence.daily(times: times);
        break;

      case 'Εβδομαδιαία':
        final days = await _showWeekdayPicker(context, currentRecurrence);
        if (days == null || days.isEmpty) return;
        newRecurrence = Recurrence.weekly(days: days);
        break;

      case 'Μηνιαία':
        final days = await _showMonthDayPicker(context, currentRecurrence);
        if (days == null || days.isEmpty) return;
        newRecurrence = Recurrence.monthly(days: days);
        break;

      case 'Καμία':
        await _clearRecurrence(ref);
        return;
    }

    if (newRecurrence != null && context.mounted) {
      await HabitService.instance.setRecurrence(habitId, newRecurrence);
      ref.invalidate(itemPropertiesProvider(habitId));
      ref.invalidate(habitStatsProvider(habitId));
      await ReminderScheduler.instance.refreshRecurringReminders();
    }
  }

  bool _recurrenceMatchesOption(Recurrence r, String option) {
    switch (option) {
      case 'Καθημερινά':
        return r.type == RecurrenceType.daily;
      case 'Εβδομαδιαία':
        return r.type == RecurrenceType.weekly;
      case 'Μηνιαία':
        return r.type == RecurrenceType.monthly;
      default:
        return false;
    }
  }

  Future<void> _clearRecurrence(WidgetRef ref) async {
    final notifier = ref.read(propertyNotifierProvider(habitId).notifier);
    await notifier.setText('recurrence_type', null);
    await notifier.setText('recurrence_interval', null);
    await notifier.setText('recurrence_days', null);
    await notifier.setText('recurrence_times', null);
    ref.invalidate(itemPropertiesProvider(habitId));
    ref.invalidate(habitStatsProvider(habitId));
    await ReminderScheduler.instance.refreshRecurringReminders();
  }

  // ── Time Picker (για daily) ──────────────────────────────────

  Future<List<String>?> _showTimePicker(
      BuildContext context, Recurrence current) async {
    final savedTimes = List<String>.from(current.times ?? []);

    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => _TimePickerSheet(initialTimes: savedTimes),
    );
  }

  // ── Weekday Picker (για weekly) ──────────────────────────────

  Future<List<int>?> _showWeekdayPicker(
      BuildContext context, Recurrence current) async {
    final savedDays = List<int>.from(current.days ?? []);

    return showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) {
        final selected = List<int>.from(savedDays);
        return StatefulBuilder(
          builder: (ctx, setModal) {
            const allDays = ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Επιλογή ημερών εβδομάδας', style: context.titleSm),
                    const SizedBox(height: Spacing.md),
                    Wrap(
                      spacing: Spacing.xs,
                      runSpacing: Spacing.xs,
                      children: List.generate(allDays.length, (index) {
                        final dayNum = index + 1;
                        final isSelected = selected.contains(dayNum);
                        return FilterChip(
                          label: Text(allDays[index]),
                          selected: isSelected,
                          onSelected: (v) => setModal(() {
                            if (v) {
                              selected.add(dayNum);
                            } else {
                              selected.remove(dayNum);
                            }
                          }),
                          selectedColor:
                              context.cPrimary.withValues(alpha: 0.2),
                          checkmarkColor: context.cPrimary,
                        );
                      }),
                    ),
                    const SizedBox(height: Spacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            child: const Text('Άκυρο')),
                        FilledButton(
                          onPressed: selected.isEmpty
                              ? null
                              : () =>
                                  Navigator.pop(ctx, List<int>.from(selected)),
                          child: const Text('Αποθήκευση'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Month Day Picker (για monthly) ───────────────────────────

  Future<List<int>?> _showMonthDayPicker(
      BuildContext context, Recurrence current) async {
    final savedDays = List<int>.from(current.days ?? []);

    return showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => _MonthDayPickerSheet(initialDays: savedDays),
    );
  }

  void _showTextEditor({
    required BuildContext context,
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final ctrl = TextEditingController(text: initial);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.md,
          left: Spacing.lg,
          right: Spacing.lg,
          top: Spacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.titleMd),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: title,
                filled: true,
                fillColor: ColorsUI.getSurface(context.brightness),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputBR,
                  borderSide:
                      BorderSide(color: ColorsUI.getBorder(context.brightness)),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Άκυρο'))),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final nav = Navigator.of(ctx);
                    await onSave(ctrl.text.trim());
                    nav.pop();
                  },
                  child: const Text('Αποθήκευση'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TIME PICKER SHEET — επιλογή ωρών για daily habit
// ════════════════════════════════════════════════════════════════

class _TimePickerSheet extends StatefulWidget {
  final List<String> initialTimes;
  const _TimePickerSheet({required this.initialTimes});

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late List<String> _times;

  @override
  void initState() {
    super.initState();
    _times = List<String>.from(widget.initialTimes);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final formatted = _formatTime(picked);
    if (!_times.contains(formatted)) {
      setState(() {
        _times.add(formatted);
        _times.sort();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.md,
        left: Spacing.lg,
        right: Spacing.lg,
        top: Spacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ώρες εκτέλεσης', style: context.titleSm),
              TextButton.icon(
                onPressed: _addTime,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Προσθήκη ώρας'),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Ο στόχος επιτυγχάνεται όταν ολοκληρωθούν ΟΛΕΣ οι ώρες.',
            style: context.bodySm.withColor(context.cText2),
          ),
          const SizedBox(height: Spacing.md),
          if (_times.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Center(
                child: Text(
                  'Δεν έχουν οριστεί ώρες.\nΠατήστε "Προσθήκη ώρας".',
                  style: context.bodyMd.withColor(context.cText2),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._times.map((t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.access_time_rounded, color: context.cPrimary),
                  title: Text(t, style: context.titleMd),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: context.cError),
                    onPressed: () => setState(() => _times.remove(t)),
                  ),
                )),
          const SizedBox(height: Spacing.md),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Άκυρο'))),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _times),
                child: const Text('Αποθήκευση'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MONTH DAY PICKER SHEET — επιλογή ημερών μήνα
// ════════════════════════════════════════════════════════════════

class _MonthDayPickerSheet extends StatefulWidget {
  final List<int> initialDays;
  const _MonthDayPickerSheet({required this.initialDays});

  @override
  State<_MonthDayPickerSheet> createState() => _MonthDayPickerSheetState();
}

class _MonthDayPickerSheetState extends State<_MonthDayPickerSheet> {
  late List<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    _selectedDays = List<int>.from(widget.initialDays);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.md,
        left: Spacing.lg,
        right: Spacing.lg,
        top: Spacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ημέρες μήνα', style: context.titleSm),
          const SizedBox(height: Spacing.xs),
          Text(
            'Ο στόχος επιτυγχάνεται όταν ολοκληρωθούν ΟΛΕΣ οι επιλεγμένες ημέρες.',
            style: context.bodySm.withColor(context.cText2),
          ),
          const SizedBox(height: Spacing.md),
          // Grid 7 x 5
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: List.generate(31, (i) {
              final day = i + 1;
              final isSelected = _selectedDays.contains(day);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                }),
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.cPrimary
                        : ColorsUI.getSurface(context.brightness),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isSelected
                          ? context.cPrimary
                          : ColorsUI.getBorder(context.brightness),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: context.bodyMd.withColor(isSelected
                          ? ColorsUI.getOnPrimary(context.brightness)
                          : context.cText),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: Spacing.lg),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Άκυρο'))),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: _selectedDays.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context, List<int>.from(_selectedDays)..sort()),
                child: const Text('Αποθήκευση'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 18, color: context.cText2),
      title: Text(label, style: context.bodyMd),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(value,
                style: context.bodyMd.withColor(context.cText2),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: Spacing.xs),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: context.cDisabled),
        ],
      ),
      onTap: onTap,
    );
  }
}
