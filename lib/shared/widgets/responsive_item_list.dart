// lib/shared/widgets/responsive_item_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'draggable_item_wrapper.dart';
import 'item_card.dart';

class ResponsiveItemList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double gridItemExtent;

  const ResponsiveItemList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.gridItemExtent = 100,
  });

  @override
  Widget build(BuildContext context) {
    final cols = context.gridColumns;

    return CustomScrollView(
      slivers: [
        cols == 1
            ? _buildList(context)
            : _buildGrid(context, cols),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.xs,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: itemBuilder(ctx, items[i]),
          ),
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, int cols) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.xs,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: Spacing.sm,
          crossAxisSpacing: Spacing.sm,
          mainAxisExtent: gridItemExtent,
        ),
        delegate: SliverChildBuilderDelegate(
              (ctx, i) => itemBuilder(ctx, items[i]),
          childCount: items.length,
        ),
      ),
    );
  }
}

// ── Έτοιμο ItemCard builder για notes/tasks/appointments ──────
class ItemCardBuilder extends ConsumerWidget {
  final Item item;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onLongPress;
  final VoidCallback? onShare;

  const ItemCardBuilder({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
    this.onShare,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagNames = ref
        .watch(itemTagsProvider(item.id))
        .valueOrNull
        ?.map((t) => t.name)
        .toList() ??
        [];

    return DraggableItemWrapper(
      itemId: item.id,
      child: ItemCard(
        item: item,
        tagNames: tagNames,
        compact: context.isMobile,
        onTap: () => onTap(item),
        onLongPress: () => onLongPress(item),
        onShare: onShare,
      ),
    );
  }
}