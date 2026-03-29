// lib/shared/widgets/item_type_icon.dart
//
// ItemTypeIcon — icon για κάθε ItemType με χρώμα και background.
// ✅ Dark mode: χρησιμοποιεί ColorsUI.itemTypeColor
//
// ΧΡΗΣΗ:
//   ItemTypeIcon(type: ItemType.note)
//   ItemTypeIcon(type: ItemType.task, size: 32)
//   ItemTypeIcon.filled(type: ItemType.habit)   // με έγχρωμο background
//   ItemTypeIcon.outlined(type: ItemType.goal)  // με border
//
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/item.dart';

enum ItemTypeIconStyle { plain, filled, outlined }

class ItemTypeIcon extends StatelessWidget {
  final ItemType type;
  final double size;
  final ItemTypeIconStyle style;

  /// Custom χρώμα — αν null χρησιμοποιεί το ColorsUI.itemTypeColor
  final Color? color;

  const ItemTypeIcon(
      this.type, {
        super.key,
        this.size  = AppIconSize.md,
        this.style = ItemTypeIconStyle.plain,
        this.color,
      });

  /// Με έγχρωμο κυκλικό background
  const ItemTypeIcon.filled(
      this.type, {
        super.key,
        this.size  = AppIconSize.md,
        this.color,
      })  : style = ItemTypeIconStyle.filled;

  /// Με border
  const ItemTypeIcon.outlined(
      this.type, {
        super.key,
        this.size  = AppIconSize.md,
        this.color,
      })  : style = ItemTypeIconStyle.outlined;

  // ── Icon data per type ────────────────────────────────────────

  static IconData iconDataFor(ItemType type) {
    switch (type) {
      case ItemType.note:      return Icons.note_rounded;
      case ItemType.task:      return Icons.check_circle_outline_rounded;
      case ItemType.event:     return Icons.event_rounded;
      case ItemType.contact:   return Icons.person_rounded;
      case ItemType.habit:     return Icons.loop_rounded;
      case ItemType.project:   return Icons.folder_rounded;
      case ItemType.goal:      return Icons.flag_rounded;
      case ItemType.finance:   return Icons.account_balance_wallet_rounded;
      case ItemType.bookmark:  return Icons.bookmark_rounded;
      case ItemType.journal:   return Icons.auto_stories_rounded;
      case ItemType.appointment:  return Icons.cases_rounded;
      case ItemType.checklist: return Icons.checklist_rounded;
      case ItemType.knowledge: return Icons.article_rounded;
    }
  }

  // ── Label per type (Ελληνικά) ─────────────────────────────────

  static String labelFor(ItemType type) {
    switch (type) {
      case ItemType.note:      return 'Σημείωση';
      case ItemType.task:      return 'Εργασία';
      case ItemType.event:     return 'Συμβάν';
      case ItemType.contact:   return 'Επαφή';
      case ItemType.habit:     return 'Συνήθεια';
      case ItemType.project:   return 'Έργο';
      case ItemType.goal:      return 'Στόχος';
      case ItemType.finance:   return 'Οικονομικά';
      case ItemType.bookmark:  return 'Σελιδοδείκτης';
      case ItemType.journal:   return 'Ημερολόγιο';
      case ItemType.appointment:return 'Ραντεβου';
      case ItemType.checklist: return 'Λίστα';
      case ItemType.knowledge: return 'Συλλογή';
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? ColorsUI.itemTypeColor(type, context.brightness);
    final icon = iconDataFor(type);

    switch (style) {
      case ItemTypeIconStyle.plain:
        return Icon(icon, size: size, color: resolvedColor);

      case ItemTypeIconStyle.filled:
        final containerSize = size * 1.75;
        return Container(
          width:  containerSize,
          height: containerSize,
          decoration: BoxDecoration(
            color:  resolvedColor.withValues(alpha:0.12),
            shape:  BoxShape.circle,
          ),
          child: Icon(icon, size: size, color: resolvedColor),
        );

      case ItemTypeIconStyle.outlined:
        final containerSize = size * 1.75;
        return Container(
          width:  containerSize,
          height: containerSize,
          decoration: BoxDecoration(
            color:  Colors.transparent,
            shape:  BoxShape.circle,
            border: Border.all(color: resolvedColor.withValues(alpha:0.4), width: 1.5),
          ),
          child: Icon(icon, size: size, color: resolvedColor),
        );
    }
  }
}

// ════════════════════════════════════════════════════════════════
// ITEM TYPE PICKER — grid επιλογής τύπου (για create screen)
// ════════════════════════════════════════════════════════════════

class ItemTypePicker extends StatelessWidget {
  final ItemType? selected;
  final ValueChanged<ItemType> onSelected;

  /// Τύποι που εμφανίζονται — αν null εμφανίζονται όλοι
  final List<ItemType>? types;

  const ItemTypePicker({
    super.key,
    required this.onSelected,
    this.selected,
    this.types,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTypes = types ?? ItemType.values;

    // Responsive columns
    final cols = context.responsive(mobile: 3, tablet: 4, desktop: 6);

    return GridView.builder(
      shrinkWrap:  true,
      physics:     const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   cols,
        mainAxisSpacing:  Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        childAspectRatio: 0.85,
      ),
      itemCount: visibleTypes.length,
      itemBuilder: (context, index) {
        final type       = visibleTypes[index];
        final isSelected = type == selected;
        final typeColor  = ColorsUI.itemTypeColor(type, context.brightness);

        return GestureDetector(
          onTap: () {
            DebugConfig.print('ItemTypePicker selected: ${type.name}');
            onSelected(type);
          },
          child: AnimatedContainer(
            duration: AppDuration.fast,
            decoration: BoxDecoration(
              color: isSelected
                  ? typeColor.withValues(alpha:0.15)
                  : ColorsUI.getSurface(context.brightness),
              borderRadius: AppRadius.cardBR,
              border: Border.all(
                color: isSelected
                    ? typeColor.withValues(alpha:0.6)
                    : ColorsUI.getBorder(context.brightness),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ItemTypeIcon.filled(type, size: 24, color: typeColor),
                const SizedBox(height: Spacing.xs),
                Text(
                  ItemTypeIcon.labelFor(type),
                  style: context.labelSm.withColor(
                    isSelected ? typeColor : context.cText2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}