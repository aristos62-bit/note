// lib/features/home/home_folder_view.dart
//
// Περιεχόμενο home όταν ο χρήστης επιλέξει συγκεκριμένο φάκελο.
// ✅ ViewMode: pinned | favorites | both
// ✅ Real-time (itemsByFolderStreamProvider)
// ✅ Responsive
// ✅ Dark mode + DebugConfig
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import '../../features/appointments/appointments.dart';
import '../notes/note_detail_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../habits/habit_detail_screen.dart';
import '../calendar/event_detail_screen.dart';
import '../contacts/contact_detail_screen.dart';
import '../journal/journal_detail_screen.dart';
import '../collections/collection_detail_screen.dart';

// ── View Mode για το φάκελο ───────────────────────────────────
enum FolderViewMode { pinned, favorites, both }

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
  FolderViewMode _viewMode = FolderViewMode.pinned;

  // ── FAB: Δημιουργία νέου στοιχείου ─────────────────────────

  void _showCreateMenu(BuildContext context) {
    const types = [
      (ItemType.note,    '📝', 'Σημείωση'),
      (ItemType.task,    '✅', 'Εργασία'),
      (ItemType.event,   '📅', 'Συμβάν'),
      (ItemType.habit,   '🔄', 'Συνήθεια'),
      (ItemType.journal, '📖', 'Ημερολόγιο'),
      (ItemType.contact, '👤', 'Επαφή'),
      (ItemType.project, '📦', 'Συλλογή'),
    ];

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
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.xs),
              child: Text('Νέο στοιχείο σε "${folder.name}"',
                  style: context.titleSm),
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...types.map((t) => ListTile(
                      leading: Text(t.$2,
                          style: const TextStyle(fontSize: 22)),
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
    DebugConfig.nav('HomeFolderView createItem type=${type.name}');
    final item = await ref.read(itemNotifierProvider.notifier).create(
      type:     type,
      folderId: folder.id,
    );
    if (item == null || !mounted) return;
    ref.invalidate(itemNotifierProvider);
    // ignore: use_build_context_synchronously
    _openItem(context, item, isNew: true);
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('HomeFolderView build folder=${folder.id}');

    final statsAsync  = ref.watch(folderStatsProvider(folder.id));
    final pinnedAsync = ref.watch(pinnedByFolderStreamProvider(folder.id));
    final favoritesAsync = ref.watch(favoritesByFolderStreamProvider(folder.id));

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
              // ── Stats ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: statsAsync.when(
                  loading: () => _StatsRowSkeleton(),
                  error:   (_, __) => const SizedBox.shrink(),
                  data:    (stats) => _FolderStatsRow(stats: stats),
                ),
              ),

              // ── View Mode Toggle ──────────────────────────────────
              SliverToBoxAdapter(
                child: _FolderViewModeToggle(
                  current: _viewMode,
                  onChanged: (mode) {
                    DebugConfig.nav('HomeFolderView: mode changed to $mode');
                    setState(() => _viewMode = mode);
                  },
                ),
              ),

              // ── Content based on view mode ────────────────────────
              _buildContent(context, pinnedAsync, favoritesAsync),
            ],
          ),
        ),
        // FAB
        Positioned(
          right:  Spacing.md,
          bottom: Spacing.lg,
          child: FloatingActionButton(
            onPressed:       () => _showCreateMenu(context),
            backgroundColor: folderColor,
            foregroundColor: Colors.white,
            tooltip: 'Νέο στοιχείο',
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }

  // ── Content based on view mode ───────────────────────────────

  Widget _buildContent(
      BuildContext context,
      AsyncValue<List<Item>> pinnedAsync,
      AsyncValue<List<Item>> favoritesAsync,
      ) {
    if (_viewMode == FolderViewMode.both) {
      return _buildCombinedContent(context, pinnedAsync, favoritesAsync);
    }

    if (_viewMode == FolderViewMode.pinned) {
      return pinnedAsync.when(
        loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) {
          DebugConfig.error('HomeFolderView pinned', e);
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        },
        data: (items) => _buildItemsList(context, items),
      );
    }

    // favorites mode
    return favoritesAsync.when(
      loading: () => const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) {
        DebugConfig.error('HomeFolderView favorites', e);
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
      data: (items) => _buildItemsList(context, items),
    );
  }

  Widget _buildCombinedContent(
      BuildContext context,
      AsyncValue<List<Item>> pinnedAsync,
      AsyncValue<List<Item>> favoritesAsync,
      ) {
    final pinned = pinnedAsync.valueOrNull ?? [];
    final favorites = favoritesAsync.valueOrNull ?? [];

    final combined = <Item>[...pinned];
    for (final fav in favorites) {
      if (!combined.any((i) => i.id == fav.id)) {
        combined.add(fav);
      }
    }

    // Ταξινόμηση: pinned first, then favorites (by updatedAt)
    combined.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      final aDate = a.updatedAt ?? a.createdAt;
      final bDate = b.updatedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });

    final isLoading = pinnedAsync.isLoading && favoritesAsync.isLoading;
    final hasError = pinnedAsync.hasError || favoritesAsync.hasError;

    if (isLoading) {
      return const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator()));
    }

    if (hasError) {
      DebugConfig.error('HomeFolderView combined', pinnedAsync.error ?? favoritesAsync.error);
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (combined.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildItemsList(context, combined);
  }

  // ── Build items list (mobile list / tablet grid) ─────────────

  Widget _buildItemsList(BuildContext context, List<Item> items) {
    if (items.isEmpty) {
      return _buildEmptyState(context);
    }

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
    }

    // Tablet grid
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

  // ── Empty state ──────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    String message;
    IconData icon;

    switch (_viewMode) {
      case FolderViewMode.pinned:
        message = 'Δεν υπάρχουν καρφιτσωμένα στοιχεία';
        icon = Icons.push_pin_outlined;
        break;
      case FolderViewMode.favorites:
        message = 'Δεν υπάρχουν αγαπημένα στοιχεία';
        icon = Icons.star_outline_rounded;
        break;
      case FolderViewMode.both:
        message = 'Δεν υπάρχουν στοιχεία';
        icon = Icons.inbox_rounded;
        break;
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.responsiveHPadding, Spacing.xl,
          context.responsiveHPadding, 0,
        ),
        child: Column(children: [
          Icon(icon, size: 56, color: context.cDisabled),
          const SizedBox(height: Spacing.md),
          Text(message, style: context.titleMd),
          const SizedBox(height: Spacing.sm),
          Text(
            _viewMode == FolderViewMode.pinned
                ? 'Καρφίτσωσε στοιχεία για να τα βλέπεις εδώ.'
                : 'Πρόσθεσε αγαπημένα για να τα βλέπεις εδώ.',
            style: context.bodyMd.withColor(context.cText2),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  static Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) { return fallback; }
  }

  void _openItem(BuildContext context, Item item, {bool isNew = false}) {
    DebugConfig.nav('HomeFolderView → ${item.type.name} id=${item.id}');
    switch (item.type) {
      case ItemType.task:
        Navigator.of(context).push(AppTransitions.slideRoute(
            TaskDetailScreen(itemId: item.id)));
      case ItemType.contact:
        Navigator.of(context).push(AppTransitions.slideRoute(
            ContactDetailScreen(itemId: item.id, isNew: isNew)));
      case ItemType.journal:
        Navigator.of(context).push(AppTransitions.slideRoute(
            JournalDetailScreen(itemId: item.id, isNew: isNew)));
      case ItemType.habit:
        Navigator.of(context).push(AppTransitions.slideRoute(
            HabitDetailScreen(itemId: item.id)));
      case ItemType.event:
        Navigator.of(context).push(AppTransitions.slideRoute(
            EventDetailScreen(itemId: item.id, isNew: isNew)));
      case ItemType.project:
        Navigator.of(context).push(AppTransitions.slideRoute(
            CollectionDetailScreen(collectionId: item.id, isNew: isNew)));
      case ItemType.appointment:
        Navigator.of(context).push(AppTransitions.slideRoute(
            AppointmentDetailScreen(itemId: item.id, isNew: isNew)));
      default:
        Navigator.of(context).push(AppTransitions.slideRoute(
            NoteDetailScreen(itemId: item.id, isNew: isNew)));
    }
  }
}

// ════════════════════════════════════════════════════════════════
// FOLDER VIEW MODE TOGGLE
// ════════════════════════════════════════════════════════════════

class _FolderViewModeToggle extends StatelessWidget {
  final FolderViewMode current;
  final ValueChanged<FolderViewMode> onChanged;

  const _FolderViewModeToggle({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Spacing.sm),
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          _ToggleButton(
            icon: Icons.push_pin_rounded,
            label: 'Καρφιτσωμένα',
            isSelected: current == FolderViewMode.pinned,
            onTap: () => onChanged(FolderViewMode.pinned),
          ),
          const SizedBox(width: Spacing.xs),
          _ToggleButton(
            icon: Icons.star_rounded,
            label: 'Αγαπημένα',
            isSelected: current == FolderViewMode.favorites,
            onTap: () => onChanged(FolderViewMode.favorites),
          ),
          const SizedBox(width: Spacing.xs),
          _ToggleButton(
            icon: Icons.merge_type_rounded,
            label: 'Όλα',
            isSelected: current == FolderViewMode.both,
            onTap: () => onChanged(FolderViewMode.both),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? context.cPrimary : context.cText2;
    final bgColor = isSelected
        ? context.cPrimary.withValues(alpha: 0.12)
        : ColorsUI.getSurface(context.brightness);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm + 2,
          vertical: Spacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.badge),
          border: Border.all(
            color: isSelected ? color : ColorsUI.getBorder(context.brightness),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.labelSm.withColor(color),
            ),
          ],
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

  static const _shown = [
    ItemType.note, ItemType.task, ItemType.event,
    ItemType.habit, ItemType.contact,
  ];

  @override
  Widget build(BuildContext context) {
    final activeTypes = _shown.where((t) => (stats[t] ?? 0) > 0).toList();
    if (activeTypes.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical:   Spacing.xs,
        ),
        itemCount:        activeTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (_, i) {
          final type  = activeTypes[i];
          final count = stats[type] ?? 0;
          final color = ColorsUI.itemTypeColor(type, context.brightness);
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.08),
              borderRadius: AppRadius.cardBR,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ItemTypeIcon(type, size: 18, color: color),
                const SizedBox(width: Spacing.xs),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$count',
                        style: context.titleMd.withColor(color)),
                    Text(ItemTypeIcon.labelFor(type),
                        style: context.labelSm.withColor(context.cText2)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
            horizontal: context.responsiveHPadding,
            vertical:   Spacing.xs),
        itemCount:        3,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (_, __) => Container(
          width: 100,
          decoration: BoxDecoration(
            color: ColorsUI.getBorder(context.brightness)
                .withValues(alpha: 0.4),
            borderRadius: AppRadius.cardBR,
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

  const _FolderItemCard({
    required this.item,
    required this.onTap,
  });

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
          border: Border.all(
              color: itemColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type + Badges (pinned & favorite)
            Row(
              children: [
                ItemTypeIcon(item.type, size: 13, color: itemColor),
                const SizedBox(width: Spacing.xs),
                Text(ItemTypeIcon.labelFor(item.type),
                    style: context.labelSm.withColor(itemColor)),
                const Spacer(),
                if (item.pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin_rounded,
                        size: 12, color: context.cPrimary),
                  ),
                if (item.favorite)
                  Icon(Icons.star_rounded,
                      size: 12, color: ColorsUI.getWarning(context.brightness)),
              ],
            ),
            const SizedBox(height: Spacing.xs),

            // Τίτλος
            Text(
              item.title ?? 'Χωρίς τίτλο',
              style: context.bodyMd,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}