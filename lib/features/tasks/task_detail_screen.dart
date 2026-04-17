// lib/features/tasks/task_detail_screen.dart
//
// Detail screen εργασίας: τίτλος, status, priority, due date, subtasks, notes.
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
import '../../shared/widgets/widgets.dart';

// ── Local subtasks provider ───────────────────────────────────────

/// Απλοποιημένος provider — επιστρέφει items που έχουν
/// δημιουργηθεί ως subtasks (θα συνδεθούν μέσω RelationRepository)
final _subtasksProvider = FutureProvider.family<List<Item>, int>((ref, parentId) async {
  DebugConfig.db('_subtasksProvider parentId=$parentId');

  // Παίρνουμε όλα τα items
  final itemsAsync = ref.watch(itemsStreamProvider);
  final allItems = itemsAsync.maybeWhen(
    data: (list) => list,
    orElse: () => <Item>[],
  );

  // Φιλτράρουμε μόνο tasks που έχουν parent_id = parentId
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


// ════════════════════════════════════════════════════════════════
// TASK DETAIL SCREEN
// ════════════════════════════════════════════════════════════════

class TaskDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  const TaskDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  Timer? _titleDebounce;
  Timer? _notesDebounce;
  bool  _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    DebugConfig.nav('TaskDetailScreen init id=${widget.itemId}');
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _notesDebounce?.cancel();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Save helpers ─────────────────────────────────────────────

  void _onTitleChanged(String value) {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 600), () {
      _saveTitle(value.trim());
    });
  }

  void _onNotesChanged(String value) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 800), () {
      _saveNotes(value.trim());
    });
  }

  Future<void> _saveTitle(String title) async {
    if (!mounted) return;
    setState(() => _isSaving = true);
    DebugConfig.db('TaskDetail saveTitle id=${widget.itemId} "$title"');
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId, title: title.isEmpty ? null : title);
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  Future<void> _saveNotes(String notes) async {
    DebugConfig.db('TaskDetail saveNotes id=${widget.itemId}');
    await ref.read(propertyNotifierProvider(widget.itemId).notifier)
        .setText('notes', notes.isEmpty ? null : notes);
  }

  Future<void> _flushPendingSaves() async {
    if (_titleDebounce?.isActive == true) {
      _titleDebounce!.cancel();
      await _saveTitle(_titleCtrl.text.trim());
    }
    if (_notesDebounce?.isActive == true) {
      _notesDebounce!.cancel();
      await _saveNotes(_notesCtrl.text.trim());
    }
  }

  Future<void> _save() async {
    // Κάνει flush ό,τι pending auto‑save υπάρχει
    await _flushPendingSaves();

    // Μικρό visual feedback στο AppBar
    if (!mounted) return;
    setState(() => _isSaving = true);

    final title = _titleCtrl.text.trim();
    DebugConfig.db('TaskDetail manualSave id=${widget.itemId} title="$title"');

    // Αν θες, μπορείς εδώ να αναγκάσεις ένα extra updateItem,
    // αλλά επειδή _saveTitle ήδη κάνει update, συνήθως δεν χρειάζεται.

    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  // ── Item actions ─────────────────────────────────────────────

  Future<void> _toggleDone(Item item) async {
    final newStatus = item.status == ItemStatus.done
        ? ItemStatus.active
        : ItemStatus.done;
    DebugConfig.db('TaskDetail toggleDone id=${item.id} → ${newStatus.name}');
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(item.id, status: newStatus);
  }

  Future<void> _setStatus(ItemStatus status) async {
    DebugConfig.db('TaskDetail setStatus id=${widget.itemId} ${status.name}');
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId, status: status);
  }

  Future<void> _setPriority(ItemPriority priority) async {
    DebugConfig.db('TaskDetail setPriority id=${widget.itemId} ${priority.name}');
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId, priority: priority);
  }

  Future<void> _setDueDate(DateTime? date) async {
    DebugConfig.db('TaskDetail setDueDate id=${widget.itemId} $date');
    await ref.read(propertyNotifierProvider(widget.itemId).notifier)
        .setDate('due_date', date);
  }

  Future<void> _pickDueDate(BuildContext context, DateTime? current) async {
    final now  = DateTime.now();
    final init = current ?? now;
    final picked = await showDatePicker(
      context:     context,
      initialDate: init.isBefore(now) ? now : init,
      firstDate:   DateTime(now.year - 1),
      lastDate:    DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    await _setDueDate(picked);
  }

  Future<void> _deleteTask(BuildContext context, Item item) async {
    final future = ConfirmDialog.delete(
        context, title: 'Διαγραφή εργασίας;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('TaskDetail delete id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.of(context).pop();
  }

  // ── Pin / Favorite ───────────────────────────────────────────

  Future<void> _togglePin(Item item) async {
    DebugConfig.provider('TaskDetail togglePin id=${item.id}');
    await ref
        .read(itemNotifierProvider.notifier)
        .togglePin(item.id, item.pinned);
  }

  Future<void> _toggleFav(Item item) async {
    DebugConfig.provider('TaskDetail toggleFav id=${item.id}');
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleFavorite(item.id, item.favorite);
  }

  // ── Build ────────────────────────────────────────────────────


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

        // Αρχικοποίηση τίτλου ΜΟΝΟ αν ο controller είναι άδειος
        if (_titleCtrl.text.isEmpty && (item.title ?? '').isNotEmpty) {
          _titleCtrl.text = item.title ?? '';
          _titleCtrl.selection = TextSelection.collapsed(
            offset: _titleCtrl.text.length,
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;

            final nav   = Navigator.of(context); // cache πριν await
            // final title = _titleCtrl.text.trim();

            // Φέρνουμε τα τελευταία props για να δούμε αν υπάρχει “περιεχόμενο”
            final props = ref.read(itemPropertiesProvider(widget.itemId)).valueOrNull ?? [];
            final notes = props.where((p) => p.key == 'notes')
                .firstOrNull?.value ?? '';
            final due   = props.where((p) => p.key == 'due_date')
                .firstOrNull?.dateValue;

            final hasNotes    = notes.trim().isNotEmpty;
            final hasDueDate  = due != null;
            final hasPriority = item.priority != ItemPriority.none;
            final hasNonActiveStatus = item.status != ItemStatus.active;

            // “Άδειο” σημαίνει:
            // - μπορεί να έχει ή να μην έχει τίτλο,
            // - αλλά ΔΕΝ έχει notes, due date, priority, ούτε αλλαγμένο status.
            final isEffectivelyEmpty =
                !hasNotes &&
                    !hasDueDate &&
                    !hasPriority &&
                    !hasNonActiveStatus;

            if (isEffectivelyEmpty) {
              DebugConfig.db(
                  'TaskDetail auto-delete empty/only-title task id=${widget.itemId}');
              await ref
                  .read(itemNotifierProvider.notifier)
                  .deleteItem(widget.itemId);
              if (!nav.mounted) return;
              nav.pop();
              return;
            }

            // Αν ΔΕΝ είναι “άδειο”, αποθηκεύουμε ό,τι pending υπάρχει και γυρνάμε πίσω
            await _flushPendingSaves();
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

  // ── Mobile — single column ───────────────────────────────────

  Widget _buildMobile(BuildContext context, Item item) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, item),
      body: _TaskBody(
        item:           item,
        titleCtrl:      _titleCtrl,
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

  // ── Tablet/Desktop — two panel ───────────────────────────────

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
          VerticalDivider(
              width: 1, color: ColorsUI.getBorder(context.brightness)),
          Expanded(
            child: _TaskBody(
              item:           item,
              titleCtrl:      _titleCtrl,
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

  // ── AppBar ───────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context, Item item) {
    return AppBar(
      backgroundColor: context.cBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: _isSaving
          ? Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.cText2,
          ),
        ),
        const SizedBox(width: Spacing.xs),
        Text(
          'Αποθήκευση...',
          style: context.bodySm.withColor(context.cText2),
        ),
      ])
          : null,
      actions: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Save
              IconButton(
                icon: Icon(Icons.save_rounded, color: context.cPrimary),
                tooltip: 'Αποθήκευση',
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await _save();
                  if (!mounted) return;
                  nav.pop();
                },
              ),
              // Favorite
              IconButton(
                icon: Icon(
                  item.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                ),
                color: item.favorite
                    ? ColorsUI.getWarning(context.brightness)
                    : context.cText2,
                tooltip: item.favorite ? 'Αφαίρεση από αγαπημένα' : 'Αγαπημένο',
                onPressed: () => _toggleFav(item),
              ),
              // Pin
              IconButton(
                icon: Icon(
                  item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                ),
                color: item.pinned ? context.cPrimary : context.cText2,
                tooltip: item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
                onPressed: () => _togglePin(item),
              ),
              // Archive
              IconButton(
                icon: Icon(
                  item.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
                ),
                color: context.cText2,
                tooltip: item.archived ? 'Επαναφορά από αρχείο' : 'Αρχειοθέτηση',
                onPressed: () async {
                  DebugConfig.provider('TaskDetail toggleArchive id=${item.id}');
                  await ref
                      .read(itemNotifierProvider.notifier)
                      .toggleArchive(item.id, item.archived);
                },
              ),
              // Delete
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: context.cError),
                onPressed: () => _deleteTask(context, item),
                tooltip: 'Διαγραφή',
              ),
            ],
          ),
        ),
      ],
    );
  }


  // ── Fallbacks ────────────────────────────────────────────────

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
      icon:  Icons.task_alt,
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
    final notesVal   = props.where((p) => p.key == 'notes')
        .firstOrNull?.value ?? '';
    final tagsAsync  = ref.watch(itemTagsProvider(item.id));
    final tags       = tagsAsync.valueOrNull ?? [];

    // Sync notes controller
    if (!notesCtrl.selection.isValid && notesCtrl.text != notesVal) {
      notesCtrl.text = notesVal;
    }

    final isDone = item.status == ItemStatus.done;

    return CustomScrollView(
      slivers: [
        // ── Checkbox + Title ─────────────────────────────────────
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
                    controller: titleCtrl,
                    onChanged:  onTitleChange,
                    style: context.h2.copyWith(
                      fontWeight:     FontWeight.w600,
                      decoration:     isDone ? TextDecoration.lineThrough : null,
                      decorationColor: context.cDisabled,
                      color: isDone ? context.cDisabled : context.cText,
                    ),
                    maxLines:  null,
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

        // ── Properties (mobile) ──────────────────────────────────
        if (!hideProperties)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.responsiveHPadding),
              child: _PropertiesPanel(
                item:          item,
                onSetStatus:   onSetStatus,
                onSetPriority: onSetPriority,
                onPickDueDate: onPickDueDate,
                onClearDue:    onClearDue,
              ),
            ),
          ),

        // ── Tags ─────────────────────────────────────────────────
        if (tags.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.responsiveHPadding,
                vertical:   Spacing.sm,
              ),
              child: TagChipList.readOnly(
                tagNames:  tags.map((t) => t.name).toList(),
                tagColors: tags.map((t) => t.color).toList(),
              ),
            ),
          ),

        // ── Divider ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.responsiveHPadding),
            child: Divider(
                color: ColorsUI.getBorder(context.brightness)),
          ),
        ),

        // ── Notes ────────────────────────────────────────────────
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
                  Text('Σημειώσεις',
                      style: context.labelMd.withColor(context.cText2)),
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

        // ── Divider ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.responsiveHPadding),
            child: Divider(
                color: ColorsUI.getBorder(context.brightness)),
          ),
        ),

        // ── Subtasks ─────────────────────────────────────────────
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
            color: isDone
                ? context.cPrimary
                : ColorsUI.getBorder(context.brightness),
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
    final dueDate    = propsAsync.valueOrNull
        ?.where((p) => p.key == 'due_date').firstOrNull?.dateValue;

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

// ── Prop row ──────────────────────────────────────────────────────

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
          SizedBox(
            width: 110,
            child: Text(label,
                style: context.bodyMd.withColor(context.cText2)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Status selector ───────────────────────────────────────────────

class _StatusSelector extends StatelessWidget {
  final ItemStatus current;
  final ValueChanged<ItemStatus> onSelect;
  const _StatusSelector({required this.current, required this.onSelect});

  static const _opts = [
    (ItemStatus.active,     'Ενεργή',         Icons.radio_button_unchecked_rounded),
    (ItemStatus.inProgress, 'Σε εξέλιξη',     Icons.timelapse_rounded),
    (ItemStatus.done,       'Ολοκληρώθηκε',   Icons.check_circle_rounded),
    (ItemStatus.cancelled,  'Ακυρώθηκε',      Icons.cancel_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final opt = _opts.firstWhere((o) => o.$1 == current,
        orElse: () => _opts.first);
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
    DebugConfig.nav('StatusSelector: open picker');
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
            leading: Icon(o.$3,
                color: o.$1 == current ? context.cPrimary : context.cText2),
            title: Text(o.$2, style: context.bodyMd.copyWith(
              fontWeight: o.$1 == current ? FontWeight.w600 : FontWeight.normal,
            )),
            trailing: o.$1 == current
                ? Icon(Icons.check_rounded, color: context.cPrimary)
                : null,
            onTap: () { Navigator.pop(context); onSelect(o.$1); },
          )),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}

// ── Priority selector ─────────────────────────────────────────────

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
    DebugConfig.nav('PrioritySelector: open picker');
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
                : Icon(PriorityBadge.iconFor(p),
                color: context.priorityColor(p)),
            title: p == ItemPriority.none
                ? Text('Καμία', style: context.bodyMd)
                : PriorityBadge(priority: p),
            trailing: p == current
                ? Icon(Icons.check_rounded, color: context.cPrimary)
                : null,
            onTap: () { Navigator.pop(context); onSelect(p); },
          )),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}

// ── Due date selector ─────────────────────────────────────────────

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
    if (isOverdue)    {labelColor = context.cError;}
    else if (isToday) {labelColor = context.cWarning;}
    else              {labelColor = context.cText;}

    return GestureDetector(
      onTap: onPick,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          date != null ? date!.due : 'Χωρίς προθεσμία',
          style: context.bodyMd.withColor(
              date != null ? labelColor : context.cText2),
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
  final _ctrl   = TextEditingController();
  bool _adding  = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addSubtask(String title) async {
    if (title.trim().isEmpty) return;
    DebugConfig.db('SubtasksSection add "$title" parent=${widget.parentId}');

    // Δημιουργούμε την υποεργασία
    final newItem = await ref.read(itemNotifierProvider.notifier)
        .create(type: ItemType.task, title: title.trim());

    if (newItem != null) {
      // Αποθηκεύουμε το parent_id ως property
      await ref.read(propertyNotifierProvider(newItem.id).notifier)
          .setText('parent_id', widget.parentId.toString());
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
        padding: EdgeInsets.fromLTRB(
          context.responsiveHPadding, Spacing.sm,
          context.responsiveHPadding, Spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.checklist_rounded,
                      size: 16, color: context.cText2),
                  const SizedBox(width: Spacing.xs),
                  Text('Υποεργασίες',
                      style: context.labelMd.withColor(context.cText2)),
                ]),
                GestureDetector(
                  onTap: () => setState(() => _adding = !_adding),
                  child: Icon(
                    _adding ? Icons.close_rounded : Icons.add_rounded,
                    size: 20, color: context.cPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: Spacing.sm),

            // ── Add input ─────────────────────────────────────────
            if (_adding) ...[
              TextField(
                controller: _ctrl,
                autofocus:  true,
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.sm),
                ),
              ),
              const SizedBox(height: Spacing.sm),
            ],

            // ── List ─────────────────────────────────────────────
            subtasksAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data: (subtasks) => subtasks.isEmpty
                  ? Text('Δεν υπάρχουν υποεργασίες',
                  style: context.bodySm.withColor(context.cDisabled))
                  : Column(
                children: subtasks.map((s) =>
                    _SubtaskTile(
                      task:     s,
                      onToggle: () async {
                        final next = s.status == ItemStatus.done
                            ? ItemStatus.active
                            : ItemStatus.done;
                        await ref.read(itemNotifierProvider.notifier)
                            .updateItem(s.id, status: next);
                        ref.invalidate(
                            _subtasksProvider(widget.parentId));
                      },
                    ),
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subtask tile ──────────────────────────────────────────────────

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
                color: isDone
                    ? context.cPrimary
                    : ColorsUI.getBorder(context.brightness),
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