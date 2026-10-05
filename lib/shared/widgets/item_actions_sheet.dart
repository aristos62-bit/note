// lib/shared/widgets/item_actions_sheet.dart
//
// SPoT για τα action sheets λιστών (long-press).
// Προαγωγή των `_ItemActionsSheet` (item_list/item_list_embedded, byte-identical)
// + 6 inline παραλλαγές (task/folder/habit/collections/journal/contact).
// Pixel-identical: ίδιο chrome, ίδια σειρά tiles, ίδια χρώματα/labels.
//
// ΧΡΗΣΗ:
//   ItemActionsSheet.show(context, item: item, onPin: () => ..., onDelete: () => ...);
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import 'priority_badge.dart';
import 'sheet_handle.dart';

class ItemActionsSheet extends StatelessWidget {
  final Item item;

  /// false → χωρίς τίτλο/Divider (habit, journal, contact)
  final bool showTitle;

  /// titleSm για folder_browser/collections — default titleMd
  final TextStyle? titleStyle;

  /// true μόνο task → PriorityBadge δίπλα στον τίτλο
  final bool showPriority;

  /// collections: tune_rounded + 'Επεξεργασία συλλογής'
  final IconData editIcon;
  final String editLabel;

  final VoidCallback? onEdit;
  final VoidCallback? onOpen;
  final VoidCallback? onPin;
  final VoidCallback? onFav;
  final VoidCallback? onShare;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const ItemActionsSheet({
    super.key,
    required this.item,
    this.showTitle = true,
    this.titleStyle,
    this.showPriority = false,
    this.editIcon = Icons.edit_rounded,
    this.editLabel = 'Επεξεργασία',
    this.onEdit,
    this.onOpen,
    this.onPin,
    this.onFav,
    this.onShare,
    this.onArchive,
    this.onDelete,
  });

  /// Ανοίγει το sheet. Το pop γίνεται με sheet-context (όχι blind pop caller).
  static Future<void> show(
    BuildContext context, {
    required Item item,
    bool showTitle = true,
    TextStyle? titleStyle,
    bool showPriority = false,
    IconData editIcon = Icons.edit_rounded,
    String editLabel = 'Επεξεργασία',
    VoidCallback? onEdit,
    VoidCallback? onOpen,
    VoidCallback? onPin,
    VoidCallback? onFav,
    VoidCallback? onShare,
    VoidCallback? onArchive,
    VoidCallback? onDelete,
  }) {
    DebugConfig.print('ItemActionsSheet.show id=${item.id}');
    return showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => ItemActionsSheet(
        item: item,
        showTitle: showTitle,
        titleStyle: titleStyle,
        showPriority: showPriority,
        editIcon: editIcon,
        editLabel: editLabel,
        onEdit: onEdit == null ? null : () => _popAnd(ctx, onEdit),
        onOpen: onOpen == null ? null : () => _popAnd(ctx, onOpen),
        onPin: onPin == null ? null : () => _popAnd(ctx, onPin),
        onFav: onFav == null ? null : () => _popAnd(ctx, onFav),
        onShare: onShare == null ? null : () => _popAnd(ctx, onShare),
        onArchive: onArchive == null ? null : () => _popAnd(ctx, onArchive),
        onDelete: onDelete == null ? null : () => _popAnd(ctx, onDelete),
      ),
    );
  }

  static void _popAnd(BuildContext ctx, VoidCallback fn) {
    Navigator.pop(ctx);
    fn();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(
            margin: EdgeInsets.symmetric(vertical: Spacing.sm),
          ),
          if (showTitle) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.xs),
              child: showPriority
                  ? Row(children: [
                      Expanded(
                        child: Text(item.title ?? 'Χωρίς τίτλο',
                            style: titleStyle ?? context.titleMd,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (item.priority != ItemPriority.none)
                        PriorityBadge(priority: item.priority),
                    ])
                  : Text(item.title ?? 'Χωρίς τίτλο',
                      style: titleStyle ?? context.titleMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
            ),
            const Divider(),
          ],
          if (onEdit != null)
            ListTile(
              leading: Icon(editIcon),
              title: Text(editLabel),
              onTap: onEdit,
            ),
          if (onOpen != null)
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Άνοιγμα'),
              onTap: onOpen,
            ),
          if (onPin != null)
            ListTile(
              leading: Icon(item.pinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
                  color: item.pinned ? context.cPrimary : context.cText2),
              title: Text(item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα'),
              onTap: onPin,
            ),
          if (onFav != null)
            ListTile(
              leading: Icon(
                  item.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: item.favorite
                      ? ColorsUI.getWarning(context.brightness)
                      : context.cText2),
              title: Text(
                  item.favorite ? 'Αφαίρεση από αγαπημένα' : 'Αγαπημένο'),
              onTap: onFav,
            ),
          if (onShare != null)
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Κοινοποίηση'),
              onTap: onShare,
            ),
          if (onArchive != null)
            ListTile(
              leading: Icon(Icons.archive_rounded, color: context.cText2),
              title: Text(item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση'),
              onTap: onArchive,
            ),
          if (onDelete != null)
            ListTile(
              leading:
                  Icon(Icons.delete_outline_rounded, color: context.cError),
              title: Text('Διαγραφή', style: TextStyle(color: context.cError)),
              onTap: onDelete,
            ),
          const SizedBox(height: Spacing.sm),
        ],
      ),
    );
  }
}
