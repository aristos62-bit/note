// lib/features/home/folder_browser_items.dart
//
// Items list (mobile) για browser/folder views (extract από folder_browser_screen).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';

class FolderItemsList extends StatelessWidget {
  final List<Item> items;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onDelete;
  final ValueChanged<Item>? onShare;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback? onReorderStart;
  final VoidCallback? onReorderEnd;

  const FolderItemsList({
    super.key,
    required this.items,
    required this.onTap,
    required this.onDelete,
    this.onShare,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
  });

  @override
  Widget build(BuildContext context) {
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
// ITEMS GRID — tablet (extract από folder_browser_screen)
// ════════════════════════════════════════════════════════════════

class FolderItemsGrid extends StatelessWidget {
  final List<Item> items;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onDelete;
  final ValueChanged<Item>? onShare;

  const FolderItemsGrid({
    super.key,
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
            compact: true,
            customBackgroundColor: overrideColor,
            onTap: () => onTap(items[i]),
            onShare: onShare != null ? () => onShare!(items[i]) : null,
          );
        },
      ),
    );
  }
}
