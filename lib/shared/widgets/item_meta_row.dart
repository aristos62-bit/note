// lib/shared/widgets/item_meta_row.dart
//
// ItemMetaRow — η γραμμή μεταδεδομένων (chips) του ItemCard, με δύο mode:
//
// ✅ full     — χωρίς [ItemCardMetaScope] (λίστες / responsive grid):
//               ΑΚΡΙΒΩΣ η σημερινή συμπεριφορά (`Wrap`, πολλαπλές γραμμές).
// ✅ compact  — με scope, meta πλάτος ≥ [kItemMetaCompactMinWidth]:
//               μία γραμμή: κουκκίδα προτεραιότητας + ημερομηνία + έως 2 tags
//               (3 αν ≥ [kItemMetaWideMinWidth]) + `+N`.
// ✅ minimal  — με scope, στενότερο: μία γραμμή με κουκκίδα + ημερομηνία.
//
// Γιατί: σε fixed-extent grid cells (~200 dp κελί → ~114 dp meta) το `Wrap`
// τύλιγε 2+ chips σε 2η γραμμή → RenderFlex overflow (S288e / E47).
// Σε dense mode ΔΕΝ τυλίγεται τίποτα: τα chips είναι `Flexible` + `maxLines: 1`
// και ό,τι κρύβεται (Αρχείο, ετικέτα προτεραιότητας, επιπλέον tags) μεταφέρεται
// στο semantics label (TalkBack), όχι μόνο οπτικά.
//
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import 'priority_badge.dart';

/// Ελάχιστο πλάτος περιεχομένου meta row ώστε να χωρούν και ετικέτες.
const double kItemMetaCompactMinWidth = 280;

/// Ελάχιστο πλάτος για 3 ετικέτες (αντί για 2).
const double kItemMetaWideMinWidth = 400;

/// Ελάχιστο ύψος της meta row σε dense mode.
///
/// Ίσο με το ύψος ενός chip στο text scale 1.0 (22 dp), ώστε το ύψος της
/// κάρτας μέσα στο fixed-extent κελί να μένει σταθερό (92 dp) ανεξάρτητα από
/// το αν η κάρτα έχει ημερομηνία/tags ή μόνο κουκκίδα προτεραιότητας.
const double kItemMetaDenseMinHeight = 22;

/// Κάτω από αυτό το πλάτος δεν χωράει ούτε κουκκίδα + ημερομηνία χωρίς
/// εσωτερικό overflow των chips (padding/icon είναι μη ελαστικά) → μόνο
/// κουκκίδα, με το υπόλοιπο info στο semantics.
const double kItemMetaNarrowMinWidth = 72;

/// Πόσο πλάτος έχει διαθέσιμο η meta row της κάρτας.
enum ItemMetaDensity {
  /// Χωρίς γνωστό πλάτος → σημερινή συμπεριφορά (`Wrap`).
  full,

  /// Γνωστό, άνετο πλάτος → μία γραμμή με ετικέτες.
  compact,

  /// Γνωστό, στενό πλάτος → μία γραμμή, μόνο κουκκίδα + ημερομηνία.
  minimal,
}

/// Καθαρή συνάρτηση (testable): `null` → [ItemMetaDensity.full].
ItemMetaDensity itemMetaDensityFor(double? maxWidth) {
  if (maxWidth == null) return ItemMetaDensity.full;
  if (maxWidth >= kItemMetaCompactMinWidth) return ItemMetaDensity.compact;
  return ItemMetaDensity.minimal;
}

/// Πόσες ετικέτες χωρούν στο δοσμένο πλάτος (2 ή 3).
int itemMetaMaxTagsFor(double maxWidth) =>
    maxWidth >= kItemMetaWideMinWidth ? 3 : 2;

/// Παρέχει το πλάτος του κελιού του grid στην [ItemMetaRow] που βρίσκεται
/// μέσα στο `itemBuilder`. Χωρίς scope → [ItemMetaDensity.full].
class ItemCardMetaScope extends InheritedWidget {
  /// Πλάτος του κελιού (πριν αφαιρεθούν border/accent/padding της κάρτας).
  final double maxWidth;

  const ItemCardMetaScope({
    super.key,
    required this.maxWidth,
    required super.child,
  });

  static double? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ItemCardMetaScope>()?.maxWidth;

  @override
  bool updateShouldNotify(ItemCardMetaScope oldWidget) =>
      maxWidth != oldWidget.maxWidth;
}

// ════════════════════════════════════════════════════════════════
// ITEM META ROW
// ════════════════════════════════════════════════════════════════

class ItemMetaRow extends StatelessWidget {
  final Item item;
  final DateTime? dueDate;
  final List<String> tagNames;
  final bool isArchived;
  final bool compact;
  final Color secondaryColor;

  /// Πλάτος περιεχομένου που έχει διαθέσιμο η γραμμή.
  /// `null` → full mode. Αν δεν δοθεί, διαβάζεται από [ItemCardMetaScope].
  final double? maxWidth;

  const ItemMetaRow({
    super.key,
    required this.item,
    required this.dueDate,
    required this.tagNames,
    this.isArchived = false,
    required this.compact,
    required this.secondaryColor,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = this.maxWidth ?? ItemCardMetaScope.maybeOf(context);
    final density = itemMetaDensityFor(maxWidth);

    if (density == ItemMetaDensity.full) return _buildFull(context);
    return _buildDense(context, maxWidth!, density);
  }

  // ── FULL: σημερινή συμπεριφορά, χωρίς καμία αλλαγή ──────────────

  Widget _buildFull(BuildContext context) {
    final maxTags = context.responsive(mobile: 1, tablet: 2, desktop: 3);
    final chips = <Widget>[];

    if (isArchived) {
      chips.add(_ArchivedChip(textColor: secondaryColor));
    }

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

  // ── DENSE: μία γραμμή, ποτέ wrap/overflow ──────────────────────

  Widget _buildDense(
    BuildContext context,
    double maxWidth,
    ItemMetaDensity density,
  ) {
    final hasPriority = item.priority != ItemPriority.none;
    final maxTags =
        density == ItemMetaDensity.compact ? itemMetaMaxTagsFor(maxWidth) : 0;
    final visibleTags = tagNames.take(maxTags).toList(growable: false);
    final hiddenTagCount = tagNames.length - visibleTags.length;

    final children = <Widget>[];

    if (hasPriority) {
      children.add(PriorityBadge.dot(priority: item.priority));
    }

    if (dueDate != null) {
      children.add(Flexible(
        child: _DueDateChip(date: dueDate!, dense: true),
      ));
    }

    for (final name in visibleTags) {
      children.add(Flexible(
        child: _TagChipSmall(
          name: name,
          textColor: secondaryColor,
          dense: true,
        ),
      ));
    }

    if (hiddenTagCount > 0) {
      // Το `+N` δεν είναι Flexible: μένει πάντα αναγνώσιμο.
      children.add(_TagChipSmall(
        name: '+$hiddenTagCount',
        textColor: secondaryColor,
        dense: true,
      ));
    }

    // Ό,τι δεν φαίνεται, μεταφέρεται στο semantics label (TalkBack).
    final hidden = <String>[
      if (isArchived) 'Αρχείο',
      if (hasPriority)
        'Προτεραιότητα: ${AppStringUtils.priorityLabel(item.priority.name)}',
      if (hiddenTagCount > 0)
        'Ετικέτες: ${tagNames.skip(visibleTags.length).join(', ')}',
    ];

    if (children.isEmpty && hidden.isEmpty) return const SizedBox.shrink();

    // Παθολογικά στενό πλάτος (< κουκκίδα + ημερομηνία): μόνο κουκκίδα.
    if (maxWidth < kItemMetaNarrowMinWidth) {
      children
        ..clear()
        ..addAll([
          if (hasPriority)
            Flexible(
              fit: FlexFit.loose,
              child: PriorityBadge.dot(priority: item.priority),
            ),
        ]);
    }

    final Widget row = children.isEmpty
        ? const SizedBox.shrink()
        : ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: kItemMetaDenseMinHeight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: Spacing.xs,
              children: children,
            ),
          );

    if (hidden.isEmpty) return row;
    return Semantics(
      container: false,
      label: hidden.join(' · '),
      child: row,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CHIPS
// ════════════════════════════════════════════════════════════════

class _ArchivedChip extends StatelessWidget {
  final Color textColor;
  const _ArchivedChip({required this.textColor});

  @override
  Widget build(BuildContext context) {
    final bgColor = textColor.withValues(alpha: 0.12);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Spacing.xs + 2, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.archive_rounded, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text('Αρχείο', style: context.labelSm.copyWith(color: textColor)),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final ItemPriority priority;
  const _PriorityChip({required this.priority});

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
          Icon(PriorityBadge.iconFor(priority), size: 10, color: color),
          const SizedBox(width: 3),
          Text(AppStringUtils.priorityLabel(priority.name),
              style: context.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _DueDateChip extends StatelessWidget {
  final DateTime date;

  /// true → επιτρέπεται shrink (Flexible + ellipsis) μέσα σε dense row.
  final bool dense;

  const _DueDateChip({required this.date, this.dense = false});

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

    final text = Text(
      date.due,
      style: context.labelSm.copyWith(color: color),
      maxLines: dense ? 1 : null,
      overflow: dense ? TextOverflow.ellipsis : null,
      softWrap: dense ? false : null,
    );

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
          if (dense) Flexible(child: text) else text,
        ],
      ),
    );
  }
}

class _TagChipSmall extends StatelessWidget {
  final String name;
  final Color textColor;

  /// true → επιτρέπεται shrink (Flexible + ellipsis) μέσα σε dense row.
  final bool dense;

  const _TagChipSmall({
    required this.name,
    required this.textColor,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      style: context.labelSm.copyWith(color: textColor),
      maxLines: dense ? 1 : null,
      overflow: dense ? TextOverflow.ellipsis : null,
      softWrap: dense ? false : null,
    );

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Spacing.xs + 2, vertical: 2),
      decoration: BoxDecoration(
        color:
            Colors.white.withValues(alpha: 0.15), // ελαφρύ overlay για αντίθεση
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: dense
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [Flexible(child: text)],
            )
          : text,
    );
  }
}
