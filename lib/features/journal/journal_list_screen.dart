// lib/features/journal/journal_list_screen.dart
//
// Λίστα ημερολογίου — ομαδοποιημένη κατά ημερομηνία.
// Ακολουθεί τη νέα λογική: itemsStreamProvider + Navigator.push + isNew.
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
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  bool  _searchActive = false;
  Timer? _debounce;
  String _searchQuery = '';

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
  }

  // ── Create entry ─────────────────────────────────────────────

  Future<void> _createEntry() async {
    DebugConfig.nav('JournalList: create entry');
    final item = await ref.read(itemNotifierProvider.notifier)
        .create(type: ItemType.journal);
    if (item == null || !mounted) return;
    ref.invalidate(itemNotifierProvider);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => JournalDetailScreen(itemId: item.id, isNew: true),
    ));
  }

  void _openDetail(int id) {
    DebugConfig.nav('JournalList → JournalDetail id=$id');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => JournalDetailScreen(itemId: id, isNew: false),
    ));
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

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('JournalListScreen build');
    final entriesAsync = ref.watch(itemsStreamProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEntry,
        tooltip: 'Νέα καταχώρηση',
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          if (_searchActive) _SearchBar(
            controller: _searchCtrl,
            focusNode:  _searchFocus,
            onChanged:  _onSearchChanged,
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
                  // Φιλτράρισμα μόνο journal items
                  var entries = allItems
                      .where((i) => i.type == ItemType.journal)
                      .toList();

                  // Search
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    entries = entries.where((e) =>
                        (e.title ?? '').toLowerCase().contains(q)).toList();
                  }

                  // Ταξινόμηση: νεότερες πρώτα
                  entries.sort((a, b) =>
                      (b.updatedAt ?? b.createdAt)
                          .compareTo(a.updatedAt ?? a.createdAt));

                  if (entries.isEmpty) {
                    return _searchQuery.isNotEmpty
                        ? EmptyState.search(query: _searchQuery)
                        : EmptyState.forType(ItemType.journal,
                        onAction: _createEntry);
                  }

                  return ResponsiveLayout(
                    mobile:  _JournalListMobile(
                      entries:  entries,
                      onTap:    (id) => _openDetail(id),
                      onDelete: (item) => _delete(item),
                    ),
                    tablet: _JournalListTablet(
                      entries:  entries,
                      onTap:    (id) => _openDetail(id),
                      onDelete: (item) => _delete(item),
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

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor:        context.cBg,
      elevation:              0,
      scrolledUnderElevation: 1,
      title: const Text('Ημερολόγιο'),
      actions: [
        IconButton(
          icon: Icon(_searchActive
              ? Icons.search_off_rounded
              : Icons.search_rounded),
          onPressed: _toggleSearch,
          tooltip: 'Αναζήτηση',
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MOBILE LIST — ομαδοποιημένη κατά μήνα
// ════════════════════════════════════════════════════════════════

class _JournalListMobile extends StatelessWidget {
  final List<Item> entries;
  final ValueChanged<int>  onTap;
  final ValueChanged<Item> onDelete;

  const _JournalListMobile({
    required this.entries,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMonth(entries);

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
                item:     item,
                onTap:    () => onTap(item.id),
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
  final List<Item> entries;
  final ValueChanged<int>  onTap;
  final ValueChanged<Item> onDelete;

  const _JournalListTablet({
    required this.entries,
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
        crossAxisCount:   cols,
        mainAxisSpacing:  Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        mainAxisExtent:   160,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) => _JournalCard(
        item:     entries[i],
        onTap:    () => onTap(entries[i].id),
        onDelete: () => onDelete(entries[i]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// JOURNAL CARD
// ════════════════════════════════════════════════════════════════

class _JournalCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _JournalCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date  = item.updatedAt ?? item.createdAt;
    final color = ColorsUI.itemTypeColor(ItemType.journal, context.brightness);

    // Ημέρα εβδομάδας
    const weekDays = ['', 'Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
    final dayLabel = '${weekDays[date.weekday]}, ${date.day}';

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color:        ColorsUI.getCard(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(
              color: ColorsUI.getBorder(context.brightness)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date header ────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color:        color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Text(dayLabel,
                      style: context.labelSm.withColor(color)),
                ),
                const Spacer(),
                Text(date.timeOnly,
                    style: context.labelSm.withColor(context.cDisabled)),
                if (item.favorite) ...[
                  const SizedBox(width: Spacing.xs),
                  Icon(Icons.star_rounded, size: 14,
                      color: ColorsUI.getWarning(context.brightness)),
                ],
              ],
            ),

            const SizedBox(height: Spacing.sm),

            // ── Title ──────────────────────────────────────────
            Text(
              item.title?.isNotEmpty == true
                  ? item.title!
                  : 'Χωρίς τίτλο',
              style: context.titleSm.copyWith(
                color: item.title?.isNotEmpty == true
                    ? context.cText
                    : context.cDisabled,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: Spacing.xs),

            // ── Relative time ──────────────────────────────────
            Text(date.relative,
                style: context.labelSm.withColor(context.cDisabled)),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        context.cBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title:   const Text('Επεξεργασία'),
              onTap: () { Navigator.pop(context); onTap(); },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: context.cError),
              title: Text('Διαγραφή',
                  style: TextStyle(color: context.cError)),
              onTap: () { Navigator.pop(context); onDelete(); },
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// GROUP BY MONTH helper
// ════════════════════════════════════════════════════════════════

class _MonthGroup {
  final String monthLabel;
  final List<Item> items;
  const _MonthGroup(this.monthLabel, this.items);
}

List<_MonthGroup> _groupByMonth(List<Item> entries) {
  const months = [
    '', 'Ιανουάριος', 'Φεβρουάριος', 'Μάρτιος', 'Απρίλιος',
    'Μάιος', 'Ιούνιος', 'Ιούλιος', 'Αύγουστος',
    'Σεπτέμβριος', 'Οκτώβριος', 'Νοέμβριος', 'Δεκέμβριος',
  ];

  final map = <String, List<Item>>{};
  for (final item in entries) {
    final date = item.updatedAt ?? item.createdAt;
    final key  = '${months[date.month]} ${date.year}';
    map.putIfAbsent(key, () => []).add(item);
  }

  return map.entries
      .map((e) => _MonthGroup(e.key, e.value))
      .toList();
}

// ════════════════════════════════════════════════════════════════
// SEARCH BAR
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
        focusNode:  focusNode,
        onChanged:  onChanged,
        style:      context.bodyMd,
        decoration: InputDecoration(
          hintText:  'Αναζήτηση καταχωρήσεων...',
          hintStyle: context.bodyMd.withColor(context.cDisabled),
          prefixIcon: Icon(Icons.search_rounded, color: context.cText2),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close_rounded, color: context.cText2),
            onPressed: () { controller.clear(); onChanged(''); },
          )
              : null,
          filled:    true,
          fillColor: ColorsUI.getSurface(context.brightness),
          border: OutlineInputBorder(
            borderRadius: AppRadius.inputBR,
            borderSide:   BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// LOADING LIST
// ════════════════════════════════════════════════════════════════

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical:   Spacing.sm,
      ),
      itemCount:        5,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder:      (_, __) => const ItemCardSkeleton(),
    );
  }
}