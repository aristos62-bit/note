// lib/features/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'event_detail_screen.dart';

final _monthEventsProvider =
FutureProvider.family<Map<DateTime, List<Item>>, DateTime>(
        (ref, month) async {
      final allItems = ref.watch(itemsStreamProvider).valueOrNull ?? [];
      final events = allItems.where((i) => i.type == ItemType.event).toList();
      final result = <DateTime, List<Item>>{};

      for (final event in events) {
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
      return result;
    });

final _selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final _focusedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int? _selectedFolderId;
  bool _userExplicitlySelected = false;
  final GlobalKey<ItemListEmbeddedState> _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Η αρχική επιλογή θα γίνει στο build όταν φορτώσουν οι φάκελοι
  }

  @override
  Widget build(BuildContext context) {
    final focusedMonth = ref.watch(_focusedMonthProvider);
    final selectedDay = ref.watch(_selectedDayProvider);
    final monthAsync = ref.watch(_monthEventsProvider(focusedMonth));
    final foldersAsync = ref.watch(foldersStreamProvider);
    final folders = foldersAsync.valueOrNull ?? [];

    // ✅ Διαβάζουμε την προτίμηση του χρήστη από τις ρυθμίσεις
    final preferredId = ref.watch(preferredFolderIdProvider);

    // ✅ Αυτόματη επιλογή φακέλου μόνο αν ο χρήστης δεν έχει επιλέξει ρητά
    if (!_userExplicitlySelected) {
      foldersAsync.whenData((_) {
        if (_selectedFolderId == null && mounted && folders.isNotEmpty) {
          int? targetId = preferredId;
          // Αν ο preferred δεν υπάρχει ή είναι null, πέφτουμε στον system
          if (targetId == null || !folders.any((f) => f.id == targetId)) {
            targetId = folders.firstWhere(
                  (f) => f.isSystem,
              orElse: () => folders.first,
            ).id;
          }
          setState(() => _selectedFolderId = targetId);
          DebugConfig.nav('Calendar: auto-selected folder id=$targetId (preferredId=$preferredId)');
        }
      });
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
          if (folders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: FolderChipSelector(
                folders: folders,
                selectedFolderId: _selectedFolderId,
                onSelect: (id) {
                  setState(() {
                    _selectedFolderId = id;
                    _userExplicitlySelected = true;   // ✅ ο χρήστης έκανε ρητή επιλογή
                  });
                },
              ),
            ),
          Expanded(
            child: ResponsiveLayout(
              mobile: _buildMobile(
                  context, ref, focusedMonth, selectedDay, monthAsync),
              tablet: _buildTablet(
                  context, ref, focusedMonth, selectedDay, monthAsync),
            ),
          ),
        ],
      ),
    );
  }

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
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => _listKey.currentState?.toggleSearch(),
          tooltip: 'Αναζήτηση',
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            final cur = ref.read(_focusedMonthProvider);
            ref.read(_focusedMonthProvider.notifier).state =
                DateTime(cur.year, cur.month - 1);
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
            ref.read(_focusedMonthProvider.notifier).state =
                DateTime(cur.year, cur.month + 1);
          },
        ),
      ],
    );
  }

  Widget _buildMobile(
      BuildContext context,
      WidgetRef ref,
      DateTime focusedMonth,
      DateTime selectedDay,
      AsyncValue<Map<DateTime, List<Item>>> monthAsync,
      ) {
    return Column(
      children: [
        _MonthGrid(
          focusedMonth: focusedMonth,
          selectedDay: selectedDay,
          eventDays: monthAsync.valueOrNull?.keys.toSet() ?? {},
          onDayTap: (day) =>
          ref.read(_selectedDayProvider.notifier).state = day,
        ),
        const Divider(height: 1),
        Expanded(
          child: ItemListEmbedded(
            key: _listKey,
            itemType: ItemType.event,
            folderId: _selectedFolderId,
            onItemTap: (item) => Navigator.of(context).push(
              AppTransitions.slideRoute(EventDetailScreen(itemId: item.id)),
            ),
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
      AsyncValue<Map<DateTime, List<Item>>> monthAsync,
      ) {
    return Row(
      children: [
        SizedBox(
          width: context.isDesktop ? 400 : 340,
          child: Column(
            children: [
              _MonthGrid(
                focusedMonth: focusedMonth,
                selectedDay: selectedDay,
                eventDays: monthAsync.valueOrNull?.keys.toSet() ?? {},
                onDayTap: (day) =>
                ref.read(_selectedDayProvider.notifier).state = day,
              ),
              const Divider(height: 1),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ItemListEmbedded(
            key: _listKey,
            itemType: ItemType.event,
            folderId: _selectedFolderId,
            onItemTap: (item) => Navigator.of(context).push(
              AppTransitions.slideRoute(EventDetailScreen(itemId: item.id)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createEvent(
      BuildContext context, WidgetRef ref, DateTime selectedDay) async {
    final item = await ref.read(itemNotifierProvider.notifier).create(
      type: ItemType.event,
      folderId: _selectedFolderId,
    );
    if (item == null || !context.mounted) return;

    final startTime =
    DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 9, 0);
    await ref
        .read(propertyNotifierProvider(item.id).notifier)
        .setDate('start_time', startTime);

    if (!context.mounted) return;
    Navigator.of(context).push(
      AppTransitions.slideRoute(
          EventDetailScreen(itemId: item.id, isNew: true)),
    );
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
          Row(
            children: _weekDays
                .map((d) => Expanded(
              child: Center(
                child: Text(d,
                    style:
                    context.labelSm.withColor(context.cText2)),
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: Spacing.xs),
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