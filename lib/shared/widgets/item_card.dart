// lib/shared/widgets/item_card.dart
//
// Responsive card για εμφάνιση οποιουδήποτε Item σε λίστα.
// ✅ Responsive: compact σε mobile, πλατύτερο σε tablet/desktop
// ✅ Dark mode: χρησιμοποιεί ItemColorHelper για background & text contrast
// ✅ DebugConfig: logs σε onTap / checkbox
//
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../helpers/item_color_helper.dart';

// ════════════════════════════════════════════════════════════════
// ITEM CARD
// ════════════════════════════════════════════════════════════════

class ItemCard extends StatelessWidget {
  final Item item;
  final DateTime? dueDate;
  final List<String> tagNames;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onCheckboxChanged;

  const ItemCard({
    super.key,
    required this.item,
    this.dueDate,
    this.tagNames = const [],
    this.compact = false,
    this.onTap,
    this.onLongPress,
    this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;
    final typeColor = context.itemTypeColor(item.type);
    final accentColor = item.color != null
        ? (_parseColor(item.color!) ?? typeColor)
        : typeColor;

    final isCompact = compact ||
        (context.isMobile && item.title != null && item.title!.length < 30);

    // ⭐ Χρώμα φόντου: πάντα από τον τύπο (ItemColorHelper)
    final backgroundColor =
        ItemColorHelper.backgroundColorForType(item.type, context);

    // ⭐ Χρώμα κειμένου: βέλτιστη αντίθεση πάνω στο background
    final foregroundColor =
        ItemColorHelper.textColorForBackground(backgroundColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha: 0.7);

    return GestureDetector(
      onTap: () {
        DebugConfig.nav('ItemCard.onTap id=${item.id} type=${item.type.name}');
        onTap?.call();
      },
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.cardBR,
          border: Border.all(
            color: item.pinned
                ? accentColor.withValues(alpha: 0.4)
                : ColorsUI.getBorder(b),
            width: item.pinned ? 1.5 : 1.0,
          ),
          boxShadow: item.pinned ? AppShadows.card(b) : null,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AccentBar(color: accentColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: isCompact ? Spacing.sm : Spacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TitleRow(
                        item: item,
                        typeColor: accentColor,
                        compact: isCompact,
                        onCheckboxChanged: onCheckboxChanged,
                        foregroundColor: foregroundColor,
                      ),
                      const SizedBox(height: Spacing.xs),
                      _MetaRow(
                        item: item,
                        dueDate: dueDate,
                        tagNames: tagNames,
                        compact: isCompact,
                        foregroundColor: foregroundColor,
                        secondaryColor: secondaryForeground,
                      ),
                    ],
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final shouldShowTrailing = item.favorite || item.pinned;

                  DebugConfig.print(
                    'ItemCard TRAILING CHECK id=${item.id} '
                    'favorite=${item.favorite} pinned=${item.pinned} '
                    'show=$shouldShowTrailing isCompact=$isCompact',
                  );

                  if (!shouldShowTrailing) {
                    return const SizedBox.shrink();
                  }

                  return _TrailingSection(
                    item: item,
                    foregroundColor: foregroundColor,
                  );
                },
              ),
              Builder(
                builder: (context) {
                  DebugConfig.print(
                    'ItemCard HIDDEN TRAILING id=${item.id} isCompact=$isCompact',
                  );

                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _parseColor(String hex) {
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return null;
    }
  }
}

// ════════════════════════════════════════════════════════════════
// ACCENT BAR
// ════════════════════════════════════════════════════════════════

class _AccentBar extends StatelessWidget {
  final Color color;
  const _AccentBar({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: ui.Radius.circular(AppRadius.card),
          bottomLeft: ui.Radius.circular(AppRadius.card),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TITLE ROW
// ════════════════════════════════════════════════════════════════

class _TitleRow extends StatelessWidget {
  final Item item;
  final Color typeColor;
  final bool compact;
  final ValueChanged<bool>? onCheckboxChanged;
  final Color foregroundColor;

  const _TitleRow({
    required this.item,
    required this.typeColor,
    required this.compact,
    this.onCheckboxChanged,
    required this.foregroundColor,
  });

  bool get _showCheckbox =>
      (item.type == ItemType.task || item.type == ItemType.checklist) &&
          onCheckboxChanged != null;

  bool get _isDone => item.status == ItemStatus.done;

  String get _untitledLabel {
    switch (item.type) {
      case ItemType.note:
        return 'Χωρίς τίτλο';
      case ItemType.task:
        return 'Νέα εργασία';
      case ItemType.journal:
        return 'Νέα καταχώρηση';
      default:
        return 'Χωρίς τίτλο';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_showCheckbox) ...[
          GestureDetector(
            onTap: () {
              DebugConfig.print(
                  'ItemCard checkbox id=${item.id} done=${!_isDone}');
              onCheckboxChanged?.call(!_isDone);
            },
            child: AnimatedContainer(
              duration: AppDuration.fast,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _isDone ? typeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(
                  color: _isDone
                      ? typeColor
                      : ColorsUI.getBorder(context.brightness),
                  width: 2,
                ),
              ),
              child: _isDone
                  ? Icon(Icons.check,
                  size: 14,
                  color: ColorsUI.getAccessibleTextColor(typeColor))
                  : null,
            ),
          ),
          const SizedBox(width: Spacing.sm),
        ],
        if (!_showCheckbox) ...[
          _ItemTypeIcon(
              type: item.type, color: typeColor, size: compact ? 16 : 18),
          const SizedBox(width: Spacing.xs + 2),
        ],
        Expanded(
          child: Text(
            item.title?.isNotEmpty == true ? item.title! : _untitledLabel,
            style: (compact ? context.bodyMd : context.titleMd).copyWith(
              color: item.title?.isNotEmpty == true
                  ? foregroundColor
                  : foregroundColor.withValues(alpha: 0.5),
              decoration: _isDone ? TextDecoration.lineThrough : null,
              decorationColor: foregroundColor.withValues(alpha: 0.5),
            ),
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // ⭐ STAR (favorite) – αριστερά από το pin, ίδιο μέγεθος 14
        if (item.favorite) ...[
          const SizedBox(width: Spacing.xs),
          Icon(
            Icons.star_rounded,
            size: 14,
            color: foregroundColor,
          ),
        ],
        if (item.pinned) ...[
          const SizedBox(width: Spacing.xs),
          Icon(
            Icons.push_pin_rounded,
            size: 14,
            color: foregroundColor,
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// META ROW
// ════════════════════════════════════════════════════════════════

class _MetaRow extends StatelessWidget {
  final Item item;
  final DateTime? dueDate;
  final List<String> tagNames;
  final bool compact;
  final Color foregroundColor;
  final Color secondaryColor;

  const _MetaRow({
    required this.item,
    required this.dueDate,
    required this.tagNames,
    required this.compact,
    required this.foregroundColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxTags = context.responsive(mobile: 1, tablet: 2, desktop: 3);
    final chips = <Widget>[];

    if (item.priority != ItemPriority.none) {
      chips.add(_PriorityChip(priority: item.priority));
    }

    if (dueDate != null) {
      chips.add(_DueDateChip(date: dueDate!));
    }

    for (int i = 0; i < tagNames.length && i < maxTags; i++) {
      chips.add(_TagChipSmall(
        name: tagNames[i],
        textColor: secondaryColor,
      ));
    }
    if (tagNames.length > maxTags) {
      chips.add(_TagChipSmall(
        name: '+${tagNames.length - maxTags}',
        textColor: secondaryColor,
      ));
    }

    if (!compact && item.updatedAt != null) {
      chips.add(
        Text(
          item.updatedAt!.relative,
          style: context.bodySm.copyWith(color: secondaryColor),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TRAILING SECTION
// ════════════════════════════════════════════════════════════════

class _TrailingSection extends StatelessWidget {
  final Item item;
  final Color foregroundColor;

  const _TrailingSection({
    required this.item,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    DebugConfig.print(
      'ItemCard TrailingSection id=${item.id} favorite=${item.favorite}',
    );

    return SizedBox(
      width: 28,
      child: Center(
        child: Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: foregroundColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PRIORITY CHIP
// ════════════════════════════════════════════════════════════════

class _PriorityChip extends StatelessWidget {
  final ItemPriority priority;
  const _PriorityChip({required this.priority});

  IconData get _icon {
    switch (priority) {
      case ItemPriority.urgent:
        return Icons.priority_high_rounded;
      case ItemPriority.high:
        return Icons.keyboard_arrow_up_rounded;
      case ItemPriority.medium:
        return Icons.remove_rounded;
      case ItemPriority.low:
        return Icons.keyboard_arrow_down_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.priorityColor(priority);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Spacing.xs + 2, vertical: 2),
      decoration: BoxDecoration(
        color: context.priorityColorSoft(priority),
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(AppStringUtils.priorityLabel(priority.name),
              style: context.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// DUE DATE CHIP
// ════════════════════════════════════════════════════════════════

class _DueDateChip extends StatelessWidget {
  final DateTime date;
  const _DueDateChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final isOverdue = date.isOverdue && !date.isToday;
    final isToday = date.isToday;

    final Color color;
    if (isOverdue) {
      color = context.cError;
    } else if (isToday) {
      color = context.cWarning;
    } else {
      color = context.cText2;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Spacing.xs + 2, vertical: 2),
      decoration: BoxDecoration(
        color: (isOverdue || isToday)
            ? color.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: (isOverdue || isToday)
            ? Border.all(color: color.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue
                ? Icons.warning_amber_rounded
                : Icons.calendar_today_rounded,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(date.due, style: context.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAG CHIP SMALL
// ════════════════════════════════════════════════════════════════

class _TagChipSmall extends StatelessWidget {
  final String name;
  final Color textColor;

  const _TagChipSmall({
    required this.name,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Spacing.xs + 2, vertical: 2),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(alpha: 0.15), // ελαφρύ overlay για αντίθεση
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        name,
        style: context.labelSm.copyWith(color: textColor),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ITEM TYPE ICON
// ════════════════════════════════════════════════════════════════

class _ItemTypeIcon extends StatelessWidget {
  final ItemType type;
  final Color color;
  final double size;

  const _ItemTypeIcon({
    required this.type,
    required this.color,
    required this.size,
  });

  IconData get _icon {
    switch (type) {
      case ItemType.note:
        return Icons.note_rounded;
      case ItemType.task:
        return Icons.check_circle_outline_rounded;
      case ItemType.event:
        return Icons.event_rounded;
      case ItemType.contact:
        return Icons.person_rounded;
      case ItemType.habit:
        return Icons.loop_rounded;
      case ItemType.project:
        return Icons.folder_rounded;
      case ItemType.goal:
        return Icons.flag_rounded;
      case ItemType.finance:
        return Icons.account_balance_wallet_rounded;
      case ItemType.bookmark:
        return Icons.bookmark_rounded;
      case ItemType.journal:
        return Icons.auto_stories_rounded;
      case ItemType.appointment:
        return Icons.cases_rounded;
      case ItemType.checklist:
        return Icons.checklist_rounded;
      case ItemType.knowledge:
        return Icons.lightbulb_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Icon(_icon, size: size, color: color);
}

// ════════════════════════════════════════════════════════════════
// ITEM CARD SKELETON — loading placeholder
// ════════════════════════════════════════════════════════════════

class ItemCardSkeleton extends StatefulWidget {
  final bool compact;
  const ItemCardSkeleton({super.key, this.compact = false});

  @override
  State<ItemCardSkeleton> createState() => _ItemCardSkeletonState();
}

class _ItemCardSkeletonState extends State<ItemCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.compact ? 56 : 80,
        decoration: BoxDecoration(
          color: ColorsUI.getBorder(context.brightness)
              .withValues(alpha: _anim.value),
          borderRadius: AppRadius.cardBR,
        ),
      ),
    );
  }
}
