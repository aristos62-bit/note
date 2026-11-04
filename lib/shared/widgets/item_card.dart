// lib/shared/widgets/item_card.dart
//
// Responsive card για εμφάνιση οποιουδήποτε Item σε λίστα.
// ✅ Responsive: compact σε mobile, πλατύτερο σε tablet/desktop
// ✅ Dark mode: χρησιμοποιεί ItemColorHelper για background & text contrast
// ✅ DebugConfig: logs σε onTap / checkbox
//
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../helpers/item_color_helper.dart';
import 'item_meta_row.dart';
import 'item_type_icon.dart';

// ════════════════════════════════════════════════════════════════
// ITEM CARD
// ════════════════════════════════════════════════════════════════

class ItemCard extends StatelessWidget {
  final Item item;
  final DateTime? dueDate;
  final List<String> tagNames;
  final bool compact;
  final bool isArchived;
  final Color? customBackgroundColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onCheckboxChanged;
  final VoidCallback? onShare;

  const ItemCard({
    super.key,
    required this.item,
    this.dueDate,
    this.tagNames = const [],
    this.compact = false,
    this.isArchived = false,
    this.customBackgroundColor,
    this.onTap,
    this.onLongPress,
    this.onCheckboxChanged,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final b = context.brightness;
    final typeColor = context.itemTypeColor(item.type);
    // Γενέθλια/ειδικές: accent φούξια/πορτοκαλί, αλλιώς χρώμα τύπου.
    final accentColor = ItemColorHelper.specialAccent(item) ??
        (item.color != null
            ? (_parseColor(item.color!) ?? typeColor)
            : typeColor);

    final isCompact = compact ||
        (context.isMobile && item.title != null && item.title!.length < 30);

    // ⭐ Χρώμα φόντου: override settings > γενέθλια/ειδική tint > default τύπου
    Color? specialBg;
    if (ItemColorHelper.isBirthdayEvent(item)) {
      specialBg = ItemColorHelper.birthdayBackground(context);
    } else if (ItemColorHelper.isSpecialDayEvent(item)) {
      specialBg = ItemColorHelper.specialDayBackground(context);
    }
    final backgroundColor = customBackgroundColor ??
        specialBg ??
        ItemColorHelper.backgroundColorForType(item.type, context);

    // ⭐ Χρώμα κειμένου: βέλτιστη αντίθεση πάνω στο background
    final foregroundColor =
        ItemColorHelper.textColorForBackground(backgroundColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha: 0.7);

    // Πλάτος κελιού (grid με ItemCardMetaScope) → πλάτος meta row.
    // Χωρίς scope (λίστες / responsive grid) → null → full mode (Wrap).
    final cellWidth = ItemCardMetaScope.maybeOf(context);
    final metaWidth = cellWidth == null ? null : _metaContentWidth(cellWidth);

    return GestureDetector(
      onTap: () {
        // DebugConfig.nav('ItemCard.onTap id=${item.id} type=${item.type.name}');
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
                        ItemMetaRow(
                          item: item,
                          dueDate: dueDate,
                          tagNames: tagNames,
                          isArchived: isArchived,
                          compact: isCompact,
                          secondaryColor: secondaryForeground,
                          maxWidth: metaWidth,
                        ),
                      ],
                    ),
                ),
              ),
              Builder(
                builder: (context) {
                  if (onShare == null) return const SizedBox.shrink();

                  return _TrailingSection(
                    foregroundColor: foregroundColor,
                    onShare: onShare,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Πλάτος που μένει για τη meta row: πλάτος κελιού μείον τα chrome της
  /// κάρτας (border 2×1 ή 2×1.5, accent bar 4, horizontal padding 2×16,
  /// + 48 για το share slot όταν υπάρχει) — ίδιο με το πραγματικό layout.
  double _metaContentWidth(double cellWidth) {
    final border = item.pinned ? 1.5 : 1.0;
    final chrome = 2 * border +
        4.0 + // _AccentBar
        2 * Spacing.md +
        (onShare != null ? 48.0 : 0.0); // _TrailingSection
    return math.max(0.0, cellWidth - chrome);
  }

  Color? _parseColor(String hex) {
    return ItemColorHelper.parseHex(hex);
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
          Semantics(
            checked: _isDone,
            label: 'Ολοκλήρωση εργασίας',
            excludeSemantics: true,
            onTap: () => onCheckboxChanged?.call(!_isDone),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // DebugConfig.print(
                //     'ItemCard checkbox id=${item.id} done=${!_isDone}');
                onCheckboxChanged?.call(!_isDone);
              },
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
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
              ),
            ),
          ),
          const SizedBox(width: Spacing.xs),
        ],
        if (!_showCheckbox) ...[
          // Γενέθλια/ειδικές: emoji αντί type-icon (pattern _FolderChip).
          if (ItemColorHelper.isBirthdayEvent(item) ||
              ItemColorHelper.isSpecialDayEvent(item))
            Text(
              item.icon!,
              style: TextStyle(fontSize: compact ? 16 : 18),
            )
          else
            ItemTypeIcon(
                item.type, color: typeColor, size: compact ? 16 : 18),
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
// TRAILING SECTION
// ════════════════════════════════════════════════════════════════

class _TrailingSection extends StatelessWidget {
  final Color foregroundColor;
  final VoidCallback? onShare;

  const _TrailingSection({
    required this.foregroundColor,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (onShare != null)
            Semantics(
              button: true,
              label: 'Κοινοποίηση',
              excludeSemantics: true,
              onTap: onShare,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onShare,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(
                      Icons.share_rounded,
                      size: 16,
                      color: foregroundColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── ITEM TYPE ICON: SPoT shared ItemTypeIcon (η private κλάση διαγράφηκε,
// Φ4a βήμα 8 — knowledge ενοποιήθηκε σε article_rounded) ─────────────

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
