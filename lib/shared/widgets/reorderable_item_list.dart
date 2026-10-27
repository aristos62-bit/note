import 'package:flutter/material.dart';
import 'package:reorderable_grid/reorderable_grid.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import 'reorder_handle.dart';

class ReorderableItemList extends StatelessWidget {
  final List<Item> items;
  final Widget Function(BuildContext context, Item item, int index) itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;
  final double gridItemExtent;

  /// Ανώτατο extent στο text scale 1.4 (auto-height). null → ίσο με gridItemExtent.
  final double? gridItemExtentMax;

  final bool shrinkWrap;
  final ScrollPhysics? physics;

  // ── ΝΕΟ: callbacks για isDraggingProvider ──────────────────────
  final VoidCallback? onReorderStart;
  final VoidCallback? onReorderEnd;

  /// false → κανένα drag (π.χ. «Πρόσφατα», όπου η σειρά είναι χρονική).
  /// Συνδυάζεται (AND) με την policy pinned/favorites — δεν την παρακάμπτει.
  final bool dragEnabled;

  const ReorderableItemList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    this.gridItemExtent = 100,
    this.gridItemExtentMax,
    this.shrinkWrap = false,
    this.physics,
    this.onReorderStart,   // ← ΝΕΟ
    this.onReorderEnd,     // ← ΝΕΟ
    this.dragEnabled = true,
  });

  bool _isDraggable(Item item) =>
      dragEnabled && !item.pinned && !item.favorite;

  @override
  Widget build(BuildContext context) {
    final cols = context.gridColumns;

    if (cols == 1) {
      return _buildList(context);
    }
    return _buildGrid(context, cols);
  }

  Widget _buildList(BuildContext context) {
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.xs,
        context.responsiveHPadding, 80,
      ),
      shrinkWrap: shrinkWrap,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final draggable = _isDraggable(item);
        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          key: ValueKey(item.id),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // ← ΔΙΟΡΘΩΣΗ (ήταν start)
            children: [
              Expanded(child: itemBuilder(ctx, item, i)),
              if (draggable)
                ReorderableDragStartListener(
                  index: i,
                  child: const ReorderHandle(),
                )
              else
              // Placeholder ίδιου πλάτους για να μην αλλάζει το layout
                const SizedBox(width: 30),
            ],
          ),
        );
      },
      onReorderItem: onReorder,
      onReorderStart: (_) => onReorderStart?.call(),  // ← ΝΕΟ
      onReorderEnd: (_) => onReorderEnd?.call(),       // ← ΝΕΟ
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }

  Widget _buildGrid(BuildContext context, int cols) {
    return CustomScrollView(
      shrinkWrap: shrinkWrap,
      physics: physics,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsiveHPadding,
            vertical: Spacing.xs,
          ),
          sliver: SliverReorderableGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: Spacing.sm,
              crossAxisSpacing: Spacing.sm,
              mainAxisExtent: context.autoGridItemExtent(
                base: gridItemExtent,
                max: gridItemExtentMax ?? gridItemExtent,
              ),
            ),
            itemBuilder: (ctx, i) {
              final item = items[i];
              final draggable = _isDraggable(item);
              return Stack(
                key: ValueKey(item.id),
                clipBehavior: Clip.none,
                children: [
                  itemBuilder(ctx, item, i),
                  if (draggable)
                    Positioned(
                      right: -4,
                      top: 0,
                      bottom: 0,
                      child: ReorderableGridDragStartListener(
                        index: i,
                        enabled: true,
                        child: const ReorderHandle(),
                      ),
                    ),
                ],
              );
            },
            itemCount: items.length,
            onReorder: onReorder,
            itemDragEnable: (i) => _isDraggable(items[i]),
            // Auto-scroll μόνο όταν το scroll είναι ενεργό· το ίδιο το πακέτο
            // ορίζει: «Should be disabled if ... NeverScrollableScrollPhysics».
            autoScroll: physics is! NeverScrollableScrollPhysics,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}