// lib/features/calendar/calendar_screen.dart
//
// Calendar screen: month view + event list.
// Custom month grid — χωρίς εξωτερικό package.
// ✅ Responsive: mobile (month+list) / tablet (side-by-side)
// ✅ Dark mode: ColorsUI + context extensions + ItemColorHelper
// ✅ DebugConfig: nav, db, provider logs
// ✅ ViewMode toggle (pinned/favorites/all) τοποθετημένο κάτω από το ημερολόγιο
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'event_detail_screen.dart';
import '../../helpers/item_color_helper.dart';

/// Όλα τα events του workspace (real-time μέσα από το itemsStreamProvider)
final _eventsProvider = FutureProvider<List<Item>>((ref) async {
  final itemsAsync = ref.watch(itemsStreamProvider);

  // Αν ήδη έχουμε data, χρησιμοποίησέ τα
  final items = itemsAsync.maybeWhen(
    data: (list) => list,
    orElse: () => <Item>[],
  );

  final events = items.where((i) => i.type == ItemType.event).toList();
  DebugConfig.db('_eventsProvider events=${events.length}');
  return events;
});

/// Events ενός συγκεκριμένου μήνα (μετά φόρτωση start_time)
final _monthEventsProvider =
FutureProvider.family<Map<DateTime, List<Item>>, DateTime>(
        (ref, month) async {
      final allEvents = await ref.watch(_eventsProvider.future);
      final result = <DateTime, List<Item>>{};

      for (final event in allEvents) {
        final props = await ref.watch(itemPropertiesProvider(event.id).future);
        final startStr =
            props.where((p) => p.key == 'start_time').firstOrNull?.value;
        if (startStr == null) continue;
        final start = DateTime.tryParse(startStr);
        if (start == null) continue;
        if (start.year != month.year || start.month != month.month) continue;
        final day = DateTime(start.year, start.month, start.day);
        result.putIfAbsent(day, () => []).add(event);
      }
      DebugConfig.db('_monthEventsProvider month=$month days=${result.length}');
      return result;
    });

/// Selected day
final _selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Focused month
final _focusedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// ════════════════════════════════════════════════════════════════
// CALENDAR SCREEN
// ════════════════════════════════════════════════════════════════

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int? _selectedFolderId;

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('CalendarScreen build');

    final focusedMonth = ref.watch(_focusedMonthProvider);
    final selectedDay = ref.watch(_selectedDayProvider);
    final monthAsync = ref.watch(_monthEventsProvider(focusedMonth));
    final foldersAsync = ref.watch(foldersStreamProvider);
    final folders = foldersAsync.valueOrNull ?? [];

    // Φιλτράρισμα events ανά folder + view mode
    final allEventsForDay = monthAsync.valueOrNull?[selectedDay] ?? [];
    var eventsForDay = allEventsForDay;
    if (_selectedFolderId != null) {
      eventsForDay = eventsForDay
          .where((e) => e.folderId == _selectedFolderId)
          .toList();
    }
    // 🔹 Φιλτράρισμα view mode
    final viewMode = ref.watch(listViewModeProvider);
    switch (viewMode) {
      case ListViewMode.pinned:
        eventsForDay = eventsForDay.where((e) => e.pinned).toList();
        break;
      case ListViewMode.favorites:
        eventsForDay = eventsForDay.where((e) => e.favorite).toList();
        break;
      case ListViewMode.all:
        break;
    }

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, ref, focusedMonth),
      floatingActionButton: _selectedFolderId != null
          ? FloatingActionButton(
        onPressed: () => _createEvent(context, ref, selectedDay),
        tooltip: 'Νέο συμβάν',
        child: const Icon(Icons.add_rounded),
      )
          : null,
      body: Column(
        children: [
          // ── Folder selector ───────────────────────────────
          if (folders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: FolderChipSelector(
                folders: folders,
                selectedFolderId: _selectedFolderId,
                onSelect: (id) {
                  setState(() => _selectedFolderId = id);
                  DebugConfig.nav('Calendar: select folder id=$id');
                },
              ),
            ),
          // ── Calendar body (με το toggle μέσα) ─────────────────
          Expanded(
            child: ResponsiveLayout(
              mobile: _buildMobile(context, ref, focusedMonth, selectedDay,
                  monthAsync, eventsForDay),
              tablet: _buildTablet(context, ref, focusedMonth, selectedDay,
                  monthAsync, eventsForDay),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────

  AppBar _buildAppBar(
      BuildContext context, WidgetRef ref, DateTime focusedMonth) {
    final months = [
      'Ιανουάριος',
      'Φεβρουάριος',
      'Μάρτιος',
      'Απρίλιος',
      'Μάιος',
      'Ιούνιος',
      'Ιούλιος',
      'Αύγουστος',
      'Σεπτέμβριος',
      'Οκτώβριος',
      'Νοέμβριος',
      'Δεκέμβριος',
    ];

    return AppBar(
      backgroundColor: context.cBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Text('${months[focusedMonth.month - 1]} ${focusedMonth.year}',
          style: context.titleLg),
      actions: [
        // Prev month
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            final cur = ref.read(_focusedMonthProvider);
            ref.read(_focusedMonthProvider.notifier).state =
                DateTime(cur.year, cur.month - 1);
            DebugConfig.nav('Calendar: prevMonth');
          },
        ),
        // Today
        TextButton(
          onPressed: () {
            final now = DateTime.now();
            ref.read(_focusedMonthProvider.notifier).state =
                DateTime(now.year, now.month);
            ref.read(_selectedDayProvider.notifier).state =
                DateTime(now.year, now.month, now.day);
            DebugConfig.nav('Calendar: today');
          },
          child: const Text('Σήμερα'),
        ),
        // Next month
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            final cur = ref.read(_focusedMonthProvider);
            ref.read(_focusedMonthProvider.notifier).state =
                DateTime(cur.year, cur.month + 1);
            DebugConfig.nav('Calendar: nextMonth');
          },
        ),
      ],
    );
  }

  // ── Mobile — month grid on top, then toggle, then events list ──

  Widget _buildMobile(
      BuildContext context,
      WidgetRef ref,
      DateTime focusedMonth,
      DateTime selectedDay,
      AsyncValue<Map<DateTime, List<Item>>> monthAsync,
      List<Item> eventsForDay,
      ) {
    return Column(
      children: [
        // Month grid
        _MonthGrid(
          focusedMonth: focusedMonth,
          selectedDay: selectedDay,
          eventDays: monthAsync.valueOrNull?.keys.toSet() ?? {},
          onDayTap: (day) {
            DebugConfig.provider('Calendar: selectDay $day');
            ref.read(_selectedDayProvider.notifier).state = day;
          },
        ),
        Divider(height: 1, color: ColorsUI.getBorder(context.brightness)),
        // View mode toggle κάτω από το ημερολόγιο
        const ViewModeToggle(),
        const SizedBox(height: Spacing.xs),
        // Events list
        Expanded(
          child: _EventsList(
            day: selectedDay,
            events: eventsForDay,
            onTap: (id) => Navigator.of(context).push(
                AppTransitions.slideRoute(EventDetailScreen(itemId: id))),
          ),
        ),
      ],
    );
  }

  // ── Tablet — month grid left, then toggle, then events right ──

  Widget _buildTablet(
      BuildContext context,
      WidgetRef ref,
      DateTime focusedMonth,
      DateTime selectedDay,
      AsyncValue<Map<DateTime, List<Item>>> monthAsync,
      List<Item> eventsForDay,
      ) {
    return Row(
      children: [
        // Left: calendar column (grid + toggle)
        SizedBox(
          width: context.isDesktop ? 400 : 340,
          child: Column(
            children: [
              _MonthGrid(
                focusedMonth: focusedMonth,
                selectedDay: selectedDay,
                eventDays: monthAsync.valueOrNull?.keys.toSet() ?? {},
                onDayTap: (day) {
                  ref.read(_selectedDayProvider.notifier).state = day;
                },
              ),
              const Divider(height: 1),
              const ViewModeToggle(),
              const SizedBox(height: Spacing.xs),
            ],
          ),
        ),
        VerticalDivider(
            width: 1, color: ColorsUI.getBorder(context.brightness)),
        // Right: events
        Expanded(
          child: _EventsList(
            day: selectedDay,
            events: eventsForDay,
            onTap: (id) => Navigator.of(context).push(
                AppTransitions.slideRoute(EventDetailScreen(itemId: id))),
          ),
        ),
      ],
    );
  }

  // ── Create event ─────────────────────────────────────────────

  Future<void> _createEvent(
      BuildContext context, WidgetRef ref, DateTime selectedDay) async {
    DebugConfig.nav('Calendar: createEvent for $selectedDay');
    final item = await ref.read(itemNotifierProvider.notifier).create(
      type: ItemType.event,
      folderId: _selectedFolderId,
    );
    if (item == null || !context.mounted) return;

    final startTime = DateTime(
        selectedDay.year, selectedDay.month, selectedDay.day, 9, 0);
    await ref
        .read(propertyNotifierProvider(item.id).notifier)
        .setDate('start_time', startTime);

    if (!context.mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.of(context).push(
      AppTransitions.slideRoute(
          EventDetailScreen(itemId: item.id, isNew: true)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MONTH GRID (ίδιο)
// ════════════════════════════════════════════════════════════════

class _MonthGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Set<DateTime> eventDays;
  final ValueChanged<DateTime> onDayTap;

  static const _weekDays = ['Δ', 'Τ', 'Τ', 'Π', 'Π', 'Σ', 'Κ'];

  const _MonthGrid({
    required this.focusedMonth,
    required this.selectedDay,
    required this.eventDays,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    // Monday=1 … Sunday=7 → offset 0-6
    final startOffset = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth =
    DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);

    return Container(
      color: ColorsUI.getSurface(context.brightness),
      padding:
      const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.sm),
      child: Column(
        children: [
          // Day headers
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

          // Day cells
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
              final date =
              DateTime(focusedMonth.year, focusedMonth.month, day);
              final isToday = date == today;
              final isSelected = date == selectedDay;
              final hasEvent = eventDays.contains(date);

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
                    children: [
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
                      // Event dot
                      if (hasEvent && !isSelected)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: context.cPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// EVENTS LIST — για επιλεγμένη ημέρα (ίδιο)
// ════════════════════════════════════════════════════════════════

class _EventsList extends StatelessWidget {
  final DateTime day;
  final List<Item> events;
  final ValueChanged<int> onTap;

  const _EventsList({
    required this.day,
    required this.events,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final months = [
      '',
      'Ιαν',
      'Φεβ',
      'Μαρ',
      'Απρ',
      'Μαΐ',
      'Ιουν',
      'Ιουλ',
      'Αυγ',
      'Σεπ',
      'Οκτ',
      'Νοε',
      'Δεκ',
    ];
    final weekDays = [
      '',
      'Δευτέρα',
      'Τρίτη',
      'Τετάρτη',
      'Πέμπτη',
      'Παρασκευή',
      'Σάββατο',
      'Κυριακή',
    ];
    final dayLabel =
        '${weekDays[day.weekday]}, ${day.day} ${months[day.month]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.responsiveHPadding,
            Spacing.md,
            context.responsiveHPadding,
            Spacing.sm,
          ),
          child: Text(dayLabel, style: context.titleSm),
        ),

        // Events
        Expanded(
          child: events.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_available_rounded,
                    size: 48, color: context.cDisabled),
                const SizedBox(height: Spacing.sm),
                Text('Δεν υπάρχουν συμβάντα',
                    style: context.bodyMd.withColor(context.cDisabled)),
              ],
            ),
          )
              : ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHPadding,
              vertical: Spacing.xs,
            ),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
            itemBuilder: (_, i) => _EventTile(
              event: events[i],
              onTap: () => onTap(events[i].id),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// EVENT TILE — με χρήση ItemColorHelper (ίδιο)
// ════════════════════════════════════════════════════════════════

class _EventTile extends ConsumerWidget {
  final Item event;
  final VoidCallback onTap;

  const _EventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(event.id));
    final props = propsAsync.valueOrNull ?? [];
    final startStr =
        props.where((p) => p.key == 'start_time').firstOrNull?.value;
    final endStr = props.where((p) => p.key == 'end_time').firstOrNull?.value;
    final location = props.where((p) => p.key == 'location').firstOrNull?.value;
    final allDay =
        props.where((p) => p.key == 'all_day').firstOrNull?.value == 'true';

    final startTime = startStr != null ? DateTime.tryParse(startStr) : null;
    final endTime = endStr != null ? DateTime.tryParse(endStr) : null;

    // ⭐ Χρώμα φόντου από ItemColorHelper
    final backgroundColor =
    ItemColorHelper.backgroundColorForType(ItemType.event, context);
    // ⭐ Χρώμα κειμένου με βάση την αντίθεση
    final foregroundColor =
    ItemColorHelper.textColorForBackground(backgroundColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha:0.7);
    // ⭐ Χρώμα accent bar
    final accentColor = ItemColorHelper.iconColorForType(ItemType.event, context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.cardBR,
          border: Border.all(color: ColorsUI.getBorder(context.brightness)),
        ),
        child: Row(
          children: [
            // Color bar (accent)
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Builder(
                    builder: (_) {
                      final rawTitle = event.title ?? '';
                      final hasTitle = rawTitle.trim().isNotEmpty;
                      final title = hasTitle ? rawTitle : '(χωρίς τίτλο)';

                      return Text(
                        title,
                        style: context.titleSm.copyWith(
                          color: hasTitle ? foregroundColor : secondaryForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),

                  const SizedBox(height: 4),

                  // Time
                  if (allDay)
                    Text(
                      'Ολοήμερο',
                      style: context.bodySm.copyWith(color: secondaryForeground),
                    )
                  else if (startTime != null)
                    Text(
                      endTime != null
                          ? '${startTime.timeOnly} – ${endTime.timeOnly}'
                          : startTime.timeOnly,
                      style: context.bodySm.copyWith(color: secondaryForeground),
                    ),

                  // Location
                  if (location != null && location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: secondaryForeground,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            location,
                            style: context.bodySm.copyWith(color: secondaryForeground),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            Icon(Icons.chevron_right_rounded,
                size: 18, color: secondaryForeground),
          ],
        ),
      ),
    );
  }
}