// lib/features/calendar/event_detail_screen.dart
//
// Detail screen συμβάντος: τίτλος, ημερομηνία, ώρα, τοποθεσία.
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

class EventDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  final bool isNew; // <= ΠΡΟΣΘΗΚΗ

  const EventDetailScreen({
    super.key,
    required this.itemId,
    this.isNew = false, // default για υπάρχοντα
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
  bool  _isSaving = false;
  bool _isEditingTitle = false;
  String _lastSavedTitle = '';
  bool _hasEverBeenSaved = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl    = TextEditingController();
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

  // ── Save helpers ─────────────────────────────────────────────

  void _onTitleChanged(String v) {
    _isEditingTitle = true;
    _titleDebounce?.cancel();
    // Δεν κάνουμε πια auto-save εδώ, μόνο local state
  }

  void _onLocationChanged(String v) {
    _locationDebounce?.cancel();
    // Δεν κάνουμε auto-save εδώ, μόνο local state
  }


  Future<void> _saveTitle(String title) async {
    if (!mounted) return;
    if (title == _lastSavedTitle) return;

    setState(() => _isSaving = true);
    DebugConfig.db('EventDetail saveTitle id=${widget.itemId} "$title"');

    await ref
        .read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId, title: title.isEmpty ? null : title);

    _lastSavedTitle   = title;
    _hasEverBeenSaved = true; // <= εδώ μαρκάρουμε ότι έγινε manual save

    if (!mounted) return;
    setState(() => _isSaving = false);
  }



  Future<void> _saveLocation(String location) async {
    DebugConfig.db('EventDetail saveLocation id=${widget.itemId}');
    await ref.read(propertyNotifierProvider(widget.itemId).notifier)
        .setText('location', location.isEmpty ? null : location);
  }

  // ── Pop guard — αποθήκευση / διαγραφή πριν φύγουμε ────────────

  Future<bool> _onPopInvoked() async {
    _titleDebounce?.cancel();
    _locationDebounce?.cancel();

    // Case 1: ΝΕΟ event, δεν έχει γίνει ποτέ manual save
    if (widget.isNew && !_hasEverBeenSaved) {
      DebugConfig.db(
        'EventDetail auto-delete NEW event without manual save id=${widget.itemId}',
      );
      await ref
          .read(itemNotifierProvider.notifier)
          .deleteItem(widget.itemId);
      return true;
    }

    // Case 2: υπάρχον event ή νέο που έχει ήδη σωθεί με save
    // → δεν κάνουμε ούτε auto-save ούτε delete στο back
    DebugConfig.nav(
      'EventDetail back keep event id=${widget.itemId} isNew=${widget.isNew} hasEverSaved=$_hasEverBeenSaved',
    );
    return true;
  }


  // ── Date/time pickers ────────────────────────────────────────

  Future<void> _pickStartTime(
      BuildContext context, DateTime? current, bool allDay) async {
    final now  = DateTime.now();
    final init = current ?? now;

    // 1. Επιλογή ημερομηνίας
    final date = await showDatePicker(
      context:     context,
      initialDate: init,
      firstDate:   DateTime(now.year - 1),
      lastDate:    DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    DateTime dt;

    if (allDay) {
      // Ολοήμερο → κρατάμε ΜΟΝΟ την ημερομηνία (00:00)
      dt = DateTime(date.year, date.month, date.day);
    } else {
      // Κανονικό → ζητάμε και ώρα
      if (!context.mounted) return;
      final time = await showTimePicker(
        context:     context,
        initialTime: TimeOfDay.fromDateTime(init),
      );
      if (time == null) return;
      dt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }

    DebugConfig.db('EventDetail setStartTime $dt allDay=$allDay');
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
        .setDate('start_time', dt);
  }


  Future<void> _pickEndTime(
      BuildContext context,
      DateTime? current,
      DateTime? start,
      bool allDay,
      ) async {
    final now  = DateTime.now();
    final init = current ?? start?.add(const Duration(hours: 1)) ?? now;

    // 1. Επιλογή ημερομηνίας
    final date = await showDatePicker(
      context:     context,
      initialDate: init,
      firstDate:   start ?? DateTime(now.year - 1),
      lastDate:    DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    DateTime dt;

    if (allDay) {
      // Ολοήμερο → μόνο ημερομηνία
      dt = DateTime(date.year, date.month, date.day);
    } else {
      if (!context.mounted) return;
      final time = await showTimePicker(
        context:     context,
        initialTime: TimeOfDay.fromDateTime(init),
      );
      if (time == null) return;
      dt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }

    DebugConfig.db('EventDetail setEndTime $dt allDay=$allDay');
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
        .setDate('end_time', dt);
  }


  Future<void> _toggleAllDay(bool value) async {
    DebugConfig.db('EventDetail allDay=$value');
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
        .setText('all_day', value ? 'true' : 'false');
  }



  Future<void> _delete(BuildContext context) async {
    final future = ConfirmDialog.delete(
      context,
      title: 'Διαγραφή συμβάντος;',
    );
    final ok = await future;
    if (!ok || !mounted) return;

    DebugConfig.db('EventDetail delete id=${widget.itemId}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
    // Δεν χρειάζεται invalidate: itemsStreamProvider θα ενημερώσει calendar

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: false).pop();
  }



  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('EventDetailScreen build id=${widget.itemId}');
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error:   (e, _) {
        DebugConfig.error('EventDetail load failed', e);
        return _buildError();
      },
      data: (item) {
        if (item == null) return _buildNotFound();

        // Sync title
        // Sync title από DB μόνο όταν ΔΕΝ edittext χειροκίνητα
        final itemTitle = item.title ?? '';

// Αρχικοποίηση lastSavedTitle
        if (_lastSavedTitle.isEmpty && itemTitle.isNotEmpty) {
          _lastSavedTitle = itemTitle;
        }

        if (!_isEditingTitle &&
            _titleCtrl.text != itemTitle) {
          final cursorAtEnd =
              _titleCtrl.selection.baseOffset == _titleCtrl.text.length;
          _titleCtrl.text = itemTitle;
          if (cursorAtEnd) {
            _titleCtrl.selection =
                TextSelection.collapsed(offset: _titleCtrl.text.length);
          }
        }


        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav    = Navigator.of(context, rootNavigator: false);
            final canPop = await _onPopInvoked();
            if (canPop) nav.pop();
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
      item:               item,
      titleCtrl:          _titleCtrl,
      locationCtrl:       _locationCtrl,
      isSaving:           _isSaving,
      onTitleChange:      _onTitleChanged,
      onLocationChange:   _onLocationChanged,
      onPickStart:        (cur, allDay) => _pickStartTime(context, cur, allDay),
      onPickEnd:          (cur, start, allDay) =>
          _pickEndTime(context, cur, start, allDay),
      onToggleAllDay:     _toggleAllDay,
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
            onPickStart: (cur, allDay) =>
                _pickStartTime(context, cur, allDay),
            onPickEnd: (cur, start, allDay) =>
                _pickEndTime(context, cur, start, allDay),
            onToggleAllDay: _toggleAllDay,
          ),
        ),
        VerticalDivider(
          width: 1,
          color: ColorsUI.getBorder(context.brightness),
        ),
        Expanded(
          child: _EventBody(
            item:         item,
            titleCtrl:    _titleCtrl,
            locationCtrl: _locationCtrl,
            isSaving:     _isSaving,
            onTitleChange:    _onTitleChanged,
            onLocationChange: _onLocationChanged,
            onPickStart: (cur, allDay) =>
                _pickStartTime(context, cur, allDay),
            onPickEnd: (cur, start, allDay) =>
                _pickEndTime(context, cur, start, allDay),
            onToggleAllDay: _toggleAllDay,
            hideProperties:  true,
          ),
        ),
      ],
    ),
  );


  AppBar _buildAppBar(BuildContext context, Item item) => AppBar(
    backgroundColor:        context.cBg,
    elevation:              0,
    scrolledUnderElevation: 1,
    title: _isSaving
        ? Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 14, height: 14,
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
      // Save
      IconButton(
        icon: Icon(Icons.save_rounded, color: context.cPrimary),
        tooltip: 'Αποθήκευση',
        onPressed: () async {
          final title    = _titleCtrl.text.trim();
          final location = _locationCtrl.text.trim();

          DebugConfig.db(
            'EventDetail manual save pressed id=${item.id} title="$title" location="$location"',
          );

          // 1. Αποθήκευση τίτλου
          await _saveTitle(title);

          // 2. Αποθήκευση τοποθεσίας
          await _saveLocation(location);

          // 3. Μετά από save γύρνα πάντα πίσω
          if (!context.mounted) return;
          Navigator.of(context, rootNavigator: false).pop();
        },
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
        icon: Icons.event_busy_rounded,
        title: 'Το συμβάν δεν βρέθηκε'),
  );
}

// ════════════════════════════════════════════════════════════════
// EVENT BODY
// ════════════════════════════════════════════════════════════════

class _EventBody extends ConsumerWidget {
  final Item item;
  final TextEditingController titleCtrl;
  final TextEditingController locationCtrl;
  final bool isSaving;
  final ValueChanged<String> onTitleChange;
  final ValueChanged<String> onLocationChange;
  final void Function(DateTime?, bool) onPickStart;
  final void Function(DateTime?, DateTime?, bool) onPickEnd;
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
    required this.onPickEnd,
    required this.onToggleAllDay,
    this.hideProperties = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final props      = propsAsync.valueOrNull ?? [];
    final location   = props.where((p) => p.key == 'location')
        .firstOrNull?.value ?? '';

    // Sync location controller
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
                    style: context.h2.copyWith(
                        fontWeight: FontWeight.w600),
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
                item:           item,
                onPickStart:    onPickStart,
                onPickEnd:      onPickEnd,
                onToggleAllDay: onToggleAllDay,
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
            child: Divider(
                color: ColorsUI.getBorder(context.brightness)),
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
                      hintStyle: context.bodyMd.withColor(
                          context.cDisabled),
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
  final Item item;
  final void Function(DateTime?, bool) onPickStart;
  final void Function(DateTime?, DateTime?, bool) onPickEnd;

  final ValueChanged<bool> onToggleAllDay;

  const _EventPropertiesPanel({
    required this.item,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onToggleAllDay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final props      = propsAsync.valueOrNull ?? [];
    final startStr   = props.where((p) => p.key == 'start_time')
        .firstOrNull?.value;
    final endStr     = props.where((p) => p.key == 'end_time')
        .firstOrNull?.value;
    final allDay     = props.where((p) => p.key == 'all_day')
        .firstOrNull?.value == 'true';

    final startTime = startStr != null ? DateTime.tryParse(startStr) : null;
    final endTime   = endStr != null ? DateTime.tryParse(endStr) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.sm),

        // All day toggle
        _PropRow(
          icon:  Icons.wb_sunny_rounded,
          label: 'Ολοήμερο',
          child: Switch(
            value: allDay,
            onChanged: (value) {
              // Γράφουμε ΠΑΝΤΑ την τιμή που ζήτησε ο χρήστης
              onToggleAllDay(value);
            },
            activeThumbColor: context.cPrimary,
          ),
        ),

        // Start time
        _PropRow(
          icon:  Icons.schedule_rounded,
          label: 'Έναρξη',
          child: GestureDetector(
            onTap: () => onPickStart(startTime, allDay),
            child: Text(
              startTime != null
                  ? (allDay
                  ? startTime.short
                  : startTime.dateTime)
                  : 'Επιλογή',
              style: context.bodyMd.withColor(
                  startTime != null ? context.cText : context.cText2),
            ),
          ),
        ),

        // End time
        _PropRow(
          icon:  Icons.schedule_outlined,
          label: 'Λήξη',
          child: GestureDetector(
            onTap: () => onPickEnd(endTime, startTime, allDay),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  endTime != null
                      ? (allDay ? endTime.short : endTime.timeOnly)
                      : 'Επιλογή',
                  style: context.bodyMd.withColor(
                      endTime != null
                          ? context.cText : context.cText2),
                ),
                if (endTime != null) ...[
                  const SizedBox(width: Spacing.xs),
                  GestureDetector(
                    onTap: () => ref
                        .read(propertyNotifierProvider(item.id).notifier)
                        .remove('end_time'),
                    child: Icon(Icons.close_rounded,
                        size: 14, color: context.cText2),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: Spacing.sm),
      ],
    );
  }
}

class _PropRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _PropRow({
    required this.icon, required this.label, required this.child});

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