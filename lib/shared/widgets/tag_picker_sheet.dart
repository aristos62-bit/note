// lib/shared/widgets/tag_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';
import 'safe_sheet.dart';
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
    if (!mounted) return;
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final itemTagsAsync = ref.watch(itemTagsProvider(widget.itemId));
    final itemTagIds =
        itemTagsAsync.valueOrNull?.map((t) => t.id).toSet() ?? {};

    return SafeSheet(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Spacing.sm),
            Text('Προσθήκη Tag', style: context.titleSm),
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
                              if (!mounted) return;
                              nav.pop();
                            },
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }
}

// Helper function για εύκολη χρήση
void showTagPickerSheet(BuildContext context, int itemId) {
  showSafeSheet<void>(
    context,
    scrollControlled: true,
    child: TagPickerSheet(itemId: itemId),
  );
}