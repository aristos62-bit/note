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
// ✅ Filter tags
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'journal_detail_screen.dart';
import '../../services/services.dart';
import '../../helpers/item_color_helper.dart';

final _journalSearchQueryProvider = StateProvider<String>((ref) => '');
final _journalTagFilterProvider  = StateProvider<Set<String>>((ref) => {});

class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen>
    with FolderAutoSelectMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;
  bool _showArchiveHintShown = false;
  Timer? _debounce;
  Set<String> _visibleTagNames = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_journalSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchCtrl.clear();
        ref.read(_journalSearchQueryProvider.notifier).state = '';
        ref.read(_journalTagFilterProvider.notifier).state = {};
      }
    });
    if (_searchActive) {
      Future.microtask(() => _searchFocus.requestFocus());
    }
  }

  Future<void> _createEntry() async {
    final selectedFolderId = ref.read(selectedFolderIdProvider);
    if (selectedFolderId == null) return;
    final item = await ref.read(itemNotifierProvider.notifier).create(
      type: ItemType.journal,
      folderId: selectedFolderId,
    );
    if (item == null || !mounted) return;
    Navigator.of(context).push(AppTransitions.slideRoute(
        JournalDetailScreen(itemId: item.id, isNew: true)));
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

  Future<DateTime> _getDisplayDate(Item item) async {
    final props = await ref.read(itemPropertiesProvider(item.id).future);
    final entryDateStr = props.where((p) => p.key == 'entry_date').firstOrNull?.value;
    if (entryDateStr != null) {
      final parsed = DateTime.tryParse(entryDateStr);
      if (parsed != null) return parsed;
    }
    return item.updatedAt ?? item.createdAt;
  }

  Future<List<_EntryWithDate>> _processEntriesWithDate(List<Item> entries) async {
    final result = <_EntryWithDate>[];
    for (final entry in entries) {
      final date = await _getDisplayDate(entry);
      result.add(_EntryWithDate(entry: entry, displayDate: date));
    }
    result.sort((a, b) => b.displayDate.compareTo(a.displayDate));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(itemsStreamProvider);
    final searchQuery = ref.watch(_journalSearchQueryProvider);
    final activeTags = ref.watch(_journalTagFilterProvider);
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
      floatingActionButton: selectedFolderId != null ? _buildFab() : null,
      body: Column(
        children: [
          if (_searchActive)
            _SearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
            ),
          // 🆕 Αυτόνομος folder selector
          const DraggableFolderSelector(),
          if (_visibleTagNames.isNotEmpty)
            _TagFilterRow(
              tags: _visibleTagNames.toList(),
              activeTags: activeTags,
              onTagTap: (name) {
                final current = ref.read(_journalTagFilterProvider);
                final newSet = {...current};
                if (newSet.contains(name)) {
                  newSet.remove(name);
                } else {
                  newSet.add(name);
                }
                ref.read(_journalTagFilterProvider.notifier).state = newSet;
              },
            ),
          const ViewModeToggle(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(itemsStreamProvider),
              child: entriesAsync.when(
                loading: () => _LoadingList(),
                error: (e, _) => EmptyState.error(
                  onRetry: () => ref.invalidate(itemNotifierProvider),
                ),
                data: (allItems) {
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
                  if (searchQuery.isNotEmpty) {
                    final q = searchQuery.toLowerCase();
                    entries = entries.where((e) => (e.title ?? '').toLowerCase().contains(q)).toList();
                  }
                  if (activeTags.isNotEmpty) {
                    entries = entries.where((e) {
                      final tags = ref.read(itemTagsProvider(e.id)).valueOrNull ?? [];
                      return tags.any((t) => activeTags.contains(t.name));
                    }).toList();
                  }

                  final visibleTagNames = <String>{};
                  for (final e in entries) {
                    final tags = ref.read(itemTagsProvider(e.id)).valueOrNull ?? [];
                    for (final t in tags) {visibleTagNames.add(t.name);}
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (!const SetEquality<String>().equals(_visibleTagNames, visibleTagNames)) {
                      setState(() => _visibleTagNames = visibleTagNames);
                    }
                  });

                  if (entries.isEmpty) {
                    if (searchQuery.isNotEmpty || activeTags.isNotEmpty) {
                      return EmptyState.search(query: searchQuery);
                    }
                    return EmptyState.forType(ItemType.journal, onAction: _createEntry);
                  }

                  return FutureBuilder<List<_EntryWithDate>>(
                    future: _processEntriesWithDate(entries),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return EmptyState.error(onRetry: () => ref.invalidate(itemsStreamProvider));
                      }
                      final processed = snapshot.data!;
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
      IconButton(
        icon: Icon(_searchActive ? Icons.search_off_rounded : Icons.search_rounded),
        onPressed: _toggleSearch,
        tooltip: _searchActive ? 'Κλείσιμο αναζήτησης' : 'Αναζήτηση',
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (value) {
          if (value == 'archived') {
            final show = ref.read(showArchivedProvider);
            ref.read(showArchivedProvider.notifier).state = !show;
            if (!show && !_showArchiveHintShown) {
              _showArchiveHintShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Πατήστε παρατεταμένα (long press) στο στοιχείο για επαναφορά')),
                  );
                }
              });
            }
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'archived',
            child: Row(children: [
              const Icon(Icons.archive_rounded, size: 18),
              const SizedBox(width: Spacing.sm),
              Text(
                ref.watch(showArchivedProvider)
                    ? 'Απόκρυψη συμπιεσμένων αρχείων'
                    : 'Εμφάνιση συμπιεσμένων αρχείων',
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
            ...group.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _DraggableJournalCard(item: item, onTap: onTap, onDelete: onDelete, onShare: onShare != null ? () => onShare!(item) : null),
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
    final cols = context.gridColumns;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.sm, context.responsiveHPadding, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        mainAxisExtent: 160,
      ),
      itemCount: entriesWithDate.length,
      itemBuilder: (_, i) => _DraggableJournalCard(
        item: entriesWithDate[i].entry,
        onTap: onTap,
        onDelete: onDelete,
        onShare: onShare != null ? () => onShare!(entriesWithDate[i].entry) : null,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Draggable Journal Card
// ──────────────────────────────────────────────
class _DraggableJournalCard extends ConsumerWidget {
  final Item item;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;
  final VoidCallback? onShare;
  const _DraggableJournalCard({required this.item, required this.onTap, required this.onDelete, this.onShare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final showArchived = ref.watch(showArchivedProvider);
    final isArchived = item.archived && showArchived;
    DebugConfig.db('JournalCard id=${item.id} archived=${item.archived} showArchived=$showArchived isArchived=$isArchived');
    final overrideColor = ref.watch(itemTypeCardColorOverrideProvider(ItemType.journal));
    final backgroundColor = overrideColor ?? ItemColorHelper.backgroundColorForType(ItemType.journal, context);
    final foregroundColor = ItemColorHelper.textColorForBackground(backgroundColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha: 0.7);
    final accentColor = ColorsUI.itemTypeColor(ItemType.journal, context.brightness);

    return propsAsync.when(
      loading: () => _buildDraggable(context, null, backgroundColor, foregroundColor, secondaryForeground, accentColor, isArchived),
      error: (_, __) => _buildDraggable(context, null, backgroundColor, foregroundColor, secondaryForeground, accentColor, isArchived),
      data: (props) {
        final entryDateStr = props.where((p) => p.key == 'entry_date').firstOrNull?.value;
        final displayDate = entryDateStr != null ? DateTime.tryParse(entryDateStr) : (item.updatedAt ?? item.createdAt);
        return _buildDraggable(context, displayDate, backgroundColor, foregroundColor, secondaryForeground, accentColor, isArchived);
      },
    );
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
    const weekDays = ['', 'Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
    final dayLabel = '${weekDays[date.weekday]}, ${date.day}';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(AppRadius.bottomSheet), topRight: Radius.circular(AppRadius.bottomSheet)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: Spacing.sm), width: 40, height: 4, decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(2))),
            ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('Επεξεργασία'), onTap: () { Navigator.pop(context); onTap(item.id); }),
            if (onShare != null)
              ListTile(leading: const Icon(Icons.share_rounded), title: const Text('Κοινοποίηση'), onTap: () { Navigator.pop(context); onShare!(); }),
            ListTile(leading: Icon(Icons.delete_outline_rounded, color: context.cError), title: Text('Διαγραφή', style: TextStyle(color: context.cError)), onTap: () { Navigator.pop(context); onDelete(item); }),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Group by month helper
// ──────────────────────────────────────────────
class _MonthGroup {
  final String monthLabel;
  final List<Item> items;
  const _MonthGroup(this.monthLabel, this.items);
}

List<_MonthGroup> _groupByMonth(List<_EntryWithDate> entriesWithDate) {
  const months = ['', 'Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος', 'Μάιος', 'Ιούνιος', 'Ιούλιος', 'Αύγουστος', 'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος'];
  final map = <String, List<Item>>{};
  for (final ewd in entriesWithDate) {
    final date = ewd.displayDate;
    final key = '${months[date.month]} ${date.year}';
    map.putIfAbsent(key, () => []).add(ewd.entry);
  }
  return map.entries.map((e) => _MonthGroup(e.key, e.value)).toList();
}

// ──────────────────────────────────────────────
// Shared widgets: SearchBar, TagFilterRow, LoadingList
// ──────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.focusNode, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    color: context.cBg,
    padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.sm, context.responsiveHPadding, Spacing.sm),
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: context.bodyMd,
      decoration: InputDecoration(
        hintText: 'Αναζήτηση καταχωρήσεων...',
        hintStyle: context.bodyMd.withColor(context.cDisabled),
        prefixIcon: Icon(Icons.search_rounded, color: context.cText2),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(icon: Icon(Icons.close_rounded, color: context.cText2), onPressed: () { controller.clear(); onChanged(''); })
            : null,
        filled: true,
        fillColor: ColorsUI.getSurface(context.brightness),
        border: OutlineInputBorder(borderRadius: AppRadius.inputBR, borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      ),
    ),
  );
}

class _TagFilterRow extends StatelessWidget {
  final List<String> tags;
  final Set<String> activeTags;
  final ValueChanged<String> onTagTap;
  const _TagFilterRow({required this.tags, required this.activeTags, required this.onTagTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
      itemCount: tags.length,
      separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
      itemBuilder: (_, i) => TagChip(
        name: tags[i],
        color: null,
        selected: activeTags.contains(tags[i]),
        compact: true,
        onTap: () => onTagTap(tags[i]),
      ),
    ),
  );
}

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: Spacing.sm),
    itemCount: 5,
    separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
    itemBuilder: (_, __) => const ItemCardSkeleton(),
  );
}