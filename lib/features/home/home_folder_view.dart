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

  void _showCreateMenu(BuildContext context) {
    const types = [
      (ItemType.note, '📝', 'Σημείωση'),
      (ItemType.task, '✅', 'Εργασία'),
      (ItemType.event, '📅', 'Συμβάν'),
      (ItemType.habit, '🔄', 'Συνήθεια'),
      (ItemType.journal, '📖', 'Ημερολόγιο'),
      (ItemType.contact, '👤', 'Επαφή'),
      (ItemType.project, '📦', 'Συλλογή'),
      (ItemType.appointment, '📅', 'Ραντεβού'),
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
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
              child: Text('Νέο στοιχείο σε "${folder.name}"', style: context.titleSm),
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...types.map((t) => ListTile(
                      leading: Text(t.$2, style: const TextStyle(fontSize: 22)),
                      title: Text(t.$3, style: context.bodyMd),
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: context.cDisabled),
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
    DebugConfig.nav('HomeFolderView createItem type=${type.name}');
    final item = await ref.read(itemNotifierProvider.notifier).create(
      type: type,
      folderId: folder.id,
    );
    if (item == null || !mounted) return;
    ref.invalidate(itemNotifierProvider);
    _openItem(context, item, isNew: true);
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('HomeFolderView build folder=${folder.id}');

    final statsAsync = ref.watch(folderStatsProvider(folder.id));
    final pinnedAsync = ref.watch(pinnedByFolderStreamProvider(folder.id));
    final favoritesAsync = ref.watch(favoritesByFolderStreamProvider(folder.id));
    final recentAsync = ref.watch(recentByFolderProvider(folder.id));

    final folderColor = _colorFromHex(folder.color, context.cPrimary);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(itemsByFolderStreamProvider(folder.id));
            ref.invalidate(folderStatsProvider(folder.id));
            ref.invalidate(pinnedByFolderStreamProvider(folder.id));
            ref.invalidate(favoritesByFolderStreamProvider(folder.id));
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: statsAsync.when(
                  loading: () => _StatsRowSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (stats) => _FolderStatsRow(stats: stats),
                ),
              ),
              SliverToBoxAdapter(
                child: _FolderViewModeToggle(
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
              ),
              if (_viewMode == FolderViewMode.all)
                const SliverToBoxAdapter(child: SizedBox.shrink())
              else
                _buildContent(context, pinnedAsync, favoritesAsync, recentAsync),
            ],
          ),
        ),
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
    );
  }

  Widget _buildContent(
      BuildContext context,
      AsyncValue<List<Item>> pinnedAsync,
      AsyncValue<List<Item>> favoritesAsync,
      AsyncValue<List<Item>> recentAsync,
      ) {
    switch (_viewMode) {
      case FolderViewMode.pinned:
        return pinnedAsync.when(
          loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
          error: (e, _) {
            DebugConfig.error('HomeFolderView pinned', e);
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
          data: (items) => _buildItemsList(context, items),
        );
      case FolderViewMode.favorites:
        return favoritesAsync.when(
          loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
          error: (e, _) {
            DebugConfig.error('HomeFolderView favorites', e);
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
          data: (items) => _buildItemsList(context, items),
        );
      case FolderViewMode.recent:
        return recentAsync.when(
          loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
          error: (e, _) {
            DebugConfig.error('HomeFolderView recent', e);
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
          data: (items) => _buildItemsList(context, items),
        );
      case FolderViewMode.all:
        return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }

  Widget _buildItemsList(BuildContext context, List<Item> items) {
    if (items.isEmpty) return _buildEmptyState(context);

    if (context.isMobile) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(
          context.responsiveHPadding, Spacing.md,
          context.responsiveHPadding, 100,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _FolderItemCard(
                item: items[i],
                onTap: () => _openItem(context, items[i]),
              ),
            ),
            childCount: items.length,
          ),
        ),
      );
    } else {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(
          context.responsiveHPadding, Spacing.md,
          context.responsiveHPadding, 100,
        ),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: context.gridColumns,
            mainAxisSpacing: Spacing.sm,
            crossAxisSpacing: Spacing.sm,
            mainAxisExtent: 100,
          ),
          delegate: SliverChildBuilderDelegate(
                (_, i) => _FolderItemCard(
              item: items[i],
              onTap: () => _openItem(context, items[i]),
            ),
            childCount: items.length,
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final (icon, title, subtitle) = switch (_viewMode) {
      FolderViewMode.pinned => (Icons.push_pin_outlined, 'Δεν υπάρχουν καρφιτσωμένα στοιχεία', 'Καρφίτσωσε στοιχεία για να τα βλέπεις εδώ.'),
      FolderViewMode.favorites => (Icons.star_outline_rounded, 'Δεν υπάρχουν αγαπημένα στοιχεία', 'Πρόσθεσε αγαπημένα για να τα βλέπεις εδώ.'),
      FolderViewMode.recent => (Icons.history_rounded, 'Δεν υπάρχουν πρόσφατα στοιχεία', 'Δημιούργησε στοιχεία στον φάκελο για να τα βλέπεις εδώ.'),
      FolderViewMode.all => (Icons.inbox_rounded, 'Ο φάκελος είναι άδειος', 'Πάτα + για να δημιουργήσεις το πρώτο στοιχείο.'),
    };
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.xl, context.responsiveHPadding, 0),
        child: Column(children: [
          Icon(icon, size: 56, color: context.cDisabled),
          const SizedBox(height: Spacing.md),
          Text(title, style: context.titleMd),
          const SizedBox(height: Spacing.sm),
          Text(subtitle, style: context.bodyMd.withColor(context.cText2), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  static Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  void _openItem(BuildContext context, Item item, {bool isNew = false}) {
    DebugConfig.nav('HomeFolderView → ${item.type.name} id=${item.id}');
    switch (item.type) {
      case ItemType.task:
        context.push(AppRoutes.task(item.id));
        break;
      case ItemType.contact:
        context.push(AppRoutes.contact(item.id));
        break;
      case ItemType.journal:
        context.push(AppRoutes.journal_(item.id));
        break;
      case ItemType.habit:
        context.push(AppRoutes.habit(item.id));
        break;
      case ItemType.event:
        context.push(AppRoutes.note(item.id));
        break;
      case ItemType.project:
        context.push('/collections/${item.id}');
        break;
      case ItemType.appointment:
        context.push('/appointments/${item.id}');
        break;
      default:
        context.push(AppRoutes.note(item.id));
    }
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ToggleButton(
            icon: Icons.push_pin_rounded,
            tooltip: 'Καρφιτσωμένα',
            isSelected: current == FolderViewMode.pinned,
            activeColor: Colors.red,
            onTap: () => onChanged(FolderViewMode.pinned),
          ),
          const SizedBox(width: Spacing.md),
          _ToggleButton(
            icon: Icons.star_rounded,
            tooltip: 'Αγαπημένα',
            isSelected: current == FolderViewMode.favorites,
            activeColor: Colors.amber,
            onTap: () => onChanged(FolderViewMode.favorites),
          ),
          const SizedBox(width: Spacing.md),
          _ToggleButton(
            icon: Icons.history_rounded,
            tooltip: 'Πρόσφατα',
            isSelected: current == FolderViewMode.recent,
            activeColor: Colors.blue,
            onTap: () => onChanged(FolderViewMode.recent),
          ),
          const SizedBox(width: Spacing.md),
          _ToggleButton(
            icon: Icons.list_rounded,
            tooltip: 'Όλα',
            isSelected: current == FolderViewMode.all,
            activeColor: Colors.green,
            onTap: () => onChanged(FolderViewMode.all),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? activeColor : context.cText2;
    final bgColor = isSelected
        ? activeColor.withValues(alpha: 0.12)
        : ColorsUI.getSurface(context.brightness);
    final borderColor = isSelected ? activeColor : ColorsUI.getBorder(context.brightness);

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FOLDER STATS ROW (unchanged)
// ════════════════════════════════════════════════════════════════

class _FolderStatsRow extends StatelessWidget {
  final Map<ItemType, int> stats;
  const _FolderStatsRow({required this.stats});

  static const _shown = [ItemType.note, ItemType.task, ItemType.event, ItemType.habit, ItemType.contact];

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
// FOLDER ITEM CARD (με badges)
// ════════════════════════════════════════════════════════════════

class _FolderItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;
  const _FolderItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemColor = ColorsUI.itemTypeColor(item.type, context.brightness);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: ColorsUI.getCard(context.brightness),
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
                Text(ItemTypeIcon.labelFor(item.type), style: context.labelSm.withColor(itemColor)),
                const Spacer(),
                if (item.pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin_rounded, size: 12, color: context.cPrimary),
                  ),
                if (item.favorite)
                  Icon(Icons.star_rounded, size: 12, color: ColorsUI.getWarning(context.brightness)),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(item.title ?? 'Χωρίς τίτλο', style: context.bodyMd, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}