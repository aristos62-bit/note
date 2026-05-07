import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';

/// Reusable widget που εμφανίζει φακέλους και δέχεται drag & drop.
///
/// Είναι πλήρως αυτόνομο: διαβάζει τα folders και το selectedFolderId
/// από Riverpod providers. Δεν δέχεται πλέον εξωτερικές παραμέτρους.
class DraggableFolderSelector extends ConsumerStatefulWidget {
  const DraggableFolderSelector({super.key});

  @override
  ConsumerState<DraggableFolderSelector> createState() =>
      _DraggableFolderSelectorState();
}

class _DraggableFolderSelectorState
    extends ConsumerState<DraggableFolderSelector> {
  int? _dragOverFolderId;

  @override
  Widget build(BuildContext context) {
    // Διαβάζουμε τα folders από τον αντίστοιχο provider
    final foldersAsync = ref.watch(foldersStreamProvider);
    final folders = foldersAsync.valueOrNull ?? [];

    // Διαβάζουμε το επιλεγμένο folder από τον κεντρικό provider
    final selectedFolderId = ref.watch(selectedFolderIdProvider);

    // Μέθοδος αλλαγής φακέλου (ενημέρωση του κεντρικού provider)
    void selectFolder(int? id) {
      ref.read(selectedFolderIdProvider.notifier).state = id;
      DebugConfig.nav('DraggableFolderSelector: select folder id=$id');
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.xs,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip(
              folderId: null,
              label: 'Όλοι',
              icon: Icons.folder_open_rounded,
              color: context.cPrimary,
              isSelected: selectedFolderId == null,
              selectFolder: selectFolder,
            ),
            const SizedBox(width: Spacing.xs),
            ...folders.map((f) {
              final color = _colorFromHex(f.color, context.cPrimary);
              return _buildChip(
                folderId: f.id,
                label: f.name,
                icon: Icons.folder_rounded,
                color: color,
                isSelected: selectedFolderId == f.id,
                selectFolder: selectFolder,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required int? folderId,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required ValueChanged<int?> selectFolder,
  }) {
    final isDragOver = _dragOverFolderId == folderId;
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        DebugConfig.db(
            '📁 Drop target: folder $label, will accept item ${details.data}');
        setState(() => _dragOverFolderId = folderId);
        return true;
      },
      onAcceptWithDetails: (details) async {
        DebugConfig.db(
            '✅ DROP ACCEPTED: item ${details.data} → folder $label');
        final itemId = details.data;
        final notifier = ref.read(itemNotifierProvider.notifier);
        await notifier.moveToFolder(itemId, folderId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Μετακινήθηκε στον φάκελο "$label"'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
        setState(() => _dragOverFolderId = null);
      },
      onLeave: (_) {
        setState(() => _dragOverFolderId = null);
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTap: () => selectFolder(folderId),
          child: Container(
            width: 80,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color
                  : (isDragOver
                  ? color.withValues(alpha: 0.3)
                  : ColorsUI.getSurface(context.brightness)),
              borderRadius: BorderRadius.circular(12),
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
                Icon(icon,
                    size: 18, color: isSelected ? Colors.white : color),
                const SizedBox(height: Spacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: context.labelMd.copyWith(
                      color: isSelected ? Colors.white : color,
                      fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
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
      },
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