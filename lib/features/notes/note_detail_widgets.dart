// lib/features/notes/note_detail_widgets.dart
//
// Παρουσίαση detail σημείωσης (extract από note_detail_screen — Φ4b-21).
// Byte-identical μεταφορά: NoteDetailBody + NoteDetailMetadata + _MetaRow.
// Micro-fix: inline showTagPickerSheet (διαγραφή νεκρού wrapper _showTagPicker).
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';

// ════════════════════════════════════════════════════════════════
// NOTE BODY — title + blocks
// ════════════════════════════════════════════════════════════════

class NoteDetailBody extends ConsumerWidget {
  final Item item;
  final TextEditingController titleCtrl;
  final ValueChanged<String> onTitleChange;
  final bool isSaving;

  const NoteDetailBody({
    super.key,
    required this.item,
    required this.titleCtrl,
    required this.onTitleChange,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(blocksStreamProvider(item.id));
    final tagsAsync = ref.watch(itemTagsProvider(item.id));

    return CustomScrollView(
      slivers: [
        // Title
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding,
              Spacing.md,
              context.responsiveHPadding,
              Spacing.xs,
            ),
            child: TextField(
              controller: titleCtrl,
              onChanged: onTitleChange,
              style: context.h2.copyWith(fontWeight: FontWeight.w600),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Τίτλος...',
                hintStyle: context.h2.withColor(context.cDisabled),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),

        // Meta: updated at + tags + content header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.updatedAt != null)
                  Text(
                    'Τελ. τροποποίηση ${item.updatedAt!.relative}',
                    style: context.bodySm.withColor(context.cDisabled),
                  ),
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tags', style: context.labelSm.withColor(context.cText2)),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Προσθήκη'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => showTagPickerSheet(context, item.id),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                tagsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (tags) => TagChipList.interactive(
                    tagNames: tags.map((t) => t.name).toList(),
                    tagColors: tags.map((t) => t.color).toList(),
                    onTagDelete: (name) async {
                      if (tags.isEmpty) return;
                      final tag = tags.firstWhere((t) => t.name == name, orElse: () => tags.first);
                      await ref.read(tagNotifierProvider.notifier).removeFromItem(item.id, tag.id);
                    },
                    onAdd: () => showTagPickerSheet(context, item.id),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sm),
                  child: Text('Περιεχόμενο', style: context.labelSm.withColor(context.cText2)),
                ),
                const SizedBox(height: Spacing.sm),
                Divider(color: ColorsUI.getBorder(context.brightness)),
              ],
            ),
          ),
        ),

        // Blocks
        blocksAsync.when(
          loading: () => SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(context.responsiveHPadding),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) {
            DebugConfig.error('NoteDetail blocks load failed', e);
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
          data: (blocks) => BlockEditorWidget(itemId: item.id, blocks: blocks),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// METADATA PANEL (tablet)
// ════════════════════════════════════════════════════════════════

class NoteDetailMetadata extends ConsumerWidget {
  final Item item;
  const NoteDetailMetadata({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(itemTagsProvider(item.id));

    return Container(
      color: ColorsUI.getSurface(context.brightness),
      child: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          _MetaRow(
            icon: ItemTypeIcon.iconDataFor(ItemType.note),
            label: 'Τύπος',
            value: ItemTypeIcon.labelFor(ItemType.note),
          ),
          _MetaRow(
            icon: Icons.info_outline_rounded,
            label: 'Κατάσταση',
            value: AppStringUtils.statusLabel(item.status.name),
          ),
          if (item.priority != ItemPriority.none) ...[
            const SizedBox(height: Spacing.sm),
            Row(children: [
              Icon(PriorityBadge.iconFor(item.priority), size: 16, color: context.cText2),
              const SizedBox(width: Spacing.sm),
              PriorityBadge(priority: item.priority, size: BadgeSize.medium),
            ]),
          ],
          const Divider(height: Spacing.xl),
          _MetaRow(
            icon: Icons.calendar_today_rounded,
            label: 'Δημιουργία',
            value: item.createdAt.short,
          ),
          if (item.updatedAt != null)
            _MetaRow(
              icon: Icons.edit_calendar_rounded,
              label: 'Τροποποίηση',
              value: item.updatedAt!.relative,
            ),
          const Divider(height: Spacing.xl),
          Text('Tags', style: context.labelMd.withColor(context.cText2)),
          const SizedBox(height: Spacing.sm),
          tagsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (tags) => TagChipList.readOnly(
              tagNames: tags.map((t) => t.name).toList(),
              tagColors: tags.map((t) => t.color).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.cText2),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.labelSm.withColor(context.cDisabled)),
                Text(value, style: context.bodyMd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
