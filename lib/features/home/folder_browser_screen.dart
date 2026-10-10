// lib/features/home/folder_browser_screen.dart
//
// Browser για τα items ενός φακέλου.
// ✅ Real-time stream με itemsByFolderStreamProvider
// ✅ Edit/Delete φακέλου από AppBar
// ✅ Δημιουργία item (SPoT: FolderCreateSheet) στον φάκελο
// ✅ Filter ανά τύπο
// ✅ Responsive: list mobile / grid tablet
// ✅ Dark mode + DebugConfig
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../helpers/item_color_helper.dart';
import '../../shared/widgets/widgets.dart';
import '../collections/knowledge_entry_nav.dart';
import 'folder_browser_filter.dart';
import 'folder_browser_items.dart';

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
          const SnackBar(content: Text(AppErrors.saveFailed)),
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
          const SnackBar(content: Text(AppErrors.saveFailed)),
        );
      }
    }
  }

  // ── Create item in folder (SPoT: FolderCreateSheet) ─────────
  void _showCreateMenu(BuildContext context) async {
    final type = await FolderCreateSheet.show(context, folderName: _folder.name);
    if (type == null || !mounted) return;
    if (!context.mounted) return;
    await _createItem(context, type);
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
    final route =
        AppRoutes.forType(item.type, item.id) ?? AppRoutes.note(item.id);
    context.push(route, extra: true);
  }

  void _openExisting(BuildContext context, Item item) {
    DebugConfig.nav(
        'FolderBrowser open existing ${item.type.name} id=${item.id}');
    if (item.type == ItemType.knowledge) {
      openKnowledgeEntry(context, ref, item);
      return;
    }
    final route =
        AppRoutes.forType(item.type, item.id) ?? AppRoutes.note(item.id);
    context.push(route);
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
            FolderTypeFilter(
              selected: _typeFilter,
              onChanged: (t) {
                DebugConfig.nav('FolderBrowser filter=${t?.name}');
                setState(() => _typeFilter = t);
              },
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
                        child: Text(AppErrors.loadFailed,
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
                      mobile: FolderItemsList(
                        items: filteredItems,
                        onTap: (i) => _openExisting(context, i),
                        onDelete: (i) => _deleteItem(i),
                        onShare: (i) => ShareService.shareItem(context, i.id),
                        // ── ΝΕΟ: reorder callbacks ──────────────────
                        onReorder: (oldIdx, newIdx) {
                          if (oldIdx == newIdx) return;
                          final full = ref.read(itemsByFolderStreamProvider(_folder.id)).valueOrNull ?? const [];
                          final merged = ReorderUtils.moveAndMerge(full: full, filtered: filteredItems, oldIndex: oldIdx, newIndex: newIdx);
                          ref.read(itemNotifierProvider.notifier).reorder(merged);
                        },
                        onReorderStart: () =>
                        ref.read(isDraggingProvider.notifier).state = true,
                        onReorderEnd: () =>
                        ref.read(isDraggingProvider.notifier).state = false,
                      ),
                      tablet: FolderItemsGrid(
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


