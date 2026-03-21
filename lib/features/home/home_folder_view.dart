// lib/features/home/home_folder_view.dart
//
// Περιεχόμενο home όταν ο χρήστης επιλέξει συγκεκριμένο φάκελο.
// Εμφανίζει: Stats φακέλου | Σήμερα | Πρόσφατα
// ✅ Real-time (itemsByFolderStreamProvider)
// ✅ Responsive
// ✅ Dark mode + DebugConfig
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import '../notes/note_detail_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../habits/habit_detail_screen.dart';
import '../calendar/event_detail_screen.dart';
import '../contacts/contact_detail_screen.dart';
import '../journal/journal_detail_screen.dart';
import '../collections/collection_detail_screen.dart';

// ════════════════════════════════════════════════════════════════
// HOME FOLDER VIEW
// ════════════════════════════════════════════════════════════════

class HomeFolderView extends ConsumerStatefulWidget {
  final Folder folder;

  const HomeFolderView({super.key, required this.folder});

  @override
  ConsumerState<HomeFolderView> createState() => _HomeFolderViewState();
}

class _HomeFolderViewState extends ConsumerState<HomeFolderView> {
  Folder get folder => widget.folder;

  // ── FAB: Δημιουργία νέου στοιχείου ─────────────────────────

  void _showCreateMenu(BuildContext context) {
    const types = [
      (ItemType.note,    '📝', 'Σημείωση'),
      (ItemType.task,    '✅', 'Εργασία'),
      (ItemType.event,   '📅', 'Συμβάν'),
      (ItemType.habit,   '🔄', 'Συνήθεια'),
      (ItemType.journal, '📖', 'Ημερολόγιο'),
      (ItemType.contact, '👤', 'Επαφή'),
      (ItemType.project, '📦', 'Συλλογή'),
    ];

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
                color:        context.cBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.xs),
              child: Text('Νέο στοιχείο σε "${folder.name}"',
                  style: context.titleSm),
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...types.map((t) => ListTile(
                      leading: Text(t.$2,
                          style: const TextStyle(fontSize: 22)),
                      title: Text(t.$3, style: context.bodyMd),
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 18, color: context.cDisabled),
                      onTap: () async {
                        Navigator.pop(context);
                        await _createItem(context, t.$1);
                      },
                    )),
                    const SizedBox(height: Spacing.sm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createItem(BuildContext context, ItemType type) async {
    DebugConfig.nav('HomeFolderView createItem type=${type.name}');
    final item = await ref.read(itemNotifierProvider.notifier).create(
      type:     type,
      folderId: folder.id,
    );
    if (item == null || !mounted) return;
    ref.invalidate(itemNotifierProvider);
    // ignore: use_build_context_synchronously
    _openItem(context, item, isNew: true);
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('HomeFolderView build folder=${folder.id}');

    final itemsAsync  = ref.watch(itemsByFolderStreamProvider(folder.id));
    final statsAsync  = ref.watch(folderStatsProvider(folder.id));
    final recentAsync = ref.watch(recentByFolderProvider(folder.id));

    final folderColor = _colorFromHex(folder.color, context.cPrimary);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(itemsByFolderStreamProvider(folder.id));
            ref.invalidate(folderStatsProvider(folder.id));
            ref.invalidate(recentByFolderProvider(folder.id));
          },
          child: CustomScrollView(
            slivers: [
              // ── Stats ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: statsAsync.when(
                  loading: () => _StatsRowSkeleton(),
                  error:   (_, __) => const SizedBox.shrink(),
                  data:    (stats) => _FolderStatsRow(stats: stats),
                ),
              ),

              // ── Σήμερα ────────────────────────────────────────────
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  icon:  Icons.today_rounded,
                  title: 'Σήμερα',
                ),
              ),
              itemsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: Spacing.md),
                    child: ItemCardSkeleton(),
                  ),
                ),
                error: (e, _) => const SliverToBoxAdapter(
                    child: SizedBox.shrink()),
                data: (items) => _TodaySectionSliver(
                  items:    items,
                  folder:   folder,
                  onTap:    (item) => _openItem(context, item),
                  onToggle: (item) => _toggleDone(ref, item),
                ),
              ),

              // ── Πρόσφατα ─────────────────────────────────────────
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  icon:  Icons.history_rounded,
                  title: 'Πρόσφατα',
                ),
              ),
              recentAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Spacing.md),
                    child: ItemCardSkeleton(),
                  ),
                ),
                error: (e, _) => const SliverToBoxAdapter(
                    child: SizedBox.shrink()),
                data: (items) => _RecentSectionSliver(
                  items: items,
                  folder: folder,
                  onTap:  (item) => _openItem(context, item),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
        // FAB
        Positioned(
          right:  Spacing.md,
          bottom: Spacing.lg,
          child: FloatingActionButton(
            onPressed:       () => _showCreateMenu(context),
            backgroundColor: folderColor,
            foregroundColor: Colors.white,
            tooltip: 'Νέο στοιχείο',
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }

  static Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) { return fallback; }
  }

  void _openItem(BuildContext context, Item item, {bool isNew = false}) {
    DebugConfig.nav('HomeFolderView → ${item.type.name} id=${item.id}');
    switch (item.type) {
      case ItemType.task:
        Navigator.of(context).push(AppTransitions.slideRoute(
            TaskDetailScreen(itemId: item.id)));
      case ItemType.contact:
        Navigator.of(context).push(AppTransitions.slideRoute(
            ContactDetailScreen(itemId: item.id, isNew: isNew)));
      case ItemType.journal:
        Navigator.of(context).push(AppTransitions.slideRoute(
            JournalDetailScreen(itemId: item.id, isNew: isNew)));
      case ItemType.habit:
        Navigator.of(context).push(AppTransitions.slideRoute(
            HabitDetailScreen(itemId: item.id)));
      case ItemType.event:
        Navigator.of(context).push(AppTransitions.slideRoute(
            EventDetailScreen(itemId: item.id, isNew: isNew)));
      case ItemType.project:
        Navigator.of(context).push(AppTransitions.slideRoute(
            CollectionDetailScreen(collectionId: item.id, isNew: isNew)));
      default:
        Navigator.of(context).push(AppTransitions.slideRoute(
            NoteDetailScreen(itemId: item.id, isNew: isNew)));
    }
  }

  Future<void> _toggleDone(WidgetRef ref, Item item) async {
    final next = item.status == ItemStatus.done
        ? ItemStatus.active
        : ItemStatus.done;
    DebugConfig.db('HomeFolderView toggleDone id=${item.id} → ${next.name}');
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(item.id, status: next);
  }
}

// ════════════════════════════════════════════════════════════════
// FOLDER STATS ROW
// ════════════════════════════════════════════════════════════════

class _FolderStatsRow extends StatelessWidget {
  final Map<ItemType, int> stats;
  const _FolderStatsRow({required this.stats});

  static const _shown = [
    ItemType.note, ItemType.task, ItemType.event,
    ItemType.habit, ItemType.contact,
  ];

  @override
  Widget build(BuildContext context) {
    // Φίλτρο: μόνο τύποι με count > 0
    final activeTypes = _shown.where((t) => (stats[t] ?? 0) > 0).toList();
    if (activeTypes.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical:   Spacing.xs,
        ),
        itemCount:        activeTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (_, i) {
          final type  = activeTypes[i];
          final count = stats[type] ?? 0;
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
                    Text('$count',
                        style: context.titleMd.withColor(color)),
                    Text(ItemTypeIcon.labelFor(type),
                        style: context.labelSm.withColor(context.cText2)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
            horizontal: context.responsiveHPadding,
            vertical:   Spacing.xs),
        itemCount:        3,
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
// TODAY SECTION SLIVER
// ════════════════════════════════════════════════════════════════

class _TodaySectionSliver extends ConsumerWidget {
  final List<Item>  items;
  final Folder      folder;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onToggle;

  const _TodaySectionSliver({
    required this.items,
    required this.folder,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tasks: μη completed που έχουν due date σήμερα ή παλαιότερα
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayTasks = <Item>[];
    for (final item in items) {
      if (item.type != ItemType.task) continue;
      if (item.status == ItemStatus.done) continue;
      if (item.deletedAt != null) continue;
      final due = ref.watch(dueDateProvider(item.id)).valueOrNull;
      if (due == null) continue;
      if (!DateTime(due.year, due.month, due.day).isAfter(today)) {
        todayTasks.add(item);
      }
    }

    if (todayTasks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsiveHPadding,
            vertical:   Spacing.xs,
          ),
          child: Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color:        ColorsUI.getSurface(context.brightness),
              borderRadius: AppRadius.cardBR,
            ),
            child: Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: context.cSuccess, size: 20),
              const SizedBox(width: Spacing.sm),
              Text('Όλα έτοιμα για σήμερα! 🎉',
                  style: context.bodyMd),
            ]),
          ),
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
            child: _TaskTile(
              task:     todayTasks[i],
              onTap:    () => onTap(todayTasks[i]),
              onToggle: () => onToggle(todayTasks[i]),
            ),
          ),
          childCount: todayTasks.take(5).length,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RECENT SECTION SLIVER
// ════════════════════════════════════════════════════════════════

class _RecentSectionSliver extends StatelessWidget {
  final List<Item>  items;
  final Folder      folder;
  final ValueChanged<Item> onTap;

  const _RecentSectionSliver({
    required this.items,
    required this.folder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
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
              item:    items[i],
              compact: true,
              onTap:   () => onTap(items[i]),
            ),
          ),
          childCount: items.length,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SECTION HEADER
// ════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.lg,
        context.responsiveHPadding, Spacing.sm,
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: context.cText2),
        const SizedBox(width: Spacing.xs),
        Text(title, style: context.titleSm),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TASK TILE
// ════════════════════════════════════════════════════════════════

class _TaskTile extends StatelessWidget {
  final Item task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _TaskTile({
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
          border: Border.all(
              color: ColorsUI.getBorder(context.brightness)),
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
                  color: isDone
                      ? context.cPrimary
                      : ColorsUI.getBorder(context.brightness),
                  width: 2,
                ),
              ),
              child: isDone
                  ? Icon(Icons.check_rounded, size: 14,
                  color: ColorsUI.getAccessibleTextColor(
                      context.cPrimary))
                  : null,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              task.title ?? 'Χωρίς τίτλο',
              style: context.bodyMd.copyWith(
                decoration: isDone
                    ? TextDecoration.lineThrough : null,
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