// lib/shared/widgets/tag_chip.dart
//
// TagChip — εμφανίζει ένα tag ως chip.
// ✅ Responsive: wrap layout σε πολλά tags
// ✅ Dark mode: χρησιμοποιεί ColorsUI
// ✅ DebugConfig: log στο onTap / onDelete
//
// ΧΡΗΣΗ:
//   // Απλό chip (read-only)
//   TagChip(name: 'flutter')
//
//   // Με χρώμα (από tag.color)
//   TagChip(name: tag.name, color: tag.color)
//
//   // Με delete button
//   TagChip(name: 'flutter', onDelete: () => removeTag(tag))
//
//   // Κλικάρισμό (για φιλτράρισμα)
//   TagChip(name: 'flutter', onTap: () => filterByTag(tag))
//
//   // Επιλεγμένο (για multi-select)
//   TagChip(name: 'flutter', selected: true, onTap: () => toggleTag(tag))
//
//   // Λίστα tags με wrap
//   TagChipList(tagNames: ['flutter', 'dart', 'mobile'])
//
//   // Interactive tag list (για edit mode)
//   TagChipList.interactive(
//     tags: itemTags,
//     onRemove: (tag) => removeTag(tag),
//     onAdd: () => showTagPicker(),
//   )
//
import 'package:flutter/material.dart';
import '../../core/core.dart';

// ════════════════════════════════════════════════════════════════
// TAG CHIP
// ════════════════════════════════════════════════════════════════

class TagChip extends StatelessWidget {
  final String name;

  /// Hex color από tag.color (π.χ. '#6750A4')
  final String? color;

  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// Compact — μικρότερο padding, χρησιμοποιείται στο ItemCard
  final bool compact;

  const TagChip({
    super.key,
    required this.name,
    this.color,
    this.selected = false,
    this.onTap,
    this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final b           = context.brightness;
    final accentColor = _resolveColor(context);

    final bgColor = selected
        ? accentColor.withValues(alpha:0.15)
        : ColorsUI.getSurface(b);

    final borderColor = selected
        ? accentColor.withValues(alpha:0.5)
        : ColorsUI.getBorder(b);

    final textColor = selected
        ? accentColor
        : context.cText2;

    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    return GestureDetector(
      onTap: onTap == null ? null : () {
        DebugConfig.print('TagChip.onTap name="$name" selected=${!selected}');
        onTap!();
      },
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: onDelete != null
            ? padding.copyWith(right: 4)
            : padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot χρώματος (αν έχει custom color)
            if (color != null) ...[
              Container(
                width: compact ? 6 : 8,
                height: compact ? 6 : 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],

            // Label
            Text(
              name,
              style: (compact ? context.labelSm : context.labelMd)
                  .withColor(textColor),
            ),

            // Delete button
            if (onDelete != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: () {
                  DebugConfig.print('TagChip.onDelete name="$name"');
                  onDelete!();
                },
                child: Icon(
                  Icons.close_rounded,
                  size: compact ? 12 : 14,
                  color: textColor.withValues(alpha:0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _resolveColor(BuildContext context) {
    if (color == null) return context.cPrimary;
    try {
      final clean = color!.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return context.cPrimary;
    }
  }
}

// ════════════════════════════════════════════════════════════════
// TAG CHIP LIST — wrap layout για πολλά tags
// ════════════════════════════════════════════════════════════════

class TagChipList extends StatelessWidget {
  final List<String> tagNames;
  final List<String?> tagColors;

  /// Επιλεγμένα tags (για filter mode)
  final Set<String> selectedTags;

  final ValueChanged<String>? onTagTap;
  final ValueChanged<String>? onTagDelete;

  /// Αν true, εμφανίζει + button για προσθήκη tag
  final bool showAddButton;
  final VoidCallback? onAdd;

  /// Max tags να εμφανιστούν (0 = όλα)
  final int maxVisible;

  final bool compact;

  const TagChipList({
    super.key,
    required this.tagNames,
    this.tagColors = const [],
    this.selectedTags = const {},
    this.onTagTap,
    this.onTagDelete,
    this.showAddButton = false,
    this.onAdd,
    this.maxVisible = 0,
    this.compact = false,
  });

  /// Read-only list — απλή εμφάνιση
  const TagChipList.readOnly({
    super.key,
    required this.tagNames,
    this.tagColors = const [],
    this.compact = false,
    this.maxVisible = 0,
  })  : selectedTags   = const {},
        onTagTap       = null,
        onTagDelete    = null,
        showAddButton  = false,
        onAdd          = null;

  /// Interactive list — με delete + add button
  const TagChipList.interactive({
    super.key,
    required this.tagNames,
    this.tagColors = const [],
    this.onTagDelete,
    this.onAdd,
    this.compact = false,
  })  : selectedTags  = const {},
        onTagTap      = null,
        showAddButton = true,
        maxVisible    = 0;

  /// Filter list — για φιλτράρισμα με multi-select
  const TagChipList.filter({
    super.key,
    required this.tagNames,
    this.tagColors = const [],
    required this.selectedTags,
    required this.onTagTap,
    this.compact = false,
  })  : onTagDelete   = null,
        showAddButton = false,
        onAdd         = null,
        maxVisible    = 0;

  @override
  Widget build(BuildContext context) {
    final visible = maxVisible > 0 && tagNames.length > maxVisible
        ? tagNames.sublist(0, maxVisible)
        : tagNames;

    final overflow = maxVisible > 0 && tagNames.length > maxVisible
        ? tagNames.length - maxVisible
        : 0;

    return Wrap(
      spacing: Spacing.chipGap + 2,
      runSpacing: Spacing.chipGap + 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Tags
        for (int i = 0; i < visible.length; i++)
          TagChip(
            name:     visible[i],
            color:    i < tagColors.length ? tagColors[i] : null,
            selected: selectedTags.contains(visible[i]),
            compact:  compact,
            onTap:    onTagTap != null ? () => onTagTap!(visible[i]) : null,
            onDelete: onTagDelete != null ? () => onTagDelete!(visible[i]) : null,
          ),

        // Overflow badge — "+3 ακόμα"
        if (overflow > 0)
          _OverflowChip(count: overflow, compact: compact),

        // Add button
        if (showAddButton)
          _AddTagButton(onTap: onAdd, compact: compact),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// OVERFLOW CHIP — "+3"
// ════════════════════════════════════════════════════════════════

class _OverflowChip extends StatelessWidget {
  final int count;
  final bool compact;
  const _OverflowChip({required this.count, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: context.cBorder),
      ),
      child: Text(
        '+$count',
        style: (compact ? context.labelSm : context.labelMd)
            .withColor(context.cText2),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADD TAG BUTTON
// ════════════════════════════════════════════════════════════════

class _AddTagButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool compact;
  const _AddTagButton({this.onTap, required this.compact});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        DebugConfig.print('TagChipList: add tag tapped');
        onTap?.call();
      },
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: context.cBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded,
                size: compact ? 12 : 14, color: context.cText2),
            const SizedBox(width: 3),
            Text('Tag',
                style: (compact ? context.labelSm : context.labelMd)
                    .withColor(context.cText2)),
          ],
        ),
      ),
    );
  }
}