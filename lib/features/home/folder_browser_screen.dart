// lib/features/home/folder_browser_screen.dart
//
// Browser για τα items ενός φακέλου.
// ✅ Real-time stream με itemsByFolderStreamProvider
// ✅ Edit/Delete φακέλου από AppBar
// ✅ Δημιουργία item (note/task/event/contact/journal) στον φάκελο
// ✅ Filter ανά τύπο
// ✅ Responsive: list mobile / grid tablet
// ✅ Dark mode + DebugConfig
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../helpers/item_color_helper.dart';
import '../../shared/widgets/widgets.dart';
import '../notes/note_detail_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../contacts/contact_detail_screen.dart';
import '../journal/journal_detail_screen.dart';
import '../habits/habit_detail_screen.dart';
import '../calendar/event_detail_screen.dart';
import '../collections/collection_detail_screen.dart';

// ════════════════════════════════════════════════════════════════
// FOLDER BROWSER SCREEN
// ════════════════════════════════════════════════════════════════

class FolderBrowserScreen extends ConsumerStatefulWidget {
  final Folder folder;
  const FolderBrowserScreen({super.key, required this.folder});

  @override
  ConsumerState<FolderBrowserScreen> createState() =>
      _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends ConsumerState<FolderBrowserScreen> {
  late Folder _folder;
  ItemType? _typeFilter;

  Color get _folderColor =>
      ItemColorHelper.parseHex(_folder.color) ?? const Color(0xFF6366F1);

  // ── Edit folder (SPoT: FolderFormDialog) ─────────────────────────
  Future<void> _editFolder(BuildContext context) async {
    DebugConfig.nav('FolderBrowser open edit folder id=${_folder.id}');
    final result = await FolderFormDialog.show(
      context,
      title: 'Επεξεργασία Φακέλου',
      confirmLabel: 'Αποθήκευση',
      initialName: _folder.name,
      initialIcon: _folder.icon ?? kDefaultFolderIcon,
      initialColor: _folder.color ?? kDefaultFolderColor,
    );
    if (result == null || !context.mounted) return;
    DebugConfig.db('FolderBrowser update id=${_folder.id} name="${result.name}"');
    try {
      await ref.read(folderNotifierProvider.notifier).rename(
            _folder.id,
            name: result.name,
            icon: result.icon,
            color: result.color,
          );
    } catch (e, s) {
      DebugConfig.error('FolderBrowser rename failed', e, s);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Σφάλμα κατά την αποθήκευση')),
        );
      }
    }
  }

  // ── Delete folder (με try‑catch) ─────────────────────────────
  Future<void> _deleteFolder(BuildContext context) async {
    final future = ConfirmDialog.delete(
      context,
      title: 'Διαγραφή φακέλου "${_folder.name}";',
      subtitle: 'Τα items θα παραμείνουν αλλά δεν θα ανήκουν σε φάκελο.',
    );
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('FolderBrowser delete id=${_folder.id}');

    try {
      await ref.read(folderNotifierProvider.notifier).delete(_folder.id);
      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // ── Create item in folder ────────────────────────────────────
  void _showCreateMenu(BuildContext context) {
    const types = [
      (ItemType.note, '📝', 'Σημείωση'),
      (ItemType.task, '✅', 'Εργασία'),
      (ItemType.event, '📅', 'Συμβάν'),
      (ItemType.habit, '🔄', 'Συνήθεια'),
      (ItemType.journal, '📖', 'Ημερολόγιο'),
      (ItemType.contact, '👤', 'Επαφή'),
      (ItemType.project, '📦', 'Συλλογή'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(
              margin: EdgeInsets.symmetric(vertical: Spacing.sm),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.xs),
              child: Text('Νέο στοιχείο σε "${_folder.name}"',
                  style: context.titleSm),
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...types.map((t) => ListTile(
                          leading:
                              Text(t.$2, style: const TextStyle(fontSize: 22)),
                          title: Text(t.$3, style: context.bodyMd),
                          trailing: Icon(Icons.chevron_right_rounded,
                              size: 18, color: context.cDisabled),
                          onTap: () async {
                            Navigator.pop(context);
                            await _createItem(context, t.$1);
                          },
                        )),
                    const SizedBox(height: Spacing.sm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createItem(BuildContext context, ItemType type) async {
    DebugConfig.nav(
        'FolderBrowser createItem type=${type.name} folderId=${_folder.id}');
    final item = await ref.read(itemNotifierProvider.notifier).create(
          type: type,
          folderId: _folder.id,
        );
    if (item == null || !mounted) return;
    ref.invalidate(itemNotifierProvider);
    if (!context.mounted) return;
    _openItem(context, item);
  }

  // ── Open item (new & existing) ───────────────────────────────
  void _openItem(BuildContext context, Item item) {
    DebugConfig.nav('FolderBrowser → ${item.type.name} id=${item.id}');
    switch (item.type) {
      case ItemType.task:
        Navigator.of(context)
            .push(AppTransitions.slideRoute(TaskDetailScreen(itemId: item.id)));
      case ItemType.contact:
        Navigator.of(context).push(AppTransitions.slideRoute(
            ContactDetailScreen(itemId: item.id, isNew: true)));
      case ItemType.journal:
        Navigator.of(context).push(AppTransitions.slideRoute(
            JournalDetailScreen(itemId: item.id, isNew: true)));
      case ItemType.habit:
        Navigator.of(context).push(AppTransitions.slideRoute(
            HabitDetailScreen(itemId: item.id, isNew: true)));
      case ItemType.event:
        Navigator.of(context).push(AppTransitions.slideRoute(
            EventDetailScreen(itemId: item.id, isNew: true)));
      case ItemType.project:
        Navigator.of(context).push(AppTransitions.slideRoute(
            CollectionDetailScreen(collectionId: item.id, isNew: true)));
      default:
        Navigator.of(context).push(AppTransitions.slideRoute(
            NoteDetailScreen(itemId: item.id, isNew: true)));
    }
  }

  void _openExisting(BuildContext context, Item item) {
    DebugConfig.nav(
        'FolderBrowser open existing ${item.type.name} id=${item.id}');
    switch (item.type) {
      case ItemType.task:
        Navigator.of(context)
            .push(AppTransitions.slideRoute(TaskDetailScreen(itemId: item.id)));
      case ItemType.contact:
        Navigator.of(context).push(
            AppTransitions.slideRoute(ContactDetailScreen(itemId: item.id)));
      case ItemType.journal:
        Navigator.of(context).push(
            AppTransitions.slideRoute(JournalDetailScreen(itemId: item.id)));
      case ItemType.habit:
        Navigator.of(context).push(
            AppTransitions.slideRoute(HabitDetailScreen(itemId: item.id)));
      case ItemType.event:
        Navigator.of(context).push(
            AppTransitions.slideRoute(EventDetailScreen(itemId: item.id)));
      case ItemType.project:
        Navigator.of(context).push(AppTransitions.slideRoute(
            CollectionDetailScreen(collectionId: item.id)));
      default:
        Navigator.of(context)
            .push(AppTransitions.slideRoute(NoteDetailScreen(itemId: item.id)));
    }
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Συγχρονισμός _folder από real-time stream (όχι μόνο widget.folder)
    _folder = ref.watch(folderByIdProvider(widget.folder.id)).valueOrNull ?? widget.folder;
    DebugConfig.provider('FolderBrowserScreen build id=${_folder.id}');
    final folderItemsAsync = ref.watch(itemsByFolderStreamProvider(_folder.id));
    final isDragging = ref.watch(isDraggingProvider); // ← ΝΕΟ

    return PopScope(
      // ← ΝΕΟ: κλειδώνει back gesture κατά το drag
      canPop: !isDragging,
      child: Scaffold(
        backgroundColor: context.cBg,
        appBar: _buildAppBar(context),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateMenu(context),
          backgroundColor: _folderColor,
          foregroundColor: Colors.white,
          tooltip: 'Νέο στοιχείο',
          child: const Icon(Icons.add_rounded),
        ),
        body: Column(
          children: [
            // Type filter
            _TypeFilter(
              selected: _typeFilter,
              onChanged: (t) => setState(() => _typeFilter = t),
            ),
            // Items list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(itemNotifierProvider),
                child: folderItemsAsync.when(
                  loading: () => ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.responsiveHPadding,
                      vertical: Spacing.sm,
                    ),
                    itemCount: 4,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Spacing.sm),
                    itemBuilder: (_, __) => const ItemCardSkeleton(),
                  ),
                  error: (e, _) {
                    DebugConfig.error('FolderBrowser load', e);
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.responsiveHPadding),
                        child: Text('Σφάλμα φόρτωσης: $e',
                            style: context.bodySm.withColor(context.cError)),
                      ),
                    );
                  },
                  data: (items) {
                    // Εφαρμογή φίλτρου τύπου (αν υπάρχει)
                    var filteredItems = items;
                    if (_typeFilter != null) {
                      filteredItems =
                          items.where((i) => i.type == _typeFilter).toList();
                    }

                    if (filteredItems.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: context.responsivePadding,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_folder.icon ?? '📁',
                                  style: const TextStyle(fontSize: 64)),
                              const SizedBox(height: Spacing.md),
                              Text('Ο φάκελος είναι άδειος',
                                  style: context.titleMd),
                              const SizedBox(height: Spacing.sm),
                              Text(
                                'Πάτησε + για να προσθέσεις\nτο πρώτο στοιχείο.',
                                style: context.bodyMd.withColor(context.cText2),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ResponsiveLayout(
                      mobile: _ItemsList(
                        items: filteredItems,
                        onTap: (i) => _openExisting(context, i),
                        onDelete: (i) => _deleteItem(i),
                        onShare: (i) => ShareService.shareItem(context, i.id),
                        // ── ΝΕΟ: reorder callbacks ──────────────────
                        onReorder: (oldIdx, newIdx) {
                          if (oldIdx == newIdx) return;
                          final reordered = List<Item>.from(filteredItems);
                          final moved = reordered.removeAt(oldIdx);
                          reordered.insert(
                            newIdx,
                            moved,
                          );
                          ref.read(itemNotifierProvider.notifier).reorder(reordered);
                        },
                        onReorderStart: () =>
                        ref.read(isDraggingProvider.notifier).state = true,
                        onReorderEnd: () =>
                        ref.read(isDraggingProvider.notifier).state = false,
                      ),
                      tablet: _ItemsGrid(
                        items: filteredItems,
                        onTap: (i) => _openExisting(context, i),
                        onDelete: (i) => _deleteItem(i),
                        onShare: (i) => ShareService.shareItem(context, i.id),
                      ),
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

  AppBar _buildAppBar(BuildContext context) => AppBar(
        backgroundColor: context.cBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_folder.icon ?? '📁', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: Spacing.xs),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_folder.name,
                      style: context.titleSm, overflow: TextOverflow.ellipsis),
                  Text('Όλα τα Στοιχεία',
                      style: context.labelSm.withColor(context.cText2)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded, color: context.cText2),
            tooltip: 'Επεξεργασία φακέλου',
            onPressed: () => _editFolder(context),
          ),
          if (!_folder.isSystem)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: context.cError),
              tooltip: 'Διαγραφή φακέλου',
              onPressed: () => _deleteFolder(context),
            ),
        ],
      );

  Future<void> _deleteItem(Item item) async {
    final future = ConfirmDialog.delete(
      context,
      title: 'Διαγραφή "${item.title ?? 'στοιχείου'}";',
    );
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('FolderBrowser deleteItem id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    ref.invalidate(itemNotifierProvider);
  }

}

// ════════════════════════════════════════════════════════════════
// TYPE FILTER BAR (unchanged)
// ════════════════════════════════════════════════════════════════

class _TypeFilter extends StatelessWidget {
  final ItemType? selected;
  final ValueChanged<ItemType?> onChanged;

  const _TypeFilter({required this.selected, required this.onChanged});

  static const _types = [
    (null, 'Όλα'),
    (ItemType.note, 'Σημειώσεις'),
    (ItemType.task, 'Εργασίες'),
    (ItemType.event, 'Συμβάντα'),
    (ItemType.habit, 'Συνήθειες'),
    (ItemType.journal, 'Ημερολόγιο'),
    (ItemType.contact, 'Επαφές'),
    (ItemType.project, 'Συλλογές'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical: Spacing.xs,
        ),
        itemCount: _types.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
        itemBuilder: (_, i) {
          final type = _types[i].$1;
          final label = _types[i].$2;
          final isActive = selected == type;
          final color = type != null
              ? ColorsUI.itemTypeColor(type, context.brightness)
              : context.cPrimary;

          return GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: AppDuration.fast,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm + 2, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.12)
                    : ColorsUI.getSurface(context.brightness),
                borderRadius: BorderRadius.circular(AppRadius.badge),
                border: Border.all(
                  color:
                      isActive ? color : ColorsUI.getBorder(context.brightness),
                ),
              ),
              child: Text(label,
                  style: context.labelSm
                      .withColor(isActive ? color : context.cText2)),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ITEMS LIST — mobile (unchanged)
// ════════════════════════════════════════════════════════════════

class _ItemsList extends StatelessWidget {
  final List<Item> items;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onDelete;
  final ValueChanged<Item>? onShare;
  // ── ΝΕΟ ──────────────────────────────────────────────────────
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback? onReorderStart;
  final VoidCallback? onReorderEnd;

  const _ItemsList({
    required this.items,
    required this.onTap,
    required this.onDelete,
    this.onShare,
    required this.onReorder,      // ← ΝΕΟ
    this.onReorderStart,          // ← ΝΕΟ
    this.onReorderEnd,            // ← ΝΕΟ
  });

  @override
  Widget build(BuildContext context) {
    // ── Αντικαθιστά το ListView.separated ────────────────────
    return ReorderableItemList(
      items: items,
      onReorder: onReorder,
      onReorderStart: onReorderStart,
      onReorderEnd: onReorderEnd,
      itemBuilder: (ctx, item, index) => Consumer(
        builder: (_, ref, __) {
          final overrideColor = ref.watch(itemTypeCardColorOverrideProvider(item.type));
          return ItemCard(
            item: item,
            compact: true,
            customBackgroundColor: overrideColor,
            onTap: () => onTap(item),
            onLongPress: () => _showActions(ctx, item),
            onShare: onShare != null ? () => onShare!(item) : null,
          );
        },
      ),
    );
  }

  void _showActions(BuildContext context, Item item) {
    ItemActionsSheet.show(
      context,
      item: item,
      titleStyle: context.titleSm,
      onEdit: () => onTap(item),
      onDelete: () => onDelete(item),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ITEMS GRID — tablet (unchanged)
// ════════════════════════════════════════════════════════════════

class _ItemsGrid extends StatelessWidget {
  final List<Item> items;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onDelete;
  final ValueChanged<Item>? onShare;

  const _ItemsGrid({
    required this.items,
    required this.onTap,
    required this.onDelete,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding,
        Spacing.sm,
        context.responsiveHPadding,
        80,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.gridColumns,
        mainAxisSpacing: Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        mainAxisExtent: 100,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => Consumer(
        builder: (_, ref, __) {
          final overrideColor = ref.watch(itemTypeCardColorOverrideProvider(items[i].type));
          return ItemCard(
            item: items[i],
            customBackgroundColor: overrideColor,
            onTap: () => onTap(items[i]),
            onShare: onShare != null ? () => onShare!(items[i]) : null,
          );
        },
      ),
    );
  }
}


