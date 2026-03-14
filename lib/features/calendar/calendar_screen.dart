// lib/features/calendar/calendar_screen.dart
//
// Calendar screen: month view + event list.
// Custom month grid — χωρίς εξωτερικό package.
// ✅ Responsive: mobile (month+list) / tablet (side-by-side)
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/core.dart';
import '../../core/router/app_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';

// ── Local providers ───────────────────────────────────────────────

/// Όλα τα events του workspace
final _eventsProvider = FutureProvider<List<Item>>((ref) async {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return [];
  DebugConfig.db('_eventsProvider wsId=$wsId');
  return db.items.getByWorkspace(wsId, type: ItemType.event);
});

/// Events ενός συγκεκριμένου μήνα (μετά φόρτωση start_time)
final _monthEventsProvider =
FutureProvider.family<Map<DateTime, List<Item>>, DateTime>(
        (ref, month) async {
      final allEvents = await ref.watch(_eventsProvider.future);
      final result    = <DateTime, List<Item>>{};

      for (final event in allEvents) {
        final props = await ref.watch(
            itemPropertiesProvider(event.id).future);
        final startStr = props
            .where((p) => p.key == 'start_time')
            .firstOrNull?.value;
        if (startStr == null) continue;
        final start = DateTime.tryParse(startStr);
        if (start == null) continue;
        if (start.year != month.year || start.month != month.month) continue;
        final day = DateTime(start.year, start.month, start.day);
        result.putIfAbsent(day, () => []).add(event);
      }
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

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    DebugConfig.provider('CalendarScreen build');

    final focusedMonth  = ref.watch(_focusedMonthProvider);
    final selectedDay   = ref.watch(_selectedDayProvider);
    final monthAsync    = ref.watch(_monthEventsProvider(focusedMonth));

    final eventsForDay  = monthAsync.valueOrNull?[selectedDay] ?? [];

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, ref, focusedMonth),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createEvent(context, ref, selectedDay),
        tooltip: 'Νέο συμβάν',
        child: const Icon(Icons.add_rounded),
      ),
      body: ResponsiveLayout(
        mobile:  _buildMobile(context, ref, focusedMonth,
            selectedDay, monthAsync, eventsForDay),
        tablet:  _buildTablet(context, ref, focusedMonth,
            selectedDay, monthAsync, eventsForDay),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context, WidgetRef ref,
      DateTime focusedMonth) {
    final months = [
      'Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος',
      'Μάιος', 'Ιούνιος', 'Ιούλιος', 'Αύγουστος',
      'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος',
    ];

    return AppBar(
      backgroundColor:        context.cBg,
      elevation:              0,
      scrolledUnderElevation: 1,
      title: Text(
          '${months[focusedMonth.month - 1]} ${focusedMonth.year}',
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

  // ── Mobile — month grid on top, list below ───────────────────

  Widget _buildMobile(
      BuildContext context, WidgetRef ref,
      DateTime focusedMonth, DateTime selectedDay,
      AsyncValue<Map<DateTime, List<Item>>> monthAsync,
      List<Item> eventsForDay,
      ) {
    return Column(
      children: [
        // Month grid
        _MonthGrid(
          focusedMonth: focusedMonth,
          selectedDay:  selectedDay,
          eventDays: monthAsync.valueOrNull?.keys.toSet() ?? {},
          onDayTap: (day) {
            DebugConfig.provider('Calendar: selectDay $day');
            ref.read(_selectedDayProvider.notifier).state = day;
          },
        ),
        Divider(height: 1, color: ColorsUI.getBorder(context.brightness)),
        // Events list
        Expanded(
          child: _EventsList(
            day:    selectedDay,
            events: eventsForDay,
            onTap:  (id) => context.push('/calendar/$id'),
          ),
        ),
      ],
    );
  }

  // ── Tablet — month grid left, list right ─────────────────────

  Widget _buildTablet(
      BuildContext context, WidgetRef ref,
      DateTime focusedMonth, DateTime selectedDay,
      AsyncValue<Map<DateTime, List<Item>>> monthAsync,
      List<Item> eventsForDay,
      ) {
    return Row(
      children: [
        // Left: calendar
        SizedBox(
          width: context.isDesktop ? 400 : 340,
          child: Column(
            children: [
              _MonthGrid(
                focusedMonth: focusedMonth,
                selectedDay:  selectedDay,
                eventDays: monthAsync.valueOrNull?.keys.toSet() ?? {},
                onDayTap: (day) {
                  ref.read(_selectedDayProvider.notifier).state = day;
                },
              ),
            ],
          ),
        ),
        VerticalDivider(
            width: 1,
            color: ColorsUI.getBorder(context.brightness)),
        // Right: events
        Expanded(
          child: _EventsList(
            day:    selectedDay,
            events: eventsForDay,
            onTap:  (id) => context.push('/calendar/$id'),
          ),
        ),
      ],
    );
  }

  // ── Create event ─────────────────────────────────────────────

  Future<void> _createEvent(BuildContext context, WidgetRef ref,
      DateTime selectedDay) async {
    DebugConfig.nav('Calendar: createEvent for $selectedDay');
    final item = await ref.read(itemNotifierProvider.notifier)
        .create(type: ItemType.event);
    if (item == null || !context.mounted) return;

    // Set start_time = selected day 09:00
    final startTime = DateTime(
        selectedDay.year, selectedDay.month, selectedDay.day, 9, 0);
    await ref.read(propertyNotifierProvider(item.id).notifier)
        .setDate('start_time', startTime);

    ref.invalidate(_eventsProvider);
    // ignore: use_build_context_synchronously
    context.push('/calendar/${item.id}');
  }
}

// ════════════════════════════════════════════════════════════════
// MONTH GRID
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
    final now        = DateTime.now();
    final today      = DateTime(now.year, now.month, now.day);
    final firstOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    // Monday=1 … Sunday=7 → offset 0-6
    final startOffset = (firstOfMonth.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(
        focusedMonth.year, focusedMonth.month);

    return Container(
      color: ColorsUI.getSurface(context.brightness),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.sm),
      child: Column(
        children: [
          // Day headers
          Row(
            children: _weekDays.map((d) => Expanded(
              child: Center(
                child: Text(d,
                    style: context.labelSm.withColor(context.cText2)),
              ),
            )).toList(),
          ),
          const SizedBox(height: Spacing.xs),

          // Day cells
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 44,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (_, index) {
              if (index < startOffset) return const SizedBox.shrink();
              final day = index - startOffset + 1;
              final date = DateTime(
                  focusedMonth.year, focusedMonth.month, day);
              final isToday    = date == today;
              final isSelected = date == selectedDay;
              final hasEvent   = eventDays.contains(date);

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
                        ? Border.all(
                        color: context.cPrimary, width: 1.5)
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
                            width: 5, height: 5,
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
// EVENTS LIST — για επιλεγμένη ημέρα
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
      '', 'Ιαν', 'Φεβ', 'Μαρ', 'Απρ', 'Μαΐ', 'Ιουν',
      'Ιουλ', 'Αυγ', 'Σεπ', 'Οκτ', 'Νοε', 'Δεκ',
    ];
    final weekDays = [
      '', 'Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη',
      'Παρασκευή', 'Σάββατο', 'Κυριακή',
    ];
    final dayLabel =
        '${weekDays[day.weekday]}, ${day.day} ${months[day.month]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.responsiveHPadding, Spacing.md,
            context.responsiveHPadding, Spacing.sm,
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
                    style: context.bodyMd
                        .withColor(context.cDisabled)),
              ],
            ),
          )
              : ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHPadding,
              vertical:   Spacing.xs,
            ),
            itemCount:        events.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: Spacing.sm),
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
// EVENT TILE
// ════════════════════════════════════════════════════════════════

class _EventTile extends ConsumerWidget {
  final Item event;
  final VoidCallback onTap;

  const _EventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(event.id));
    final props      = propsAsync.valueOrNull ?? [];
    final startStr   = props.where((p) => p.key == 'start_time')
        .firstOrNull?.value;
    final endStr     = props.where((p) => p.key == 'end_time')
        .firstOrNull?.value;
    final location   = props.where((p) => p.key == 'location')
        .firstOrNull?.value;
    final allDay     = props.where((p) => p.key == 'all_day')
        .firstOrNull?.value == 'true';

    final startTime  = startStr != null ? DateTime.tryParse(startStr) : null;
    final endTime    = endStr != null ? DateTime.tryParse(endStr) : null;

    final color = ColorsUI.itemTypeColor(ItemType.event, context.brightness);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color:        ColorsUI.getCard(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(
              color: ColorsUI.getBorder(context.brightness)),
        ),
        child: Row(
          children: [
            // Color bar
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color:        color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title ?? 'Χωρίς τίτλο',
                      style: context.titleSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // Time
                  if (allDay)
                    Text('Ολοήμερο',
                        style: context.bodySm
                            .withColor(context.cText2))
                  else if (startTime != null)
                    Text(
                      endTime != null
                          ? '${startTime.timeOnly} – ${endTime.timeOnly}'
                          : startTime.timeOnly,
                      style: context.bodySm.withColor(context.cText2),
                    ),
                  // Location
                  if (location != null &&
                      location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: context.cText2),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(location,
                            style: context.bodySm
                                .withColor(context.cText2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: context.cDisabled),
          ],
        ),
      ),
    );
  }
}