// lib/shared/widgets/priority_badge.dart
//
// PriorityBadge — εμφανίζει την προτεραιότητα ενός Item.
// ✅ Responsive: auto size από context.responsive() ή manual BadgeSize
// ✅ Dark mode: χρησιμοποιεί ColorsUI / context extensions
// ✅ DebugConfig: log στο build (debug only)
//
// ΧΡΗΣΗ:
//   PriorityBadge(priority: item.priority)               // auto responsive size
//   PriorityBadge(priority: item.priority, size: BadgeSize.large)  // manual
//   PriorityBadge.dot(priority: item.priority)           // μόνο dot
//
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/item.dart';

enum BadgeSize { small, medium, large }

class PriorityBadge extends StatelessWidget {
  final ItemPriority priority;

  /// Αν null, το size επιλέγεται αυτόματα από context.responsive()
  final BadgeSize? size;
  final bool showLabel;
  final bool showIcon;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.size,
    this.showLabel = true,
    this.showIcon  = true,
  });

  /// Μόνο έγχρωμη κουκκίδα — για compact lists / ItemCard
  const PriorityBadge.dot({
    super.key,
    required this.priority,
    this.size = BadgeSize.small,
  })  : showLabel = false,
        showIcon  = false;

  // ── Static helpers ────────────────────────────────────────────

  static IconData iconFor(ItemPriority p) {
    switch (p) {
      case ItemPriority.urgent: return Icons.priority_high_rounded;
      case ItemPriority.high:   return Icons.keyboard_arrow_up_rounded;
      case ItemPriority.medium: return Icons.remove_rounded;
      case ItemPriority.low:    return Icons.keyboard_arrow_down_rounded;
      case ItemPriority.none:   return Icons.remove_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (priority == ItemPriority.none) return const SizedBox.shrink();

    DebugConfig.print('PriorityBadge: ${priority.name}');

    final color     = context.priorityColor(priority);
    final softColor = context.priorityColorSoft(priority);
    final label     = AppStringUtils.priorityLabel(priority.name);

    // Responsive auto-size αν δεν έχει οριστεί manual
    final BadgeSize resolvedSize = size ?? context.responsive(
      mobile:  BadgeSize.small,
      tablet:  BadgeSize.medium,
      desktop: BadgeSize.medium,
    );

    final double iconSz;
    final double dotSz;
    final TextStyle textStyle;
    final EdgeInsets padding;

    switch (resolvedSize) {
      case BadgeSize.small:
        iconSz    = 10;
        dotSz     = 8;
        textStyle = context.labelSm;
        padding   = const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
      case BadgeSize.medium:
        iconSz    = 12;
        dotSz     = 10;
        textStyle = context.labelMd;
        padding   = const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
      case BadgeSize.large:
        iconSz    = 14;
        dotSz     = 12;
        textStyle = context.labelLg;
        padding   = const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    }

    // Dot only
    if (!showLabel && !showIcon) {
      return Container(
        width: dotSz, height: dotSz,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: color.withValues(alpha:0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(iconFor(priority), size: iconSz, color: color),
            const SizedBox(width: 3),
          ],
          if (showLabel)
            Text(label, style: textStyle.withColor(color)),
        ],
      ),
    );
  }
}