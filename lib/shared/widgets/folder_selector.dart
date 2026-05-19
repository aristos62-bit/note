// lib/shared/widgets/folder_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

// ── Type-safe wrapper για folder reorder drag ──────────────────
// Διαχωρίζει τα folder drag (index) από item drag (database ID)
class _FolderDragData {
  final int index;
  const _FolderDragData(this.index);
}

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
            icon: '📂',
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
            final isSystem = folder.isSystem == true;

            return Padding(
              padding: const EdgeInsets.only(right: Spacing.xs),
              child: DragTarget<Object>(               // ✅ Object: δέχεται int (item) ΚΑΙ _FolderDragData (folder)
                onWillAcceptWithDetails: (details) {
                  setState(() => _dragOverIndex = idx);
                  return true;
                },
                onAcceptWithDetails: (details) async {
                  final data = details.data;

                  if (data is _FolderDragData) {
                    // ── Folder reorder ──────────────────────────
                    final fromIdx = data.index;
                    if (fromIdx == idx) {
                      setState(() => _dragOverIndex = null);
                      return;
                    }
                    final newOrder = List<Folder>.from(folders);
                    final draggedFolder = newOrder.removeAt(fromIdx); // ✅ ασφαλές: είναι σίγουρα έγκυρο folder index
                    newOrder.insert(idx, draggedFolder);
                    await ref
                        .read(folderNotifierProvider.notifier)
                        .reorderFolders(newOrder);

                  } else if (data is int) {
                    // ── Item → Folder move ──────────────────────
                    final itemId = data;
                    await ref
                        .read(itemNotifierProvider.notifier)
                        .moveToFolder(itemId, folder.id);
                  }

                  setState(() => _dragOverIndex = null);
                },
                onLeave: (_) => setState(() => _dragOverIndex = null),
                builder: (context, candidateData, rejectedData) {
                  return LongPressDraggable<_FolderDragData>( // ✅ typed: περνά _FolderDragData, όχι int
                    data: _FolderDragData(idx),
                    delay: const Duration(milliseconds: 200),
                    feedback: Material(
                      color: Colors.transparent,
                      child: _FolderChip(
                        label: folder.name,
                        icon: folder.icon ?? '📁',
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
                        icon: folder.icon ?? '📁',
                        isSelected: widget.selectedFolderId == folder.id,
                        color: folderColor,
                        onTap: () => widget.onSelect(folder.id),
                      ),
                    ),
                    child: _FolderChip(
                      label: folder.name,
                      icon: folder.icon ?? '📁',
                      isSelected: widget.selectedFolderId == folder.id,
                      color: folderColor,
                      onTap: () => widget.onSelect(folder.id),
                      isDragOver: isDragOver,
                      onMoreTap: (!isSystem && widget.onFolderLongPress != null)
                          ? () => widget.onFolderLongPress!(folder)
                          : null,
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

// ════════════════════════════════════════════════════════════════
// FOLDER CHIP (αναλλοίωτο)
// ════════════════════════════════════════════════════════════════

class _FolderChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;
  final bool isDragOver;
  final bool isDragging;

  const _FolderChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.onMoreTap,
    this.isDragOver = false,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        width: 80,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    icon,
                    style: TextStyle(
                      fontSize: 18,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: context.labelSm.copyWith(
                        color: isSelected ? Colors.white : color,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (onMoreTap != null && !isDragging)
              Positioned(
                top: -2,
                right: -2,
                child: GestureDetector(
                  onTap: onMoreTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      size: 13,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}