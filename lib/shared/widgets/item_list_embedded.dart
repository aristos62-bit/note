// lib/shared/widgets/item_list_embedded.dart
//
// Ενσωματωμένη λίστα items (χωρίς AppBar/FAB) για χρήση μέσα σε άλλες οθόνες.
// ✅ Search, filter tags
// ✅ Responsive: list mobile / grid tablet
// ✅ Dark mode + DebugConfig
// ✅ Fix: κλείδωμα pop κατά το drag (αποφυγή ανεπιθύμητου back gesture)
// ✅ Βελτιστοποίηση: χρήση κεντρικού selectedFolderIdProvider & DraggableFolderSelector
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../widgets/widgets.dart';

class ItemListEmbedded extends ConsumerStatefulWidget {
  final ItemType itemType;
  final int? folderId;
  final ValueChanged<Item> onItemTap;
  final bool showFolderSelector;
  final void Function(Item)? onShare;

  /// Προαιρετικό day-scope (ημερολόγιο): μόνο αυτά τα ids.
  /// null = όλα (όπως πριν — οι άλλες οθόνες ανεπηρέαστες).
  final Set<int>? onlyIds;

  /// True όσο φορτώνει το day-map (δείχνει skeleton αντί για empty state).
  final bool dayLoading;

  const ItemListEmbedded({
    super.key,
    required this.itemType,
    this.folderId,
    required this.onItemTap,
    this.showFolderSelector = true,
    this.onShare,
    this.onlyIds,
    this.dayLoading = false,
  });

  @override
  ItemListEmbeddedState createState() => ItemListEmbeddedState();
}

class ItemListEmbeddedState extends ConsumerState<ItemListEmbedded> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;
  Timer? _debounce;
  String _searchQuery = '';           // ✅
  Set<String> _activeTags = {};       // ✅
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
    _debounce = Timer(AppDuration.debounceSearch, () {
      setState(() => _searchQuery = value.trim());
    });
  }

  void toggleSearch() {
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      setState(() {
        _searchQuery = '';
        _activeTags = {};
      });
    } else {
      Future.microtask(() => _searchFocus.requestFocus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync   = ref.watch(itemsStreamProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);
    final viewMode     = ref.watch(listViewModeProvider);

    DebugConfig.db('📁 ItemListEmbedded: foldersAsync.hasValue=${foldersAsync.hasValue}, count=${foldersAsync.valueOrNull?.length ?? 0}');
    if (foldersAsync.hasValue) {
      for (var f in foldersAsync.valueOrNull ?? []) {
        DebugConfig.db('📁 Folder: id=${f.id}, name=${f.name}');
      }
    }

    final searchQuery = _searchQuery;
    final activeTags = _activeTags;

    // 🆕 Διαβάζουμε τον provider για το κλείδωμα του pop
    final isDragging = ref.watch(isDraggingProvider);

    return PopScope(
      canPop: !isDragging,
      child: Column(
        children: [
          // ── Folder selector (drag target) ───────────────────
          // 🆕 Χρησιμοποιούμε τον αυτόνομο DraggableFolderSelector
          // αντί για το ενσωματωμένο _FolderDropZone
          if (widget.showFolderSelector)
            const DraggableFolderSelector(),
          // ── Chrome (search/tags/toggle): shrinkable wrapper —
          //    με ανοιχτό πληκτρολόγιο ο χώρος μικραίνει και το
          //    σταθερό chrome θα έκανε overflow (RenderFlex).
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Search bar ──────────────────────────────
                  if (_searchActive)
                    _EmbeddedSearchBar(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      hint: 'Αναζήτηση...',
                    ),
                  if (_visibleTagNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Spacing.xs),
                      child: _EmbeddedTagFilterRow(
                        tags: _visibleTagNames.toList(),
                        activeTags: activeTags,
                        onTagTap: (name) {
                          final newSet = {..._activeTags};  // ✅ χρησιμοποιούμε απευθείας το _activeTags
                          if (newSet.contains(name)) {
                            newSet.remove(name);
                          } else {
                            newSet.add(name);
                          }
                          setState(() => _activeTags = newSet);
                        },
                      ),
                    ),
                  const ViewModeToggle(),
                ],
              ),
            ),
          ),
          Expanded(
            child: widget.dayLoading
                ? _EmbeddedLoadingList()
                : RefreshIndicator(
              onRefresh: () async => ref.invalidate(itemsStreamProvider),
              child: itemsAsync.when(
                loading: () => _EmbeddedLoadingList(),
                error: (e, _) => EmptyState.error(
                  onRetry: () => ref.invalidate(itemsStreamProvider),
                ),
                data: (allItems) {
                  var items = allItems
                      .where((i) => i.type == widget.itemType)
                      .toList();

                  if (widget.folderId != null) {
                    items = items
                        .where((i) => i.folderId == widget.folderId)
                        .toList();
                  }

                  // Day-scope (ημερολόγιο): μόνο τα events της ημέρας.
                  if (widget.onlyIds != null) {
                    items = items
                        .where((i) => widget.onlyIds!.contains(i.id))
                        .toList();
                    DebugConfig.db(
                        'ItemListEmbedded day filter shown=${items.length}');
                  }

                  switch (viewMode) {
                    case ListViewMode.pinned:
                      items = items.where((i) => i.pinned).toList();
                      break;
                    case ListViewMode.favorites:
                      items = items.where((i) => i.favorite).toList();
                      break;
                    case ListViewMode.all:
                      break;
                  }

                  final visibleTagNames = <String>{};
                  for (final item in items) {
                    final tags =
                        ref.read(itemTagsProvider(item.id)).valueOrNull ?? [];
                    for (final t in tags) {
                      visibleTagNames.add(t.name);
                    }
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (!setEquals(_visibleTagNames, visibleTagNames)) {
                      setState(() => _visibleTagNames = visibleTagNames);
                    }
                  });

                  var filtered = _filterItems(items, searchQuery);

                  if (activeTags.isNotEmpty) {
                    filtered = filtered.where((item) {
                      final tags = ref.read(itemTagsProvider(item.id)).valueOrNull ?? [];
                      final tagNames = tags.map((t) => t.name);
                      return tagNames.any((name) => activeTags.contains(name));
                    }).toList();
                  }

                  if (filtered.isEmpty) {
                    // Compact + scrollable: το panel κάτω από το grid
                    // έχει λίγο ύψος (overflow σε μικρές οθόνες).
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: EmptyState.forType(
                        widget.itemType,
                        onAction: null,
                        compact: true,
                      ),
                    );
                  }

                  return _EmbeddedItemListBody(
                    items: filtered,
                    itemType: widget.itemType,
                    onTap: widget.onItemTap,
                    onLongPress: (item) => _showItemActions(context, item),
                    onShare: widget.onShare,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Item> _filterItems(List<Item> items, String query) {
    if (query.isEmpty) return items;
    final q = query.toLowerCase();
    return items.where((i) => (i.title ?? '').toLowerCase().contains(q)).toList();
  }

  void _showItemActions(BuildContext context, Item item) {
    ItemActionsSheet.show(
      context,
      item: item,
      onPin: () => _togglePin(item),
      onFav: () => _toggleFav(item),
      onArchive: () => _archive(item),
      onDelete: () => _delete(item),
    );
  }

  Future<void> _togglePin(Item item) async {
    await ref.read(itemNotifierProvider.notifier).togglePin(item.id, item.pinned);
  }

  Future<void> _toggleFav(Item item) async {
    await ref.read(itemNotifierProvider.notifier).toggleFavorite(item.id, item.favorite);
  }

  Future<void> _archive(Item item) async {
    await handleArchive(
      context: context,
      ref: ref,
      itemId: item.id,
      isArchived: item.archived,
      label: ItemLabelX.fromType(widget.itemType),
      showPopOnArchive: false,
      showPopOnUnarchive: false,
    );
  }

  Future<void> _delete(Item item) async {
    final ok = await ConfirmDialog.delete(context, title: 'Διαγραφή στοιχείου;');
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
  }
}

// ──────────────────────────────────────────────
// Βοηθητικά Embedded Widgets
// ──────────────────────────────────────────────

class _EmbeddedSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String hint;

  const _EmbeddedSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cBg,
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding,
        Spacing.sm,
        context.responsiveHPadding,
        Spacing.sm,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: context.bodyMd,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: context.bodyMd.withColor(context.cDisabled),
          prefixIcon: Icon(Icons.search_rounded, color: context.cText2),
          suffixIcon: SearchClearButton(
            controller: controller,
            onCleared: () => onChanged(''),
          ),
          filled: true,
          fillColor: ColorsUI.getSurface(context.brightness),
          border: OutlineInputBorder(
            borderRadius: AppRadius.inputBR,
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
        ),
      ),
    );
  }
}

class _EmbeddedTagFilterRow extends StatelessWidget {
  final List<String> tags;
  final Set<String> activeTags;
  final ValueChanged<String> onTagTap;

  const _EmbeddedTagFilterRow({
    required this.tags,
    required this.activeTags,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
}

class _EmbeddedItemListBody extends ConsumerWidget {
  final List<Item> items;
  final ItemType itemType;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onLongPress;
  final void Function(Item)? onShare;

  const _EmbeddedItemListBody({
    required this.items,
    required this.itemType,
    required this.onTap,
    required this.onLongPress,
    this.onShare,
  });

  void _onReorder(int oldIndex, int newIndex, WidgetRef ref) {
    if (oldIndex == newIndex) return;
    final reordered = List<Item>.from(items);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    ref.read(itemNotifierProvider.notifier).reorder(reordered);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableItemList(
      items: items,
      onReorder: (oldIndex, newIndex) => _onReorder(oldIndex, newIndex, ref),
      // ── ΝΕΟ: κλειδώνει back gesture κατά το reorder drag ──
      onReorderStart: () => ref.read(isDraggingProvider.notifier).state = true,
      onReorderEnd:   () => ref.read(isDraggingProvider.notifier).state = false,
      itemBuilder: (ctx, item, index) => ItemCardBuilder(
        item: item,
        onTap: onTap,
        onLongPress: onLongPress,
        onShare: onShare != null ? () => onShare!(item) : null,
      ),
    );
  }
}

class _EmbeddedLoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.sm,
      ),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, __) => const ItemCardSkeleton(),
    );
  }
}
