import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/models.dart';

class FolderChipSelector extends StatelessWidget {
  final List<Folder> folders;
  final int? selectedFolderId;
  final ValueChanged<int?> onSelect;
  final ValueChanged<Folder>? onFolderLongPress;

  const FolderChipSelector({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.onSelect,
    this.onFolderLongPress,
  });

  static Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FolderChip(
            label: 'Όλοι',
            icon: Icons.folder_open_rounded,
            isSelected: selectedFolderId == null,
            color: context.cPrimary,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: Spacing.xs),
          ...folders.map((f) {
            final folderColor = _colorFromHex(f.color, context.cPrimary);
            return Padding(
              padding: const EdgeInsets.only(right: Spacing.xs),
              child: FolderChip(
                label: f.name,
                icon: Icons.folder_rounded,
                isSelected: selectedFolderId == f.id,
                color: folderColor,
                onTap: () => onSelect(f.id),
                onLongPress: onFolderLongPress != null
                    ? () => onFolderLongPress!(f)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class FolderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FolderChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Container(
            width: 80,        // από 60 σε 80
            height: 56,       // από 40 σε 56
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color : ColorsUI.getSurface(context.brightness),
              borderRadius: BorderRadius.circular(12.0), // από 8 σε 12
              border: Border.all(
                color: isSelected ? color : ColorsUI.getBorder(context.brightness),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: isSelected ? Colors.white : color), // από 10 σε 18
                const SizedBox(height: Spacing.sm), // από xs σε sm
                Flexible(
                  child: Text(
                    label,
                    style: context.labelMd.copyWith(  // από labelSm σε labelMd
                      color: isSelected ? Colors.white : color,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (onLongPress != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onLongPress,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : ColorsUI.getSurface(context.brightness).withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 18, // από 16 σε 18
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}