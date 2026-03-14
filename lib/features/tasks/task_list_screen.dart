// lib/features/tasks/task_list_screen.dart
//
// Λίστα εργασιών με φίλτρα status/priority, due dates, FAB δημιουργίας.
// ✅ Responsive: list mobile / grid tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'task_detail_screen.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';

// ── Local providers ───────────────────────────────────────────────

final _tasksProvider = FutureProvider<List<Item>>((ref) async {
  final db          = ref.watch(dbProvider);
  final wsId        = ref.watch(activeWorkspaceIdProvider);
  final showArchived = ref.watch(showArchivedProvider);
  if (wsId == null) return [];
  DebugConfig.db('_tasksProvider load wsId=$wsId');
  return db.items.getByWorkspace(
    wsId,
    type: ItemType.task,
    includeArchived: showArchived,
  );
});

final _statusFilterProvider  = StateProvider<ItemStatus?>((ref) => null);
final _priorityFilterProvider = StateProvider<ItemPriority?>((ref) => null);
final _searchQueryProvider    = StateProvider<String>((ref) => '');

// ════════════════════════════════════════════════════════════════
// TASK LIST SCREEN
// ════════════════════════════════════════════════════════════════

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  bool  _searchActive = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Search ───────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      DebugConfig.search('TaskList search: "$value"');
      ref.read(_searchQueryProvider.notifier).state = value.trim();
    });
  }

  void _toggleSearch() {
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      ref.read(_searchQueryProvider.notifier).state = '';
    } else {
      Future.microtask(() => _searchFocus.requestFocus());
    }
  }

  // ── Create task ──────────────────────────────────────────────

  Future<void> _createTask() async {
    DebugConfig.nav('TaskList: create task');
    final item = await ref.read(itemNotifierProvider.notifier)
        .create(type: ItemType.task);
    if (item == null || !mounted) return;
    ref.invalidate(_tasksProvider);
    _openDetail(item.id);
  }

  void _openDetail(int id) {
    DebugConfig.nav('TaskList → TaskDetail id=$id');
    context.push(AppRoutes.task(id));
  }
  // ── Toggle done ──────────────────────────────────────────────

  Future<void> _toggleDone(Item item) async {
    final newStatus = item.status == ItemStatus.done
        ? ItemStatus.active
        : ItemStatus.done;
    DebugConfig.db('TaskList toggleDone id=${item.id} → ${newStatus.name}');
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(item.id, status: newStatus);
    ref.invalidate(_tasksProvider);
  }

  // ── Item actions ─────────────────────────────────────────────

  void _showItemActions(BuildContext context, Item item) {
    DebugConfig.nav('TaskList: showActions id=${item.id}');
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => _TaskActionsSheet(
        item:      item,
        onEdit:    () { Navigator.pop(context); _openDetail(item.id); },
        onPin:     () => _togglePin(item),
        onArchive: () => _archive(item),
        onDelete:  () => _delete(item),
      ),
    );
  }

  Future<void> _togglePin(Item item) async {
    Navigator.pop(context);
    await ref.read(itemNotifierProvider.notifier)
        .togglePin(item.id, item.pinned);
    ref.invalidate(_tasksProvider);
  }

  Future<void> _archive(Item item) async {
    Navigator.pop(context);
    final future = ConfirmDialog.archive(context);
    final ok = await future;
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier)
        .toggleArchive(item.id, item.archived);
    ref.invalidate(_tasksProvider);
  }

  Future<void> _delete(Item item) async {
    Navigator.pop(context);
    final future = ConfirmDialog.delete(
        context, title: 'Διαγραφή εργασίας;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('TaskList delete id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    ref.invalidate(_tasksProvider);
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('TaskListScreen build');

    final tasksAsync     = ref.watch(_tasksProvider);
    final statusFilter   = ref.watch(_statusFilterProvider);
    final priorityFilter = ref.watch(_priorityFilterProvider);
    final searchQuery    = ref.watch(_searchQueryProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTask,
        tooltip: 'Νέα εργασία',
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────
          if (_searchActive) _SearchBar(
            controller: _searchCtrl,
            focusNode:  _searchFocus,
            onChanged:  _onSearchChanged,
          ),

          // ── Filter chips ──────────────────────────────────────
          _FilterRow(
            statusFilter:   statusFilter,
            priorityFilter: priorityFilter,
            onStatusTap: (s) {
              final cur = ref.read(_statusFilterProvider);
              ref.read(_statusFilterProvider.notifier).state =
              cur == s ? null : s;
              DebugConfig.provider('TaskList statusFilter: ${s.name}');
            },
            onPriorityTap: (p) {
              final cur = ref.read(_priorityFilterProvider);
              ref.read(_priorityFilterProvider.notifier).state =
              cur == p ? null : p;
              DebugConfig.provider('TaskList priorityFilter: ${p.name}');
            },
          ),

          // ── Stats bar ─────────────────────────────────────────
          tasksAsync.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data: (tasks) => _StatsBar(tasks: tasks),
          ),

          // ── Task list ─────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(_tasksProvider),
              child: tasksAsync.when(
                loading: () => _LoadingList(),
                error: (e, _) {
                  DebugConfig.error('TaskList load failed', e);
                  return EmptyState.error(
                      onRetry: () => ref.invalidate(_tasksProvider));
                },
                data: (tasks) {
                  final filtered = _filter(tasks, searchQuery,
                      statusFilter, priorityFilter);

                  if (filtered.isEmpty) {
                    return searchQuery.isNotEmpty ||
                        statusFilter != null ||
                        priorityFilter != null
                        ? EmptyState.search(query: searchQuery)
                        : EmptyState.forType(
                        ItemType.task, onAction: _createTask);
                  }

                  // Ομαδοποίηση: Overdue / Today / Upcoming / No date / Done
                  return _TaskListBody(
                    tasks:       filtered,
                    onTap:       (item) => _openDetail(item.id),
                    onLongPress: (item) => _showItemActions(context, item),
                    onToggleDone: _toggleDone,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Εργασίες'),
      actions: [
        IconButton(
          icon: Icon(_searchActive
              ? Icons.search_off_rounded
              : Icons.search_rounded),
          onPressed: _toggleSearch,
          tooltip: 'Αναζήτηση',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) {
            if (v == 'archived') {
              final show = ref.read(showArchivedProvider);
              ref.read(showArchivedProvider.notifier).state = !show;
              ref.invalidate(_tasksProvider);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'archived',
              child: Row(children: [
                const Icon(Icons.archive_rounded, size: 18),
                const SizedBox(width: Spacing.sm),
                Text(ref.watch(showArchivedProvider)
                    ? 'Απόκρυψη αρχείου'
                    : 'Εμφάνιση αρχείου'),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  List<Item> _filter(List<Item> tasks, String query,
      ItemStatus? status, ItemPriority? priority) {
    var list = tasks;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((t) =>
          (t.title ?? '').toLowerCase().contains(q)).toList();
    }
    if (status != null) {
      list = list.where((t) => t.status == status).toList();
    }
    if (priority != null) {
      list = list.where((t) => t.priority == priority).toList();
    }
    return list;
  }
}

// ════════════════════════════════════════════════════════════════
// TASK LIST BODY — ομαδοποίηση σε sections
// ════════════════════════════════════════════════════════════════

class _TaskListBody extends ConsumerWidget {
  final List<Item> tasks;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onLongPress;
  final ValueChanged<Item> onToggleDone;

  const _TaskListBody({
    required this.tasks,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Φόρτωσε due dates από ItemProperty για κάθε task
    final Map<int, DateTime?> dueDates = {};
    for (final task in tasks) {
      final props = ref.watch(itemPropertiesProvider(task.id)).valueOrNull ?? [];
      final dueProp = props.where((p) => p.key == 'due_date').firstOrNull;
      dueDates[task.id] = dueProp?.dateValue;
    }

    // Ομαδοποίηση
    final now      = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);

    final overdue  = <Item>[];
    final todayT   = <Item>[];
    final upcoming = <Item>[];
    final noDate   = <Item>[];
    final done     = <Item>[];

    for (final task in tasks) {
      if (task.status == ItemStatus.done) {
        done.add(task); continue;
      }
      final due = dueDates[task.id];
      if (due == null) {
        noDate.add(task);
      } else {
        final dueDay = DateTime(due.year, due.month, due.day);
        if (dueDay.isBefore(today))      {overdue.add(task);}
        else if (dueDay == today)         {todayT.add(task);}
        else                              {upcoming.add(task);}
      }
    }

    return CustomScrollView(
      slivers: [
        if (overdue.isNotEmpty)  ...[
          _SectionHeader(label: 'Ληξιπρόθεσμες', color: context.cError),
          _buildSliver(context, ref, overdue, dueDates),
        ],
        if (todayT.isNotEmpty) ...[
          _SectionHeader(label: 'Σήμερα', color: context.cWarning),
          _buildSliver(context, ref, todayT, dueDates),
        ],
        if (upcoming.isNotEmpty) ...[
          _SectionHeader(label: 'Επερχόμενες', color: context.cPrimary),
          _buildSliver(context, ref, upcoming, dueDates),
        ],
        if (noDate.isNotEmpty) ...[
          const _SectionHeader(label: 'Χωρίς ημερομηνία'),
          _buildSliver(context, ref, noDate, dueDates),
        ],
        if (done.isNotEmpty) ...[
          _SectionHeader(label: 'Ολοκληρωμένες (${done.length})'),
          _buildSliver(context, ref, done, dueDates, dimmed: true),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildSliver(BuildContext context, WidgetRef ref,
      List<Item> items, Map<int, DateTime?> dueDates, {bool dimmed = false}) {
    final cols = context.gridColumns;

    if (cols == 1) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical: Spacing.xs,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Opacity(
                opacity: dimmed ? 0.6 : 1.0,
                child: _TaskCard(
                  item:         items[i],
                  dueDate:      dueDates[items[i].id],
                  onTap:        () => onTap(items[i]),
                  onLongPress:  () => onLongPress(items[i]),
                  onToggleDone: () => onToggleDone(items[i]),
                ),
              ),
            ),
            childCount: items.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.xs,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:  cols,
          mainAxisSpacing:  Spacing.sm,
          crossAxisSpacing: Spacing.sm,
          mainAxisExtent:   88,
        ),
        delegate: SliverChildBuilderDelegate(
              (_, i) => Opacity(
            opacity: dimmed ? 0.6 : 1.0,
            child: _TaskCard(
              item:         items[i],
              dueDate:      dueDates[items[i].id],
              onTap:        () => onTap(items[i]),
              onLongPress:  () => onLongPress(items[i]),
              onToggleDone: () => onToggleDone(items[i]),
            ),
          ),
          childCount: items.length,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TASK CARD — ItemCard με checkbox
// ════════════════════════════════════════════════════════════════

class _TaskCard extends ConsumerWidget {
  final Item item;
  final DateTime? dueDate;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleDone;

  const _TaskCard({
    required this.item,
    required this.dueDate,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(itemTagsProvider(item.id));
    final tagNames  = tagsAsync.valueOrNull?.map((t) => t.name).toList() ?? [];

    return ItemCard(
      item:        item,
      dueDate:     dueDate,
      tagNames:    tagNames,
      compact:     context.isMobile,
      onTap:       onTap,
      onLongPress: onLongPress,
      onCheckboxChanged: (_) => onToggleDone(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SECTION HEADER
// ════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color? color;

  const _SectionHeader({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.responsiveHPadding, Spacing.md,
          context.responsiveHPadding, Spacing.xs,
        ),
        child: Text(
          label,
          style: context.labelMd.withColor(color ?? context.cText2),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATS BAR — σύνοψη done/total
// ════════════════════════════════════════════════════════════════

class _StatsBar extends StatelessWidget {
  final List<Item> tasks;
  const _StatsBar({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final total  = tasks.where((t) => !t.archived).length;
    final done   = tasks.where((t) => t.status == ItemStatus.done).length;
    if (total == 0) return const SizedBox.shrink();

    final progress = done / total;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.sm,
        context.responsiveHPadding, 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$done / $total ολοκληρώθηκαν',
                  style: context.labelSm.withColor(context.cText2)),
              Text('${(progress * 100).toInt()}%',
                  style: context.labelSm.withColor(context.cText2)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            progress,
              minHeight:        4,
              backgroundColor:  ColorsUI.getBorder(context.brightness),
              valueColor: AlwaysStoppedAnimation<Color>(context.cPrimary),
            ),
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FILTER ROW — status + priority chips
// ════════════════════════════════════════════════════════════════

class _FilterRow extends StatelessWidget {
  final ItemStatus?   statusFilter;
  final ItemPriority? priorityFilter;
  final ValueChanged<ItemStatus>   onStatusTap;
  final ValueChanged<ItemPriority> onPriorityTap;

  const _FilterRow({
    required this.statusFilter,
    required this.priorityFilter,
    required this.onStatusTap,
    required this.onPriorityTap,
  });

  static const _statuses = [
    (ItemStatus.active,     'Ενεργές'),
    (ItemStatus.inProgress, 'Σε εξέλιξη'),
    (ItemStatus.done,       'Ολοκληρωμένες'),
  ];

  static const _priorities = [
    ItemPriority.urgent,
    ItemPriority.high,
    ItemPriority.medium,
    ItemPriority.low,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
        ),
        children: [
          // Status filters
          ..._statuses.map((s) => Padding(
            padding: const EdgeInsets.only(right: Spacing.xs),
            child: _StatusChip(
              label:    s.$2,
              selected: statusFilter == s.$1,
              onTap:    () => onStatusTap(s.$1),
            ),
          )),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xs, vertical: 6),
            child: VerticalDivider(
                color: ColorsUI.getBorder(context.brightness), width: 1),
          ),

          // Priority filters
          ..._priorities.map((p) => Padding(
            padding: const EdgeInsets.only(right: Spacing.xs),
            child: PriorityBadge(
              priority:  p,
              size:      BadgeSize.small,
              showIcon:  true,
              showLabel: true,
            ),
          )),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm + 2, vertical: Spacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? context.cPrimary.withValues(alpha:0.12)
              : ColorsUI.getSurface(context.brightness),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: selected
                ? context.cPrimary.withValues(alpha:0.5)
                : ColorsUI.getBorder(context.brightness),
          ),
        ),
        child: Text(
          label,
          style: context.labelSm.withColor(
              selected ? context.cPrimary : context.cText2),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TASK ACTIONS SHEET
// ════════════════════════════════════════════════════════════════

class _TaskActionsSheet extends StatelessWidget {
  final Item item;
  final VoidCallback onEdit;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _TaskActionsSheet({
    required this.item,
    required this.onEdit,
    required this.onPin,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.xs),
            child: Row(children: [
              Expanded(
                child: Text(item.title ?? 'Χωρίς τίτλο',
                    style: context.titleMd,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (item.priority != ItemPriority.none)
                PriorityBadge(priority: item.priority),
            ]),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Επεξεργασία'),
            onTap: onEdit,
          ),
          ListTile(
            leading: Icon(item.pinned
                ? Icons.push_pin_rounded
                : Icons.push_pin_outlined),
            title: Text(item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα'),
            onTap: onPin,
          ),
          ListTile(
            leading: const Icon(Icons.archive_rounded),
            title: Text(item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση'),
            onTap: onArchive,
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: context.cError),
            title: Text('Διαγραφή', style: TextStyle(color: context.cError)),
            onTap: onDelete,
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SEARCH BAR
// ════════════════════════════════════════════════════════════════

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
        context.responsiveHPadding, Spacing.sm,
        context.responsiveHPadding, Spacing.sm,
      ),
      child: TextField(
        controller: controller,
        focusNode:  focusNode,
        onChanged:  onChanged,
        style:      context.bodyMd,
        decoration: InputDecoration(
          hintText:    'Αναζήτηση εργασιών...',
          hintStyle:   context.bodyMd.withColor(context.cDisabled),
          prefixIcon:  Icon(Icons.search_rounded, color: context.cText2),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close_rounded, color: context.cText2),
            onPressed: () { controller.clear(); onChanged(''); },
          )
              : null,
          filled:      true,
          fillColor:   ColorsUI.getSurface(context.brightness),
          border: OutlineInputBorder(
            borderRadius: AppRadius.inputBR,
            borderSide:   BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
        ),
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
      itemCount:        5,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder:      (_, __) => const ItemCardSkeleton(),
    );
  }
}