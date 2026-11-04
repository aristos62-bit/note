import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:reorderable_grid/reorderable_grid.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import 'item_meta_row.dart';
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

  /// N2: το drag handle δεν υπήρχε καθόλου στο semantics tree. Προσθέτουμε
  /// label + custom actions ώστε η αναδιάταξη να είναι εφικτή και με TalkBack
  /// (χωρίς σύρσιμο). Τα i±1 ταιριάζουν με τον adjusted `newIndex` του
  /// `onReorderItem`/`SliverReorderableGrid.onReorder`.
  Widget _dragHandle(int index) {
    final actions = <CustomSemanticsAction, VoidCallback>{};
    if (index > 0) {
      actions[const CustomSemanticsAction(label: 'Μετακίνηση πάνω')] =
          () => onReorder(index, index - 1);
    }
    if (index < items.length - 1) {
      actions[const CustomSemanticsAction(label: 'Μετακίνηση κάτω')] =
          () => onReorder(index, index + 1);
    }
    return Semantics(
      container: true,
      label: 'Αναδιάταξη',
      hint: 'Ενέργειες για μετακίνηση πάνω ή κάτω',
      customSemanticsActions: actions,
      child: const ReorderHandle(),
    );
  }

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
                  child: _dragHandle(i),
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
    final hPadding = context.responsiveHPadding;
    const spacing = Spacing.sm;

    // Το πλάτος του κελιού είναι γνωστό ΕΔΩ (πριν το CustomScrollView), ώστε
    // η meta row της κάρτας να μείνει σε μία γραμμή μέσα στο fixed extent
    // (S289/E47). Γιατί όχι `SliverLayoutBuilder`: το `SliverConstraints ==`
    // περιλαμβάνει το `scrollOffset` → rebuild σε κάθε scroll.
    return LayoutBuilder(
      builder: (layoutContext, constraints) {
        final double? cellWidth = constraints.hasBoundedWidth
            ? math.max(
                0.0,
                (constraints.maxWidth - hPadding * 2 - spacing * (cols - 1)) /
                    cols,
              )
            : null;

        return CustomScrollView(
          shrinkWrap: shrinkWrap,
          physics: physics,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: hPadding,
                vertical: Spacing.xs,
              ),
              sliver: SliverReorderableGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  mainAxisExtent: context.autoGridItemExtent(
                    base: gridItemExtent,
                    max: gridItemExtentMax ?? gridItemExtent,
                  ),
                ),
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  final draggable = _isDraggable(item);
                  final card = itemBuilder(ctx, item, i);
                  return Stack(
                    key: ValueKey(item.id),
                    clipBehavior: Clip.none,
                    children: [
                      // Το scope μπαίνει ΜΕΣΑ στο keyed Stack: το
                      // reorderable_grid απαιτεί key στο άμεσο παιδί του
                      // itemBuilder (reorderable_grid.dart:795).
                      if (cellWidth != null)
                        ItemCardMetaScope(maxWidth: cellWidth, child: card)
                      else
                        card,
                      if (draggable)
                        Positioned(
                          right: -4,
                          top: 0,
                          bottom: 0,
                          child: ReorderableGridDragStartListener(
                            index: i,
                            enabled: true,
                            child: _dragHandle(i),
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
      },
    );
  }
}