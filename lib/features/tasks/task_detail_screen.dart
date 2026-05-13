// lib/features/tasks/task_detail_screen.dart
//
// Detail screen εργασίας: τίτλος, status, priority, due date, subtasks, notes.
// ✅ Responsive: single col mobile / two-panel tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
// ✅ Reminders: μόνο από εικονίδιο AppBar
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';

// ── Local subtasks provider ───────────────────────────────────────

final _subtasksProvider = StreamProvider.family<List<Item>, int>((ref, parentId) async* {
  DebugConfig.db('_subtasksProvider parentId=$parentId');

  yield* ref.watch(itemsStreamProvider.stream).asyncMap((allItems) async {
    final subtasks = <Item>[];
    for (final item in allItems) {
      if (item.type != ItemType.task) continue;
      final props = await ref.read(itemPropertiesProvider(item.id).future);
      final parentIdStr = props.where((p) => p.key == 'parent_id').firstOrNull?.value;
      if (parentIdStr != null && int.tryParse(parentIdStr) == parentId) {
        subtasks.add(item);
      }
    }
    DebugConfig.db('_subtasksProvider found ${subtasks.length} subtasks');
    return subtasks;
  });
});

// ════════════════════════════════════════════════════════════════
// TASK DETAIL SCREEN
// ════════════════════════════════════════════════════════════════

class TaskDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  final bool isNew;
  const TaskDetailScreen({super.key, required this.itemId, this.isNew = false});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late final FocusNode _titleFocusNode;
  Timer? _notesDebounce;
  bool  _isSaving = false;
  bool  _isEditingTitle = false;
  String _lastSavedTitle = '';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _titleFocusNode = FocusNode();

    _titleFocusNode.addListener(() {
      if (!_titleFocusNode.hasFocus) {
        _isEditingTitle = false;
        _saveTitle(_titleCtrl.text.trim());
      } else {
        _isEditingTitle = true;
      }
    });

    DebugConfig.nav('TaskDetailScreen init id=${widget.itemId}');
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    _isEditingTitle = true;
  }

  void _onNotesChanged(String value) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 800), () {
      _saveNotes(value.trim());
    });
  }

  Future<void> _saveTitle(String title) async {
    if (!mounted) return;
    if (title == _lastSavedTitle) return;

    setState(() => _isSaving = true);
    DebugConfig.db('TaskDetail saveTitle id=${widget.itemId} "$title"');
    try {
      await ref.read(itemNotifierProvider.notifier)
          .updateItem(widget.itemId, title: title.isEmpty ? null : title);
      _lastSavedTitle = title;
    } catch (e) {
      DebugConfig.error('TaskDetail _saveTitle', e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveOrDelete() async {
    final title = _titleCtrl.text.trim();

    if (title.isEmpty) {
      if (widget.isNew) {
        DebugConfig.db('TaskDetail delete empty new task id=${widget.itemId}');
        try {
          await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
        } catch (e) {
          DebugConfig.error('TaskDetail _saveOrDelete delete', e);
        }
      }
      return;
    }

    // Έχει τίτλο → flush όλων των εκκρεμών saves
    try {
      await _flushPendingSaves();
    } catch (e) {
      DebugConfig.error('TaskDetail _saveOrDelete', e);
    }
  }

  Future<void> _saveNotes(String notes) async {
    DebugConfig.db('TaskDetail saveNotes id=${widget.itemId}');
    try {
      await ref.read(propertyNotifierProvider(widget.itemId).notifier)
          .setText('notes', notes.isEmpty ? null : notes);
    } catch (e) {
      DebugConfig.error('TaskDetail _saveNotes', e);
    }
  }

  Future<void> _flushPendingSaves() async {
    await _saveTitle(_titleCtrl.text.trim());
    if (_notesDebounce?.isActive == true) {
      _notesDebounce!.cancel();
      await _saveNotes(_notesCtrl.text.trim());
    }
  }

  Future<void> _toggleDone(Item item) async {
    final newStatus = item.status == ItemStatus.done ? ItemStatus.active : ItemStatus.done;
    DebugConfig.db('TaskDetail toggleDone id=${item.id} → ${newStatus.name}');
    await ref.read(itemNotifierProvider.notifier).updateItem(item.id, status: newStatus);
  }

  Future<void> _setStatus(ItemStatus status) async {
    DebugConfig.db('TaskDetail setStatus id=${widget.itemId} ${status.name}');
    await ref.read(itemNotifierProvider.notifier).updateItem(widget.itemId, status: status);
  }

  Future<void> _setPriority(ItemPriority priority) async {
    DebugConfig.db('TaskDetail setPriority id=${widget.itemId} ${priority.name}');
    await ref.read(itemNotifierProvider.notifier).updateItem(widget.itemId, priority: priority);
  }

  Future<void> _setDueDate(DateTime? date) async {
    DebugConfig.db('TaskDetail setDueDate id=${widget.itemId} $date');
    await ref.read(propertyNotifierProvider(widget.itemId).notifier).setDate('due_date', date);
  }

  Future<void> _pickDueDate(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final init = current ?? now;
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('el', 'GR'),
      initialDate: init.isBefore(now) ? now : init,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    await _setDueDate(picked);
  }

  Future<void> _deleteTask(BuildContext context, Item item) async {
    final future = ConfirmDialog.delete(context, title: 'Διαγραφή εργασίας;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('TaskDetail delete id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _togglePin(Item item) async {
    DebugConfig.provider('TaskDetail togglePin id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).togglePin(item.id, item.pinned);
  }

  Future<void> _toggleFav(Item item) async {
    DebugConfig.provider('TaskDetail toggleFav id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).toggleFavorite(item.id, item.favorite);
  }

  // --- Εμφάνιση bottom sheet με ReminderSection ---
  Future<void> _showReminderDialog() async {
    final title = _titleCtrl.text.trim().isEmpty ? 'Εργασία' : _titleCtrl.text.trim();
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
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('TaskDetailScreen build id=${widget.itemId}');
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) {
        DebugConfig.error('TaskDetail load failed', e);
        return _buildError();
      },
      data: (item) {
        if (item == null) return _buildNotFound();

        if (_lastSavedTitle.isEmpty && (item.title ?? '').isNotEmpty) {
          _lastSavedTitle = item.title ?? '';
        }
        if (!_isEditingTitle && _titleCtrl.text != (item.title ?? '')) {
          final cursorAtEnd = _titleCtrl.selection.baseOffset == _titleCtrl.text.length;
          _titleCtrl.text = item.title ?? '';
          if (cursorAtEnd) {
            _titleCtrl.selection = TextSelection.collapsed(offset: _titleCtrl.text.length);
          }
        }

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

  Widget _buildMobile(BuildContext context, Item item) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, item),
      body: _TaskBody(
        item:           item,
        titleCtrl:      _titleCtrl,
        titleFocusNode: _titleFocusNode,
        notesCtrl:      _notesCtrl,
        isSaving:       _isSaving,
        onTitleChange:  _onTitleChanged,
        onNotesChange:  _onNotesChanged,
        onToggleDone:   () => _toggleDone(item),
        onSetStatus:    _setStatus,
        onSetPriority:  _setPriority,
        onPickDueDate:  (cur) => _pickDueDate(context, cur),
        onClearDue:     () => _setDueDate(null),
        hideProperties: false,
      ),
    );
  }

  Widget _buildTablet(BuildContext context, Item item) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, item),
      body: Row(
        children: [
          SizedBox(
            width: context.isDesktop ? 300 : 260,
            child: Container(
              color: ColorsUI.getSurface(context.brightness),
              child: _PropertiesPanel(
                item:          item,
                onSetStatus:   _setStatus,
                onSetPriority: _setPriority,
                onPickDueDate: (cur) => _pickDueDate(context, cur),
                onClearDue:    () => _setDueDate(null),
              ),
            ),
          ),
          VerticalDivider(width: 1, color: ColorsUI.getBorder(context.brightness)),
          Expanded(
            child: _TaskBody(
              item:           item,
              titleCtrl:      _titleCtrl,
              titleFocusNode: _titleFocusNode,
              notesCtrl:      _notesCtrl,
              isSaving:       _isSaving,
              onTitleChange:  _onTitleChanged,
              onNotesChange:  _onNotesChanged,
              onToggleDone:   () => _toggleDone(item),
              onSetStatus:    _setStatus,
              onSetPriority:  _setPriority,
              onPickDueDate:  (cur) => _pickDueDate(context, cur),
              onClearDue:     () => _setDueDate(null),
              hideProperties: true,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, Item item) {
    return AppBar(
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
        // Save
        IconButton(
          visualDensity: VisualDensity.compact,
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
            _notesDebounce?.cancel();
            final nav = Navigator.of(context);
            setState(() => _isSaving = true);
            try {
              await _flushPendingSaves();
              if (mounted) nav.pop();
            } catch (e) {
              DebugConfig.error('TaskDetail save button', e);
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
        // Reminder
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.notifications_none_rounded, color: context.cText2, size: 20),
          onPressed: _showReminderDialog,
          tooltip: 'Υπενθύμιση',
        ),
        // Favorite
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            item.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: item.favorite ? ColorsUI.getWarning(context.brightness) : context.cText2,
            size: 20,
          ),
          tooltip: item.favorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
          onPressed: () => _toggleFav(item),
        ),
        // Pin
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: item.pinned ? context.cPrimary : context.cText2,
            size: 20,
          ),
          tooltip: item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
          onPressed: () => _togglePin(item),
        ),
        // Archive
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            item.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
            color: context.cText2,
            size: 20,
          ),
          tooltip: item.archived ? 'Επαναφορά από αρχείο' : 'Αρχειοθέτηση',
          onPressed: () async {
            await ref.read(itemNotifierProvider.notifier).toggleArchive(item.id, item.archived);
          },
        ),
        // Delete
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.delete_outline_rounded, color: context.cError, size: 20),
          onPressed: () => _deleteTask(context, item),
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
    body: EmptyState.error(onRetry: () => ref.invalidate(itemStreamProvider(widget.itemId))),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const EmptyState(
      icon: Icons.task_alt,
      title: 'Η εργασία δεν βρέθηκε',
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// TASK BODY
// ════════════════════════════════════════════════════════════════

class _TaskBody extends ConsumerWidget {
  final Item item;
  final TextEditingController titleCtrl;
  final FocusNode titleFocusNode;
  final TextEditingController notesCtrl;
  final bool isSaving;
  final ValueChanged<String>       onTitleChange;
  final ValueChanged<String>       onNotesChange;
  final VoidCallback               onToggleDone;
  final ValueChanged<ItemStatus>   onSetStatus;
  final ValueChanged<ItemPriority> onSetPriority;
  final ValueChanged<DateTime?>    onPickDueDate;
  final VoidCallback               onClearDue;
  final bool hideProperties;

  const _TaskBody({
    required this.item,
    required this.titleCtrl,
    required this.titleFocusNode,
    required this.notesCtrl,
    required this.isSaving,
    required this.onTitleChange,
    required this.onNotesChange,
    required this.onToggleDone,
    required this.onSetStatus,
    required this.onSetPriority,
    required this.onPickDueDate,
    required this.onClearDue,
    required this.hideProperties,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final props      = propsAsync.valueOrNull ?? [];
    final notesVal   = props.where((p) => p.key == 'notes').firstOrNull?.value ?? '';
    final tagsAsync  = ref.watch(itemTagsProvider(item.id));
    final tags       = tagsAsync.valueOrNull ?? [];

    if (!notesCtrl.selection.isValid && notesCtrl.text != notesVal) {
      notesCtrl.text = notesVal;
    }

    final isDone = item.status == ItemStatus.done;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.lg,
              context.responsiveHPadding, Spacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: Spacing.md),
                  child: _DoneCheckbox(
                    isDone: isDone,
                    onTap:  onToggleDone,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller:  titleCtrl,
                    focusNode:   titleFocusNode,
                    onChanged:   onTitleChange,
                    style: context.h2.copyWith(
                      fontWeight:      FontWeight.w600,
                      decoration:      isDone ? TextDecoration.lineThrough : null,
                      decorationColor: context.cDisabled,
                      color: isDone ? context.cDisabled : context.cText,
                    ),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText:  'Τίτλος εργασίας...',
                      hintStyle: context.h2.withColor(context.cDisabled),
                      border:    InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (!hideProperties)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
              child: _PropertiesPanel(
                item:          item,
                onSetStatus:   onSetStatus,
                onSetPriority: onSetPriority,
                onPickDueDate: onPickDueDate,
                onClearDue:    onClearDue,
              ),
            ),
          ),

        if (tags.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: Spacing.sm),
              child: TagChipList.readOnly(
                tagNames:  tags.map((t) => t.name).toList(),
                tagColors: tags.map((t) => t.color).toList(),
              ),
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
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.md,
              context.responsiveHPadding, Spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.notes_rounded, size: 16, color: context.cText2),
                  const SizedBox(width: Spacing.xs),
                  Text('Σημειώσεις', style: context.labelMd.withColor(context.cText2)),
                ]),
                const SizedBox(height: Spacing.sm),
                TextField(
                  controller: notesCtrl,
                  onChanged:  onNotesChange,
                  style:      context.bodyMd,
                  maxLines:   null,
                  minLines:   3,
                  decoration: InputDecoration(
                    hintText:  'Πρόσθεσε σημειώσεις...',
                    hintStyle: context.bodyMd.withColor(context.cDisabled),
                    border:    InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
            child: Divider(color: ColorsUI.getBorder(context.brightness)),
          ),
        ),

        _SubtasksSection(parentId: item.id),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// DONE CHECKBOX
// ════════════════════════════════════════════════════════════════

class _DoneCheckbox extends StatelessWidget {
  final bool isDone;
  final VoidCallback onTap;
  const _DoneCheckbox({required this.isDone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.normal,
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: isDone ? context.cPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isDone ? context.cPrimary : ColorsUI.getBorder(context.brightness),
            width: 2,
          ),
        ),
        child: isDone
            ? Icon(Icons.check_rounded, size: 16,
            color: ColorsUI.getAccessibleTextColor(context.cPrimary))
            : null,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROPERTIES PANEL
// ════════════════════════════════════════════════════════════════

class _PropertiesPanel extends ConsumerWidget {
  final Item item;
  final ValueChanged<ItemStatus>   onSetStatus;
  final ValueChanged<ItemPriority> onSetPriority;
  final ValueChanged<DateTime?>    onPickDueDate;
  final VoidCallback               onClearDue;

  const _PropertiesPanel({
    required this.item,
    required this.onSetStatus,
    required this.onSetPriority,
    required this.onPickDueDate,
    required this.onClearDue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final dueDate    = propsAsync.valueOrNull?.where((p) => p.key == 'due_date').firstOrNull?.dateValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.sm),

        _PropRow(
          icon:  Icons.flag_outlined,
          label: 'Κατάσταση',
          child: _StatusSelector(
            current:  item.status,
            onSelect: onSetStatus,
          ),
        ),

        _PropRow(
          icon:  Icons.priority_high_rounded,
          label: 'Προτεραιότητα',
          child: _PrioritySelector(
            current:  item.priority,
            onSelect: onSetPriority,
          ),
        ),

        _PropRow(
          icon:  Icons.calendar_today_rounded,
          label: 'Προθεσμία',
          child: _DueDateSelector(
            date:    dueDate,
            onPick:  () => onPickDueDate(dueDate),
            onClear: dueDate != null ? onClearDue : null,
          ),
        ),

        const SizedBox(height: Spacing.sm),
      ],
    );
  }
}

class _PropRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Widget   child;
  const _PropRow({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.cText2),
          const SizedBox(width: Spacing.sm),
          SizedBox(width: 110, child: Text(label, style: context.bodyMd.withColor(context.cText2))),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  final ItemStatus current;
  final ValueChanged<ItemStatus> onSelect;
  const _StatusSelector({required this.current, required this.onSelect});

  static const _opts = [
    (ItemStatus.active,     'Ενεργή',       Icons.radio_button_unchecked_rounded),
    (ItemStatus.inProgress, 'Σε εξέλιξη',   Icons.timelapse_rounded),
    (ItemStatus.done,       'Ολοκληρώθηκε', Icons.check_circle_rounded),
    (ItemStatus.cancelled,  'Ακυρώθηκε',    Icons.cancel_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final opt = _opts.firstWhere((o) => o.$1 == current, orElse: () => _opts.first);
    return GestureDetector(
      onTap: () => _pick(context),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(opt.$3, size: 16, color: context.cPrimary),
        const SizedBox(width: Spacing.xs),
        Text(opt.$2, style: context.bodyMd),
        const SizedBox(width: 2),
        Icon(Icons.arrow_drop_down_rounded, size: 18, color: context.cText2),
      ]),
    );
  }

  void _pick(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Spacing.sm),
          Text('Κατάσταση', style: context.titleMd),
          const SizedBox(height: Spacing.xs),
          ..._opts.map((o) => ListTile(
            leading: Icon(o.$3, color: o.$1 == current ? context.cPrimary : context.cText2),
            title: Text(o.$2, style: context.bodyMd.copyWith(
              fontWeight: o.$1 == current ? FontWeight.w600 : FontWeight.normal,
            )),
            trailing: o.$1 == current ? Icon(Icons.check_rounded, color: context.cPrimary) : null,
            onTap: () { Navigator.pop(context); onSelect(o.$1); },
          )),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  final ItemPriority current;
  final ValueChanged<ItemPriority> onSelect;
  const _PrioritySelector({required this.current, required this.onSelect});

  static const _opts = [
    ItemPriority.none,
    ItemPriority.low,
    ItemPriority.medium,
    ItemPriority.high,
    ItemPriority.urgent,
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (current == ItemPriority.none)
          Text('Καμία', style: context.bodyMd.withColor(context.cText2))
        else
          PriorityBadge(priority: current, size: BadgeSize.small),
        const SizedBox(width: 2),
        Icon(Icons.arrow_drop_down_rounded, size: 18, color: context.cText2),
      ]),
    );
  }

  void _pick(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Spacing.sm),
          Text('Προτεραιότητα', style: context.titleMd),
          const SizedBox(height: Spacing.xs),
          ..._opts.map((p) => ListTile(
            leading: p == ItemPriority.none
                ? Icon(Icons.remove_rounded, color: context.cText2)
                : Icon(PriorityBadge.iconFor(p), color: context.priorityColor(p)),
            title: p == ItemPriority.none
                ? Text('Καμία', style: context.bodyMd)
                : PriorityBadge(priority: p),
            trailing: p == current ? Icon(Icons.check_rounded, color: context.cPrimary) : null,
            onTap: () { Navigator.pop(context); onSelect(p); },
          )),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}

class _DueDateSelector extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  const _DueDateSelector({required this.date, required this.onPick, this.onClear});

  @override
  Widget build(BuildContext context) {
    final isOverdue = date != null && date!.isOverdue && !date!.isToday;
    final isToday   = date?.isToday ?? false;

    final Color labelColor;
    if (isOverdue)    { labelColor = context.cError; }
    else if (isToday) { labelColor = context.cWarning; }
    else              { labelColor = context.cText; }

    return GestureDetector(
      onTap: onPick,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          date != null ? date!.due : 'Χωρίς προθεσμία',
          style: context.bodyMd.withColor(date != null ? labelColor : context.cText2),
        ),
        const SizedBox(width: Spacing.xs),
        if (date != null && onClear != null)
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close_rounded, size: 16, color: context.cText2),
          )
        else
          Icon(Icons.add_rounded, size: 16, color: context.cText2),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SUBTASKS SECTION
// ════════════════════════════════════════════════════════════════

class _SubtasksSection extends ConsumerStatefulWidget {
  final int parentId;
  const _SubtasksSection({required this.parentId});

  @override
  ConsumerState<_SubtasksSection> createState() => _SubtasksSectionState();
}

class _SubtasksSectionState extends ConsumerState<_SubtasksSection> {
  final _ctrl  = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addSubtask(String title) async {
    if (title.trim().isEmpty) return;
    DebugConfig.db('SubtasksSection add "$title" parent=${widget.parentId}');

    final newItem = await ref.read(itemNotifierProvider.notifier).create(type: ItemType.task, title: title.trim());
    if (newItem != null) {
      await ref.read(propertyNotifierProvider(newItem.id).notifier).setText('parent_id', widget.parentId.toString());
    }

    _ctrl.clear();
    if (mounted) setState(() => _adding = false);
    ref.invalidate(_subtasksProvider(widget.parentId));
  }

  @override
  Widget build(BuildContext context) {
    final subtasksAsync = ref.watch(_subtasksProvider(widget.parentId));

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.sm, context.responsiveHPadding, Spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.checklist_rounded, size: 16, color: context.cText2),
                  const SizedBox(width: Spacing.xs),
                  Text('Υποεργασίες', style: context.labelMd.withColor(context.cText2)),
                ]),
                GestureDetector(
                  onTap: () => setState(() => _adding = !_adding),
                  child: Icon(_adding ? Icons.close_rounded : Icons.add_rounded, size: 20, color: context.cPrimary),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            if (_adding) ...[
              TextField(
                controller:  _ctrl,
                autofocus:   true,
                onSubmitted: _addSubtask,
                style:       context.bodyMd,
                decoration: InputDecoration(
                  hintText:  'Νέα υποεργασία...',
                  hintStyle: context.bodyMd.withColor(context.cDisabled),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: () => _addSubtask(_ctrl.text),
                  ),
                  filled:    true,
                  fillColor: ColorsUI.getSurface(context.brightness),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.inputBR,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                ),
              ),
              const SizedBox(height: Spacing.sm),
            ],
            subtasksAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data: (subtasks) => subtasks.isEmpty
                  ? Text('Δεν υπάρχουν υποεργασίες', style: context.bodySm.withColor(context.cDisabled))
                  : Column(
                children: subtasks.map((s) => _SubtaskTile(
                  task:     s,
                  onToggle: () async {
                    final next = s.status == ItemStatus.done ? ItemStatus.active : ItemStatus.done;
                    await ref.read(itemNotifierProvider.notifier).updateItem(s.id, status: next);
                    ref.invalidate(_subtasksProvider(widget.parentId));
                  },
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtaskTile extends StatelessWidget {
  final Item task;
  final VoidCallback onToggle;
  const _SubtaskTile({required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == ItemStatus.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(children: [
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: isDone ? context.cPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: isDone ? context.cPrimary : ColorsUI.getBorder(context.brightness),
                width: 2,
              ),
            ),
            child: isDone
                ? Icon(Icons.check_rounded, size: 13,
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
          ),
        ),
      ]),
    );
  }
}