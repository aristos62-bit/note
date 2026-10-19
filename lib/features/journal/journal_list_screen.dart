// lib/features/journal/journal_list_screen.dart
//
// Λίστα ημερολογίου — ομαδοποιημένη κατά ημερομηνία.
// ✅ Folder-based: FAB μόνο όταν επιλεγεί φάκελος
// ✅ Responsive: list mobile / grid tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions + ItemColorHelper
// ✅ DebugConfig: nav, db, provider logs
// ✅ ViewMode toggle (pinned/favorites/all) ενσωματωμένο
// ✅ Αυτόματη επιλογή φακέλου βάσει ρυθμίσεων (προεπιλεγμένος ή "Γενικά")
// ✅ Περιμένει τα settings πριν επιλέξει φάκελο (διορθωμένο)
//
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'journal_detail_screen.dart';
import '../../services/services.dart';
import '../../helpers/item_color_helper.dart';
import '../../helpers/super_note_helper.dart';

/// Pure helper: ημερομηνία προβολής εγγραφής (entry_date → fallback).
/// Ίδια σημασιολογία με τα παλιά _getDisplayDate/_DraggableJournalCard (byte-identical αποτελέσματα).
DateTime journalEntryDisplayDate(Item item, List<ItemProperty> props) {
  final str = props.where((p) => p.key == 'entry_date').firstOrNull?.value;
  return (str != null ? DateTime.tryParse(str) : null) ?? item.updatedAt ?? item.createdAt;
}

/// Batch: ημερομηνίες όλων των journal entries — 1 DB call αντί για N.
/// Reactivity: itemsStream (CRUD) + journalDatesVersionProvider (entry_date edits —
/// τα property-writes δεν αγγίζουν Item rows, S130-class). Αγνοεί content/mood σκόπιμα.
/// Κατανάλωση με valueOrNull (entries-precedent): ποτέ loading-flash σε rebuilds.
final journalDatesProvider = FutureProvider.autoDispose<Map<int, DateTime>>((ref) async {
  final items = ref.watch(itemsStreamProvider).valueOrNull
      ?.where((i) => i.type == ItemType.journal)
      .toList() ??
      const [];
  if (items.isEmpty) return {};
  ref.watch(journalDatesVersionProvider);
  final ids = items.map((e) => e.id).toList();
  DebugConfig.db('_journalDatesProvider: ids=${ids.length}');
  try {
    final all = await SuperNoteHelper.instance.properties.getAllForItems(ids);
    return {for (final it in items) it.id: journalEntryDisplayDate(it, all[it.id] ?? const <ItemProperty>[])};
  } catch (e, s) {
    DebugConfig.error('_journalDatesProvider', e, s);
    return {};
  }
});

class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen>
    with FolderAutoSelectMixin {
  bool _creating = false;

  Future<void> _createEntry() async {
    if (_creating) return;
    final selectedFolderId = ref.read(selectedFolderIdProvider);
    if (selectedFolderId == null) return;
    setState(() => _creating = true);
    try {
      final item = await ref.read(itemNotifierProvider.notifier).create(
        type: ItemType.journal,
        folderId: selectedFolderId,
      );
      if (item == null || !mounted) return;
      await Navigator.of(context).push(AppTransitions.slideRoute(
          JournalDetailScreen(itemId: item.id, isNew: true)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _openDetail(int id) {
    Navigator.of(context).push(AppTransitions.slideRoute(
        JournalDetailScreen(itemId: id, isNew: false)));
  }

  Future<void> _delete(Item item) async {
    final ok = await ConfirmDialog.delete(context, title: 'Διαγραφή καταχώρησης;');
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(itemsStreamProvider);
    final datesMap = ref.watch(journalDatesProvider).valueOrNull ?? {};
    final foldersAsync = ref.watch(foldersStreamProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);

    // 🆕 Διαβάζουμε το επιλεγμένο folder από τον κεντρικό provider
    final selectedFolderId = ref.watch(selectedFolderIdProvider);

    tryAutoSelectFolder(
      foldersAsync: foldersAsync,
      settingsAsync: settingsAsync,
      debugLabel: 'JournalList',
    );

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(),
      floatingActionButton: selectedFolderId != null && !_creating ? _buildFab() : null,
      body: Column(
        children: [
          const DraggableFolderSelector(),
          const ViewModeToggle(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(itemsStreamProvider),
              child: entriesAsync.when(
                loading: () => const _LoadingList(),
                error: (e, _) => EmptyState.error(
                  onRetry: () => ref.invalidate(itemsStreamProvider),
                ),
                data: (allItems) {
                  if (_creating) return const _LoadingList();
                  var entries = allItems.where((i) => i.type == ItemType.journal).toList();
                  if (selectedFolderId != null) {
                    entries = entries.where((e) => e.folderId == selectedFolderId).toList();
                  }
                  final viewMode = ref.watch(listViewModeProvider);
                  switch (viewMode) {
                    case ListViewMode.pinned:
                      entries = entries.where((e) => e.pinned).toList();
                      break;
                    case ListViewMode.favorites:
                      entries = entries.where((e) => e.favorite).toList();
                      break;
                    case ListViewMode.all:
                      break;
                  }
                  if (entries.isEmpty) {
                    return EmptyState.forType(ItemType.journal, onAction: _createEntry);
                  }

                  final processed = entries
                      .map((e) => _EntryWithDate(
                            entry: e,
                            displayDate: datesMap[e.id] ?? e.updatedAt ?? e.createdAt,
                          ))
                      .toList()
                    ..sort((a, b) => b.displayDate.compareTo(a.displayDate));
                  return ResponsiveLayout(
                    mobile: _JournalListMobile(
                      entriesWithDate: processed,
                      onTap: _openDetail,
                      onDelete: _delete,
                      onShare: (item) => ShareService.shareItem(context, item.id),
                    ),
                    tablet: _JournalListTablet(
                      entriesWithDate: processed,
                      onTap: _openDetail,
                      onDelete: _delete,
                      onShare: (item) => ShareService.shareItem(context, item.id),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: context.cBg,
    elevation: 0,
    scrolledUnderElevation: 1,
    title: const Text('Ημερολόγιο'),
    actions: [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (value) {
          if (value == 'archived') {
            ref.read(showArchivedProvider.notifier).state =
                !ref.read(showArchivedProvider);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'archived',
            child: Row(children: [
              const Icon(Icons.archive_rounded, size: 18),
              const SizedBox(width: Spacing.sm),
              // Flexible: το label δεν χωράει μονούς στο 140% (menu max 280dp)
              Flexible(
                child: Text(
                  ref.watch(showArchivedProvider)
                      ? 'Απόκρυψη αρχειοθετημένων'
                      : 'Εμφάνιση αρχειοθετημένων',
                ),
              ),
            ]),
          ),
        ],
      ),
    ],
  );

  Widget _buildFab() => FloatingActionButton(
    onPressed: _createEntry,
    tooltip: 'Νέα καταχώρηση',
    child: const Icon(Icons.add_rounded),
  );
}

// Helper class
class _EntryWithDate {
  final Item entry;
  final DateTime displayDate;
  _EntryWithDate({required this.entry, required this.displayDate});
}

// ──────────────────────────────────────────────
// Mobile List (grouped by month) with draggable cards
// ──────────────────────────────────────────────
class _JournalListMobile extends StatelessWidget {
  final List<_EntryWithDate> entriesWithDate;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;
  final void Function(Item)? onShare;
  const _JournalListMobile({required this.entriesWithDate, required this.onTap, required this.onDelete, this.onShare});

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMonth(entriesWithDate);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.sm, context.responsiveHPadding, 80),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final group = grouped[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.xs),
              child: Text(group.monthLabel, style: context.labelMd.withColor(context.cText2)),
            ),
            ...group.items.map((ewd) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _DraggableJournalCard(item: ewd.entry, displayDate: ewd.displayDate, onTap: onTap, onDelete: onDelete, onShare: onShare != null ? () => onShare!(ewd.entry) : null),
            )),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// Tablet Grid with draggable cards
// ──────────────────────────────────────────────
class _JournalListTablet extends StatelessWidget {
  final List<_EntryWithDate> entriesWithDate;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;
  final void Function(Item)? onShare;
  const _JournalListTablet({required this.entriesWithDate, required this.onTap, required this.onDelete, this.onShare});

  @override
  Widget build(BuildContext context) {
    return ResponsiveItemList<_EntryWithDate>(
      items: entriesWithDate,
      itemKey: (e, i) => ValueKey<int>(e.entry.id),
      itemBuilder: (_, ewd) => _DraggableJournalCard(
        item: ewd.entry,
        displayDate: ewd.displayDate,
        onTap: onTap,
        onDelete: onDelete,
        onShare: onShare != null ? () => onShare!(ewd.entry) : null,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Draggable Journal Card
// ──────────────────────────────────────────────
class _DraggableJournalCard extends ConsumerWidget {
  final Item item;
  final DateTime displayDate;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;
  final VoidCallback? onShare;
  const _DraggableJournalCard({required this.item, required this.displayDate, required this.onTap, required this.onDelete, this.onShare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showArchived = ref.watch(showArchivedProvider);
    final isArchived = item.archived && showArchived;
    DebugConfig.db('JournalCard id=${item.id} archived=${item.archived} showArchived=$showArchived isArchived=$isArchived');
    final overrideColor = ref.watch(itemTypeCardColorOverrideProvider(ItemType.journal));
    final backgroundColor = overrideColor ?? ItemColorHelper.backgroundColorForType(ItemType.journal, context);
    final foregroundColor = ItemColorHelper.textColorForBackground(backgroundColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha: 0.7);
    final accentColor = ColorsUI.itemTypeColor(ItemType.journal, context.brightness);

    return _buildDraggable(context, displayDate, backgroundColor, foregroundColor, secondaryForeground, accentColor, isArchived);
  }

  Widget _buildDraggable(
      BuildContext context,
      DateTime? displayDate,
      Color backgroundColor,
      Color foregroundColor,
      Color secondaryForeground,
      Color accentColor,
      bool isArchived,
      ) {
    final date = displayDate ?? (item.updatedAt ?? item.createdAt);
    const weekDays = AppDateUtils.weekdayNames;
    final dayLabel = '${weekDays[date.weekday - 1]}, ${date.day}';
    final card = Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.cardBR,
        border: Border.all(color: ColorsUI.getBorder(context.brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Text(dayLabel, style: context.labelSm.copyWith(color: accentColor)),
              ),
              const Spacer(),
              Text(date.timeOnly, style: context.labelSm.copyWith(color: secondaryForeground)),
              if (item.favorite) ...[
                const SizedBox(width: Spacing.xs),
                Icon(Icons.star_rounded, size: 14, color: ColorsUI.getWarning(context.brightness)),
              ],
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            item.title?.isNotEmpty == true ? item.title! : 'Χωρίς τίτλο',
            style: context.titleSm.copyWith(color: item.title?.isNotEmpty == true ? foregroundColor : secondaryForeground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Spacing.xs),
          Text(date.relative, style: context.labelSm.copyWith(color: secondaryForeground)),
        ],
      ),
    );

    final result = DraggableItemWrapper(
      itemId: item.id,
      child: GestureDetector(
        onTap: () => onTap(item.id),
        onLongPress: () => _showActions(context),
        child: card,
      ),
    );

    return isArchived
        ? Opacity(opacity: 0.5, child: result)
        : result;
  }

  void _showActions(BuildContext context) {
    ItemActionsSheet.show(
      context,
      item: item,
      showTitle: false,
      onEdit: () => onTap(item.id),
      onShare: onShare == null ? null : () => onShare!(),
      onDelete: () => onDelete(item),
    );
  }
}

// ──────────────────────────────────────────────
// Group by month helper
// ──────────────────────────────────────────────
class _MonthGroup {
  final String monthLabel;
  final List<_EntryWithDate> items;
  const _MonthGroup(this.monthLabel, this.items);
}

List<_MonthGroup> _groupByMonth(List<_EntryWithDate> entriesWithDate) {
  const months = AppDateUtils.monthFullNames;
  final map = <String, List<_EntryWithDate>>{};
  for (final ewd in entriesWithDate) {
    final date = ewd.displayDate;
    final key = '${months[date.month - 1]} ${date.year}';
    map.putIfAbsent(key, () => []).add(ewd);
  }
  return map.entries.map((e) => _MonthGroup(e.key, e.value)).toList();
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: Spacing.sm),
    itemCount: 5,
    separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
    itemBuilder: (_, __) => const ItemCardSkeleton(),
  );
}