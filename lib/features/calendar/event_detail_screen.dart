// lib/features/calendar/event_detail_screen.dart
//
// Detail screen συμβάντος: τίτλος, ημερομηνία, ώρα, τοποθεσία, υπενθύμιση.
// ✅ Favorite toggle στο AppBar
// ✅ Responsive: single col mobile / two-panel tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
// ✅ Reminders: μόνο από εικονίδιο AppBar (όχι inline)
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../helpers/item_color_helper.dart';
import '../../shared/widgets/widgets.dart';
import '../../services/reminder_scheduler.dart';
import '../settings/settings_colors.dart';
import 'event_properties_panel.dart';
import 'span_utils.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  final bool isNew;

  const EventDetailScreen({
    super.key,
    required this.itemId,
    this.isNew = false,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with DetailScreenMixin<EventDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _locationCtrl;
  late final FocusNode _titleFocusNode;
  Timer? _locationDebounce;
  bool _isSaving = false;
  bool _isSavingTitle = false;
  bool _isEditingTitle = false;
  String _lastSavedTitle = '';
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _isArchived = false;

  @override
  TextEditingController get titleCtrl => _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(() {
      if (!_titleFocusNode.hasFocus) {
        _isEditingTitle = false;
        _saveTitle(_titleCtrl.text.trim());
      } else {
        _isEditingTitle = true;
      }
    });
    initScreen(itemId: widget.itemId, isNew: widget.isNew);
  }

  @override
  void dispose() {
    _locationDebounce?.cancel();
    disposeScreen();
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _onTitleChanged(String v) {
    _isEditingTitle = true;
  }

  void _onLocationChanged(String v) {
    _locationDebounce?.cancel();

    _locationDebounce = Timer(
      AppDuration.debounceTitle,
      () async {
        await _saveLocation(v.trim());
      },
    );
  }

  Future<void> _saveTitle(String title) async {
    if (!mounted) return;

    // 🔥 NEW: block parallel saves
    if (_isSavingTitle) {
      DebugConfig.db('EventDetail saveTitle SKIPPED (in-flight) pending="$title"');
      return;
    }

    // 🔥 NEW: avoid duplicate writes
    if (title == _lastSavedTitle) {
      DebugConfig.db('EventDetail saveTitle SKIPPED (duplicate) title="$title"');
      return;
    }

    _isSavingTitle = true;
    setState(() => _isSaving = true);

    DebugConfig.db('EventDetail saveTitle id=${widget.itemId} "$title"');

    try {
      await ref
          .read(itemNotifierProvider.notifier)
          .updateItem(widget.itemId, title: title.isEmpty ? null : title);

      _lastSavedTitle = title;
    } catch (e) {
      DebugConfig.error('EventDetail saveTitle', e);
    } finally {
      _isSavingTitle = false;
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveLocation(String location) async {
    DebugConfig.db('EventDetail saveLocation id=${widget.itemId}');
    try {
      await ref
          .read(propertyNotifierProvider(widget.itemId).notifier)
          .setText('location', location.isEmpty ? null : location);
    } catch (e) {
      DebugConfig.error('EventDetail _saveLocation', e);
    }
  }

  Future<void> _saveNotes(String notes) async {
    DebugConfig.db('EventDetail saveNotes id=${widget.itemId}');
    try {
      await ref
          .read(propertyNotifierProvider(widget.itemId).notifier)
          .setText('notes', notes.isEmpty ? null : notes);
    } catch (e) {
      DebugConfig.error('EventDetail _saveNotes', e);
    }
  }

  Future<void> _flushSaves() async {
    await _saveTitle(_titleCtrl.text.trim());
    await _saveLocation(_locationCtrl.text.trim());
  }

  Future<void> _toggleFavorite() async {
    DebugConfig.provider('EventDetail toggleFavorite id=${widget.itemId}');

    await ref
        .read(itemNotifierProvider.notifier)
        .toggleFavorite(widget.itemId, _isFavorite);
  }

  Future<void> _togglePinned() async {
    DebugConfig.provider('EventDetail togglePinned id=${widget.itemId}');

    await ref
        .read(itemNotifierProvider.notifier)
        .togglePin(widget.itemId, _isPinned);
  }

  /// Ενιαία λογική για κουμπί Save και back arrow.
  /// Flush των debounce timers και αποθήκευση — χωρίς validation, χωρίς navigation.
  /// Χρησιμοποιείται από _save() και _onPopInvoked() (auto-save on back).
  Future<void> _saveData() async {
    _locationDebounce?.cancel();
    await _flushSaves();
  }

  /// Save button: validation + _saveData() + pop.
  Future<void> _save() async {
    final ok = await executeSave(() => _saveData());
    if (ok && mounted) safePop();
  }

  /// Back arrow: αν κενός τίτλος → delete μόνο αν isNew, αλλιώς pop.
  /// Αν ΟΚ → auto-save + pop.
  Future<bool> _onPopInvoked() async {
    await executeSaveOrDelete(
      saveFn: _saveData,
      deleteFn: () => ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId),
    );
    return true;
  }

  Future<void> _pickStartTime(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final init = current ?? now;

    // Για γενέθλια και ειδική μέρα επιτρέπουμε παλιές ημερομηνίες
    final item = ref.read(itemStreamProvider(widget.itemId)).valueOrNull;
    // firstDate: παλιές ημερομηνίες και για γενέθλια και για ειδικές.
    final isBirthdayOrSpecial = ItemColorHelper.isBirthdayEvent(item) ||
        ItemColorHelper.isSpecialDayEvent(item);
    final firstDate = isBirthdayOrSpecial
        ? DateTime(AppDateUtils.earliestYear)
        : DateTime(now.year - 1);

    final lastDate = DateTime(now.year + AppDateUtils.pickerLastYears);
    // E41: το SDK απαιτεί firstDate <= initialDate <= lastDate
    // (date_picker.dart:235,239) — ένα παλιό event εκτός εύρους θα έκανε assert.
    final initialDate = init.isBefore(firstDate)
        ? firstDate
        : (init.isAfter(lastDate) ? lastDate : init);

    final date = await showDatePicker(
      context: context,
      locale: const Locale('el', 'GR'),
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return;
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(init),
    );
    if (time == null) return;
    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    DebugConfig.db('EventDetail setStartTime $dt');
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
        .setDate('start_time', dt);

    // Αν είναι γενέθλια ή ειδική ημέρα, ενημέρωσε και την
    // επαναλαμβανόμενη υπενθύμιση με το νέο μήνα/ημέρα
    // Resync ΜΟΝΟ για γενέθλια (αυτόματη ετήσια) — οι ειδικές
    // ρυθμίζονται από την καμπάνα, δεν τις αγγίζουμε (όπως απλά events).
    if (ItemColorHelper.isBirthdayEvent(item)) {
      final newRrule =
          'FREQ=YEARLY;INTERVAL=1;BYMONTH=${date.month};BYMONTHDAY=${date.day}';
      final newTrigger = DateTime(
        date.year, date.month, date.day, dt.hour, dt.minute,
      );
      final existing =
          await ref.read(dbProvider).reminders.getForItem(widget.itemId);
      final existingRoot = existing
          .where((r) =>
              r.rrule?.contains('YEARLY') == true &&
              r.parentReminderId == null)
          .firstOrNull;
      final keptTitle = existingRoot?.title;
      final freshTitle = _titleCtrl.text.trim().isEmpty
          ? 'Συμβάν'
          : _titleCtrl.text.trim();
      if (existingRoot != null) {
        await ReminderScheduler.instance.deleteReminderThread(existingRoot.id);
      }
      await ref.read(dbProvider).reminders.create(
            itemId: widget.itemId,
            triggerAt: newTrigger,
            rrule: newRrule,
            title: keptTitle ?? 'Υπενθύμιση',
            body: freshTitle,
          );
      DebugConfig.notif('EventDetail birthday resync: deleteThread+create m=${date.month} d=${date.day}');
      await ReminderScheduler.instance.refreshRecurringReminders();
    }
  }

  /// E41: λήξη πολυήμερου. `firstDate` = έναρξη + 1 ημέρα (το `end_date` είναι
  /// inclusive)· `lastDate` επεκτείνεται ώστε να μη σκάει το SDK assert όταν
  /// η έναρξη βρίσκεται στο όριο του picker.
  Future<void> _pickEndDate(BuildContext context, DateTime? start) async {
    if (start == null) return;
    final now = DateTime.now();
    final firstDate =
        DateTime(start.year, start.month, start.day + 1);
    var lastDate = DateTime(now.year + AppDateUtils.pickerLastYears);
    if (lastDate.isBefore(firstDate)) lastDate = firstDate;

    final date = await showDatePicker(
      context: context,
      locale: const Locale('el', 'GR'),
      initialDate: firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return;

    DebugConfig.db('EventDetail setEndDate $date');
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
        .setDate(
            PropertyKeys.endDate, DateTime(date.year, date.month, date.day));
  }

  /// E41: χρώμα γραμμής — κοινό `SettingsColorPickerSheet` (pattern
  /// `settings_colors.dart:87-99`: `builder: sheetCtx` + pop με sheet ctx).
  Future<void> _pickSpanColor(BuildContext context) async {
    final props =
        ref.read(itemPropertiesProvider(widget.itemId)).valueOrNull ?? const [];
    final currentHex = spanColorOf(props);

    await showSafeSheet<void>(
      context,
      builder: (sheetCtx) => SettingsColorPickerSheet(
        type: ItemType.event,
        currentHex: currentHex,
        onSelected: (hex) {
          Navigator.pop(sheetCtx);
          _saveSpanColor(hex);
        },
      ),
    );
  }

  Future<void> _saveSpanColor(String? hex) async {
    DebugConfig.db('EventDetail setSpanColor $hex');
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
        .setText(PropertyKeys.spanColor, hex);
  }

  Future<void> _toggleAllDay(bool newValue) async {
    DebugConfig.db('EventDetail allDay=$newValue');
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
        .setText('all_day', newValue.toString());
  }

  Future<void> _delete(BuildContext context) async {
    final future = ConfirmDialog.delete(context, title: 'Διαγραφή συμβάντος;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('EventDetail delete id=${widget.itemId}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: false).pop();
  }

  Future<void> _archive() async {
    await handleArchive(
      context: context,
      ref: ref,
      itemId: widget.itemId,
      isArchived: _isArchived,
      label: ItemLabel.event,
    );
  }

  // --- Υπολογισμός startDateTime για υπενθύμιση ---
  DateTime? _getStartDateTime() {
    final props = ref.read(itemPropertiesProvider(widget.itemId)).valueOrNull;
    final startStr =
        props?.where((p) => p.key == 'start_time').firstOrNull?.value;
    return startStr != null ? DateTime.tryParse(startStr) : null;
  }

  // --- Εμφάνιση bottom sheet με ReminderSection ---
  Future<void> _showReminderDialog() async {
    final startDateTime = _getStartDateTime();
    final title =
        _titleCtrl.text.trim().isEmpty ? 'Συμβάν' : _titleCtrl.text.trim();

    DebugConfig.nav(
        '🔔 EVENT_DETAIL: _showReminderDialog called, startDateTime=$startDateTime, itemId=${widget.itemId}');

    await showReminderSheet(
      context,
      itemId: widget.itemId,
      itemTitle: title,
      defaultStartTime: startDateTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('EventDetailScreen build id=${widget.itemId}');
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) {
        DebugConfig.error('EventDetail load failed', e);
        return _buildError();
      },
      data: (item) {
        if (item == null) return _buildNotFound();

        final itemTitle = item.title ?? '';
        if (_lastSavedTitle.isEmpty && itemTitle.isNotEmpty) {
          _lastSavedTitle = itemTitle;
        }
        if (!_isEditingTitle && _titleCtrl.text != itemTitle) {
          final cursorAtEnd =
              _titleCtrl.selection.baseOffset == _titleCtrl.text.length;
          _titleCtrl.text = itemTitle;
          if (cursorAtEnd) {
            _titleCtrl.selection =
                TextSelection.collapsed(offset: _titleCtrl.text.length);
          }
        }

        if (_isFavorite != item.favorite) _isFavorite = item.favorite;
        if (_isPinned != item.pinned) _isPinned = item.pinned;
        if (_isArchived != item.archived) _isArchived = item.archived;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final canPop = await _onPopInvoked();
            if (context.mounted && canPop)
              {Navigator.of(context, rootNavigator: false).pop();}
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
        appBar: _EventDetailAppBar(
          isSaving: _isSaving,
          isPinned: _isPinned,
          isFavorite: _isFavorite,
          isArchived: _isArchived,
          onSave: _save,
          onReminder: _showReminderDialog,
          onPin: _togglePinned,
          onFavorite: _toggleFavorite,
          onArchive: _archive,
          onDelete: () => _delete(context),
        ),
        body: _EventBody(
          item: item,
          titleCtrl: _titleCtrl,
          locationCtrl: _locationCtrl,
          titleFocusNode: _titleFocusNode,
          isSaving: _isSaving,
          onTitleChange: _onTitleChanged,
          onLocationChange: _onLocationChanged,
          onNotesSaved: _saveNotes,
          onPickStart: (cur) => _pickStartTime(context, cur),
          onPickEnd: (start) => _pickEndDate(context, start),
          onPickSpanColor: () => _pickSpanColor(context),
          onToggleAllDay: _toggleAllDay,
        ),
      );

  Widget _buildTablet(BuildContext context, Item item) => Scaffold(
        backgroundColor: context.cBg,
        appBar: _EventDetailAppBar(
          isSaving: _isSaving,
          isPinned: _isPinned,
          isFavorite: _isFavorite,
          isArchived: _isArchived,
          onSave: _save,
          onReminder: _showReminderDialog,
          onPin: _togglePinned,
          onFavorite: _toggleFavorite,
          onArchive: _archive,
          onDelete: () => _delete(context),
        ),
        body: Row(
          children: [
            SizedBox(
              width: 280,
              child: EventPropertiesPanel(
                item: item,
                onPickStart: (cur) => _pickStartTime(context, cur),
                onPickEnd: (start) => _pickEndDate(context, start),
                onPickSpanColor: () => _pickSpanColor(context),
                onToggleAllDay: _toggleAllDay,
              ),
            ),
            VerticalDivider(
              width: 1,
              color: ColorsUI.getBorder(context.brightness),
            ),
            Expanded(
              child: _EventBody(
                item: item,
                titleCtrl: _titleCtrl,
                locationCtrl: _locationCtrl,
                titleFocusNode: _titleFocusNode,
                isSaving: _isSaving,
                onTitleChange: _onTitleChanged,
                onLocationChange: _onLocationChanged,
                onNotesSaved: _saveNotes,
                onPickStart: (cur) => _pickStartTime(context, cur),
                onPickEnd: (start) => _pickEndDate(context, start),
                onPickSpanColor: () => _pickSpanColor(context),
                onToggleAllDay: _toggleAllDay,
                hideProperties: true,
              ),
            ),
          ],
        ),
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
            icon: Icons.event_busy_rounded, title: 'Το συμβάν δεν βρέθηκε'),
      );
}

// ════════════════════════════════════════════════════════════════
// EVENT BODY (χωρίς ReminderSection)
// ════════════════════════════════════════════════════════════════

class _EventBody extends ConsumerWidget {
  final Item item;
  final TextEditingController titleCtrl;
  final TextEditingController locationCtrl;
  final FocusNode titleFocusNode;
  final bool isSaving;
  final ValueChanged<String> onTitleChange;
  final ValueChanged<String> onLocationChange;
  final ValueChanged<String> onNotesSaved;
  final ValueChanged<DateTime?> onPickStart;
  final ValueChanged<DateTime?> onPickEnd;
  final VoidCallback onPickSpanColor;
  final ValueChanged<bool> onToggleAllDay;
  final bool hideProperties;

  const _EventBody({
    required this.item,
    required this.titleCtrl,
    required this.locationCtrl,
    required this.titleFocusNode,
    required this.isSaving,
    required this.onTitleChange,
    required this.onLocationChange,
    required this.onNotesSaved,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPickSpanColor,
    required this.onToggleAllDay,
    this.hideProperties = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final props = propsAsync.valueOrNull ?? [];
    final location =
        props.where((p) => p.key == 'location').firstOrNull?.value ?? '';
    final notesVal =
        props.where((p) => p.key == 'notes').firstOrNull?.value ?? '';

    if (!locationCtrl.selection.isValid && locationCtrl.text != location) {
      locationCtrl.text = location;
    }

    return CustomScrollView(
      slivers: [
        // Title
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.lg,
                context.responsiveHPadding, Spacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 8, right: Spacing.sm),
                  decoration: BoxDecoration(
                    color: ColorsUI.itemTypeColor(
                        ItemType.event, context.brightness),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: titleCtrl,
                    focusNode: titleFocusNode,
                    onChanged: onTitleChange,
                    style: context.h2.copyWith(fontWeight: FontWeight.w600),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Τίτλος συμβάντος...',
                      hintStyle: context.h2.withColor(context.cDisabled),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Properties (mobile)
        if (!hideProperties)
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
              child: EventPropertiesPanel(
                item: item,
                onPickStart: onPickStart,
                onPickEnd: onPickEnd,
                onPickSpanColor: onPickSpanColor,
                onToggleAllDay: onToggleAllDay,
              ),
            ),
          ),

        // Location
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding,
              Spacing.md,
              context.responsiveHPadding,
              0,
            ),
            child: Divider(color: ColorsUI.getBorder(context.brightness)),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHPadding,
              vertical: Spacing.sm,
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 18, color: context.cText2),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: TextField(
                      controller: locationCtrl,
                      onChanged: onLocationChange,
                      style: context.bodyMd,
                      decoration: InputDecoration(
                        hintText: 'Τοποθεσία...',
                        hintStyle: context.bodyMd.withColor(context.cDisabled),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 🆕 ΜΟΝΙΜΟ ΜΗΝΥΜΑ ΓΙΑ ΓΕΝΕΘΛΙΑ
              if (ItemColorHelper.isBirthdayEvent(item))
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.cSuccess.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.cSuccess.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Είναι Γενέθλια — θα οριστεί αυτόματα ετήσια υπενθύμιση',
                    style: context.bodySm.copyWith(
                      color: context.cSuccess,
                      height: 1.3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ]),
          ),
        ),
        // Σημειώσεις (κοινόχρηστο περιεχόμενο, pattern TaskDetail)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding,
              Spacing.md,
              context.responsiveHPadding,
              Spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notes_rounded,
                        size: 16, color: context.cText2),
                    const SizedBox(width: Spacing.sm),
                    Text('Σημειώσεις',
                        style:
                            context.labelMd.withColor(context.cText2)),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                ContentFieldWidget(
                  initialText: notesVal,
                  hintText: 'Πρόσθεσε σημειώσεις...',
                  onSaved: onNotesSaved,
                  onDeleteEmpty: () => onNotesSaved(''),
                  debounce: AppDuration.debounceTitle,
                ),
                LinkList(text: notesVal),
              ],
            ),
          ),
        ),
        // Συνημμένα (share intent — SPoT AttachmentsStrip)
        AttachmentsStrip(itemId: item.id),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// APP BAR
// ════════════════════════════════════════════════════════════════

class _EventDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final bool isSaving;
  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;

  final VoidCallback onSave;
  final VoidCallback onReminder;
  final VoidCallback onPin;
  final VoidCallback onFavorite;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _EventDetailAppBar({
    required this.isSaving,
    required this.isPinned,
    required this.isFavorite,
    required this.isArchived,
    required this.onSave,
    required this.onReminder,
    required this.onPin,
    required this.onFavorite,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: context.cBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: isSaving
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      actions: [
        IconButton(
          icon: Icon(Icons.save_rounded, color: context.cPrimary),
          tooltip: 'Αποθήκευση',
          onPressed: onSave,
        ),
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: context.cText2),
          onPressed: onReminder,
          tooltip: 'Υπενθύμιση',
        ),
        IconButton(
          icon: Icon(
            isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: isPinned ? context.cPrimary : context.cText2,
          ),
          tooltip: isPinned ? 'Ξεκαρφίτσωμα' : 'Καρφίτσωμα',
          onPressed: onPin,
        ),
        IconButton(
          icon: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isFavorite
                ? ColorsUI.getWarning(context.brightness)
                : context.cText2,
          ),
          tooltip: isFavorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
          onPressed: onFavorite,
        ),
        IconButton(
          icon: Icon(
            isArchived
                ? Icons.unarchive_rounded
                : Icons.archive_rounded,
            color: context.cText2,
          ),
          onPressed: onArchive,
          tooltip: isArchived ? 'Επαναφορά' : 'Αρχειοθέτηση',
        ),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: context.cError),
          tooltip: 'Διαγραφή',
          onPressed: onDelete,
        ),
      ],
    );
  }
}
