// lib/shared/screens/item_list_screen.dart
//
// Γενική οθόνη λίστας για οποιονδήποτε τύπο Item.
// ✅ Αυτόματη επιλογή φακέλου βάσει ρυθμίσεων (προεπιλεγμένος ή "Γενικά")
// ✅ Περιμένει την τιμή των ρυθμίσεων πριν επιλέξει φάκελο
// ✅ FAB δημιουργίας
// ✅ Responsive: list mobile / grid tablet+desktop
// ✅ Dark mode + DebugConfig
// ✅ Fix: κλείδωμα pop κατά το drag (αποφυγή ανεπιθύμητου back gesture)
// ✅ Βελτιστοποίηση: χρήση κεντρικού selectedFolderIdProvider
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../widgets/widgets.dart';

// ΜΕΤΑ:
class ItemListScreen extends ConsumerStatefulWidget {
  final ItemType itemType;
  final String title;
  final Widget Function(BuildContext context, Item item, {bool isNew}) detailScreenBuilder;

  /// Προαιρετικό override για το FAB.
  /// Αν οριστεί, χρησιμοποιείται αντί του default FAB.
  /// Το widget είναι υπεύθυνο για τη δική του visibility λογική.
  final Widget? floatingActionButtonOverride;

  const ItemListScreen({
    super.key,
    required this.itemType,
    required this.title,
    required this.detailScreenBuilder,
    this.floatingActionButtonOverride,  // ← ΝΕΟ
  });

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen>
    with FolderAutoSelectMixin {
  bool _showArchiveHintShown = false;

  @override
  void dispose() {
    super.dispose();
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
    DebugConfig.db('ItemListScreen _archive id=${item.id} archived=${item.archived}');
    Navigator.pop(context);
    await handleArchive(
      context: context,
      ref: ref,
      itemId: item.id,
      isArchived: item.archived,
      label: _labelForType(widget.itemType),
      showPopOnArchive: false,
      showPopOnUnarchive: false,
    );
    DebugConfig.db('ItemListScreen _archive DONE id=${item.id}');
  }

  ItemLabel _labelForType(ItemType type) {
    switch (type) {
      case ItemType.note:        return ItemLabel.note;
      case ItemType.task:        return ItemLabel.task;
      case ItemType.event:       return ItemLabel.event;
      case ItemType.contact:     return ItemLabel.contact;
      case ItemType.habit:       return ItemLabel.habit;
      case ItemType.journal:     return ItemLabel.journal;
      case ItemType.appointment: return ItemLabel.appointment;
      case ItemType.knowledge:   return ItemLabel.entry;
      default:                   return ItemLabel.note;
    }
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
                    Text(ref.watch(showArchivedProvider) ? 'Απόκρυψη συμπιεσμένων αρχείων' : 'Εμφάνιση συμπιεσμένων αρχείων'),
                  ]),
                ),
              ],
            ),
          ],
        ),
        // ΜΕΤΑ:
        floatingActionButton: widget.floatingActionButtonOverride ??
            (selectedFolderId != null
                ? FloatingActionButton(
              onPressed: _createItem,
              tooltip: 'Νέο',
              child: const Icon(Icons.add_rounded),
            )
                : null),
        body: Column(
          children: [
            const DraggableFolderSelector(),
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

                    if (items.isEmpty) {
                      return EmptyState.forType(widget.itemType, onAction: _createItem);
                    }
                    return _ItemListBody(
                      items: items,
                      itemType: widget.itemType,
                      onTap: _openDetail,
                      onLongPress: (item) => _showItemActions(context, item),
                      onShare: (item) => ShareService.shareItem(context, item.id),
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

}

class _ItemListBody extends ConsumerWidget {
  final List<Item> items;
  final ItemType itemType;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onLongPress;
  final ValueChanged<Item>? onShare;

  const _ItemListBody({
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
      onReorderStart: () => ref.read(isDraggingProvider.notifier).state = true,
      onReorderEnd:   () => ref.read(isDraggingProvider.notifier).state = false,
      itemBuilder: (ctx, item, index) => ItemCardBuilder(
        item: item,
        tagNames: const [],
        onTap: onTap,
        onLongPress: onLongPress,
        onShare: onShare != null ? () => onShare!(item) : null,
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
