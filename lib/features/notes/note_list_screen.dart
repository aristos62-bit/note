// lib/features/notes/note_list_screen.dart
//
// Λίστα σημειώσεων με search, filter tags, FAB δημιουργίας.
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
import 'note_detail_screen.dart';

// ── Local providers ───────────────────────────────────────────────

/// Notes του active workspace (πάντα ItemType.note)
final _notesProvider = FutureProvider<List<Item>>((ref) async {
  final db    = ref.watch(dbProvider);
  final wsId  = ref.watch(activeWorkspaceIdProvider);
  final showArchived = ref.watch(showArchivedProvider);
  if (wsId == null) return [];
  DebugConfig.db('_notesProvider load wsId=$wsId archived=$showArchived');
  return db.items.getByWorkspace(
    wsId,
    type: ItemType.note,
    includeArchived: showArchived,
  );
});

/// Search query τοπικό state
final _searchQueryProvider = StateProvider<String>((ref) => '');

/// Active tag filter
final _activeTagFilterProvider = StateProvider<String?>((ref) => null);

// ════════════════════════════════════════════════════════════════
// NOTE LIST SCREEN
// ════════════════════════════════════════════════════════════════

class NoteListScreen extends ConsumerStatefulWidget {
  const NoteListScreen({super.key});

  @override
  ConsumerState<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends ConsumerState<NoteListScreen> {
  final _searchCtrl   = TextEditingController();
  final _searchFocus  = FocusNode();
  bool  _searchActive = false;
  Timer? _debounce;

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
      DebugConfig.search('NoteList search: "$value"');
      ref.read(_searchQueryProvider.notifier).state = value.trim();
    });
  }

  void _toggleSearch() {
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      ref.read(_searchQueryProvider.notifier).state = '';
      ref.read(_activeTagFilterProvider.notifier).state = null;
    } else {
      Future.microtask(() => _searchFocus.requestFocus());
    }
    DebugConfig.nav('NoteList toggleSearch: $_searchActive');
  }

  // ── Create note ──────────────────────────────────────────────

  Future<void> _createNote() async {
    DebugConfig.nav('NoteList: create note');
    final notifier = ref.read(itemNotifierProvider.notifier);
    final item = await notifier.create(type: ItemType.note);
    if (item == null || !mounted) return;
    ref.invalidate(_notesProvider);
    _openDetail(item.id);
  }

  void _openDetail(int id) {
    DebugConfig.nav('NoteList → NoteDetail id=$id');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteDetailScreen(itemId: id)),
    );
  }

  // ── Item actions (long press) ────────────────────────────────

  void _showItemActions(BuildContext context, Item item) {
    DebugConfig.nav('NoteList: showActions id=${item.id}');
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => _ItemActionsSheet(
        item: item,
        onPin:     () => _togglePin(item),
        onFav:     () => _toggleFav(item),
        onArchive: () => _archive(item),
        onDelete:  () => _delete(item),
      ),
    );
  }

  Future<void> _togglePin(Item item) async {
    Navigator.pop(context);
    DebugConfig.provider('NoteList togglePin id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).togglePin(item.id, item.pinned);
    ref.invalidate(_notesProvider);
  }

  Future<void> _toggleFav(Item item) async {
    Navigator.pop(context);
    DebugConfig.provider('NoteList toggleFav id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).toggleFavorite(item.id, item.favorite);
    ref.invalidate(_notesProvider);
  }

  Future<void> _archive(Item item) async {
    Navigator.pop(context);
    final future = ConfirmDialog.archive(context);
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('NoteList archive id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).toggleArchive(item.id, item.archived);
    ref.invalidate(_notesProvider);
  }

  Future<void> _delete(Item item) async {
    Navigator.pop(context);
    final future = ConfirmDialog.delete(context, title: 'Διαγραφή σημείωσης;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('NoteList delete id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    ref.invalidate(_notesProvider);
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('NoteListScreen build');

    final notesAsync   = ref.watch(_notesProvider);
    final searchQuery  = ref.watch(_searchQueryProvider);
    final activeTag    = ref.watch(_activeTagFilterProvider);
    final tagsAsync    = ref.watch(tagsProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(tagsAsync),
      floatingActionButton: _buildFab(),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────
          if (_searchActive) _SearchBar(
            controller: _searchCtrl,
            focusNode:  _searchFocus,
            onChanged:  _onSearchChanged,
          ),

          // ── Tag filter chips ──────────────────────────────────
          tagsAsync.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data: (tags) => tags.isEmpty
                ? const SizedBox.shrink()
                : _TagFilterRow(
              tags:       tags,
              activeTag:  activeTag,
              onTagTap:   (name) {
                final current = ref.read(_activeTagFilterProvider);
                ref.read(_activeTagFilterProvider.notifier).state =
                current == name ? null : name;
              },
            ),
          ),

          // ── Notes list ─────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(_notesProvider),
              child: notesAsync.when(
                loading: () => _LoadingList(),
                error:   (e, _) {
                  DebugConfig.error('NoteList load failed', e);
                  return EmptyState.error(onRetry: () => ref.invalidate(_notesProvider));
                },
                data: (notes) {
                  // Φιλτράρισμα: search + tag
                  final filtered = _filterNotes(notes, searchQuery, activeTag);

                  if (filtered.isEmpty) {
                    return searchQuery.isNotEmpty || activeTag != null
                        ? EmptyState.search(query: searchQuery)
                        : EmptyState.forType(
                      ItemType.note,
                      onAction: _createNote,
                    );
                  }

                  // Pinned πρώτα
                  final pinned   = filtered.where((n) => n.pinned).toList();
                  final unpinned = filtered.where((n) => !n.pinned).toList();

                  return _NoteListBody(
                    pinned:   pinned,
                    unpinned: unpinned,
                    onTap:    (item) => _openDetail(item.id),
                    onLongPress: (item) => _showItemActions(context, item),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(AsyncValue tagsAsync) {
    return AppBar(
      title: const Text('Σημειώσεις'),
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
              ref.invalidate(_notesProvider);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'archived',
              child: Row(children: [
                const Icon(Icons.archive_rounded, size: 18),
                const SizedBox(width: Spacing.sm),
                Text(ref.watch(showArchivedProvider)
                    ? 'Απόκρυψη αρχείου'
                    : 'Εμφάνιση αρχείου'),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: _createNote,
      tooltip: 'Νέα σημείωση',
      child: const Icon(Icons.add_rounded),
    );
  }

  List<Item> _filterNotes(List<Item> notes, String query, String? tag) {
    var list = notes;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((n) =>
          (n.title ?? '').toLowerCase().contains(q)).toList();
    }
    // Tag φιλτράρισμα γίνεται στο _NoteListBody με itemTagsProvider
    return list;
  }
}

// ════════════════════════════════════════════════════════════════
// NOTE LIST BODY — responsive list/grid
// ════════════════════════════════════════════════════════════════

class _NoteListBody extends ConsumerWidget {
  final List<Item> pinned;
  final List<Item> unpinned;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onLongPress;

  const _NoteListBody({
    required this.pinned,
    required this.unpinned,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cols = context.gridColumns;

    return CustomScrollView(
      slivers: [
        // Pinned section
        if (pinned.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.responsiveHPadding, Spacing.md,
                context.responsiveHPadding, Spacing.xs,
              ),
              child: Row(children: [
                Icon(Icons.push_pin_rounded, size: 14,
                    color: context.cText2),
                const SizedBox(width: Spacing.xs),
                Text('Καρφιτσωμένα',
                    style: context.labelMd.withColor(context.cText2)),
              ]),
            ),
          ),
          _buildGrid(context, ref, pinned, cols),
        ],

        // All notes section
        if (unpinned.isNotEmpty) ...[
          if (pinned.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.responsiveHPadding, Spacing.md,
                  context.responsiveHPadding, Spacing.xs,
                ),
                child: Text('Όλες',
                    style: context.labelMd.withColor(context.cText2)),
              ),
            ),
          _buildGrid(context, ref, unpinned, cols),
        ],

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref,
      List<Item> items, int cols) {
    if (cols == 1) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical: Spacing.xs,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _NoteCardWithTags(
                item: items[i],
                onTap: onTap,
                onLongPress: onLongPress,
              ),
            ),
            childCount: items.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.xs,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   cols,
          mainAxisSpacing:  Spacing.sm,
          crossAxisSpacing: Spacing.sm,
          mainAxisExtent:   100,
        ),
        delegate: SliverChildBuilderDelegate(
              (ctx, i) => _NoteCardWithTags(
            item: items[i],
            onTap: onTap,
            onLongPress: onLongPress,
          ),
          childCount: items.length,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// NOTE CARD WITH TAGS — φορτώνει tags async
// ════════════════════════════════════════════════════════════════

class _NoteCardWithTags extends ConsumerWidget {
  final Item item;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onLongPress;

  const _NoteCardWithTags({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(itemTagsProvider(item.id));
    final tagNames  = tagsAsync.valueOrNull?.map((t) => t.name).toList() ?? [];

    return ItemCard(
      item:        item,
      tagNames:    tagNames,
      compact:     context.isMobile,
      onTap:       () => onTap(item),
      onLongPress: () => onLongPress(item),
    );
  }
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
        controller:  controller,
        focusNode:   focusNode,
        onChanged:   onChanged,
        style:       context.bodyMd,
        decoration: InputDecoration(
          hintText:    'Αναζήτηση σημειώσεων...',
          hintStyle:   context.bodyMd.withColor(context.cDisabled),
          prefixIcon:  Icon(Icons.search_rounded, color: context.cText2),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close_rounded, color: context.cText2),
            onPressed: () {
              controller.clear();
              onChanged('');
            },
          )
              : null,
          filled:      true,
          fillColor:   ColorsUI.getSurface(context.brightness),
          border: OutlineInputBorder(
            borderRadius: AppRadius.inputBR,
            borderSide:   BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.sm,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAG FILTER ROW
// ════════════════════════════════════════════════════════════════

class _TagFilterRow extends StatelessWidget {
  final List<Tag> tags;
  final String? activeTag;
  final ValueChanged<String> onTagTap;

  const _TagFilterRow({
    required this.tags,
    required this.activeTag,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
        ),
        itemCount:     tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
        itemBuilder: (_, i) => TagChip(
          name:     tags[i].name,
          color:    tags[i].color,
          selected: activeTag == tags[i].name,
          compact:  true,
          onTap:    () => onTagTap(tags[i].name),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ITEM ACTIONS SHEET
// ════════════════════════════════════════════════════════════════

class _ItemActionsSheet extends StatelessWidget {
  final Item item;
  final VoidCallback onPin;
  final VoidCallback onFav;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _ItemActionsSheet({
    required this.item,
    required this.onPin,
    required this.onFav,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: context.cBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.xs,
            ),
            child: Text(
              item.title ?? 'Χωρίς τίτλο',
              style: context.titleMd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(),

          // Actions
          ListTile(
            leading: Icon(
              item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: item.pinned ? context.cPrimary : context.cText2,
            ),
            title: Text(item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα'),
            onTap: onPin,
          ),
          ListTile(
            leading: Icon(
              item.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: item.favorite
                  ? ColorsUI.getWarning(context.brightness)
                  : context.cText2,
            ),
            title: Text(item.favorite ? 'Αφαίρεση από αγαπημένα' : 'Αγαπημένο'),
            onTap: onFav,
          ),
          ListTile(
            leading: Icon(Icons.archive_rounded, color: context.cText2),
            title: Text(item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση'),
            onTap: onArchive,
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: context.cError),
            title: Text('Διαγραφή', style: TextStyle(color: context.cError)),
            onTap: onDelete,
          ),

          const SizedBox(height: Spacing.sm),
        ],
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
      itemCount:        6,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder:      (_, __) => const ItemCardSkeleton(),
    );
  }
}