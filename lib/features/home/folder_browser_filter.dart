// lib/features/home/folder_browser_filter.dart
//
// Type filter bar για browser/folder views (extract από folder_browser_screen).
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/models.dart';

class FolderTypeFilter extends StatelessWidget {
  final ItemType? selected;
  final ValueChanged<ItemType?> onChanged;

  const FolderTypeFilter({super.key, required this.selected, required this.onChanged});

  static const _types = [
    (null, 'Όλα'),
    (ItemType.note, 'Σημειώσεις'),
    (ItemType.task, 'Εργασίες'),
    (ItemType.event, 'Συμβάντα'),
    (ItemType.habit, 'Συνήθειες'),
    (ItemType.journal, 'Ημερολόγιο'),
    (ItemType.contact, 'Επαφές'),
    (ItemType.project, 'Συλλογές'),
    (ItemType.appointment, 'Ραντεβού'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical: Spacing.xs,
        ),
        itemCount: _types.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
        itemBuilder: (_, i) {
          final type = _types[i].$1;
          final label = _types[i].$2;
          final isActive = selected == type;
          final color = type != null
              ? ColorsUI.itemTypeColor(type, context.brightness)
              : context.cPrimary;

          return GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: AppDuration.fast,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm + 2, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.12)
                    : ColorsUI.getSurface(context.brightness),
                borderRadius: BorderRadius.circular(AppRadius.badge),
                border: Border.all(
                  color:
                      isActive ? color : ColorsUI.getBorder(context.brightness),
                ),
              ),
              child: Text(label,
                  style: context.labelSm
                      .withColor(isActive ? color : context.cText2)),
            ),
          );
        },
      ),
    );
  }
}
