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
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  // ── ΝΕΟ: callbacks για isDraggingProvider ──────────────────────
  final VoidCallback? onReorderStart;
  final VoidCallback? onReorderEnd;

  const ReorderableItemList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    this.gridItemExtent = 100,
    this.shrinkWrap = false,
    this.physics,
    this.onReorderStart,   // ← ΝΕΟ
    this.onReorderEnd,     // ← ΝΕΟ
  });

  bool _canDrag(Item item) => !item.pinned && !item.favorite;

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
        final canDrag = _canDrag(item);
        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          key: ValueKey(item.id),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // ← ΔΙΟΡΘΩΣΗ (ήταν start)
            children: [
              Expanded(child: itemBuilder(ctx, item, i)),
              if (canDrag)
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
      onReorder: onReorder,
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
              mainAxisExtent: gridItemExtent,
            ),
            itemBuilder: (ctx, i) {
              final item = items[i];
              final canDrag = _canDrag(item);
              return Stack(
                key: ValueKey(item.id),
                clipBehavior: Clip.none,
                children: [
                  itemBuilder(ctx, item, i),
                  if (canDrag)
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
            itemDragEnable: (i) => _canDrag(items[i]),
            autoScroll: false,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}