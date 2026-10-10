//
// Home Folder View — εμφάνιση περιεχομένου φακέλου
// ✅ ViewMode: pinned | favorites | recent | all
// ✅ Real-time
// ✅ Responsive
// ✅ Dark mode
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'folder_browser_screen.dart';
import 'package:go_router/go_router.dart';
import '../../services/services.dart';
import '../../helpers/item_color_helper.dart';
import '../collections/knowledge_entry_nav.dart';

// ── View Mode για το φάκελο ───────────────────────────────────
enum FolderViewMode { pinned, favorites, recent, all }

// ════════════════════════════════════════════════════════════════
// HOME FOLDER VIEW
// ════════════════════════════════════════════════════════════════

class HomeFolderView extends ConsumerStatefulWidget {
  final Folder folder;
  const HomeFolderView({super.key, required this.folder});

  @override
  ConsumerState<HomeFolderView> createState() => _HomeFolderViewState();
}

class _HomeFolderViewState extends ConsumerState<HomeFolderView> {
  Folder get folder => widget.folder;
  FolderViewMode _viewMode = FolderViewMode.recent;

  void _showCreateMenu(BuildContext context) async {
    final type =
        await FolderCreateSheet.show(context, folderName: folder.name);
    if (type == null || !mounted) return;
    if (!context.mounted) return;
    await _createItem(context, type);
  }

  Future<void> _createItem(BuildContext context, ItemType type) async {
    DebugConfig.nav('🔨 _createItem called with type: ${type.name}');
    DebugConfig.nav('HomeFolderView createItem type=${type.name}');
    final item = await ref.read(itemNotifierProvider.notifier).create(
      type: type,
      folderId: folder.id,
    );
    if (item == null || !mounted) return;
    DebugConfig.nav('✅ Item created: id=${item.id}, type=${item.type}');
    ref.invalidate(itemNotifierProvider);
    if (!context.mounted)return;
    _openItem(context, item, isNew: true);
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('HomeFolderView build folder=${folder.id}');

    final folderData  = ref.watch(folderViewDataProvider(folder.id));
    // ΝΕΟ: itemsByFolderStreamProvider → ταξινόμηση από sortOrder (κρατά τη σειρά μετά reorder)
    final allItems    = ref.watch(itemsByFolderStreamProvider(folder.id));
    final isDragging  = ref.watch(isDraggingProvider);
    final folderColor = ItemColorHelper.parseHex(folder.color) ?? context.cPrimary;

    return PopScope(
      canPop: !isDragging,
      child: Stack(
        children: [
          // Column αντί CustomScrollView → επιτρέπει ReorderableItemList με Expanded
          Column(
            children: [
              // Stats — fixed header
              folderData.when(
                loading: () => _StatsRowSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) => _FolderStatsRow(stats: data.stats),
              ),
              // ViewMode toggle — fixed header
              _FolderViewModeToggle(
                current: _viewMode,
                onChanged: (mode) {
                  DebugConfig.nav('HomeFolderView: mode changed to $mode');
                  if (mode == FolderViewMode.all) {
                    Navigator.of(context).push(AppTransitions.slideRoute(
                        FolderBrowserScreen(folder: folder)));
                  } else {
                    setState(() => _viewMode = mode);
                  }
                },
              ),
              // Scrollable list — Expanded παίρνει το υπόλοιπο ύψος
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(itemsByFolderStreamProvider(folder.id));
                    ref.invalidate(folderViewDataProvider(folder.id));
                  },
                  child: _buildContent(context, allItems),
                ),
              ),
            ],
          ),
          // FAB πάνω από τη λίστα
          Positioned(
            right: Spacing.md,
            bottom: Spacing.lg,
            child: FloatingActionButton(
              onPressed: () => _showCreateMenu(context),
              backgroundColor: folderColor,
              foregroundColor: Colors.white,
              tooltip: 'Νέο στοιχείο',
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }

  // Δέχεται πλέον allItems (sortOrder-sorted) αντί για folderViewData
  Widget _buildContent(
      BuildContext context,
      AsyncValue<List<Item>> allItemsAsync,
      ) {
    if (_viewMode == FolderViewMode.all) return const SizedBox.shrink();

    return allItemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        DebugConfig.error('HomeFolderView data', e);
        return const SizedBox.shrink();
      },
      data: (all) {
        final items = switch (_viewMode) {
          FolderViewMode.pinned    => all.where((i) => i.pinned   && i.deletedAt == null).toList(),
          FolderViewMode.favorites => all.where((i) => i.favorite && i.deletedAt == null).toList(),
          FolderViewMode.recent    => all.where((i) => i.deletedAt == null && !i.archived).take(10).toList(),
          FolderViewMode.all       => <Item>[],
        };
        // Περνάμε και τη full λίστα για σωστό reorder
        return _buildItemsList(context, items, allItems: all);
      },
    );
  }

  Widget _buildItemsList(BuildContext context, List<Item> items, {required List<Item> allItems}) {
    if (items.isEmpty) return _buildEmptyState(context);

    return ReorderableItemList(
      items: items,
      gridItemExtent: 100,
      onReorder: (oldIdx, newIdx) {
        if (oldIdx == newIdx) return;
        final merged = ReorderUtils.moveAndMerge(full: allItems, filtered: items, oldIndex: oldIdx, newIndex: newIdx);
        ref.read(itemNotifierProvider.notifier).reorder(merged);
      },
      onReorderStart: () => ref.read(isDraggingProvider.notifier).state = true,
      onReorderEnd:   () => ref.read(isDraggingProvider.notifier).state = false,
      itemBuilder: (ctx, item, index) {
        final overrideColor = ref.watch(itemTypeCardColorOverrideProvider(item.type));
        return DraggableItemWrapper(
          itemId: item.id,
          child: _FolderItemCard(
            item: item,
            onTap: () => _openItem(context, item),
            onShare: () => ShareService.shareItem(context, item.id),
            cardBackgroundColor: overrideColor,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final (icon, title, subtitle) = switch (_viewMode) {
      FolderViewMode.pinned    => (Icons.push_pin_outlined,    'Δεν υπάρχουν καρφιτσωμένα στοιχεία', 'Καρφίτσωσε στοιχεία για να τα βλέπεις εδώ.'),
      FolderViewMode.favorites => (Icons.star_outline_rounded, 'Δεν υπάρχουν αγαπημένα στοιχεία',    'Πρόσθεσε αγαπημένα για να τα βλέπεις εδώ.'),
      FolderViewMode.recent    => (Icons.history_rounded,      'Δεν υπάρχουν πρόσφατα στοιχεία',     'Δημιούργησε στοιχεία στον φάκελο για να τα βλέπεις εδώ.'),
      FolderViewMode.all       => (Icons.inbox_rounded,        'Ο φάκελος είναι άδειος',              'Πάτα + για να δημιουργήσεις το πρώτο στοιχείο.'),
    };
    // Center αντί SliverToBoxAdapter — συμβατό με Column+Expanded
    return EmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
    );
  }

  void _openItem(BuildContext context, Item item, {bool isNew = false}) {
    DebugConfig.nav('HomeFolderView → ${item.type.name} id=${item.id} isNew=$isNew');
    if (item.type == ItemType.knowledge) {
      openKnowledgeEntry(context, ref, item);
      return;
    }
    final route =
        AppRoutes.forType(item.type, item.id) ?? AppRoutes.note(item.id);
    context.push(route, extra: isNew);
  }

}

// ════════════════════════════════════════════════════════════════
// FOLDER VIEW MODE TOGGLE (κυκλικά κουμπιά, μόνο εικονίδια)
// ════════════════════════════════════════════════════════════════

class _FolderViewModeToggle extends StatelessWidget {
  final FolderViewMode current;
  final ValueChanged<FolderViewMode> onChanged;

  const _FolderViewModeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Spacing.sm),
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: CircleToggleButton.row(
        children: [
          CircleToggleButton(
            icon: Icons.push_pin_rounded,
            tooltip: 'Καρφιτσωμένα',
            isSelected: current == FolderViewMode.pinned,
            activeColor: context.cError,
            onTap: () => onChanged(FolderViewMode.pinned),
          ),
          CircleToggleButton(
            icon: Icons.star_rounded,
            tooltip: 'Αγαπημένα',
            isSelected: current == FolderViewMode.favorites,
            activeColor: context.cWarning,
            onTap: () => onChanged(FolderViewMode.favorites),
          ),
          CircleToggleButton(
            icon: Icons.history_rounded,
            tooltip: 'Πρόσφατα',
            isSelected: current == FolderViewMode.recent,
            activeColor: context.cInfo,
            onTap: () => onChanged(FolderViewMode.recent),
          ),
          CircleToggleButton(
            icon: Icons.list_rounded,
            tooltip: 'Όλα',
            isSelected: current == FolderViewMode.all,
            activeColor: context.cSuccess,
            onTap: () => onChanged(FolderViewMode.all),
          ),
        ],
      ),
    );
  }
}

// _ToggleButton διαγράφηκε (Φ4a βήμα 9) — SPoT: CircleToggleButton.
// _ViewModeToggle/_FolderViewModeToggle μοιράζονται layout via CircleToggleButton.row (Φ4a βήμα 10).

// ════════════════════════════════════════════════════════════════
// FOLDER STATS ROW (unchanged)
// ════════════════════════════════════════════════════════════════

class _FolderStatsRow extends StatelessWidget {
  final Map<ItemType, int> stats;
  const _FolderStatsRow({required this.stats});

  static const _shown = [
    ItemType.note, ItemType.task, ItemType.event, ItemType.habit,
    ItemType.journal, ItemType.contact, ItemType.project, ItemType.appointment,
  ];

  @override
  Widget build(BuildContext context) {
    final activeTypes = _shown.where((t) => (stats[t] ?? 0) > 0).toList();
    if (activeTypes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xs),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
          itemCount: activeTypes.length,
          separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
          itemBuilder: (_, i) {
            final type = activeTypes[i];
            final count = stats[type] ?? 0;
            final color = ColorsUI.itemTypeColor(type, context.brightness);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ItemTypeIcon(type, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: context.labelSm.withColor(color).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xs),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
          itemBuilder: (_, __) => Container(
            width: 50,
            height: 28,
            decoration: BoxDecoration(
              color: ColorsUI.getBorder(context.brightness).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FOLDER ITEM CARD (με χρώμα ανά τύπο, ίδια δομή)
// ════════════════════════════════════════════════════════════════

class _FolderItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;
  final VoidCallback? onShare;
  final Color? cardBackgroundColor;
  const _FolderItemCard({required this.item, required this.onTap, this.onShare, this.cardBackgroundColor});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = cardBackgroundColor ??
        ItemColorHelper.backgroundColorForType(item.type, context);
    final textColor = ItemColorHelper.textColorForBackground(backgroundColor, context);
    final itemColor = ItemColorHelper.iconColorForType(item.type, context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.cardBR,
          border: Border.all(color: itemColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ItemTypeIcon(item.type, size: 13, color: itemColor),
                const SizedBox(width: Spacing.xs),
                Text(
                  ItemTypeIcon.labelFor(item.type),
                  style: context.labelSm.copyWith(color: textColor),
                ),
                const Spacer(),
                if (item.pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin_rounded, size: 12, color: textColor),
                  ),
                if (item.favorite)
                  Icon(Icons.star_rounded, size: 12, color: textColor),
                if (onShare != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: GestureDetector(
                      onTap: onShare,
                      child: Icon(Icons.share_rounded, size: 16, color: textColor.withValues(alpha: 0.6)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              item.title ?? 'Χωρίς τίτλο',
              style: context.bodyMd.copyWith(color: textColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}