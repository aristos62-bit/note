// lib/features/journal/journal_list_screen.dart
//
// Λίστα ημερολογίου — ομαδοποιημένη κατά ημερομηνία.
// ✅ Folder-based: FAB μόνο όταν επιλεγεί φάκελος
// ✅ Responsive: list mobile / grid tablet+desktop
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
import 'journal_detail_screen.dart';

// ════════════════════════════════════════════════════════════════
// JOURNAL LIST SCREEN
// ════════════════════════════════════════════════════════════════

class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;
  Timer? _debounce;
  String _searchQuery = '';
  int? _selectedFolderId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Search ───────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      DebugConfig.search('JournalList search: "$value"');
      setState(() => _searchQuery = value.trim());
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchCtrl.clear();
        _searchQuery = '';
      }
    });
    if (_searchActive) {
      Future.microtask(() => _searchFocus.requestFocus());
    }
    DebugConfig.nav('JournalList toggleSearch: $_searchActive');
  }

  // ── Create entry ─────────────────────────────────────────────

  Future<void> _createEntry() async {
    if (_selectedFolderId == null) {
      DebugConfig.error('JournalList: createEntry without selected folder');
      return;
    }

    DebugConfig.nav('JournalList: create entry in folder id=$_selectedFolderId');
    final item = await ref.read(itemNotifierProvider.notifier)
        .create(
      type: ItemType.journal,
      folderId: _selectedFolderId,
    );
    if (item == null || !mounted) return;
    ref.invalidate(itemNotifierProvider);
    Navigator.of(context).push(AppTransitions.slideRoute(
        JournalDetailScreen(itemId: item.id, isNew: true)));
  }

  void _openDetail(int id) {
    DebugConfig.nav('JournalList → JournalDetail id=$id');
    Navigator.of(context).push(AppTransitions.slideRoute(
        JournalDetailScreen(itemId: id, isNew: false)));
  }

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _delete(Item item) async {
    final future = ConfirmDialog.delete(context,
        title: 'Διαγραφή καταχώρησης;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('JournalList delete id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    ref.invalidate(itemNotifierProvider);
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
  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('JournalListScreen build');
    final entriesAsync = ref.watch(itemsStreamProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(),
      floatingActionButton: _selectedFolderId != null ? _buildFab() : null,
      body: Column(
        children: [
          if (_searchActive) _SearchBar(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
          ),

          // ── Folder selector ("Όλοι" ή συγκεκριμένος φάκελος) ──
          foldersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (folders) {
              if (folders.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: FolderChipSelector(
                  folders: folders,
                  selectedFolderId: _selectedFolderId,
                  onSelect: (id) {
                    setState(() => _selectedFolderId = id);
                    DebugConfig.nav('JournalList: select folder id=$id');
                  },
                ),
              );
            },
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(itemNotifierProvider),
              child: entriesAsync.when(
                loading: () => _LoadingList(),
                error: (e, _) {
                  DebugConfig.error('JournalList load failed', e);
                  return EmptyState.error(
                      onRetry: () => ref.invalidate(itemNotifierProvider));
                },
                  data: (allItems) {
                    // Φιλτράρισμα (ίδιο)
                    var entries = allItems.where((i) => i.type == ItemType.journal).toList();
                    if (_selectedFolderId != null) {
                      entries = entries.where((e) => e.folderId == _selectedFolderId).toList();
                    }
                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.toLowerCase();
                      entries = entries.where((e) => (e.title ?? '').toLowerCase().contains(q)).toList();
                    }
                    if (entries.isEmpty) {
                      if (_searchQuery.isNotEmpty) {
                        return EmptyState.search(query: _searchQuery);
                      }
                      if (_selectedFolderId == null) {
                        return EmptyState.forType(ItemType.journal, onAction: null);
                      }
                      return EmptyState.forType(ItemType.journal, onAction: _createEntry);
                    }
                    // Χρησιμοποιούμε FutureBuilder για να φορτώσουμε displayDate
                    return FutureBuilder<List<_EntryWithDate>>(
                      future: _processEntriesWithDate(entries),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return EmptyState.error(onRetry: () => ref.invalidate(itemNotifierProvider));
                        }
                        final processed = snapshot.data!;
                        return ResponsiveLayout(
                          mobile: _JournalListMobile(entriesWithDate: processed, onTap: _openDetail, onDelete: _delete),
                          tablet: _JournalListTablet(entriesWithDate: processed, onTap: _openDetail, onDelete: _delete),
                        );
                      },
                    );
                  }
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: context.cBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: const Text('Ημερολόγιο'),
      actions: [
        IconButton(
          icon: Icon(_searchActive
              ? Icons.search_off_rounded
              : Icons.search_rounded),
          onPressed: _toggleSearch,
          tooltip: _searchActive ? 'Κλείσιμο αναζήτησης' : 'Αναζήτηση',
        ),
      ],
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: _createEntry,
      tooltip: 'Νέα καταχώρηση',
      child: const Icon(Icons.add_rounded),
    );
  }
}

// ── Helper class for entries with display date ─────────────────
class _EntryWithDate {
  final Item entry;
  final DateTime displayDate;
  _EntryWithDate({required this.entry, required this.displayDate});
}

// ════════════════════════════════════════════════════════════════
// MOBILE LIST — ομαδοποιημένη κατά μήνα
// ════════════════════════════════════════════════════════════════

class _JournalListMobile extends StatelessWidget {
  final List<_EntryWithDate> entriesWithDate;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;

  const _JournalListMobile({
    required this.entriesWithDate,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMonth(entriesWithDate);

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.sm,
        context.responsiveHPadding, 80,
      ),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final group = grouped[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header
            Padding(
              padding: const EdgeInsets.only(
                  top: Spacing.md, bottom: Spacing.xs),
              child: Text(
                group.monthLabel,
                style: context.labelMd.withColor(context.cText2),
              ),
            ),
            // Entries
            ...group.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _JournalCard(
                item: item,
                onTap: () => onTap(item.id),
                onDelete: () => onDelete(item),
              ),
            )),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TABLET GRID — 2 στήλες
// ════════════════════════════════════════════════════════════════

class _JournalListTablet extends StatelessWidget {
  final List<_EntryWithDate> entriesWithDate;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;

  const _JournalListTablet({
    required this.entriesWithDate,   // ✅ Σωστό
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cols = context.gridColumns;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.sm,
        context.responsiveHPadding, 80,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        mainAxisExtent: 160,
      ),
      itemCount: entriesWithDate.length,
      itemBuilder: (_, i) => _JournalCard(
        item: entriesWithDate[i].entry,
        onTap: () => onTap(entriesWithDate[i].entry.id),
        onDelete: () => onDelete(entriesWithDate[i].entry),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// JOURNAL CARD (unchanged)
// ════════════════════════════════════════════════════════════════

class _JournalCard extends ConsumerWidget {
  final Item item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _JournalCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final color = ColorsUI.itemTypeColor(ItemType.journal, context.brightness);

    return propsAsync.when(
      loading: () => _buildCardContent(context, null, color),
      error: (_, __) => _buildCardContent(context, null, color),
      data: (props) {
        final entryDateStr = props.where((p) => p.key == 'entry_date').firstOrNull?.value;
        final displayDate = entryDateStr != null
            ? DateTime.tryParse(entryDateStr)
            : (item.updatedAt ?? item.createdAt);
        return _buildCardContent(context, displayDate, color);
      },
    );
  }

  Widget _buildCardContent(BuildContext context, DateTime? displayDate, Color color) {
    final date = displayDate ?? (item.updatedAt ?? item.createdAt);
    const weekDays = ['', 'Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
    final dayLabel = '${weekDays[date.weekday]}, ${date.day}';

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: ColorsUI.getCard(context.brightness),
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
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Text(dayLabel, style: context.labelSm.withColor(color)),
                ),
                const Spacer(),
                Text(date.timeOnly, style: context.labelSm.withColor(context.cDisabled)),
                if (item.favorite) ...[
                  const SizedBox(width: Spacing.xs),
                  Icon(Icons.star_rounded, size: 14, color: ColorsUI.getWarning(context.brightness)),
                ],
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              item.title?.isNotEmpty == true ? item.title! : 'Χωρίς τίτλο',
              style: context.titleSm.copyWith(
                color: item.title?.isNotEmpty == true ? context.cText : context.cDisabled,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Spacing.xs),
            Text(date.relative, style: context.labelSm.withColor(context.cDisabled)),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) { /* unchanged */ }
}

// ════════════════════════════════════════════════════════════════
// GROUP BY MONTH helper (unchanged)
// ════════════════════════════════════════════════════════════════

class _MonthGroup {
  final String monthLabel;
  final List<Item> items;
  const _MonthGroup(this.monthLabel, this.items);
}

List<_MonthGroup> _groupByMonth(List<_EntryWithDate> entriesWithDate) {
  const months = [
    '', 'Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος',
    'Μάιος', 'Ιούνιος', 'Ιούλιος', 'Αύγουστος',
    'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος',
  ];

  final map = <String, List<Item>>{};
  for (final ewd in entriesWithDate) {
    final date = ewd.displayDate;
    final key = '${months[date.month]} ${date.year}';
    map.putIfAbsent(key, () => []).add(ewd.entry);
  }
  return map.entries.map((e) => _MonthGroup(e.key, e.value)).toList();
}

// ════════════════════════════════════════════════════════════════
// SEARCH BAR (unchanged)
// ════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cBg,
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.sm,
        context.responsiveHPadding, Spacing.sm,
      ),
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
              ? IconButton(
            icon: Icon(Icons.close_rounded, color: context.cText2),
            onPressed: () {
              controller.clear();
              onChanged('');
            },
          )
              : null,
          filled: true,
          fillColor: ColorsUI.getSurface(context.brightness),
          border: OutlineInputBorder(
            borderRadius: AppRadius.inputBR,
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// LOADING LIST (unchanged)
// ════════════════════════════════════════════════════════════════

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.sm,
      ),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, __) => const ItemCardSkeleton(),
    );
  }
}