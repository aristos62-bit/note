// lib/shared/screens/item_list_screen.dart
//
// Γενική οθόνη λίστας για οποιονδήποτε τύπο Item.
// ✅ Αυτόματη επιλογή φακέλου βάσει ρυθμίσεων (προεπιλεγμένος ή "Γενικά")
// ✅ Περιμένει την τιμή των ρυθμίσεων πριν επιλέξει φάκελο
// ✅ Search, filter tags, FAB δημιουργίας
// ✅ Responsive: list mobile / grid tablet+desktop
// ✅ Dark mode + DebugConfig
// ✅ Fix: κλείδωμα pop κατά το drag (αποφυγή ανεπιθύμητου back gesture)
// ✅ Βελτιστοποίηση: χρήση κεντρικού selectedFolderIdProvider
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../widgets/widgets.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  final ItemType itemType;
  final String title;
  final Widget Function(BuildContext context, Item item, {bool isNew}) detailScreenBuilder;

  const ItemListScreen({
    super.key,
    required this.itemType,
    required this.title,
    required this.detailScreenBuilder,
  });

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen>
    with FolderAutoSelectMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;
  Timer? _debounce;
  final _searchQueryProvider = StateProvider<String>((ref) => '');
  final _activeTagFilterProvider = StateProvider<Set<String>>((ref) => {});
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
      ref.read(_searchQueryProvider.notifier).state = value.trim();
    });
  }

  void _toggleSearch() {
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      ref.read(_searchQueryProvider.notifier).state = '';
      ref.read(_activeTagFilterProvider.notifier).state = {};
    } else {
      Future.microtask(() => _searchFocus.requestFocus());
    }
  }

  Future<void> _createItem() async {
    final selectedFolderId = ref.read(selectedFolderIdProvider);
    if (selectedFolderId == null) return;
    final notifier = ref.read(itemNotifierProvider.notifier);
    final item = await notifier.create(type: widget.itemType, folderId: selectedFolderId);
    if (item == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => widget.detailScreenBuilder(context, item, isNew: true)),
    );
  }

  void _openDetail(Item item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.detailScreenBuilder(context, item, isNew: false),
      ),
    );
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
    final ok = await ConfirmDialog.delete(context, title: 'Διαγραφή;');
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final searchQuery = ref.watch(_searchQueryProvider);
    final activeTags = ref.watch(_activeTagFilterProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final isDragging = ref.watch(isDraggingProvider);

    // 🆕 Διαβάζουμε τον επιλεγμένο φάκελο από τον κεντρικό provider
    final selectedFolderId = ref.watch(selectedFolderIdProvider);

    tryAutoSelectFolder(
      foldersAsync: foldersAsync,
      settingsAsync: settingsAsync,
      debugLabel: 'ItemList',
    );

    return PopScope(
      canPop: !isDragging,
      child: Scaffold(
        backgroundColor: context.cBg,
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              icon: Icon(_searchActive ? Icons.search_off_rounded : Icons.search_rounded),
              onPressed: _toggleSearch,
              tooltip: 'Αναζήτηση',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'archived') {
                  final show = ref.read(showArchivedProvider);
                  ref.read(showArchivedProvider.notifier).state = !show;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'archived',
                  child: Row(children: [
                    const Icon(Icons.archive_rounded, size: 18),
                    const SizedBox(width: Spacing.sm),
                    Text(ref.watch(showArchivedProvider) ? 'Απόκρυψη αρχείου' : 'Εμφάνιση αρχείου'),
                  ]),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: selectedFolderId != null
            ? FloatingActionButton(
          onPressed: _createItem,
          tooltip: 'Νέο',
          child: const Icon(Icons.add_rounded),
        )
            : null,
        body: Column(
          children: [
            if (_searchActive)
              _SearchBar(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                hint: 'Αναζήτηση...',
              ),
            // 🆕 Ο DraggableFolderSelector είναι πλέον αυτόνομος – δεν χρειάζεται parameters
            const DraggableFolderSelector(),
            if (_visibleTagNames.isNotEmpty)
              _TagFilterRow(
                tags: _visibleTagNames.toList(),
                activeTags: activeTags,
                onTagTap: (name) {
                  final current = ref.read(_activeTagFilterProvider);
                  final newSet = {...current};
                  newSet.contains(name) ? newSet.remove(name) : newSet.add(name);
                  ref.read(_activeTagFilterProvider.notifier).state = newSet;
                },
              ),
            const ViewModeToggle(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(itemNotifierProvider),
                child: itemsAsync.when(
                  loading: () => _LoadingList(),
                  error: (e, _) => EmptyState.error(onRetry: () => ref.invalidate(itemNotifierProvider)),
                  data: (allItems) {
                    var items = allItems.where((i) => i.type == widget.itemType).toList();
                    if (selectedFolderId != null) {
                      items = items.where((i) => i.folderId == selectedFolderId).toList();
                    }
                    final viewMode = ref.watch(listViewModeProvider);
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
                      final tags = ref.read(itemTagsProvider(item.id)).valueOrNull ?? [];
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

                    var filtered = _filterItems(items, searchQuery, activeTags);
                    if (filtered.isEmpty) {
                      if (searchQuery.isNotEmpty || activeTags.isNotEmpty) {
                        return EmptyState.search(query: searchQuery);
                      }
                      return EmptyState.forType(widget.itemType, onAction: _createItem);
                    }
                    return _ItemListBody(
                      items: filtered,
                      itemType: widget.itemType,
                      onTap: _openDetail,
                      onLongPress: (item) => _showItemActions(context, item),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Item> _filterItems(List<Item> items, String query, Set<String> tags) {
    var list = items;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((i) => (i.title ?? '').toLowerCase().contains(q)).toList();
    }
    if (tags.isNotEmpty) {
      list = list.where((item) {
        final t = ref.read(itemTagsProvider(item.id)).valueOrNull ?? [];
        return t.map((e) => e.name).any((n) => tags.contains(n));
      }).toList();
    }
    return list;
  }
}

// ── (τα υπόλοιπα widgets _SearchBar, _TagFilterRow, _ItemListBody, _ItemCardWithTags, _LoadingList, _ItemActionsSheet είναι ακριβώς ίδια όπως πριν) ──
// Για λόγους πληρότητας, τα παραθέτω ακριβώς ίδια:

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String hint;
  const _SearchBar({required this.controller, required this.focusNode, required this.onChanged, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cBg,
      padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.sm, context.responsiveHPadding, Spacing.sm),
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
}

class _TagFilterRow extends StatelessWidget {
  final List<String> tags;
  final Set<String> activeTags;
  final ValueChanged<String> onTagTap;
  const _TagFilterRow({required this.tags, required this.activeTags, required this.onTagTap});

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

class _ItemListBody extends StatelessWidget {
  final List<Item> items;
  final ItemType itemType;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onLongPress;
  const _ItemListBody({required this.items, required this.itemType, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return ResponsiveItemList<Item>(
      items: items,
      itemBuilder: (ctx, item) => ItemCardBuilder(
        item: item,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: Spacing.sm),
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
  const _ItemActionsSheet({required this.item, required this.onPin, required this.onFav, required this.onArchive, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
            width: 40, height: 4,
            decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
            child: Text(item.title ?? 'Χωρίς τίτλο', style: context.titleMd, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Divider(),
          ListTile(
            leading: Icon(item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: item.pinned ? context.cPrimary : context.cText2),
            title: Text(item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα'),
            onTap: onPin,
          ),
          ListTile(
            leading: Icon(item.favorite ? Icons.star_rounded : Icons.star_outline_rounded, color: item.favorite ? ColorsUI.getWarning(context.brightness) : context.cText2),
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
