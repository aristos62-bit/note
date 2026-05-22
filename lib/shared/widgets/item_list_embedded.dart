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

  const ItemListEmbedded({
    super.key,
    required this.itemType,
    this.folderId,
    required this.onItemTap,
    this.showFolderSelector = true,
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
    _debounce = Timer(const Duration(milliseconds: 300), () {
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
          // ── Search bar ──────────────────────────────────────
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
          Expanded(
            child: RefreshIndicator(
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
                    return EmptyState.forType(
                      widget.itemType,
                      onAction: null,
                    );
                  }

                  return _EmbeddedItemListBody(
                    items: filtered,
                    itemType: widget.itemType,
                    onTap: widget.onItemTap,
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

  List<Item> _filterItems(List<Item> items, String query) {
    if (query.isEmpty) return items;
    final q = query.toLowerCase();
    return items.where((i) => (i.title ?? '').toLowerCase().contains(q)).toList();
  }

  void _showItemActions(BuildContext context, Item item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => _ItemActionsSheet(
        item: item,
        onPin: () => _togglePin(item),
        onFav: () => _toggleFav(item),
        onArchive: () => _archive(item),
        onDelete: () => _delete(item),
      ),
    );
  }

  Future<void> _togglePin(Item item) async {
    Navigator.pop(context);
    await ref.read(itemNotifierProvider.notifier).togglePin(item.id, item.pinned);
  }

  Future<void> _toggleFav(Item item) async {
    Navigator.pop(context);
    await ref.read(itemNotifierProvider.notifier).toggleFavorite(item.id, item.favorite);
  }

  Future<void> _archive(Item item) async {
    Navigator.pop(context);
    final ok = await ConfirmDialog.archive(context);
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).toggleArchive(item.id, item.archived);
  }

  Future<void> _delete(Item item) async {
    Navigator.pop(context);
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

  const _EmbeddedItemListBody({
    required this.items,
    required this.itemType,
    required this.onTap,
    required this.onLongPress,
  });

  void _onReorder(int oldIndex, int newIndex, WidgetRef ref) {
    if (oldIndex == newIndex) return;
    final reordered = List<Item>.from(items);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.cBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg,
              vertical: Spacing.xs,
            ),
            child: Text(
              item.title ?? 'Χωρίς τίτλο',
              style: context.titleMd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(),
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