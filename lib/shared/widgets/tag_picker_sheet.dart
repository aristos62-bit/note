// lib/shared/widgets/tag_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';
import 'tag_chip.dart';

class TagPickerSheet extends ConsumerStatefulWidget {
  final int itemId;

  const TagPickerSheet({super.key, required this.itemId});

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addTag(String name) async {
    if (name.trim().isEmpty) return;
    final tag = await ref
        .read(tagNotifierProvider.notifier)
        .createOrGet(name.trim());
    if (tag == null || !mounted) return;
    await ref
        .read(tagNotifierProvider.notifier)
        .addToItem(widget.itemId, tag.id);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final itemTagsAsync = ref.watch(itemTagsProvider(widget.itemId));
    final itemTagIds =
        itemTagsAsync.valueOrNull?.map((t) => t.id).toSet() ?? {};

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text('Προσθήκη Tag', style: context.titleMd),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onSubmitted: _addTag,
              decoration: InputDecoration(
                hintText: 'Νέο tag...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _addTag(_ctrl.text),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            tagsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (tags) {
                final available =
                tags.where((t) => !itemTagIds.contains(t.id)).toList();
                if (available.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: available
                      .map((t) => TagChip(
                    name: t.name,
                    color: t.color,
                    onTap: () async {
                      final nav = Navigator.of(context);
                      await ref
                          .read(tagNotifierProvider.notifier)
                          .addToItem(widget.itemId, t.id);
                      nav.pop();
                    },
                  ))
                      .toList(),
                );
              },
            ),
            SizedBox(
              height: MediaQuery.of(context).padding.bottom + Spacing.sm,
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function για εύκολη χρήση
void showTagPickerSheet(BuildContext context, int itemId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColorsUI.getSurface(context.brightness),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppRadius.bottomSheet),
        topRight: Radius.circular(AppRadius.bottomSheet),
      ),
    ),
    builder: (_) => TagPickerSheet(itemId: itemId),
  );
}