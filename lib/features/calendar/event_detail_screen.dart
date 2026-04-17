// lib/features/calendar/event_detail_screen.dart
//
// Detail screen συμβάντος: τίτλος, ημερομηνία, ώρα, τοποθεσία, υπενθύμιση.
// ✅ Favorite toggle στο AppBar
// ✅ Responsive: single col mobile / two-panel tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../helpers/super_note_helper.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final int  itemId;
  final bool isNew;

  const EventDetailScreen({
    super.key,
    required this.itemId,
    this.isNew = false,
  });

  @override
  ConsumerState<EventDetailScreen> createState() =>
      _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _locationCtrl;
  Timer? _titleDebounce;
  Timer? _locationDebounce;
  bool   _isSaving       = false;
  bool   _isEditingTitle = false;
  String _lastSavedTitle = '';
  bool   _hasEverBeenSaved = false;
  bool _isPinned = false;

  // ── Favorite state ───────────────────────────────────────────
  bool _isFavorite = false;

  // ── Reminder state ───────────────────────────────────────────
  bool      _reminderEnabled   = false;
  DateTime? _reminderDateTime;
  int?      _existingReminderId;

  Future<void> _togglePinned() async {
    DebugConfig.provider('EventDetail togglePinned id=${widget.itemId}');
    await ref.read(itemNotifierProvider.notifier)
        .togglePin(widget.itemId, _isPinned);
    setState(() => _isPinned = !_isPinned);
    ref.invalidate(itemNotifierProvider);
  }

  @override
  void initState() {
    super.initState();
    _titleCtrl    = TextEditingController();
    _locationCtrl = TextEditingController();
    DebugConfig.nav('EventDetailScreen init id=${widget.itemId}');
    _loadExistingReminder();
  }

  Future<void> _loadExistingReminder() async {
    final reminders = await SuperNoteHelper.instance.reminders
        .getForItem(widget.itemId);
    if (reminders.isNotEmpty && mounted) {
      final r = reminders.first;
      setState(() {
        _reminderEnabled    = true;
        _reminderDateTime   = r.triggerAt;
        _existingReminderId = r.id;
      });
      DebugConfig.db(
          'EventDetail loaded reminder id=${r.id} at=${r.triggerAt}');
    }
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _locationDebounce?.cancel();
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Save helpers ─────────────────────────────────────────────

  void _onTitleChanged(String v) {
    _isEditingTitle = true;
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 600), () async {
      final title = _titleCtrl.text.trim();
      await _saveTitle(title);
      await Future.delayed(const Duration(milliseconds: 100));
      _isEditingTitle = false;
    });
  }

  void _onLocationChanged(String v) {
    _locationDebounce?.cancel();
    _locationDebounce = Timer(
        const Duration(milliseconds: 800), () => _saveLocation(v.trim()));
  }

  Future<void> _saveTitle(String title) async {
    if (!mounted) return;
    if (title == _lastSavedTitle) return;
    setState(() => _isSaving = true);
    DebugConfig.db('EventDetail saveTitle id=${widget.itemId} "$title"');
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId, title: title.isEmpty ? null : title);
    _lastSavedTitle   = title;
    _hasEverBeenSaved = true;
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  Future<void> _saveLocation(String location) async {
    DebugConfig.db('EventDetail saveLocation id=${widget.itemId}');
    await ref.read(propertyNotifierProvider(widget.itemId).notifier)
        .setText('location', location.isEmpty ? null : location);
  }

  Future<void> _flushSaves() async {
    if (_titleDebounce?.isActive == true) {
      _titleDebounce!.cancel();
      await _saveTitle(_titleCtrl.text.trim());
    }
    if (_locationDebounce?.isActive == true) {
      _locationDebounce!.cancel();
      await _saveLocation(_locationCtrl.text.trim());
    }
  }

  // ── Favorite toggle ─────────────────────────────────────────

  Future<void> _toggleFavorite() async {
    DebugConfig.provider('EventDetail toggleFavorite id=${widget.itemId}');
    await ref.read(itemNotifierProvider.notifier)
        .toggleFavorite(widget.itemId, _isFavorite);
    setState(() => _isFavorite = !_isFavorite);
    ref.invalidate(itemNotifierProvider);
  }

  // ── Pop guard ─────────────────────────────────────────────────

  Future<bool> _onPopInvoked() async {
    _titleDebounce?.cancel();
    _locationDebounce?.cancel();

    final title    = _titleCtrl.text.trim();
    final hasTitle = title.isNotEmpty;

    // isNew χωρίς τίτλο → auto-delete
    if (widget.isNew && !_hasEverBeenSaved) {
      DebugConfig.db(
          'EventDetail auto-delete NEW event id=${widget.itemId}');
      if (_existingReminderId != null) {
        await ReminderScheduler.instance
            .cancelReminder(_existingReminderId!);
      }
      await ref.read(itemNotifierProvider.notifier)
          .deleteItem(widget.itemId);
      return true;
    }

    if (!hasTitle) {
      DebugConfig.db(
          'EventDetail auto-delete empty event id=${widget.itemId}');
      if (_existingReminderId != null) {
        await ReminderScheduler.instance
            .cancelReminder(_existingReminderId!);
      }
      await ref.read(itemNotifierProvider.notifier)
          .deleteItem(widget.itemId);
      return true;
    }

    await _flushSaves();
    return true;
  }

  // ── Reminder methods ──────────────────────────────────────────

  Future<void> _toggleReminder(bool value, DateTime? startTime) async {
    DebugConfig.db('EventDetail _toggleReminder value=$value startTime=$startTime');

    if (value) {
      if (startTime != null) {
        final dt = startTime;
        setState(() {
          _reminderEnabled  = true;
          _reminderDateTime = dt;
        });
        DebugConfig.db('EventDetail reminderSet (from start_time) at=$dt');
      } else {
        final defaultDt = DateTime.now().add(const Duration(hours: 1));
        await _pickReminderDateTime(defaultDt);
      }
    } else {
      await _cancelReminder();
    }
  }

  Future<void> _pickReminderDateTime(DateTime initial) async {
    final now      = DateTime.now();
    final safeInit = initial.isAfter(now) ? initial : now;

    final date = await showDatePicker(
      context:     context,
      initialDate: safeInit,
      firstDate:   now,
      lastDate:    DateTime(now.year + 5),
      helpText:    'Ημερομηνία υπενθύμισης',
      locale:      const Locale('el'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context:     context,
      initialTime: TimeOfDay.fromDateTime(safeInit),
      helpText:    'Ώρα υπενθύμισης',
    );
    if (time == null || !mounted) return;

    final dt = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _reminderEnabled  = true;
      _reminderDateTime = dt;
    });
    DebugConfig.db('EventDetail reminderSet at=$dt');
  }

  Future<void> _cancelReminder() async {
    if (_existingReminderId != null) {
      await ReminderScheduler.instance
          .cancelReminder(_existingReminderId!);
    }
    if (mounted) {
      setState(() {
        _reminderEnabled    = false;
        _reminderDateTime   = null;
        _existingReminderId = null;
      });
    }
  }

  Future<void> _saveReminder(String eventTitle) async {
    if (!_reminderEnabled || _reminderDateTime == null) return;
    if (_reminderDateTime!.isBefore(DateTime.now())) {
      DebugConfig.warning('EventDetail reminder in past, skip');
      return;
    }
    if (_existingReminderId != null) {
      await ReminderScheduler.instance
          .cancelReminder(_existingReminderId!);
    }
    final title    = eventTitle.isNotEmpty ? eventTitle : 'Συμβάν';
    final reminder = await SuperNoteHelper.instance.reminders.create(
      itemId:    widget.itemId,
      triggerAt: _reminderDateTime!,
      title:     title,
      body:      'Υπενθύμιση: $title',
    );
    await ReminderScheduler.instance.scheduleReminder(reminder);
    setState(() => _existingReminderId = reminder.id);
    DebugConfig.db(
        'EventDetail reminder saved id=${reminder.id} at=$_reminderDateTime');
  }

  // ── Date/time pickers ─────────────────────────────────────────

  Future<void> _pickStartTime(
      BuildContext context, DateTime? current) async {
    final now  = DateTime.now();
    final init = current ?? now;
    final date = await showDatePicker(
      context:     context,
      initialDate: init,
      firstDate:   DateTime(now.year - 1),
      lastDate:    DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    if (!context.mounted) return;
    final time = await showTimePicker(
      context:     context,
      initialTime: TimeOfDay.fromDateTime(init),
    );
    if (time == null) return;
    final dt = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    DebugConfig.db('EventDetail setStartTime $dt');
    await ref.read(propertyNotifierProvider(widget.itemId).notifier)
        .setDate('start_time', dt);
  }

  Future<void> _toggleAllDay(bool newValue) async {
    DebugConfig.db('EventDetail allDay=$newValue');
    await ref.read(propertyNotifierProvider(widget.itemId).notifier)
        .setText('all_day', newValue.toString());
  }

  Future<void> _delete(BuildContext context) async {
    final future = ConfirmDialog.delete(context,
        title: 'Διαγραφή συμβάντος;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('EventDetail delete id=${widget.itemId}');
    if (_existingReminderId != null) {
      await ReminderScheduler.instance
          .cancelReminder(_existingReminderId!);
    }
    await ref.read(itemNotifierProvider.notifier)
        .deleteItem(widget.itemId);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: false).pop();
  }

  // ── Build ─────────────────────────────────────────────────────

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

        // Sync favorite state
        if (_isFavorite != item.favorite) {
          _isFavorite = item.favorite;
        }

        // Sync pinned state
        if (_isPinned != item.pinned) {
          _isPinned = item.pinned;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav    = Navigator.of(context, rootNavigator: false);
            final canPop = await _onPopInvoked();
            if (canPop && mounted) nav.pop();
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
    body: _EventBody(
      item:             item,
      titleCtrl:        _titleCtrl,
      locationCtrl:     _locationCtrl,
      isSaving:         _isSaving,
      onTitleChange:    _onTitleChanged,
      onLocationChange: _onLocationChanged,
      onPickStart:      (cur) => _pickStartTime(context, cur),
      onToggleAllDay:   _toggleAllDay,
      reminderEnabled:  _reminderEnabled,
      reminderDateTime: _reminderDateTime,
      onToggleReminder: (v, st) => _toggleReminder(v, st),
      onEditReminder: () => _pickReminderDateTime(
        _reminderDateTime ?? DateTime.now().add(const Duration(hours: 1)),
      ),
    ),
  );

  Widget _buildTablet(BuildContext context, Item item) => Scaffold(
    backgroundColor: context.cBg,
    appBar: _buildAppBar(context, item),
    body: Row(
      children: [
        SizedBox(
          width: 280,
          child: _EventPropertiesPanel(
            item:             item,
            onPickStart:      (cur) => _pickStartTime(context, cur),
            onToggleAllDay:   _toggleAllDay,
            reminderEnabled:  _reminderEnabled,
            reminderDateTime: _reminderDateTime,
            onToggleReminder: (v, st) => _toggleReminder(v, st),
            onEditReminder: () => _pickReminderDateTime(
              _reminderDateTime ?? DateTime.now().add(const Duration(hours: 1)),
            ),
          ),
        ),
        VerticalDivider(
          width: 1,
          color: ColorsUI.getBorder(context.brightness),
        ),
        Expanded(
          child: _EventBody(
            item:             item,
            titleCtrl:        _titleCtrl,
            locationCtrl:     _locationCtrl,
            isSaving:         _isSaving,
            onTitleChange:    _onTitleChanged,
            onLocationChange: _onLocationChanged,
            onPickStart:      (cur) => _pickStartTime(context, cur),
            onToggleAllDay:   _toggleAllDay,
            hideProperties:   true,
            reminderEnabled:  _reminderEnabled,
            reminderDateTime: _reminderDateTime,
            onToggleReminder: (v, st) => _toggleReminder(v, st),
            onEditReminder: () => _pickReminderDateTime(
              _reminderDateTime ?? DateTime.now().add(const Duration(hours: 1)),
            ),
          ),
        ),
      ],
    ),
  );

  AppBar _buildAppBar(BuildContext context, Item item) => AppBar(
    backgroundColor: context.cBg,
    elevation: 0,
    scrolledUnderElevation: 1,
    title: _isSaving
        ? Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: context.cText2),
      ),
      const SizedBox(width: Spacing.xs),
      Text('Αποθήκευση...', style: context.bodySm.withColor(context.cText2)),
    ])
        : null,
    actions: [
      // Save
      IconButton(
        icon: Icon(Icons.save_rounded, color: context.cPrimary),
        tooltip: 'Αποθήκευση',
        onPressed: () async {
          final title = _titleCtrl.text.trim();
          final location = _locationCtrl.text.trim();
          DebugConfig.db('EventDetail manual save id=${item.id} title="$title"');
          await _saveTitle(title);
          await _saveLocation(location);
          if (_reminderEnabled) {
            await _saveReminder(title);
          } else if (_existingReminderId != null) {
            await _cancelReminder();
          }
          await ReminderScheduler.instance.scheduleAll();
          if (!context.mounted) return;
          Navigator.of(context, rootNavigator: false).pop();
        },
      ),
      // PIN button
      IconButton(
        icon: Icon(
          _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          color: _isPinned ? context.cPrimary : context.cText2,
        ),
        onPressed: _togglePinned,
        tooltip: _isPinned ? 'Ξεκαρφίτσωμα' : 'Καρφίτσωμα',
      ),
      // Favorite
      IconButton(
        icon: Icon(
          _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
          color: _isFavorite ? ColorsUI.getWarning(context.brightness) : context.cText2,
        ),
        onPressed: _toggleFavorite,
        tooltip: _isFavorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
      ),
      // Delete
      IconButton(
        icon: Icon(Icons.delete_outline_rounded, color: context.cText2),
        tooltip: 'Διαγραφή',
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
    body: EmptyState.error(onRetry: () =>
        ref.invalidate(itemStreamProvider(widget.itemId))),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const EmptyState(
        icon:  Icons.event_busy_rounded,
        title: 'Το συμβάν δεν βρέθηκε'),
  );
}

// ════════════════════════════════════════════════════════════════
// EVENT BODY
// ════════════════════════════════════════════════════════════════

class _EventBody extends ConsumerWidget {
  final Item                        item;
  final TextEditingController       titleCtrl;
  final TextEditingController       locationCtrl;
  final bool                        isSaving;
  final ValueChanged<String>        onTitleChange;
  final ValueChanged<String>        onLocationChange;
  final ValueChanged<DateTime?>     onPickStart;
  final ValueChanged<bool>          onToggleAllDay;
  final bool                        hideProperties;
  final bool                        reminderEnabled;
  final DateTime?                   reminderDateTime;
  final void Function(bool, DateTime?) onToggleReminder;
  final VoidCallback                onEditReminder;

  const _EventBody({
    required this.item,
    required this.titleCtrl,
    required this.locationCtrl,
    required this.isSaving,
    required this.onTitleChange,
    required this.onLocationChange,
    required this.onPickStart,
    required this.onToggleAllDay,
    this.hideProperties  = false,
    this.reminderEnabled = false,
    this.reminderDateTime,
    required this.onToggleReminder,
    required this.onEditReminder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final props      = propsAsync.valueOrNull ?? [];
    final location   = props.where((p) => p.key == 'location')
        .firstOrNull?.value ?? '';

    if (!locationCtrl.selection.isValid &&
        locationCtrl.text != location) {
      locationCtrl.text = location;
    }

    return CustomScrollView(
      slivers: [
        // ── Title ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.lg,
              context.responsiveHPadding, Spacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 12, height: 12,
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
                    onChanged:  onTitleChange,
                    style: context.h2.copyWith(fontWeight: FontWeight.w600),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText:  'Τίτλος συμβάντος...',
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

        // ── Properties (mobile) ──────────────────────────────
        if (!hideProperties)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.responsiveHPadding),
              child: _EventPropertiesPanel(
                item:             item,
                onPickStart:      onPickStart,
                onToggleAllDay:   onToggleAllDay,
                reminderEnabled:  reminderEnabled,
                reminderDateTime: reminderDateTime,
                onToggleReminder: onToggleReminder,
                onEditReminder:   onEditReminder,
              ),
            ),
          ),

        // ── Location ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.md,
              context.responsiveHPadding, 0,
            ),
            child: Divider(color: ColorsUI.getBorder(context.brightness)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHPadding,
              vertical:   Spacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 18, color: context.cText2),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: TextField(
                    controller: locationCtrl,
                    onChanged:  onLocationChange,
                    style:      context.bodyMd,
                    decoration: InputDecoration(
                      hintText:  'Τοποθεσία...',
                      hintStyle: context.bodyMd.withColor(context.cDisabled),
                      border:    InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// EVENT PROPERTIES PANEL
// ════════════════════════════════════════════════════════════════

class _EventPropertiesPanel extends ConsumerWidget {
  final Item                        item;
  final ValueChanged<DateTime?>     onPickStart;
  final ValueChanged<bool>          onToggleAllDay;
  final bool                        reminderEnabled;
  final DateTime?                   reminderDateTime;
  final void Function(bool, DateTime?) onToggleReminder;
  final VoidCallback                onEditReminder;

  const _EventPropertiesPanel({
    required this.item,
    required this.onPickStart,
    required this.onToggleAllDay,
    this.reminderEnabled  = false,
    this.reminderDateTime,
    required this.onToggleReminder,
    required this.onEditReminder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));

    return propsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Spacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (props) {
        final startStr = props.where((p) => p.key == 'start_time').firstOrNull?.value;
        final allDay = props.where((p) => p.key == 'all_day').firstOrNull?.value == 'true';
        final startTime = startStr != null ? DateTime.tryParse(startStr) : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Spacing.sm),

            // All day toggle
            _PropRow(
              icon: Icons.wb_sunny_rounded,
              label: 'Ολοήμερο',
              child: Switch(
                value: allDay,
                onChanged: onToggleAllDay,
                activeThumbColor: context.cPrimary,
              ),
            ),

            // Start time
            _PropRow(
              icon: Icons.schedule_rounded,
              label: 'Έναρξη',
              child: GestureDetector(
                onTap: () => onPickStart(startTime),
                child: Text(
                  startTime != null
                      ? (allDay ? startTime.short : startTime.dateTime)
                      : 'Επιλογή',
                  style: context.bodyMd.withColor(
                    startTime != null ? context.cText : context.cText2,
                  ),
                ),
              ),
            ),

            // Reminder divider
            Divider(color: ColorsUI.getBorder(context.brightness)),

            // Reminder section
            _ReminderSection(
              enabled: reminderEnabled,
              dateTime: reminderDateTime,
              onToggle: (v) => onToggleReminder(v, startTime),
              onEdit: onEditReminder,
            ),

            const SizedBox(height: Spacing.sm),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// REMINDER SECTION
// ════════════════════════════════════════════════════════════════

class _ReminderSection extends StatelessWidget {
  final bool      enabled;
  final DateTime? dateTime;
  final ValueChanged<bool> onToggle;
  final VoidCallback       onEdit;

  const _ReminderSection({
    required this.enabled,
    required this.dateTime,
    required this.onToggle,
    required this.onEdit,
  });

  String _formatReminder(DateTime dt) {
    return AppDateUtils.formatDateTime(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PropRow(
          icon:  Icons.notifications_outlined,
          label: 'Υπενθύμιση',
          child: Switch(
            value:           enabled,
            onChanged:       onToggle,
            activeThumbColor: context.cPrimary,
          ),
        ),
        if (enabled)
          _PropRow(
            icon:  Icons.alarm_rounded,
            label: 'Ώρα',
            child: GestureDetector(
              onTap: onEdit,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateTime != null
                        ? _formatReminder(dateTime!)
                        : 'Επιλογή...',
                    style: context.bodyMd.withColor(
                        dateTime != null
                            ? context.cPrimary : context.cText2),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Icon(Icons.edit_rounded, size: 13, color: context.cText2),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROP ROW
// ════════════════════════════════════════════════════════════════

class _PropRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Widget   child;

  const _PropRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2),
      child: Row(children: [
        Icon(icon, size: 16, color: context.cText2),
        const SizedBox(width: Spacing.sm),
        SizedBox(
          width: 80,
          child: Text(label,
              style: context.bodyMd.withColor(context.cText2)),
        ),
        Expanded(child: child),
      ]),
    );
  }
}