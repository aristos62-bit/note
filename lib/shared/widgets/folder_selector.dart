// lib/shared/widgets/folder_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class FolderChipSelector extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<FolderChipSelector> createState() => _FolderChipSelectorState();
}

class _FolderChipSelectorState extends ConsumerState<FolderChipSelector> {
  int? _dragOverIndex;

  @override
  Widget build(BuildContext context) {
    final folders = widget.folders;
    if (folders.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Το "Όλοι" δεν είναι draggable
          _FolderChip(
            label: 'Όλοι',
            icon: Icons.folder_open_rounded,
            isSelected: widget.selectedFolderId == null,
            color: context.cPrimary,
            onTap: () => widget.onSelect(null),
          ),
          const SizedBox(width: Spacing.xs),
          ...folders.asMap().entries.map((entry) {
            final idx = entry.key;
            final folder = entry.value;
            final folderColor = _colorFromHex(folder.color, context.cPrimary);
            final isDragOver = _dragOverIndex == idx;
            // System folders δεν είναι draggable
            final isSystem = folder.isSystem == true;

            return Padding(
              padding: const EdgeInsets.only(right: Spacing.xs),
              child: DragTarget<int>(
                onWillAcceptWithDetails: (details) {
                  setState(() => _dragOverIndex = idx);
                  return true;
                },
                onAcceptWithDetails: (details) async {
                  final draggedIndex = details.data;
                  if (draggedIndex == idx) {
                    setState(() => _dragOverIndex = null);
                    return;
                  }

                  // Δημιουργία νέας σειράς
                  final newOrder = List<Folder>.from(folders);
                  final draggedFolder = newOrder.removeAt(draggedIndex);
                  newOrder.insert(idx, draggedFolder);

                  // Ενημέρωση DB μέσω notifier
                  await ref.read(folderNotifierProvider.notifier).reorderFolders(newOrder);
                  setState(() => _dragOverIndex = null);
                },
                onLeave: (_) => setState(() => _dragOverIndex = null),
                builder: (context, candidateData, rejectedData) {
                  // Αν είναι system folder, δεν είναι draggable
                  if (isSystem) {
                    return _FolderChip(
                      label: folder.name,
                      icon: Icons.folder_rounded,
                      isSelected: widget.selectedFolderId == folder.id,
                      color: folderColor,
                      onTap: () => widget.onSelect(folder.id),
                      onLongPress: widget.onFolderLongPress != null
                          ? () => widget.onFolderLongPress!(folder)
                          : null,
                    );
                  }

                  return Draggable<int>(
                    data: idx,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _FolderChip(
                        label: folder.name,
                        icon: Icons.folder_rounded,
                        isSelected: false,
                        color: folderColor,
                        onTap: () {},
                        isDragging: true,
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _FolderChip(
                        label: folder.name,
                        icon: Icons.folder_rounded,
                        isSelected: widget.selectedFolderId == folder.id,
                        color: folderColor,
                        onTap: () => widget.onSelect(folder.id),
                        onLongPress: widget.onFolderLongPress != null
                            ? () => widget.onFolderLongPress!(folder)
                            : null,
                      ),
                    ),
                    child: _FolderChip(
                      label: folder.name,
                      icon: Icons.folder_rounded,
                      isSelected: widget.selectedFolderId == folder.id,
                      color: folderColor,
                      onTap: () => widget.onSelect(folder.id),
                      onLongPress: widget.onFolderLongPress != null
                          ? () => widget.onFolderLongPress!(folder)
                          : null,
                      isDragOver: isDragOver,
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}

class _FolderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isDragOver;
  final bool isDragging;

  const _FolderChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.isDragOver = false,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        width: 80,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : (isDragOver
              ? color.withValues(alpha: 0.3)
              : ColorsUI.getSurface(context.brightness)),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected
                ? color
                : (isDragOver
                ? color
                : ColorsUI.getBorder(context.brightness)),
            width: isDragOver ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : color),
            const SizedBox(height: Spacing.sm),
            Flexible(
              child: Text(
                label,
                style: context.labelMd.copyWith(
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
    );
  }
}