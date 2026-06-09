// lib/features/tasks/task_list_screen.dart
//
// Λίστα εργασιών με φίλτρα status/priority, due dates, FAB δημιουργίας.
// ✅ Responsive: list mobile / grid tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
// ✅ View mode toggle (pinned/favorites/all)
// ✅ Fix: φίλτρα status/priority δεν χάνουν τη λίστα
// ✅ Αυτόματη επιλογή φακέλου βάσει ρυθμίσεων (προεπιλεγμένος ή "Γενικά")
// ✅ Περιμένει τα settings πριν επιλέξει φάκελο
// ✅ Search, tags (όπως το ItemListScreen)
// ✅ Fix: κλείδωμα pop κατά το drag (αποφυγή ανεπιθύμητου back gesture)
// ✅ Progress bar ανά κάρτα εργασίας (υποεργασίες, overdue, done)
// ✅ Checkbox μπλοκαρισμένο όταν υπάρχουν υποεργασίες
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';
import 'package:go_router/go_router.dart';

final _statusFilterProvider   = StateProvider<ItemStatus?>((ref)   => null);
final _priorityFilterProvider = StateProvider<ItemPriority?>((ref) => null);
final _searchQueryProvider    = StateProvider<String>((ref)        => '');
final _taskTagFilterProvider  = StateProvider<Set<String>>((ref)   => {});

// ════════════════════════════════════════════════════════════════
// TASK LIST SCREEN
// ════════════════════════════════════════════════════════════════

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen>
    with FolderAutoSelectMixin {
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;
  bool _showArchiveHintShown = false;
  Timer? _debounce;

  Set<String> _visibleTagNames = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_statusFilterProvider.notifier).state   = null;
      ref.read(_priorityFilterProvider.notifier).state = null;
      ref.read(_searchQueryProvider.notifier).state    = '';
      ref.read(_taskTagFilterProvider.notifier).state  = {};
    });
  }

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
      DebugConfig.search('TaskList search: "$value"');
      ref.read(_searchQueryProvider.notifier).state = value.trim();
    });
  }

  void _toggleSearch() {
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      ref.read(_searchQueryProvider.notifier).state    = '';
      ref.read(_taskTagFilterProvider.notifier).state  = {};
    } else {
      Future.microtask(() => _searchFocus.requestFocus());
    }
  }

  Future<void> _createTask() async {
    final selectedFolderId = ref.read(selectedFolderIdProvider);
    DebugConfig.nav('TaskList: create task in folder id=$selectedFolderId');

    final item = await ref.read(itemNotifierProvider.notifier).create(
      type:     ItemType.task,
      folderId: selectedFolderId,
    );

    if (item == null || !mounted) return;
    _openDetail(item.id, isNew: true);
  }

  void _openDetail(int id, {bool isNew = false}) {
    DebugConfig.nav('TaskList → TaskDetail id=$id isNew=$isNew');
    context.push(AppRoutes.task(id), extra: isNew);
  }

  Future<void> _toggleDone(Item item) async {
    final newStatus =
    item.status == ItemStatus.done ? ItemStatus.active : ItemStatus.done;
    DebugConfig.db('TaskList toggleDone id=${item.id} → ${newStatus.name}');
    await ref.read(itemNotifierProvider.notifier).updateItem(item.id, status: newStatus);
  }

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
    await ref.read(itemNotifierProvider.notifier).togglePin(item.id, item.pinned);
  }

  Future<void> _archive(Item item) async {
    Navigator.pop(context);
    await handleArchive(
      context: context,
      ref: ref,
      itemId: item.id,
      isArchived: item.archived,
      label: ItemLabel.task,
      showPopOnArchive: false,
      showPopOnUnarchive: false,
    );
  }

  Future<void> _delete(Item item) async {
    Navigator.pop(context);
    final ok = await ConfirmDialog.delete(context, title: 'Διαγραφή εργασίας;');
    if (!ok || !mounted) return;
    DebugConfig.db('TaskList delete id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('TaskListScreen build');

    final itemsAsync     = ref.watch(tasksWithDetailsProvider); // ✅ parallel batch load
    final statusFilter   = ref.watch(_statusFilterProvider);
    final priorityFilter = ref.watch(_priorityFilterProvider);
    final searchQuery    = ref.watch(_searchQueryProvider);
    final activeTags     = ref.watch(_taskTagFilterProvider);
    final foldersAsync   = ref.watch(foldersStreamProvider);
    final settingsAsync  = ref.watch(settingsNotifierProvider);
    final isDragging     = ref.watch(isDraggingProvider);
    final selectedFolderId = ref.watch(selectedFolderIdProvider);

    tryAutoSelectFolder(
      foldersAsync: foldersAsync,
      settingsAsync: settingsAsync,
      debugLabel: 'TaskList',
    );

    return PopScope(
      canPop: !isDragging,
      child: Scaffold(
        backgroundColor: context.cBg,
        appBar: _buildAppBar(),
        floatingActionButton: selectedFolderId == null
            ? null
            : FloatingActionButton(
          onPressed: _createTask,
          tooltip:   'Νέα εργασία',
          child:     const Icon(Icons.add_rounded),
        ),
        body: Column(
          children: [
            if (_searchActive)
              _SearchBar(
                controller: _searchCtrl,
                focusNode:  _searchFocus,
                onChanged:  (value) {
                  setState(() {});
                  _onSearchChanged(value);
                },
              ),

            const DraggableFolderSelector(),

            _FilterRow(
              statusFilter:   statusFilter,
              priorityFilter: priorityFilter,
              onStatusTap: (s) {
                final cur = ref.read(_statusFilterProvider);
                ref.read(_statusFilterProvider.notifier).state = cur == s ? null : s;
                DebugConfig.provider('TaskList statusFilter: ${s.name}');
              },
              onPriorityTap: (p) {
                final cur = ref.read(_priorityFilterProvider);
                ref.read(_priorityFilterProvider.notifier).state = cur == p ? null : p;
                DebugConfig.provider('TaskList priorityFilter: ${p.name}');
              },
            ),

            if (_visibleTagNames.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.responsiveHPadding, 0,
                      context.responsiveHPadding, Spacing.xs,
                    ),
                    child: Text(
                      'Επιλέξτε tag για φιλτράρισμα εργασιών',
                      style: context.labelSm.withColor(context.cText2),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                          horizontal: context.responsiveHPadding),
                      itemCount:        _visibleTagNames.length,
                      separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
                      itemBuilder: (_, i) {
                        final name     = _visibleTagNames.elementAt(i);
                        final selected = activeTags.contains(name);
                        return TagChip(
                          name:     name,
                          color:    null,
                          compact:  true,
                          selected: selected,
                          onTap: () {
                            final current = ref.read(_taskTagFilterProvider);
                            final newSet  = {...current};
                            if (newSet.contains(name)) {
                              newSet.remove(name);
                            } else {
                              newSet.add(name);
                            }
                            ref.read(_taskTagFilterProvider.notifier).state = newSet;
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
                onRefresh: () async => ref.invalidate(tasksWithDetailsProvider),
                child: itemsAsync.when(
                  loading: () => _LoadingList(),
                  error: (e, _) {
                    DebugConfig.error('TaskList load failed', e);
                    return EmptyState.error(
                      onRetry: () => ref.invalidate(itemsStreamProvider),
                    );
                  },
                  data: (allTasks) {
                    // ✅ parentId ήδη φορτωμένο — μηδέν ref.read(itemPropertiesProvider) εδώ
                    var tasks = allTasks
                        .where((td) => td.task.deletedAt == null && td.parentId == null)
                        .toList();

                    final viewMode = ref.watch(listViewModeProvider);
                    switch (viewMode) {
                      case ListViewMode.pinned:
                        tasks = tasks.where((td) => td.task.pinned).toList();
                        break;
                      case ListViewMode.favorites:
                        tasks = tasks.where((td) => td.task.favorite).toList();
                        break;
                      case ListViewMode.all:
                        break;
                    }

                    if (selectedFolderId != null) {
                      tasks = tasks
                          .where((td) => td.task.folderId == selectedFolderId)
                          .toList();
                    }

                    if (searchQuery.isNotEmpty) {
                      final q = searchQuery.toLowerCase();
                      tasks = tasks
                          .where((td) =>
                          (td.task.title ?? '').toLowerCase().contains(q))
                          .toList();
                    }

                    if (statusFilter != null) {
                      tasks = tasks
                          .where((td) => td.task.status == statusFilter)
                          .toList();
                    }

                    if (priorityFilter != null) {
                      tasks = tasks
                          .where((td) => td.task.priority == priorityFilter)
                          .toList();
                    }

                    // ✅ Tags ήδη φορτωμένα — μηδέν ref.read(itemTagsProvider) εδώ
                    if (activeTags.isNotEmpty) {
                      tasks = tasks
                          .where((td) =>
                          td.tags.any((tag) => activeTags.contains(tag.name)))
                          .toList();
                    }

                    final visibleTagNames = <String>{};
                    for (final td in tasks) {
                      for (final tag in td.tags) {
                        visibleTagNames.add(tag.name);
                      }
                    }
                    _visibleTagNames = visibleTagNames;

                    if (tasks.isEmpty) {
                      final hasFilters = searchQuery.isNotEmpty ||
                          statusFilter   != null ||
                          priorityFilter != null ||
                          activeTags.isNotEmpty;

                      if (hasFilters) {
                        return EmptyState.search(query: searchQuery);
                      }
                      return EmptyState.forType(
                        ItemType.task,
                        onAction: _createTask,
                      );
                    }

                    return Column(
                      children: [
                        // _StatsBar παραμένει με List<Item>
                        _StatsBar(tasks: tasks.map((td) => td.task).toList()),
                        Expanded(
                          child: _TaskListBody(
                            tasks:        tasks,
                            onTap:        (item) => _openDetail(item.id),
                            onLongPress:  (item) =>
                                _showItemActions(context, item),
                            onToggleDone: _toggleDone,
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
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Εργασίες'),
      actions: [
        IconButton(
          icon: Icon(
            _searchActive
                ? Icons.search_off_rounded
                : Icons.search_rounded,
          ),
          onPressed: _toggleSearch,
          tooltip: _searchActive ? 'Κλείσιμο αναζήτησης' : 'Αναζήτηση',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            if (value == 'archived') {
              final show = ref.read(showArchivedProvider);
              ref.read(showArchivedProvider.notifier).state = !show;
              if (!show && !_showArchiveHintShown) {
                _showArchiveHintShown = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Πατήστε παρατεταμένα (long press) στο στοιχείο για επαναφορά')),
                    );
                  }
                });
              }
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
                      ? 'Απόκρυψη συμπιεσμένων αρχείων'
                      : 'Εμφάνιση συμπιεσμένων αρχείων',
                ),
              ]),
            ),
          ],
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TASK LIST BODY — ομαδοποίηση σε sections
// ════════════════════════════════════════════════════════════════

class _TaskListBody extends ConsumerWidget {
  final List<TaskWithDetails> tasks;
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
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdue  = <TaskWithDetails>[];
    final todayT   = <TaskWithDetails>[];
    final upcoming = <TaskWithDetails>[];
    final noDate   = <TaskWithDetails>[];
    final done     = <TaskWithDetails>[];

    for (final td in tasks) {
      if (td.task.status == ItemStatus.done) {
        done.add(td);
        continue;
      }
      final dueDate = td.dueDate;
      if (dueDate == null) {
        noDate.add(td);
      } else {
        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
        if (dueDay.isBefore(today)) {
          overdue.add(td);
        } else if (dueDay == today) {
          todayT.add(td);
        } else {
          upcoming.add(td);
        }
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, 0,
        context.responsiveHPadding, 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overdue.isNotEmpty) ...[
            _SectionHeader(label: 'Ληξιπρόθεσμες', color: context.cError),
            _buildSection(context, ref, overdue),
          ],
          if (todayT.isNotEmpty) ...[
            _SectionHeader(label: 'Σήμερα', color: context.cWarning),
            _buildSection(context, ref, todayT),
          ],
          if (upcoming.isNotEmpty) ...[
            _SectionHeader(label: 'Επερχόμενες', color: context.cPrimary),
            _buildSection(context, ref, upcoming),
          ],
          if (noDate.isNotEmpty) ...[
            const _SectionHeader(label: 'Χωρίς ημερομηνία'),
            _buildSection(context, ref, noDate),
          ],
          if (done.isNotEmpty) ...[
            _SectionHeader(label: 'Ολοκληρωμένες (${done.length})'),
            _buildSection(context, ref, done, dimmed: true),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context,
      WidgetRef ref,
      List<TaskWithDetails> items, {
        bool dimmed = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: ReorderableItemList(
        items: items.map((td) => td.task).toList(),
        gridItemExtent: 94,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: (oldIndex, newIndex) =>
            _onTaskReorder(ref, items, oldIndex, newIndex),
        itemBuilder: (ctx, item, index) {
          final td = items.firstWhere((t) => t.task.id == item.id);
          return Opacity(
            opacity: dimmed ? 0.6 : 1.0,
            child: _TaskCard(
              td: td,
              onTap: () => onTap(td.task),
              onLongPress: () => onLongPress(td.task),
              onToggleDone: () => onToggleDone(td.task),
            ),
          );
        },
      ),
    );
  }

  void _onTaskReorder(
      WidgetRef ref,
      List<TaskWithDetails> items,
      int oldIndex,
      int newIndex,
      ) {
    if (oldIndex == newIndex) return;
    final reordered = List<TaskWithDetails>.from(items);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    ref.read(itemNotifierProvider.notifier)
        .reorder(reordered.map((td) => td.task).toList());
  }
}

// ════════════════════════════════════════════════════════════════
// TASK CARD — με progress bar υποεργασιών
// ════════════════════════════════════════════════════════════════

class _TaskCard extends ConsumerWidget {
  // ✅ TaskWithDetails — dueDate + tags ήδη φορτωμένα
  final TaskWithDetails td;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleDone;

  const _TaskCard({
    required this.td,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueDate  = td.dueDate;
    final tagNames = td.tags.map((t) => t.name).toList();

    // ✅ Subtasks από TaskWithDetails — μηδέν ref.watch, μηδέν cascade rebuilds
    final subtasks    = td.subtasks;
    final hasSubtasks = subtasks.isNotEmpty;
    final showArchived = ref.watch(showArchivedProvider);
    final isArchived = td.task.archived && showArchived;
    final overrideColor = ref.watch(itemTypeCardColorOverrideProvider(td.task.type));

    DebugConfig.db('TaskCard id=${td.task.id} archived=${td.task.archived} showArchived=$showArchived isArchived=$isArchived');

    return DraggableItemWrapper(
      itemId: td.task.id,
      child: Column(
       crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          isArchived
              ? Opacity(
                  opacity: 0.5,
                  child: ItemCard(
                    item:        td.task,
                    dueDate:     dueDate,
                    tagNames:    tagNames,
                    compact:     context.isMobile,
                    isArchived:  true,
                    customBackgroundColor: overrideColor,
                    onTap:       onTap,
                    onLongPress: onLongPress,
                    onCheckboxChanged: hasSubtasks ? null : (_) => onToggleDone(),
                    onShare:    () => ShareService.shareItem(context, td.task.id),
                  ),
                )
              : ItemCard(
                  item:        td.task,
                  dueDate:     dueDate,
                  tagNames:    tagNames,
                  compact:     context.isMobile,
                  customBackgroundColor: overrideColor,
                  onTap:       onTap,
                  onLongPress: onLongPress,
                  onCheckboxChanged: hasSubtasks ? null : (_) => onToggleDone(),
                  onShare:    () => ShareService.shareItem(context, td.task.id),
                ),
          _TaskProgressBar(
            item:     td.task,
            subtasks: subtasks,
            dueDate:  dueDate,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TASK PROGRESS BAR
// ════════════════════════════════════════════════════════════════

class _TaskProgressBar extends StatelessWidget {
  final Item       item;
  final List<Item> subtasks;
  final DateTime?  dueDate;

  const _TaskProgressBar({
    required this.item,
    required this.subtasks,
    required this.dueDate,
  });

  static const Color _green = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final isDone = item.status == ItemStatus.done;
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);
    final isOverdue = dueDate != null &&
        DateTime(dueDate!.year, dueDate!.month, dueDate!.day).isBefore(today);

    final Color neutralColor = ColorsUI.getBorder(context.brightness);
    final Color errorColor   = context.cError;

    // Υπολογισμός τμημάτων μπάρας
    final List<Widget> segments;

    if (subtasks.isEmpty) {
      // Χωρίς υποεργασίες
      if (isDone) {
        segments = [Expanded(child: Container(color: _green))];
      } else if (isOverdue) {
        segments = [Expanded(child: Container(color: errorColor))];
      } else {
        // Δεν υπάρχει ακόμα πρόοδος → faint neutral για σταθερό ύψος στο grid
        segments = [Expanded(child: Container(color: neutralColor.withValues(alpha: 0.3)))];
      }
    } else {
      // Με υποεργασίες: κάθε υποεργασία = 1/N του συνολικού
      final doneCount   = subtasks.where((s) => s.status == ItemStatus.done).length;
      final undoneCount = subtasks.length - doneCount;

      segments = [
        if (doneCount > 0)
          Expanded(
            flex: doneCount,
            child: Container(color: _green),
          ),
        if (undoneCount > 0)
          Expanded(
            flex: undoneCount,
            child: Container(
              color: isOverdue ? errorColor : neutralColor.withValues(alpha: 0.5),
            ),
          ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 4,
          child: Row(children: segments),
        ),
      ),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.md,
        context.responsiveHPadding, Spacing.xs,
      ),
      child: Text(
        label,
        style: context.labelMd.withColor(color ?? context.cText2),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STATS BAR
// ════════════════════════════════════════════════════════════════

class _StatsBar extends StatelessWidget {
  final List<Item> tasks;
  const _StatsBar({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final total    = tasks.where((t) => !t.archived).length;
    final done     = tasks.where((t) => t.status == ItemStatus.done).length;
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
              value:           progress,
              minHeight:       4,
              backgroundColor: ColorsUI.getBorder(context.brightness),
              valueColor:      AlwaysStoppedAnimation<Color>(context.cPrimary),
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
  final ItemStatus?                statusFilter;
  final ItemPriority?              priorityFilter;
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
          ..._statuses.map((s) => Padding(
            padding: const EdgeInsets.only(right: Spacing.xs),
            child: _StatusChip(
              label:    s.$2,
              selected: statusFilter == s.$1,
              onTap:    () => onStatusTap(s.$1),
            ),
          )),

          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xs, vertical: 6),
            child: VerticalDivider(
                color: ColorsUI.getBorder(context.brightness), width: 1),
          ),

          ..._priorities.map((p) => Padding(
            padding: const EdgeInsets.only(right: Spacing.xs),
            child: GestureDetector(
              onTap: () => onPriorityTap(p),
              child: AnimatedContainer(
                duration: AppDuration.fast,
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm, vertical: Spacing.xs),
                decoration: BoxDecoration(
                  color: priorityFilter == p
                      ? context.priorityColor(p).withValues(alpha: 0.15)
                      : ColorsUI.getSurface(context.brightness),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(
                    color: priorityFilter == p
                        ? context.priorityColor(p)
                        : ColorsUI.getBorder(context.brightness),
                  ),
                ),
                child: PriorityBadge(
                  priority:  p,
                  size:      BadgeSize.small,
                  showIcon:  true,
                  showLabel: true,
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String       label;
  final bool         selected;
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
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm + 2, vertical: Spacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? context.cPrimary.withValues(alpha: 0.12)
              : ColorsUI.getSurface(context.brightness),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: selected
                ? context.cPrimary.withValues(alpha: 0.5)
                : ColorsUI.getBorder(context.brightness),
          ),
        ),
        child: Text(
          label,
          style: context.labelSm
              .withColor(selected ? context.cPrimary : context.cText2),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TASK ACTIONS SHEET
// ════════════════════════════════════════════════════════════════

class _TaskActionsSheet extends StatelessWidget {
  final Item         item;
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
            width:  40,
            height: 4,
            decoration: BoxDecoration(
              color:        context.cBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.xs),
            child: Row(children: [
              Expanded(
                child: Text(item.title ?? 'Χωρίς τίτλο',
                    style:    context.titleMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (item.priority != ItemPriority.none)
                PriorityBadge(priority: item.priority),
            ]),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title:   const Text('Επεξεργασία'),
            onTap:   onEdit,
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
            title:   Text(item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση'),
            onTap:   onArchive,
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: context.cError),
            title:   Text('Διαγραφή', style: TextStyle(color: context.cError)),
            onTap:   onDelete,
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
  final FocusNode             focusNode;
  final ValueChanged<String>  onChanged;

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
          hintText:   'Αναζήτηση εργασιών...',
          hintStyle:  context.bodyMd.withColor(context.cDisabled),
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
          filled:    true,
          fillColor: ColorsUI.getSurface(context.brightness),
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