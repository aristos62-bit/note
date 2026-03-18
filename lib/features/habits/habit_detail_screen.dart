// lib/features/habits/habit_detail_screen.dart
//
// Detail screen συνήθειας: τίτλος, stats, calendar heatmap, ρυθμίσεις.
// ✅ Responsive: single col mobile / two-panel tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/habit_service.dart';
import '../../shared/widgets/widgets.dart';

// ── Local providers ───────────────────────────────────────────────

final _habitStatsDetailProvider =
FutureProvider.family<HabitStats, int>((ref, habitId) async {
  DebugConfig.db('_habitStatsDetailProvider id=$habitId');

  // Εξάρτηση από το ίδιο το habit για τυχόν μελλοντικό real-time
  // (π.χ. αν αλλάξει workspace, διαγραφεί κτλ.)
  ref.watch(itemStreamProvider(habitId));

  return HabitService.instance.getStats(habitId);
});


// ════════════════════════════════════════════════════════════════
// HABIT DETAIL SCREEN
// ════════════════════════════════════════════════════════════════

class HabitDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  const HabitDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<HabitDetailScreen> createState() =>
      _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  late final TextEditingController _titleCtrl;
  Timer? _titleDebounce;
  bool  _isSaving = false;

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
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 600), () {
      _saveTitle(value.trim());
    });
  }

  Future<void> _saveTitle(String title) async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    DebugConfig.db('HabitDetail saveTitle id=${widget.itemId} "$title"');
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId, title: title.isEmpty ? null : title);
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  Future<void> _markDone() async {
    DebugConfig.db('HabitDetail markDone id=${widget.itemId}');
    await HabitService.instance.markCompleted(widget.itemId);
    ref.invalidate(_habitStatsDetailProvider(widget.itemId));
  }

  Future<void> _delete(BuildContext context) async {
    final future = ConfirmDialog.delete(context,
        title: 'Διαγραφή συνήθειας;');
    final ok = await future;
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.of(context).pop();
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

        // Sync title ΜΟΝΟ όταν ο χρήστης δεν γράφει ήδη κάτι
        final itemTitle = item.title ?? '';

        if (!_titleCtrl.selection.isValid && _titleCtrl.text != itemTitle) {
          _titleCtrl.text = itemTitle;
          _titleCtrl.selection = TextSelection.collapsed(
            offset: _titleCtrl.text.length,
          );
        }


        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;

            final nav      = Navigator.of(context);
            _titleDebounce?.cancel();
            final title    = _titleCtrl.text.trim();
            final hasTitle = title.isNotEmpty;

            if (!hasTitle) {
              DebugConfig.db(
                  'HabitDetail auto-delete empty habit id=${widget.itemId}');
              await ref
                  .read(itemNotifierProvider.notifier)
                  .deleteItem(widget.itemId);
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

  // ── Mobile ───────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context, Item item) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, item),
      body: _HabitBody(
        item:          item,
        titleCtrl:     _titleCtrl,
        isSaving:      _isSaving,
        onTitleChange: _onTitleChanged,
        onMarkDone:    _markDone,
        onDelete:      () => _delete(context),
      ),
    );
  }

  // ── Tablet ───────────────────────────────────────────────────

  Widget _buildTablet(BuildContext context, Item item) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, item),
      body: Row(
        children: [
          // Left: stats panel
          SizedBox(
            width: context.isDesktop ? 300 : 260,
            child: _StatsPanel(habitId: item.id),
          ),
          VerticalDivider(
              width: 1,
              color: ColorsUI.getBorder(context.brightness)),
          // Right: body
          Expanded(
            child: _HabitBody(
              item:          item,
              titleCtrl:     _titleCtrl,
              isSaving:      _isSaving,
              onTitleChange: _onTitleChanged,
              onMarkDone:    _markDone,
              onDelete:      () => _delete(context),
              hideStats:     true,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, Item item) {
    return AppBar(
      backgroundColor:        context.cBg,
      elevation:              0,
      scrolledUnderElevation: 1,
      title: _isSaving
          ? Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: context.cText2),
        ),
        const SizedBox(width: Spacing.xs),
        Text('Αποθήκευση...',
            style: context.bodySm.withColor(context.cText2)),
      ])
          : null,
      actions: [
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: context.cText2),
          onPressed: () => _delete(context),
          tooltip: 'Διαγραφή',
        ),
      ],
    );
  }

  Widget _buildLoading() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildError() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: EmptyState.error(onRetry: () =>
        ref.invalidate(itemStreamProvider(widget.itemId))),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const EmptyState(
      icon:  Icons.loop_rounded,
      title: 'Η συνήθεια δεν βρέθηκε',
    ),
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
  final VoidCallback onMarkDone;
  final VoidCallback onDelete;
  final bool hideStats;

  const _HabitBody({
    required this.item,
    required this.titleCtrl,
    required this.isSaving,
    required this.onTitleChange,
    required this.onMarkDone,
    required this.onDelete,
    this.hideStats = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync  = ref.watch(_habitStatsDetailProvider(item.id));
    final stats       = statsAsync.valueOrNull;
    final isDoneToday = stats?.completedToday ?? false;
    final color = ColorsUI.itemTypeColor(ItemType.habit, context.brightness);

    return CustomScrollView(
      slivers: [
        // ── Mark done hero button ─────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.lg,
              context.responsiveHPadding, Spacing.md,
            ),
            child: _MarkDoneButton(
              isDone: isDoneToday,
              color:  color,
              onTap:  isDoneToday ? null : onMarkDone,
            ),
          ),
        ),

        // ── Title ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.responsiveHPadding),
            child: TextField(
              controller: titleCtrl,
              onChanged:  onTitleChange,
              style:      context.h2.copyWith(fontWeight: FontWeight.w600),
              maxLines:   null,
              decoration: InputDecoration(
                hintText:  'Τίτλος συνήθειας...',
                hintStyle: context.h2.withColor(context.cDisabled),
                border:    InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: Spacing.md)),

        // ── Stats (mobile only) ──────────────────────────────
        if (!hideStats && stats != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.responsiveHPadding),
              child: _StatsRow(stats: stats, color: color),
            ),
          ),

        // ── Divider ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.responsiveHPadding),
            child: Divider(
                color: ColorsUI.getBorder(context.brightness)),
          ),
        ),

        // ── Calendar heatmap ─────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.md,
              context.responsiveHPadding, Spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 16, color: context.cText2),
                  const SizedBox(width: Spacing.xs),
                  Text('Ιστορικό',
                      style: context.titleSm),
                ]),
                const SizedBox(height: Spacing.md),
                _HeatmapCalendar(
                  completions: stats?.completions ?? [],
                  color: color,
                ),
              ],
            ),
          ),
        ),

        // ── Settings section ─────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.md,
              context.responsiveHPadding, Spacing.sm,
            ),
            child: _HabitSettings(habitId: item.id),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MARK DONE BUTTON
// ════════════════════════════════════════════════════════════════

class _MarkDoneButton extends StatelessWidget {
  final bool isDone;
  final Color color;
  final VoidCallback? onTap;

  const _MarkDoneButton({
    required this.isDone,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.normal,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        decoration: BoxDecoration(
          color: isDone
              ? color.withValues(alpha: 0.12)
              : color,
          borderRadius: AppRadius.cardBR,
          border: isDone
              ? Border.all(color: color.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isDone ? color : ColorsUI.getAccessibleTextColor(color),
              size: 22,
            ),
            const SizedBox(width: Spacing.sm),
            Text(
              isDone ? 'Ολοκληρώθηκε σήμερα ✓' : 'Σήμανση ως ολοκληρωμένη',
              style: context.titleSm.withColor(
                  isDone ? color : ColorsUI.getAccessibleTextColor(color)),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATS ROW — streak / best / total / progress
// ════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final HabitStats stats;
  final Color color;
  const _StatsRow({required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(
          icon:  Icons.local_fire_department_rounded,
          value: '${stats.streak}',
          label: 'Streak',
          color: stats.streak > 0
              ? ColorsUI.getWarning(context.brightness)
              : context.cDisabled,
        )),
        const SizedBox(width: Spacing.sm),
        Expanded(child: _StatCard(
          icon:  Icons.emoji_events_rounded,
          value: '${stats.bestStreak}',
          label: 'Best',
          color: color,
        )),
        const SizedBox(width: Spacing.sm),
        Expanded(child: _StatCard(
          icon:  Icons.check_circle_outline_rounded,
          value: '${stats.completedCount}',
          label: 'Σύνολο',
          color: context.cText2,
        )),
        if (stats.goalCount > 0) ...[
          const SizedBox(width: Spacing.sm),
          Expanded(child: _StatCard(
            icon:  Icons.flag_rounded,
            value: '${stats.progressPercent.toInt()}%',
            label: 'Στόχος',
            color: color,
          )),
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
  const _StatCard({
    required this.icon, required this.value,
    required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: Spacing.sm, horizontal: Spacing.xs),
      decoration: BoxDecoration(
        color:        ColorsUI.getSurface(context.brightness),
        borderRadius: AppRadius.cardBR,
        border: Border.all(color: ColorsUI.getBorder(context.brightness)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: context.titleMd.withColor(color)),
          Text(label,
              style: context.labelSm.withColor(context.cText2)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HEATMAP CALENDAR — τελευταίοι 12 εβδομάδες
// ════════════════════════════════════════════════════════════════

class _HeatmapCalendar extends StatelessWidget {
  final List<DateTime> completions;
  final Color color;
  const _HeatmapCalendar({required this.completions, required this.color});

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Set με μοναδικές ημέρες
    final doneDays = completions
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    // 84 ημέρες (12 εβδομάδες) πίσω
    const weeks = 12;
    const days  = weeks * 7;
    final start = today.subtract(const Duration(days: days - 1));

    // Εβδομάδες
    final allDays = List.generate(
        days, (i) => start.add(Duration(days: i)));

    final cellSize = context.responsive<double>(
        mobile: 16, tablet: 20, desktop: 22);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day labels
        Row(
          children: ['Δ', 'Τ', 'Τ', 'Π', 'Π', 'Σ', 'Κ']
              .map((d) => SizedBox(
            width:  cellSize + 3,
            child:  Text(d,
                style: context.labelSm.withColor(context.cDisabled),
                textAlign: TextAlign.center),
          ))
              .toList(),
        ),
        const SizedBox(height: Spacing.xs),

        // Grid
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: allDays.map((day) {
            final isDone  = doneDays.contains(day);
            final isToday = day == today;
            final isFuture = day.isAfter(today);

            return Container(
              width:  cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: isFuture
                    ? Colors.transparent
                    : isDone
                    ? color
                    : ColorsUI.getBorder(context.brightness)
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
                border: isToday
                    ? Border.all(color: color, width: 2)
                    : null,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: Spacing.xs),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Λιγότερο',
                style: context.labelSm.withColor(context.cDisabled)),
            const SizedBox(width: Spacing.xs),
            ...List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2 + i * 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
            const SizedBox(width: Spacing.xs),
            Text('Περισσότερο',
                style: context.labelSm.withColor(context.cDisabled)),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATS PANEL — tablet left panel
// ════════════════════════════════════════════════════════════════

class _StatsPanel extends ConsumerWidget {
  final int habitId;
  const _StatsPanel({required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_habitStatsDetailProvider(habitId));
    final color = ColorsUI.itemTypeColor(ItemType.habit, context.brightness);

    return Container(
      color: ColorsUI.getSurface(context.brightness),
      padding: const EdgeInsets.all(Spacing.md),
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (_, __) => const SizedBox.shrink(),
        data: (stats) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Στατιστικά', style: context.titleSm),
            const SizedBox(height: Spacing.md),
            _StatCard(
              icon:  Icons.local_fire_department_rounded,
              value: '${stats.streak}',
              label: 'Τρέχον Streak',
              color: stats.streak > 0
                  ? ColorsUI.getWarning(context.brightness)
                  : context.cDisabled,
            ),
            const SizedBox(height: Spacing.sm),
            _StatCard(
              icon:  Icons.emoji_events_rounded,
              value: '${stats.bestStreak}',
              label: 'Καλύτερο Streak',
              color: color,
            ),
            const SizedBox(height: Spacing.sm),
            _StatCard(
              icon:  Icons.check_circle_outline_rounded,
              value: '${stats.completedCount}',
              label: 'Συνολικές ολοκληρώσεις',
              color: context.cText2,
            ),
            if (stats.goalCount > 0) ...[
              const SizedBox(height: Spacing.sm),
              _StatCard(
                icon:  Icons.flag_rounded,
                value: '${stats.progressPercent.toInt()}%',
                label: 'Πρόοδος στόχου',
                color: color,
              ),
            ],
            if (stats.lastCompleted != null) ...[
              const Divider(height: Spacing.xl),
              Text('Τελευταία ολοκλήρωση',
                  style: context.labelMd.withColor(context.cText2)),
              const SizedBox(height: Spacing.xs),
              Text(stats.lastCompleted!.relative,
                  style: context.bodyMd),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HABIT SETTINGS — goal, frequency
// ════════════════════════════════════════════════════════════════

class _HabitSettings extends ConsumerWidget {
  final int habitId;
  const _HabitSettings({required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(habitId));
    final props      = propsAsync.valueOrNull ?? [];
    final goalCount  = props
        .where((p) => p.key == 'goal_count')
        .firstOrNull?.value ?? '0';
    final unit       = props
        .where((p) => p.key == 'unit')
        .firstOrNull?.value ?? '';

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
            color:        ColorsUI.getSurface(context.brightness),
            borderRadius: AppRadius.cardBR,
            border: Border.all(
                color: ColorsUI.getBorder(context.brightness)),
          ),
          child: Column(
            children: [
              // Goal
              _SettingsRow(
                icon:  Icons.flag_rounded,
                label: 'Στόχος',
                value: goalCount == '0' ? 'Χωρίς στόχο' : '$goalCount φορές',
                onTap: () => _editGoal(context, ref, goalCount),
              ),
              Divider(height: 1,
                  color: ColorsUI.getBorder(context.brightness)),
              // Unit
              _SettingsRow(
                icon:  Icons.straighten_rounded,
                label: 'Μονάδα',
                value: unit.isEmpty ? 'Χωρίς μονάδα' : unit,
                onTap: () => _editUnit(context, ref, unit),
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
      title:   'Στόχος (αριθμός φορών)',
      initial: current == '0' ? '' : current,
      keyboardType: TextInputType.number,
      onSave: (val) async {
        final n = double.tryParse(val) ?? 0;
        DebugConfig.db('HabitSettings setGoal=$n id=$habitId');
        await ref.read(propertyNotifierProvider(habitId).notifier)
            .setNumber('goal_count', n);
      },
    );
  }

  void _editUnit(BuildContext context, WidgetRef ref, String current) {
    _showTextEditor(
      context: context,
      title:   'Μονάδα (π.χ. λεπτά, ποτήρια)',
      initial: current,
      onSave: (val) async {
        DebugConfig.db('HabitSettings setUnit="$val" id=$habitId');
        await ref.read(propertyNotifierProvider(habitId).notifier)
            .setText('unit', val);
      },
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
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.md,
          left:   Spacing.lg,
          right:  Spacing.lg,
          top:    Spacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.titleMd),
            const SizedBox(height: Spacing.md),
            TextField(
              controller:  ctrl,
              autofocus:   true,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText:  title,
                filled:    true,
                fillColor: ColorsUI.getSurface(context.brightness),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputBR,
                  borderSide: BorderSide(
                      color: ColorsUI.getBorder(context.brightness)),
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
    required this.icon, required this.label,
    required this.value, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 18, color: context.cText2),
      title:   Text(label, style: context.bodyMd),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: context.bodyMd.withColor(context.cText2)),
          const SizedBox(width: Spacing.xs),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: context.cDisabled),
        ],
      ),
      onTap: onTap,
    );
  }
}