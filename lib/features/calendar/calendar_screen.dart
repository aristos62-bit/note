// lib/features/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import '../../helpers/item_color_helper.dart';
import 'event_detail_screen.dart';
import 'span_utils.dart';
import '../contacts/contact_detail_screen.dart';
import '../../services/services.dart';

// ── Τύποι δημιουργίας συμβάντος ─────────────────────────────
enum _EventCreationType { event, birthday, specialDay }

// ── Τύπος ενδείξεων ημερολογίου (για sorting/display) ────────
enum _DayMarkerType { birthday, specialDay, event }

/// E41 — Δεδομένα μήνα: ημέρες → items (για πλέγμα + λίστα ημέρας) και
/// ημέρες → γραμμή πολυήμερου.
class _MonthData {
  final Map<DateTime, List<Item>> days;
  final Map<DateTime, SpanDay> bars;

  const _MonthData(this.days, this.bars);

  static const empty = _MonthData({}, {});
}

final _monthEventsProvider =
    FutureProvider.family<_MonthData, DateTime>((ref, month) async {
  // E41: το itemsStream ακούει μόνο τη collection `items` — οι αλλαγές σε
  // properties (start/end/span) χρειάζονται explicit version bump.
  ref.watch(calendarDataVersionProvider);
  final selectedFolderId = ref.watch(selectedFolderIdProvider);
  final allItems = ref.watch(itemsStreamProvider).valueOrNull ?? [];
  // S272 (E38): «Όλοι» = null → όλα· αλλιώς μόνο τα items του ακριβούς φακέλου
  // (όχι υποφάκελοι). Ισχύει και για το πλέγμα μήνα (events + γενέθλια).
  final events = allItems
      .where((i) =>
          i.type == ItemType.event &&
          (selectedFolderId == null || i.folderId == selectedFolderId))
      .toList();
  final contacts = allItems
      .where((i) =>
          i.type == ItemType.contact &&
          (selectedFolderId == null || i.folderId == selectedFolderId))
      .toList();
  final result = <DateTime, List<Item>>{};

  void addDay(DateTime day, Item item) {
    final list = result.putIfAbsent(day, () => []);
    if (!list.any((e) => e.id == item.id)) list.add(item);
  }

  // E41: 1 query για όλα τα events (πριν: N+1 — ένα getAll ανά event).
  final Map<int, List<ItemProperty>> propsMap = events.isEmpty
      ? const {}
      : await ref
          .read(dbProvider)
          .properties
          .getAllForItems([for (final e in events) e.id]);

  final spans = <SpanCandidate>[];

  for (final event in events) {
    final props = propsMap[event.id] ?? const <ItemProperty>[];
    final startStr = props
        .where((p) => p.key == PropertyKeys.startTime)
        .firstOrNull
        ?.value;
    if (startStr == null) continue;
    final start = DateTime.tryParse(startStr);
    if (start == null) continue;

    // E41: εύρος πολυήμερου. 🎂 γενέθλια εξαιρούνται (κανόνας).
    if (!ItemColorHelper.isBirthdayEvent(event)) {
      final range = spanRangeOf(props);
      if (range != null) {
        spans.add(SpanCandidate(
          itemId: event.id,
          range: range,
          colorHex: spanColorOf(props),
        ));
      }
    }

    if (start.year != month.year || start.month != month.month) continue;
    addDay(DateTime(start.year, start.month, start.day), event);
  }

  // E41: κάθε ημέρα του εύρους μπαίνει στη λίστα ημέρας — ακόμη κι αν η
  // γραμμή χάσει το lane σε επικάλυψη (all-or-nothing).
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 0);
  final byId = {for (final e in events) e.id: e};
  for (final s in spans) {
    final event = byId[s.itemId];
    if (event == null) continue;
    for (var i = 0; i < s.range.days; i++) {
      final day = DateTime(
          s.range.start.year, s.range.start.month, s.range.start.day + i);
      if (day.isBefore(monthStart) || day.isAfter(monthEnd)) continue;
      addDay(day, event);
    }
  }

  final bars = buildSpanBars(spans: spans, month: month);

  // Επέκταση ετήσιων στους μελλοντικούς μήνες (display-only, ίδιο Item —
  // tap ανοίγει τη σειρά). Μόνο yearly (birthdays + bell-yearly).
  final allRoots = await ref
      .read(dbProvider)
      .isar
      .reminders
      .filter()
      .rruleIsNotNull()
      .parentReminderIdIsNull()
      .findAll();
  final byItem = <int, Reminder>{};
  for (final r in allRoots) {
    if (r.rrule == null || r.rrule!.isEmpty) continue;
    byItem.putIfAbsent(r.itemId, () => r);
  }
  for (final event in events) {
    final root = byItem[event.id];
    if (root == null || root.rrule == null) continue;
    final day = yearlyOccurrenceDay(
        root.rrule!, root.triggerAt, month.year, month.month);
    if (day == null) continue;
    addDay(DateTime(month.year, month.month, day), event);
  }

  // Γενέθλια επαφών (display-only, ίδιο Item — tap ανοίγει την επαφή).
  // Batch props (1 query, όχι N+1 όπως τα events).
  if (contacts.isNotEmpty) {
    final propsMap = await ref
        .read(dbProvider)
        .properties
        .getAllForItems([for (final c in contacts) c.id]);
    var added = 0;
    for (final c in contacts) {
      final props = propsMap[c.id] ?? const [];
      final bStr =
          props.where((p) => p.key == 'birthday').firstOrNull?.value;
      final b = bStr != null ? DateTime.tryParse(bStr) : null;
      if (b == null) continue;
      final day = contactBirthdayDay(b, month.year, month.month);
      if (day == null) continue;
      addDay(DateTime(month.year, month.month, day), c);
      added++;
    }
    DebugConfig.db('Calendar month ${month.month}/${month.year}: contact birthdays added=$added');
  }
  return _MonthData(result, bars);
});

final _selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final _focusedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Κρατάει την επιλεγμένη μέρα μέσα στον ορατό μήνα.
/// Clamp (όχι rollover — η Dart κυλάει 31 Φεβ → 3 Μαρ).
DateTime _clampDay(DateTime day, DateTime month) {
  final max = DateUtils.getDaysInMonth(month.year, month.month);
  return DateTime(month.year, month.month, day.day > max ? max : day.day);
}

// ── Επικεφαλίδα ημέρας πάνω από τη λίστα ────────────────────────

class _DayHeader extends StatelessWidget {
  final DateTime day;
  const _DayHeader({required this.day});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.sm, Spacing.xs, Spacing.sm, 0),
      child: Row(
        children: [
          Icon(Icons.event_rounded, size: 16, color: context.cText2),
          const SizedBox(width: Spacing.xs),
          Text(
            AppDateUtils.groupHeader(day),
            style: context.labelMd.withColor(context.cText2),
          ),
        ],
      ),
    );
  }
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final GlobalKey<ItemListEmbeddedState> _listKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final focusedMonth = ref.watch(_focusedMonthProvider);
    final selectedDay = ref.watch(_selectedDayProvider);
    final monthAsync = ref.watch(_monthEventsProvider(focusedMonth));

    // Day-scope: ids των events της επιλεγμένης μέρας (0 νέα queries).
    // Κενό set = άδεια μέρα (ΟΧΙ null — το null σημαίνει «χωρίς φίλτρο»).
    final monthData = monthAsync.valueOrNull ?? _MonthData.empty;
    final dayMap = monthData.days;
    final Set<int>? dayIds = monthAsync.hasError
        ? null
        : (dayMap[selectedDay]?.map((e) => e.id).toSet() ?? <int>{});
    final dayLoading = monthAsync.isLoading;

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, ref, focusedMonth),
      // S272 (E38): πάντα ορατό — σε «Όλοι» ο picker επιλέγει φάκελο.
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreationMenu(context, ref, selectedDay),
        tooltip: 'Νέο συμβάν',
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          const DraggableFolderSelector(),
          Expanded(
            child: ResponsiveLayout(
              mobile: _buildMobile(
                  context, ref, focusedMonth, selectedDay, monthAsync,
                  dayIds: dayIds, dayLoading: dayLoading),
              tablet: _buildTablet(
                  context, ref, focusedMonth, selectedDay, monthAsync,
                  dayIds: dayIds, dayLoading: dayLoading),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(
      BuildContext context, WidgetRef ref, DateTime focusedMonth) {
    return AppBar(
      backgroundColor: context.cBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Text(
        AppDateUtils.formatMonth(focusedMonth, compact: true),
        style: context.titleLg,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => _listKey.currentState?.toggleSearch(),
          tooltip: 'Αναζήτηση',
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            final cur = ref.read(_focusedMonthProvider);
            final next = DateTime(cur.year, cur.month - 1);
            ref.read(_focusedMonthProvider.notifier).state = next;
            final synced =
                _clampDay(ref.read(_selectedDayProvider), next);
            ref.read(_selectedDayProvider.notifier).state = synced;
            DebugConfig.nav('Calendar month ${next.month}/${next.year} day synced $synced');
          },
        ),
        TextButton(
          onPressed: () {
            final now = DateTime.now();
            ref.read(_focusedMonthProvider.notifier).state =
                DateTime(now.year, now.month);
            ref.read(_selectedDayProvider.notifier).state =
                DateTime(now.year, now.month, now.day);
          },
          child: const Text('Σήμερα'),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            final cur = ref.read(_focusedMonthProvider);
            final next = DateTime(cur.year, cur.month + 1);
            ref.read(_focusedMonthProvider.notifier).state = next;
            final synced =
                _clampDay(ref.read(_selectedDayProvider), next);
            ref.read(_selectedDayProvider.notifier).state = synced;
            DebugConfig.nav('Calendar month ${next.month}/${next.year} day synced $synced');
          },
        ),
      ],
    );
  }

  Widget _buildArchivedToggle() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Align(
        alignment: Alignment.centerRight,
        child: ArchivedInlineButton(),
      ),
    );
  }

  /// Κοινό tap ημέρας (mobile + tablet): μόνο selectedDay (η λίστα δείχνει
  /// τις κάρτες — το χρώμα δείχνει επαφή/event/γενέθλια/ειδική).
  void _onDayTap(DateTime day) {
    ref.read(_selectedDayProvider.notifier).state = day;
    DebugConfig.nav('Calendar day selected $day');
  }

  /// Κοινό άνοιγμα γραμμής ημέρας (mobile + tablet): επαφή → ContactDetail.
  void _openDayItem(Item item) {
    final page = item.type == ItemType.contact
        ? ContactDetailScreen(itemId: item.id)
        : EventDetailScreen(itemId: item.id);
    Navigator.of(context).push(AppTransitions.slideRoute(page));
  }

  Widget _buildMobile(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedMonth,
    DateTime selectedDay,
    AsyncValue<_MonthData> monthAsync, {
    Set<int>? dayIds,
    bool dayLoading = false,
  }) {
    return Column(
      children: [
        _MonthGrid(
          focusedMonth: focusedMonth,
          selectedDay: selectedDay,
          // ✅ Περνάμε ολόκληρο το map (items με icon info)
          dayEvents: monthAsync.valueOrNull?.days ?? const {},
          spanBars: monthAsync.valueOrNull?.bars ?? const {},
          onDayTap: (day) => _onDayTap(day),
        ),
        const Divider(height: 1),
        _DayHeader(day: selectedDay),
        _buildArchivedToggle(),
        Flexible(
          fit: FlexFit.tight,
          child: ItemListEmbedded(
            key: _listKey,
            itemType: ItemType.event,
            folderId: ref.watch(selectedFolderIdProvider),
            showFolderSelector: false,
            onlyIds: dayIds,
            dayLoading: dayLoading,
            allowMixedTypes: true,
            onItemTap: (item) => _openDayItem(item),
            onShare: (item) => ShareService.shareItem(context, item.id),
          ),
        ),
      ],
    );
  }

  Widget _buildTablet(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedMonth,
    DateTime selectedDay,
    AsyncValue<_MonthData> monthAsync, {
    Set<int>? dayIds,
    bool dayLoading = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: context.isDesktop ? 400 : 340,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _MonthGrid(
                  focusedMonth: focusedMonth,
                  selectedDay: selectedDay,
                  dayEvents: monthAsync.valueOrNull?.days ?? const {},
                  spanBars: monthAsync.valueOrNull?.bars ?? const {},
                  onDayTap: (day) => _onDayTap(day),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Flexible(
          fit: FlexFit.tight,
          child: Column(
            children: [
              _DayHeader(day: selectedDay),
              _buildArchivedToggle(),
              Flexible(
                fit: FlexFit.tight,
                child: ItemListEmbedded(
                  key: _listKey,
                  itemType: ItemType.event,
                  folderId: ref.watch(selectedFolderIdProvider),
                  showFolderSelector: false,
                  onlyIds: dayIds,
                  dayLoading: dayLoading,
                  allowMixedTypes: true,
                  onItemTap: (item) => _openDayItem(item),
                  onShare: (item) => ShareService.shareItem(context, item.id),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Creation menu
  // ──────────────────────────────────────────────────────────────

  Future<void> _showCreationMenu(
      BuildContext context, WidgetRef ref, DateTime selectedDay) async {
    final isDark = context.brightness == Brightness.dark;
    final type = await showSafeSheet<_EventCreationType>(
      context,
      builder: (sheetCtx) => SafeSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.sm),
              child: Row(
                children: [Text('Νέο συμβάν', style: sheetCtx.titleMd)],
              ),
            ),
            const Divider(height: 1),
            _EventTypeOption(
              icon: Icons.event_rounded,
              iconBgColor: isDark ? Colors.indigo.shade900 : Colors.indigo.shade100,
              iconColor: isDark ? Colors.indigo.shade200 : Colors.indigo.shade600,
              title: 'Συμβάν',
              subtitle: 'Προγραμματισμένο γεγονός',
              onTap: () => Navigator.pop(sheetCtx, _EventCreationType.event),
            ),
            _EventTypeOption(
              icon: Icons.cake_rounded,
              iconBgColor: ItemColorHelper.birthdayBackground(sheetCtx),
              iconColor: isDark ? Colors.pink.shade200 : Colors.pink.shade600,
              title: 'Γενέθλια',
              subtitle: 'Υπενθύμιση γενεθλίων',
              onTap: () => Navigator.pop(sheetCtx, _EventCreationType.birthday),
            ),
            _EventTypeOption(
              icon: Icons.star_rounded,
              iconBgColor: ItemColorHelper.specialDayBackground(sheetCtx),
              iconColor: isDark ? Colors.amber.shade200 : Colors.amber.shade700,
              title: 'Ειδική Ημέρα',
              subtitle: 'Σημαντική ημερομηνία',
              onTap: () =>
                  Navigator.pop(sheetCtx, _EventCreationType.specialDay),
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );

    if (type == null || !context.mounted) return;

    // S272 (E38): πρώτα τύπος, μετά φάκελος. Σε «Όλοι» ο picker επιλέγει
    // φάκελο χωρίς να αλλάζει η κοινή επιλογή της εφαρμογής.
    final folderId = await resolveFolderForNewItem(context, ref);
    if (folderId == null || !context.mounted) return;

    switch (type) {
      case _EventCreationType.event:
        await _createEvent(context, ref, selectedDay, folderId);
      case _EventCreationType.birthday:
        await _createBirthdayEvent(context, ref, selectedDay, folderId);
      case _EventCreationType.specialDay:
        await _createEventWithIcon(
            context, ref, selectedDay, folderId, ItemColorHelper.kSpecialDayIcon);
    }
  }

  Future<void> _createEvent(BuildContext context, WidgetRef ref,
      DateTime selectedDay, int folderId) async {
    try {
      final item = await ref.read(itemNotifierProvider.notifier).create(
            type: ItemType.event,
            folderId: folderId,
          );
      if (item == null || !context.mounted) return;
      final startTime =
          DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 9, 0);
      final endTime = startTime.add(const Duration(hours: 1));
      final propNotifier = ref.read(propertyNotifierProvider(item.id).notifier);
      await propNotifier.setDate('start_time', startTime);
      await propNotifier.setDate('end_time', endTime);
      if (!context.mounted) return;
      Navigator.of(context).push(
        AppTransitions.slideRoute(
            EventDetailScreen(itemId: item.id, isNew: true)),
      );
    } catch (e) {
      DebugConfig.error('CalendarScreen _createEvent', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppErrors.eventCreateFailed)),
        );
      }
    }
  }


  Future<void> _createBirthdayEvent(BuildContext context, WidgetRef ref,
      DateTime selectedDay, int folderId) async {
    try {
      final item = await ref.read(itemNotifierProvider.notifier).create(
            type: ItemType.event,
            folderId: folderId,
            icon: ItemColorHelper.kBirthdayIcon,
          );
      if (item == null || !context.mounted) return;
      final startTime =
          DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 9, 0);
      final endTime = startTime.add(const Duration(hours: 1));
      final propNotifier = ref.read(propertyNotifierProvider(item.id).notifier);
      await propNotifier.setDate('start_time', startTime);
      await propNotifier.setDate('end_time', endTime);

      // Αυτόματη ετήσια υπενθύμιση (χωρίς καμπάνα — τα γενέθλια είναι 1×/χρόνο).
      final rrule = recurrenceToRRULE(Recurrence.yearly(
        month: selectedDay.month,
        day: selectedDay.day,
      ));
      await ref.read(dbProvider).reminders.create(
            itemId: item.id,
            triggerAt: startTime,
            rrule: rrule,
            title: '🎂 Γενέθλια',
            body: 'Σήμερα είναι γενεθλίων!',
          );
      await ReminderScheduler.instance.refreshRecurringReminders();
      DebugConfig.notif('CalendarScreen _createBirthdayEvent id=${item.id} m=${selectedDay.month} d=${selectedDay.day}');

      if (!context.mounted) return;
      Navigator.of(context).push(
        AppTransitions.slideRoute(
            EventDetailScreen(itemId: item.id, isNew: true)),
      );
    } catch (e) {
      DebugConfig.error('CalendarScreen _createBirthdayEvent', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppErrors.eventCreateFailed)),
        );
      }
    }
  }

  Future<void> _createEventWithIcon(BuildContext context, WidgetRef ref,
      DateTime selectedDay, int folderId, String icon) async {
    try {
      final item = await ref.read(itemNotifierProvider.notifier).create(
            type: ItemType.event,
            folderId: folderId,
            icon: icon,
          );
      if (item == null || !context.mounted) return;
      final startTime =
          DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 9, 0);
      final endTime = startTime.add(const Duration(hours: 1));
      final propNotifier = ref.read(propertyNotifierProvider(item.id).notifier);
      await propNotifier.setDate('start_time', startTime);
      await propNotifier.setDate('end_time', endTime);
      if (!context.mounted) return;
      Navigator.of(context).push(
        AppTransitions.slideRoute(
            EventDetailScreen(itemId: item.id, isNew: true)),
      );
    } catch (e) {
      DebugConfig.error('CalendarScreen _createEventWithIcon', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppErrors.eventCreateFailed)),
        );
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
// EVENT TYPE OPTION TILE (κοινό για το menu)
// ════════════════════════════════════════════════════════════════

class _EventTypeOption extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EventTypeOption({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.xs),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(title,
          style: context.bodyMd.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: context.bodySm.withColor(context.cText2)),
      onTap: onTap,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MONTH GRID — με ενδείξεις τύπου συμβάντος
// ════════════════════════════════════════════════════════════════

class _MonthGrid extends ConsumerWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;

  /// Όλα τα items ανά ημέρα — χρησιμοποιείται για τον τύπο δείκτη
  final Map<DateTime, List<Item>> dayEvents;

  /// E41: πολυήμερα — γραμμή ανά ημέρα (1 lane).
  final Map<DateTime, SpanDay> spanBars;
  final ValueChanged<DateTime> onDayTap;

  static const _weekDays = AppDateUtils.weekdayInitials;

  // ── Χρώματα δεικτών (SPoT: ItemColorHelper) ──────────────────
  static const _birthdayColor = ItemColorHelper.birthdayPink; // pink-500
  static const _specialDayColor = ItemColorHelper.specialAmber; // amber-500

  const _MonthGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.dayEvents,
    required this.spanBars,
    required this.onDayTap,
  });

  /// Υπολογίζει ποιοι τύποι markers υπάρχουν για μια ημέρα.
  /// Επιστρέφει ταξινομημένη λίστα (birthday πρώτα).
  /// E41: τα items που έχουν γραμμή/hatch αυτή την ημέρα δεν μετράνε στις τελείες.
  List<_DayMarkerType> _markersFor(DateTime date, SpanDay? spanBar) {
    final items = dayEvents[date];
    if (items == null || items.isEmpty) return [];

    final barIds = <int>{
      if (spanBar != null) spanBar.itemId,
      if (spanBar != null) ...spanBar.overlays.map((o) => o.itemId),
    };

    final types = <_DayMarkerType>{};
    for (final item in items) {
      if (barIds.contains(item.id)) continue;
      if (ItemColorHelper.isBirthdayEvent(item)) {
        types.add(_DayMarkerType.birthday);
      } else if (item.type == ItemType.contact) {
        // Γενέθλιο επαφής (στο map μπαίνει μόνο σε επέτειο) — φούξια.
        types.add(_DayMarkerType.birthday);
      } else if (ItemColorHelper.isSpecialDayEvent(item)) {
        types.add(_DayMarkerType.specialDay);
      } else {
        types.add(_DayMarkerType.event);
      }
    }

    // Ταξινόμηση: birthday > specialDay > event
    return types.toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final startOffset = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth =
        DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);

    return Container(
      color: ColorsUI.getSurface(context.brightness),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.sm),
      child: Column(
        children: [
          // ── Επικεφαλίδες ημερών ───────────────────────────
          Row(
            children: _weekDays
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: context.labelSm.withColor(context.cText2)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: Spacing.xs),

          // ── Grid ημερών ────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 44,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (_, index) {
              if (index < startOffset) return const SizedBox.shrink();

              final day = index - startOffset + 1;
              final date = DateTime(focusedMonth.year, focusedMonth.month, day);

              final isToday = date == today;
              final isSelected = date == selectedDay;
              final spanBar = spanBars[date];
              final markers = _markersFor(date, spanBar);

              return GestureDetector(
                onTap: () => onDayTap(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.cPrimary
                        : isToday
                            ? context.cPrimary.withValues(alpha: 0.12)
                            : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(color: context.cPrimary, width: 1.5)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // ── Αριθμός ημέρας ──────────────────
                      Text(
                        '$day',
                        style: context.bodyMd.withColor(
                          isSelected
                              ? ColorsUI.getAccessibleTextColor(
                                  context.cPrimary)
                              : isToday
                                  ? context.cPrimary
                                  : context.cText,
                        ),
                      ),

                      // ── E41: γραμμή πολυήμερου (κάτω μέρος κελιού) ──
                      if (spanBar != null)
                        Positioned(
                          bottom: 0,
                          left: -2,
                          right: -2,
                          height: kSpanBarTotalHeight,
                          child: _SpanBar(bar: spanBar),
                        ),

                      // ── Δείκτες τύπου συμβάντων (πάνω μέρος κελιού) ──
                      if (markers.isNotEmpty)
                        Positioned(
                          top: 3,
                          child: _DayMarkerRow(
                            markers: markers,
                            primary: context.cPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Legend ────────────────────────────────────────
          const SizedBox(height: Spacing.xs),
          const _CalendarLegend(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// E41 — SPAN BAR: 3px χρώμα + 1px halo (πάνω/κάτω)
// ════════════════════════════════════════════════════════════════

class _SpanBar extends StatelessWidget {
  final SpanDay bar;

  const _SpanBar({required this.bar});

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;
    final baseColor = spanDayColor(bar, b);
    final overlayColors = [
      for (final o in bar.overlays) spanOverlayColor(o, b)
    ];
    final outer = BorderRadius.horizontal(
      left: bar.isStart
          ? const Radius.circular(kSpanBarTotalHeight / 2)
          : Radius.zero,
      right: bar.isEnd
          ? const Radius.circular(kSpanBarTotalHeight / 2)
          : Radius.zero,
    );
    final inner = BorderRadius.horizontal(
      left: bar.isStart
          ? const Radius.circular(kSpanBarHeight / 2)
          : Radius.zero,
      right: bar.isEnd
          ? const Radius.circular(kSpanBarHeight / 2)
          : Radius.zero,
    );

    return ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          // Halo = ακριβώς το χρώμα του κελιού (αόρατο σε απλή ημέρα)· δίνει
          // 1px απόσταση από τον γεμάτο κύκλο selected/today (2.03:1 / 1.01:1).
          color: spanSurface(b),
          borderRadius: outer,
        ),
        padding: const EdgeInsets.symmetric(vertical: kSpanBarHalo),
        child: CustomPaint(
          painter: _SpanBarPainter(
            base: baseColor,
            overlays: overlayColors,
            overlapBackground: overlayColors.isEmpty
                ? baseColor
                : spanOverlapSurface(baseColor, overlayColors.first, b),
            radius: inner,
          ),
        ),
      ),
    );
  }
}

/// E41 — ζωγραφίζει τη γραμμή: συμπαγής βάση + 45° λωρίδες (hatch) για τα
/// εύρη που επικαλύπτουν την ίδια ημέρα.
class _SpanBarPainter extends CustomPainter {
  /// 1px λωρίδα ανά 3px (στα 3px ύψους διαβάζεται ως «hatch», όχι θόρυβος).
  static const double _stripeStep = 3.0;
  static const double _stripeWidth = 1.0;

  final Color base;
  final List<Color> overlays;
  final Color overlapBackground;
  final BorderRadius radius;

  const _SpanBarPainter({
    required this.base,
    required this.overlays,
    required this.overlapBackground,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: radius.topLeft,
      topRight: radius.topRight,
      bottomLeft: radius.bottomLeft,
      bottomRight: radius.bottomRight,
    );

    canvas.drawRRect(
      rrect,
      Paint()..color = overlays.isEmpty ? base : overlapBackground,
    );
    if (overlays.isEmpty) return;

    canvas.save();
    canvas.clipRRect(rrect);
    final paint = Paint()
      ..strokeWidth = _stripeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    var index = 0;
    for (var x = -size.height;
        x < size.width + size.height;
        x += _stripeStep) {
      paint.color = overlays[index % overlays.length];
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
      index++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SpanBarPainter old) {
    if (old.base != base ||
        old.overlapBackground != overlapBackground ||
        old.radius != radius ||
        old.overlays.length != overlays.length) {
      return true;
    }
    for (var i = 0; i < overlays.length; i++) {
      if (old.overlays[i] != overlays[i]) return true;
    }
    return false;
  }
}

// ════════════════════════════════════════════════════════════════
// DAY MARKER ROW — σειρά κουκκίδων ανά τύπο
// ════════════════════════════════════════════════════════════════

class _DayMarkerRow extends StatelessWidget {
  final List<_DayMarkerType> markers;
  final Color primary;

  const _DayMarkerRow({
    required this.markers,
    required this.primary,
  });

  Color _colorFor(_DayMarkerType type, Color primary) {
    switch (type) {
      case _DayMarkerType.birthday:
        return _MonthGrid._birthdayColor;
      case _DayMarkerType.specialDay:
        return _MonthGrid._specialDayColor;
      case _DayMarkerType.event:
        return primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Δείχνουμε max 3 κουκκίδες
    final visible = markers.take(3).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: _colorFor(visible[i], primary),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CALENDAR LEGEND — υπόμνημα χρωμάτων
// ════════════════════════════════════════════════════════════════

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _LegendItem(
            color: _MonthGrid._birthdayColor,
            label: 'Γενέθλια',
          ),
          const SizedBox(width: Spacing.md),
          const _LegendItem(
            color: _MonthGrid._specialDayColor,
            label: 'Ειδική ημέρα',
          ),
          const SizedBox(width: Spacing.md),
          _LegendItem(
            color: Theme.of(context).colorScheme.primary,
            label: 'Συμβάν',
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.labelSm.withColor(context.cText2),
        ),
      ],
    );
  }
}
