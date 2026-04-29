// lib/features/habits/habit_detail_screen.dart
//
// Detail screen συνήθειας: τίτλος, stats, ημερήσια πρόοδος (με +/–), heatmap, ρυθμίσεις.
// ✅ Responsive: single col mobile / two-panel tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
// ✅ Reminders: μόνο από εικονίδιο AppBar (όχι inline) – η επανάληψη γίνεται μέσω ReminderSection
// ✅ Επανάληψη συνήθειας μέσω Recurrence (ενοποίηση με HabitService)
//
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
    DebugConfig.db('HabitDetail saveTitle id=${widget.itemId} "$title"');
    await ref
        .read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId, title: title.isEmpty ? null : title);
    _lastSavedTitle = title;
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  Future<void> _save() async {
    _titleDebounce?.cancel();
    final title = _titleCtrl.text.trim();
    DebugConfig.db('HabitDetail manualSave id=${widget.itemId} title="$title"');
    await _saveTitle(title);
  }

  Future<void> _incrementProgress() async {
    DebugConfig.db('HabitDetail incrementProgress id=${widget.itemId}');
    await HabitService.instance.incrementProgress(widget.itemId);
    if (!mounted) return;
    ref.invalidate(habitStatsProvider(widget.itemId));
    await ReminderScheduler.instance.refreshRecurringReminders();
  }

  Future<void> _decrementProgress() async {
    DebugConfig.db('HabitDetail decrementProgress id=${widget.itemId}');
    await HabitService.instance.decrementProgress(widget.itemId);
    if (!mounted) return;
    ref.invalidate(habitStatsProvider(widget.itemId));
    await ReminderScheduler.instance.refreshRecurringReminders();
  }

  Future<void> _delete(BuildContext context) async {
    final future = ConfirmDialog.delete(context, title: 'Διαγραφή συνήθειας;');
    final ok = await future;
    if (!ok || !mounted) return;
    await ReminderScheduler.instance.deleteAllRemindersForItem(widget.itemId);
    if (!mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _togglePin(Item item) async {
    DebugConfig.provider('HabitDetail togglePin id=${item.id}');
    await ref
        .read(itemNotifierProvider.notifier)
        .togglePin(item.id, item.pinned);
    setState(() => _isPinned = item.pinned);
    ref.invalidate(itemNotifierProvider);
  }

  Future<void> _toggleFav(Item item) async {
    DebugConfig.provider('HabitDetail toggleFav id=${item.id}');
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleFavorite(item.id, item.favorite);
    setState(() => _isFavorite = item.favorite);
    ref.invalidate(itemNotifierProvider);
  }

  Future<void> _toggleArchive(Item item) async {
    DebugConfig.provider('HabitDetail toggleArchive id=${item.id}');
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleArchive(item.id, item.archived);
    ref.invalidate(itemNotifierProvider);
  }

  // --- Εμφάνιση bottom sheet με ReminderSection ---
  Future<void> _showReminderDialog() async {
    final title = _titleCtrl.text.trim().isEmpty ? 'Συνήθεια' : _titleCtrl.text.trim();
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
    DebugConfig.provider('HabitDetailScreen build id=${widget.itemId}');
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) {
        DebugConfig.error('HabitDetail load failed', e);
        return _buildError();
      },
      data: (item) {
        if (item == null) return _buildNotFound();

        final itemTitle = item.title ?? '';
        if (_lastSavedTitle.isEmpty && itemTitle.isNotEmpty) {
          _lastSavedTitle = itemTitle;
        }
        if (!_isEditingTitle && _titleCtrl.text != itemTitle) {
          final cursorAtEnd = _titleCtrl.selection.baseOffset == _titleCtrl.text.length;
          _titleCtrl.text = itemTitle;
          if (cursorAtEnd) {
            _titleCtrl.selection = TextSelection.collapsed(offset: _titleCtrl.text.length);
          }
        }

        if (_isPinned != item.pinned) _isPinned = item.pinned;
        if (_isFavorite != item.favorite) _isFavorite = item.favorite;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav = Navigator.of(context);
            _titleDebounce?.cancel();
            final title = _titleCtrl.text.trim();

            final props = ref.read(itemPropertiesProvider(widget.itemId)).valueOrNull ?? [];
            final goalCount = props.where((p) => p.key == 'goal_per_period').firstOrNull?.value ?? '0';
            final unit = props.where((p) => p.key == 'unit').firstOrNull?.value ?? '';

            final hasGoal = goalCount != '0';
            final hasUnit = unit.trim().isNotEmpty;
            final isEffectivelyEmpty = !hasGoal && !hasUnit;

            if (widget.isNew && isEffectivelyEmpty) {
              DebugConfig.db('HabitDetail auto-delete empty/only-title habit id=${widget.itemId}');
              await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
              if (!nav.mounted) return;
              nav.pop();
              return;
            }

            await _saveTitle(title);
            if (!nav.mounted) return;
            nav.pop();
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
        VerticalDivider(width: 1, color: ColorsUI.getBorder(context.brightness)),
        Expanded(
          child: _HabitBody(
            item: item,
            titleCtrl: _titleCtrl,
            isSaving: _isSaving,
            onTitleChange: _onTitleChanged,
            onIncrement: _incrementProgress,
            onDecrement: _decrementProgress,
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
    actionsPadding: const EdgeInsets.symmetric(horizontal: 4),
    title: _isSaving
        ? Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: context.cText2),
      ),
      const SizedBox(width: Spacing.xs),
      Text('Αποθήκευση...', style: context.bodySm.withColor(context.cText2)),
    ])
        : null,
    actions: [
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.save_rounded, color: context.cPrimary, size: 20),
        tooltip: 'Αποθήκευση',
        onPressed: () async {
          final nav = Navigator.of(context);
          await _save();
          if (nav.mounted) nav.pop();
        },
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.notifications_none_rounded, color: context.cText2, size: 20),
        onPressed: _showReminderDialog,
        tooltip: 'Υπενθύμιση',
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(_isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: _isPinned ? context.cPrimary : context.cText2, size: 20),
        onPressed: () => _togglePin(item),
        tooltip: _isPinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(_isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: _isFavorite ? ColorsUI.getWarning(context.brightness) : context.cText2, size: 20),
        onPressed: () => _toggleFav(item),
        tooltip: _isFavorite ? 'Αφαίρεση από αγαπημένα' : 'Αγαπημένη συνήθεια',
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(item.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
            color: context.cText2, size: 20),
        onPressed: () => _toggleArchive(item),
        tooltip: item.archived ? 'Επαναφορά από αρχείο' : 'Αρχειοθέτηση',
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.delete_outline_rounded, color: context.cError, size: 20),
        onPressed: () => _delete(context),
        tooltip: 'Διαγραφή',
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
    body: EmptyState.error(onRetry: () => ref.invalidate(itemStreamProvider(widget.itemId))),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const EmptyState(icon: Icons.loop_rounded, title: 'Η συνήθεια δεν βρέθηκε'),
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
  final VoidCallback onDelete;
  final bool hideStats;

  const _HabitBody({
    required this.item,
    required this.titleCtrl,
    required this.isSaving,
    required this.onTitleChange,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
    this.hideStats = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(habitStatsProvider(item.id));
    final stats = statsAsync.valueOrNull;
    final color = ColorsUI.itemTypeColor(ItemType.habit, context.brightness);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.lg, context.responsiveHPadding, Spacing.md),
            child: _ProgressSection(
              stats: stats,
              color: color,
              onIncrement: onIncrement,
              onDecrement: onDecrement,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
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
        const SliverToBoxAdapter(child: SizedBox(height: Spacing.md)),
        if (!hideStats && stats != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
              child: _StatsRow(stats: stats, color: color),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
            child: Divider(color: ColorsUI.getBorder(context.brightness)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.md, context.responsiveHPadding, Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.calendar_month_rounded, size: 16, color: context.cText2),
                  const SizedBox(width: Spacing.xs),
                  Text('Ιστορικό', style: context.titleSm),
                ]),
                const SizedBox(height: Spacing.md),
                _HeatmapCalendar(completions: stats?.completions ?? [], color: color),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.md, context.responsiveHPadding, Spacing.sm),
            child: _HabitSettings(habitId: item.id),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROGRESS SECTION
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

    final goal = stats!.goalCount;
    final dailyProgress = stats!.dailyProgress;
    final unit = stats!.unit;
    final progressPercent = stats!.progressPercent / 100;
    final isCompleted = stats!.completedToday;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progressPercent,
            minHeight: 12,
            backgroundColor: ColorsUI.getBorder(context.brightness),
            valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? context.cSuccess : color),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              goal > 0 ? '$dailyProgress / $goal $unit' : '$dailyProgress $unit',
              style: context.bodyMd.withColor(isCompleted ? context.cSuccess : context.cText),
            ),
            if (isCompleted)
              Row(
                children: [
                  Icon(Icons.celebration_rounded, size: 16, color: context.cSuccess),
                  const SizedBox(width: 4),
                  Text('Στόχος επιτεύχθηκε!', style: context.bodySm.withColor(context.cSuccess)),
                ],
              ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: dailyProgress <= 0 ? null : onDecrement,
              icon: const Icon(Icons.remove_circle_outline),
              color: dailyProgress > 0 ? context.cText2 : context.cDisabled,
            ),
            const SizedBox(width: Spacing.md),
            IconButton(
              onPressed: (goal > 0 && dailyProgress >= goal) ? null : onIncrement,
              icon: const Icon(Icons.add_circle_outline),
              color: (goal > 0 && dailyProgress >= goal) ? context.cDisabled : context.cPrimary,
            ),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATS ROW (mobile)
// ════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final HabitStats stats;
  final Color color;
  const _StatsRow({required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            value: '${stats.streak}',
            label: 'Σερί Ημερών',
            color: stats.streak > 0 ? ColorsUI.getWarning(context.brightness) : context.cDisabled,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.emoji_events_rounded,
            value: '${stats.bestStreak}',
            label: 'Μεγαλύτερο Σερι',
            color: color,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline_rounded,
            value: '${stats.completedCount}',
            label: 'Ολοκληρωμένες',
            color: context.cText2,
          ),
        ),
        if (stats.goalCount > 0) ...[
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: _StatCard(
              icon: Icons.flag_rounded,
              value: '${stats.progressPercent.toInt()}%',
              label: 'Στόχος',
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
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
  const _HeatmapCalendar({required this.completions, required this.color});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final doneDays = completions.map((d) => DateTime(d.year, d.month, d.day)).toSet();
    const weeks = 12;
    const days = weeks * 7;
    final start = today.subtract(const Duration(days: days - 1));
    final allDays = List.generate(days, (i) => start.add(Duration(days: i)));
    final cellSize = context.responsive<double>(mobile: 16, tablet: 20, desktop: 22);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: ['Δ', 'Τ', 'Τ', 'Π', 'Π', 'Σ', 'Κ']
              .map((d) => SizedBox(
            width: cellSize + 3,
            child: Text(d, style: context.labelSm.withColor(context.cDisabled), textAlign: TextAlign.center),
          ))
              .toList(),
        ),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: allDays.map((day) {
            final isDone = doneDays.contains(day);
            final isToday = day == today;
            final isFuture = day.isAfter(today);
            return Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: isFuture
                    ? Colors.transparent
                    : isDone
                    ? color
                    : ColorsUI.getBorder(context.brightness).withValues(alpha: 0.5),
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
            Text('Λιγότερο', style: context.labelSm.withColor(context.cDisabled)),
            const SizedBox(width: Spacing.xs),
            ...List.generate(
                4,
                    (i) => Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2 + i * 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
            const SizedBox(width: Spacing.xs),
            Text('Περισσότερο', style: context.labelSm.withColor(context.cDisabled)),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATS PANEL (tablet left)
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
        data: (stats) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Στατιστικά', style: context.titleSm),
            const SizedBox(height: Spacing.md),
            _StatCard(
              icon: Icons.local_fire_department_rounded,
              value: '${stats.streak}',
              label: 'Τρέχον Streak',
              color: stats.streak > 0 ? ColorsUI.getWarning(context.brightness) : context.cDisabled,
            ),
            const SizedBox(height: Spacing.sm),
            _StatCard(
              icon: Icons.emoji_events_rounded,
              value: '${stats.bestStreak}',
              label: 'Καλύτερο Streak',
              color: color,
            ),
            const SizedBox(height: Spacing.sm),
            _StatCard(
              icon: Icons.check_circle_outline_rounded,
              value: '${stats.completedCount}',
              label: 'Συνολικές ολοκληρώσεις',
              color: context.cText2,
            ),
            if (stats.goalCount > 0) ...[
              const SizedBox(height: Spacing.sm),
              _StatCard(
                icon: Icons.flag_rounded,
                value: '${stats.progressPercent.toInt()}%',
                label: 'Πρόοδος στόχου',
                color: color,
              ),
            ],
            if (stats.lastCompleted != null) ...[
              const Divider(height: Spacing.xl),
              Text('Τελευταία ολοκλήρωση', style: context.labelMd.withColor(context.cText2)),
              const SizedBox(height: Spacing.xs),
              Text(stats.lastCompleted!.relative, style: context.bodyMd),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HABIT SETTINGS (goal, unit, recurrence μέσω Recurrence)
// ════════════════════════════════════════════════════════════════

class _HabitSettings extends ConsumerWidget {
  final int habitId;

  const _HabitSettings({required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(habitId));
    final props = propsAsync.valueOrNull ?? [];
    final goalCount = props.where((p) => p.key == 'goal_per_period').firstOrNull?.value ?? '0';
    final unit = props.where((p) => p.key == 'unit').firstOrNull?.value ?? '';

    // Δημιουργούμε το τρέχον Recurrence από τις αποθηκευμένες ιδιότητες
    final allProps = <String, String?>{};
    for (final p in props) {
      allProps[p.key] = p.value;
    }
    final currentRecurrence = Recurrence.fromProperties(allProps);

    // Ετικέτα για την τρέχουσα επανάληψη
    String recurrenceLabel;
    if (allProps['recurrence_type'] == null || allProps['recurrence_type']!.isEmpty) {
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
              _SettingsRow(
                icon: Icons.flag_rounded,
                label: 'Στόχος',
                value: goalCount == '0' ? 'Χωρίς στόχο' : '$goalCount φορές',
                onTap: () => _editGoal(context, ref, goalCount),
              ),
              Divider(height: 1, color: ColorsUI.getBorder(context.brightness)),
              _SettingsRow(
                icon: Icons.straighten_rounded,
                label: 'Μονάδα',
                value: unit.isEmpty ? 'Χωρίς μονάδα' : unit,
                onTap: () => _editUnit(context, ref, unit),
              ),
              Divider(height: 1, color: ColorsUI.getBorder(context.brightness)),
              _SettingsRow(
                icon: Icons.repeat_rounded,
                label: 'Επανάληψη',
                value: recurrenceLabel,
                onTap: () => _editRecurrence(context, ref, allProps),
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
      title: 'Στόχος (αριθμός φορών την ημέρα)',
      initial: current == '0' ? '' : current,
      keyboardType: TextInputType.number,
      onSave: (val) async {
        final n = double.tryParse(val) ?? 0;
        DebugConfig.db('HabitSettings setGoal=$n id=$habitId');
        await ref.read(propertyNotifierProvider(habitId).notifier).setNumber('goal_per_period', n);
        ref.invalidate(itemPropertiesProvider(habitId));
        ref.invalidate(habitStatsProvider(habitId));
      },
    );
  }

  void _editUnit(BuildContext context, WidgetRef ref, String current) {
    _showTextEditor(
      context: context,
      title: 'Μονάδα (π.χ. λεπτά, ποτήρια)',
      initial: current,
      onSave: (val) async {
        DebugConfig.db('HabitSettings setUnit="$val" id=$habitId');
        await ref.read(propertyNotifierProvider(habitId).notifier).setText('unit', val);
      },
    );
  }

  void _editRecurrence(BuildContext context, WidgetRef ref, Map<String, String?> props) async {
    final currentType = props['recurrence_type'];
    final result = await showModalBottomSheet<String>(
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
              child: Text('Επανάληψη συνήθειας', style: context.titleSm),
            ),
            const Divider(),
            ListTile(
              title: const Text('Καμία (μία φορά)'),
              trailing: (currentType == null || currentType.isEmpty)
                  ? Icon(Icons.check_rounded, color: context.cPrimary)
                  : null,
              onTap: () => Navigator.pop(ctx, 'none'),
            ),
            ListTile(
              title: const Text('Καθημερινά'),
              trailing: currentType == 'daily'
                  ? Icon(Icons.check_rounded, color: context.cPrimary)
                  : null,
              onTap: () => Navigator.pop(ctx, 'daily'),
            ),
            ListTile(
              title: const Text('Εβδομαδιαία'),
              subtitle: const Text('Επιλέξτε ημέρες'),
              trailing: currentType == 'weekly'
                  ? Icon(Icons.check_rounded, color: context.cPrimary)
                  : null,
              onTap: () => Navigator.pop(ctx, 'weekly'),
            ),
            ListTile(
              title: const Text('Μηνιαία'),
              trailing: currentType == 'monthly'
                  ? Icon(Icons.check_rounded, color: context.cPrimary)
                  : null,
              onTap: () => Navigator.pop(ctx, 'monthly'),
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    if (result == 'none') {
      await _clearRecurrence(ref);
      return;
    }

    // Δημιουργία νέου Recurrence
    Recurrence? newRecurrence;
    switch (result) {
      case 'daily':
        newRecurrence = const Recurrence(type: RecurrenceType.daily, interval: 1);
        break;
      case 'monthly':
        newRecurrence = const Recurrence(type: RecurrenceType.monthly, interval: 1, dayOfMonth: 1);
        break;
      case 'weekly':
        final selectedDays = await _showWeekdayPicker(context, ref);
        if (!context.mounted) return;
        if (selectedDays != null && selectedDays.isNotEmpty) {
          newRecurrence = Recurrence(
            type: RecurrenceType.weekly,
            interval: 1,
            days: selectedDays,
          );
        } else {
          return; // ο χρήστης ακύρωσε ή δεν επέλεξε ημέρες
        }
        break;
    }

    if (newRecurrence != null) {
      await HabitService.instance.setRecurrence(habitId, newRecurrence);
      ref.invalidate(itemPropertiesProvider(habitId));
      ref.invalidate(habitStatsProvider(habitId));
      await ReminderScheduler.instance.refreshRecurringReminders();
    }
  }

  Future<void> _clearRecurrence(WidgetRef ref) async {
    final notifier = ref.read(propertyNotifierProvider(habitId).notifier);
    await notifier.setText('recurrence_type', null);
    await notifier.setText('recurrence_interval', null);
    await notifier.setText('recurrence_days', null);
    ref.invalidate(itemPropertiesProvider(habitId));
    ref.invalidate(habitStatsProvider(habitId));
    await ReminderScheduler.instance.refreshRecurringReminders();
  }

  /// Επιστρέφει λίστα με ints ημερών (1=Δευ, 7=Κυρ) ή null αν ακυρώθηκε
  Future<List<int>?> _showWeekdayPicker(BuildContext context, WidgetRef ref) async {
    final props = ref.read(itemPropertiesProvider(habitId)).valueOrNull ?? [];
    final allProps = <String, String?>{};
    for (final p in props) {
      allProps[p.key] = p.value;
    }
    final currentRecurrence = Recurrence.fromProperties(allProps);
    final savedDays = List<int>.from(currentRecurrence.days ?? []);

    const allDays = ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
    final selectedDays = List<int>.from(savedDays);

    return showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return SafeArea(
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
                  child: Text(
                    'Επιλογή ημερών επανάληψης',
                    style: context.titleSm,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: List.generate(allDays.length, (index) {
                    final dayName = allDays[index];
                    final dayNum = index + 1;
                    final isSelected = selectedDays.contains(dayNum);
                    return FilterChip(
                      label: Text(dayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setModal(() {
                          if (selected) {
                            selectedDays.add(dayNum);
                          } else {
                            selectedDays.remove(dayNum);
                          }
                        });
                      },
                      selectedColor: context.cPrimary.withValues(alpha: 0.2),
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
                      child: const Text('Άκυρο'),
                    ),
                    FilledButton(
                      onPressed: selectedDays.isEmpty
                          ? null
                          : () => Navigator.pop(ctx, List<int>.from(selectedDays)),
                      child: const Text('Αποθήκευση'),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
              ],
            ),
          );
        },
      ),
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
                  borderSide: BorderSide(color: ColorsUI.getBorder(context.brightness)),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Άκυρο'),
                ),
              ),
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
          Text(value, style: context.bodyMd.withColor(context.cText2)),
          const SizedBox(width: Spacing.xs),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.cDisabled),
        ],
      ),
      onTap: onTap,
    );
  }
}