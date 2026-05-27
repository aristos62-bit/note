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
import '../../shared/widgets/widgets.dart';
import '../../services/reminder_scheduler.dart';

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

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _locationCtrl;
  Timer? _titleDebounce;
  Timer? _locationDebounce;
  bool _isSaving = false;
  bool _isSavingTitle = false;
  bool _isEditingTitle = false;
  String _lastSavedTitle = '';
  String? _pendingTitleValue;
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _isArchived = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    DebugConfig.nav('EventDetailScreen init id=${widget.itemId}');
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _locationDebounce?.cancel();
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged(String v) {
    _isEditingTitle = true;

    final trimmed = v.trim();

    // 🔥 NEW: ignore duplicate pending values
    if (_pendingTitleValue == trimmed) return;

    _pendingTitleValue = trimmed;

    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 600), () async {
      final title = _pendingTitleValue ?? '';

      await _saveTitle(title);

      await Future.delayed(const Duration(milliseconds: 100));
      _isEditingTitle = false;
    });
  }

  void _onLocationChanged(String v) {
    _locationDebounce?.cancel();

    _locationDebounce = Timer(
      const Duration(milliseconds: 800),
      () async {
        await _saveLocation(v.trim());
      },
    );
  }

  Future<void> _saveTitle(String title) async {
    if (!mounted) return;

    // 🔥 NEW: block parallel saves
    if (_isSavingTitle) return;

    // 🔥 NEW: avoid duplicate writes
    if (title == _lastSavedTitle) return;

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
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
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
    _titleDebounce?.cancel();
    _locationDebounce?.cancel();
    await _flushSaves();
  }

  /// Save button: validation + _saveData() + pop.
  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Παρακαλώ προσθέστε τίτλο')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context, rootNavigator: false);
    try {
      await _saveData();
      if (mounted) {
        setState(() => _isSaving = false);
        navigator.pop();
      }
    } catch (e) {
      DebugConfig.error('EventDetail _save', e);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα αποθήκευσης: ${e.toString()}')),
        );
      }
    }
  }

  /// Back arrow: αν κενός τίτλος → delete μόνο αν isNew, αλλιώς pop.
  /// Αν ΟΚ → auto-save + pop.
  Future<bool> _onPopInvoked() async {
    if (_isSaving) return false;
    if (_titleCtrl.text.trim().isEmpty) {
      if (widget.isNew) {
        DebugConfig.db(
            'EventDetail delete empty new event id=${widget.itemId}');
        await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
      }
      return true;
    }
    try {
      await _saveData();
    } catch (e) {
      DebugConfig.error('EventDetail auto-save on pop', e);
    }
    return true;
  }

  Future<void> _pickStartTime(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final init = current ?? now;

    // Για γενέθλια και ειδική μέρα επιτρέπουμε παλιές ημερομηνίες
    final item = ref.read(itemStreamProvider(widget.itemId)).valueOrNull;
    final isBirthdayOrSpecial = item?.icon == '🎂' || item?.icon == '⭐';
    final firstDate =
        isBirthdayOrSpecial ? DateTime(1900) : DateTime(now.year - 1);

    final date = await showDatePicker(
      context: context,
      locale: const Locale('el', 'GR'),
      initialDate: init,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 5),
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
    if (isBirthdayOrSpecial) {
      final newRrule =
          'FREQ=YEARLY;INTERVAL=1;BYMONTH=${date.month};BYMONTHDAY=${date.day}';
      final newTrigger = DateTime(
        date.year, date.month, date.day, dt.hour, dt.minute,
      );
      await ref.read(dbProvider).reminders.updateRootReminderForItem(
            widget.itemId,
            newRrule: newRrule,
            newTriggerAt: newTrigger,
          );
      await ReminderScheduler.instance.refreshRecurringReminders();
    }
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
    final ok = await ConfirmDialog.archive(context);
    if (!ok || !mounted) return;
    DebugConfig.db('EventDetail archive id=${widget.itemId}');
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleArchive(widget.itemId, _isArchived);
    if (mounted) Navigator.of(context, rootNavigator: false).pop();
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
          defaultStartTime: startDateTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('EventDetailScreen build id=${widget.itemId}');
    final itemAsync = ref.watch(
      itemStreamProvider(widget.itemId).select((value) => value),
    );

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
          brightness: context.brightness,
          primaryColor: context.cPrimary,
          textColor: context.cText,
          text2Color: context.cText2,
          errorColor: context.cError,
        ),
        body: _EventBody(
          item: item,
          titleCtrl: _titleCtrl,
          locationCtrl: _locationCtrl,
          isSaving: _isSaving,
          onTitleChange: _onTitleChanged,
          onLocationChange: _onLocationChanged,
          onPickStart: (cur) => _pickStartTime(context, cur),
          onToggleAllDay: _toggleAllDay,
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
                item: item,
                onPickStart: (cur) => _pickStartTime(context, cur),
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
                isSaving: _isSaving,
                onTitleChange: _onTitleChanged,
                onLocationChange: _onLocationChanged,
                onPickStart: (cur) => _pickStartTime(context, cur),
                onToggleAllDay: _toggleAllDay,
                hideProperties: true,
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
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        actions: [
          // Save
          IconButton(
            icon: Icon(Icons.save_rounded, color: context.cPrimary),
            tooltip: 'Αποθήκευση',
            onPressed: _save,
          ),
          // Reminder
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: context.cText2),
            onPressed: _showReminderDialog,
            tooltip: 'Υπενθύμιση',
          ),
          // Pin
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
              color: _isFavorite
                  ? ColorsUI.getWarning(context.brightness)
                  : context.cText2,
            ),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
          ),
          // Archive
          IconButton(
            icon: Icon(
              item.archived
                  ? Icons.unarchive_rounded
                  : Icons.archive_rounded,
              color: context.cText2,
            ),
            onPressed: _archive,
            tooltip: item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση',
          ),
          // Delete
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: context.cError),
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
  final bool isSaving;
  final ValueChanged<String> onTitleChange;
  final ValueChanged<String> onLocationChange;
  final ValueChanged<DateTime?> onPickStart;
  final ValueChanged<bool> onToggleAllDay;
  final bool hideProperties;

  const _EventBody({
    required this.item,
    required this.titleCtrl,
    required this.locationCtrl,
    required this.isSaving,
    required this.onTitleChange,
    required this.onLocationChange,
    required this.onPickStart,
    required this.onToggleAllDay,
    this.hideProperties = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final props = propsAsync.valueOrNull ?? [];
    final location =
        props.where((p) => p.key == 'location').firstOrNull?.value ?? '';

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
              child: _EventPropertiesPanel(
                item: item,
                onPickStart: onPickStart,
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
              if (item.icon == '🎂')
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Είναι Γενέθλια — θα οριστεί αυτόματα ετήσια υπενθύμιση',
                    style: context.bodySm.copyWith(
                      color: Colors.green.shade700,
                      height: 1.3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ]),
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
  final Item item;
  final ValueChanged<DateTime?> onPickStart;
  final ValueChanged<bool> onToggleAllDay;

  const _EventPropertiesPanel({
    required this.item,
    required this.onPickStart,
    required this.onToggleAllDay,
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
        String? prop(String key) =>
            props.where((p) => p.key == key).firstOrNull?.value;

        final startStr = prop('start_time');
        final allDay = prop('all_day') == 'true';
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
                      startTime != null ? context.cText : context.cText2),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROP ROW
// ════════════════════════════════════════════════════════════════

class _PropRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _PropRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.cText2),
          const SizedBox(width: Spacing.sm),
          SizedBox(
            width: 80,
            child: Text(label, style: context.bodyMd.withColor(context.cText2)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

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

  final Brightness brightness;
  final Color primaryColor;
  final Color textColor;
  final Color text2Color;
  final Color errorColor;

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
    required this.brightness,
    required this.primaryColor,
    required this.textColor,
    required this.text2Color,
    required this.errorColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: ColorsUI.getSurface(brightness),
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
          icon: Icon(Icons.save_rounded, color: primaryColor),
          tooltip: 'Αποθήκευση',
          onPressed: onSave,
        ),
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: text2Color),
          onPressed: onReminder,
          tooltip: 'Υπενθύμιση',
        ),
        IconButton(
          icon: Icon(
            isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: isPinned ? primaryColor : text2Color,
          ),
          onPressed: onPin,
        ),
        IconButton(
          icon: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isFavorite ? ColorsUI.getWarning(brightness) : text2Color,
          ),
          onPressed: onFavorite,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: errorColor),
          onPressed: onDelete,
        ),
        IconButton(
          icon: Icon(
            isArchived
                ? Icons.unarchive_rounded
                : Icons.archive_rounded,
            color: text2Color,
          ),
          onPressed: onArchive,
          tooltip: isArchived ? 'Επαναφορά' : 'Αρχειοθέτηση',
        ),
      ],
    );
  }
}
