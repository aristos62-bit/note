// lib/shared/widgets/responsive_item_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'draggable_item_wrapper.dart';
import 'item_card.dart';

/// Auto-height λίστα/πλέγμα:
/// - Mobile (1 col): απλή λίστα.
/// - Tablet/Desktop (2-3 cols): lazy [SliverList] από *γραμμές*· κάθε γραμμή
///   έχει ίδιο ύψος μέσω `IntrinsicHeight` + `Row(stretch)`, ώστε τα κελιά
///   μιας γραμμής να παίρνουν το φυσικό (auto) ύψος του περιεχομένου τους.
///
/// Το `IntrinsicHeight` ΔΕΝ δουλεύει με `LayoutBuilder`/scrollables μέσα στα
/// cards — γι' αυτό το collections grid (LayoutBuilder) χρησιμοποιεί extent.
class ResponsiveItemList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Horizontal padding σελίδας (default: context.responsiveHPadding).
  final double? horizontalPadding;

  /// Κενό κάτω από τη λίστα (default 80).
  final double bottomInset;

  /// Ελάχιστο ύψος γραμμής/κελιού.
  final double minRowHeight;

  /// Key ανά item (για σωστό state reuse σε updates).
  final Key Function(T item, int index)? itemKey;

  const ResponsiveItemList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.horizontalPadding,
    this.bottomInset = 80,
    this.minRowHeight = 48,
    this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    final cols = context.gridColumns;
    final hPad = horizontalPadding ?? context.responsiveHPadding;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, Spacing.xs, hPad, 0),
          sliver: cols <= 1
              ? _buildList(context)
              : _buildGrid(context, cols),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (ctx, i) => Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: itemBuilder(ctx, items[i]),
        ),
        childCount: items.length,
      ),
    );
  }

  Widget _buildGrid(BuildContext context, int cols) {
    final rowCount = (items.length + cols - 1) ~/ cols;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (ctx, row) {
          final start = row * cols;
          final end = start + cols < items.length ? start + cols : items.length;
          final rowItems = items.sublist(start, end);
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: IntrinsicHeight(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minRowHeight),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < cols; c++) ...[
                      if (c > 0) const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: c < rowItems.length
                            ? KeyedSubtree(
                                key: itemKey?.call(rowItems[c], start + c) ??
                                    ValueKey<int>(start + c),
                                child: itemBuilder(ctx, rowItems[c]),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
        childCount: rowCount,
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
  // ✅ ΝΕΟ: tags περνάνε από τον parent — μηδέν ref.watch per-item
  final List<String> tagNames;

  const ItemCardBuilder({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
    this.onShare,
    this.tagNames = const [],   // ← default κενή λίστα για backwards compat
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Αφαιρέθηκε: ref.watch(itemTagsProvider(item.id)) — N+1 query
    final showArchived  = ref.watch(showArchivedProvider);
    final isArchived    = item.archived && showArchived;
    final overrideColor = ref.watch(itemTypeCardColorOverrideProvider(item.type));

    DebugConfig.db('ItemCardBuilder id=${item.id} archived=${item.archived} showArchived=$showArchived isArchived=$isArchived');

    return DraggableItemWrapper(
      itemId: item.id,
      child: isArchived
          ? Opacity(
        opacity: 0.5,
        child: ItemCard(
          item: item,
          tagNames: tagNames,
          compact: true,
          isArchived: true,
          customBackgroundColor: overrideColor,
          onTap: () => onTap(item),
          onLongPress: () => onLongPress(item),
          onShare: onShare,
        ),
      )
          : ItemCard(
        item: item,
        tagNames: tagNames,
        compact: true,
        customBackgroundColor: overrideColor,
        onTap: () => onTap(item),
        onLongPress: () => onLongPress(item),
        onShare: onShare,
      ),
    );
  }
}