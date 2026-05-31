// lib/features/notes/note_detail_screen.dart
//
// Detail screen σημείωσης: editable title + block editor.
// ✅ Responsive: single col mobile / two-panel tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
// ✅ Reminders: μόνο από εικονίδιο AppBar
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';

// ════════════════════════════════════════════════════════════════
// NOTE DETAIL SCREEN
// ════════════════════════════════════════════════════════════════

class NoteDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  final bool isNew;

  const NoteDetailScreen({
    super.key,
    required this.itemId,
    this.isNew = false,
  });

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  late final TextEditingController _titleCtrl;
  Timer? _saveDebounce;
  bool _isSaving = false;
  bool _isEditingTitle = false;
  String _lastSavedTitle = '';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    DebugConfig.nav('NoteDetailScreen init id=${widget.itemId}');
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    _isEditingTitle = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), () {
      _isEditingTitle = false;
      _saveTitle(value.trim());
    });
  }

  Future<void> _saveTitle(String title) async {
    if (!mounted) return;
    if (title == _lastSavedTitle) return;
    setState(() => _isSaving = true);
    DebugConfig.db('NoteDetail saveTitle id=${widget.itemId} "$title"');
    try {
      await ref
          .read(itemNotifierProvider.notifier)
          .updateItem(widget.itemId, title: title.isEmpty ? null : title);
      _lastSavedTitle = title;
    } catch (e) {
      DebugConfig.error('NoteDetail _saveTitle', e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  Future<void> _togglePin(Item item) async {
    DebugConfig.provider('NoteDetail togglePin id=${item.id}');
    await ref
        .read(itemNotifierProvider.notifier)
        .togglePin(item.id, item.pinned);
  }

  Future<void> _toggleFav(Item item) async {
    DebugConfig.provider('NoteDetail toggleFav id=${item.id}');
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleFavorite(item.id, item.favorite);
  }

  Future<void> _deleteNote(BuildContext context, Item item) async {
    final future = ConfirmDialog.delete(context, title: 'Διαγραφή σημείωσης;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('NoteDetail delete id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  // --- Εμφάνιση bottom sheet με ReminderSection ---
  Future<void> _showReminderDialog() async {
    final title = _titleCtrl.text.trim().isEmpty ? 'Σημείωση' : _titleCtrl.text.trim();
    await showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: ReminderSection(
          itemId: widget.itemId,
          itemTitle: title,
          defaultStartTime: null,
        ),
      ),
    );
  }

  /// Ενιαία λογική για κουμπί Save και back arrow.
  Future<void> _saveOrDelete() async {
    _saveDebounce?.cancel();
    final title = _titleCtrl.text.trim();

    if (title.isEmpty) {
      // Κενός τίτλος → διαγραφή μόνο αν isNew
      if (widget.isNew) {
        DebugConfig.db('NoteDetail delete empty new note id=${widget.itemId}');
        try {
          await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
        } catch (e) {
          DebugConfig.error('NoteDetail _saveOrDelete delete', e);
        }
      }
      return;
    }

    // Έχει τίτλο → αποθήκευση
    await _saveTitle(title);
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) {
        DebugConfig.error('NoteDetail load failed', e);
        return _buildError();
      },
      data: (item) {
        if (item == null) return _buildNotFound();

        final itemTitle = item.title ?? '';
        if (_lastSavedTitle.isEmpty && itemTitle.isNotEmpty) {
          _lastSavedTitle = itemTitle;
        }
        if (!_isEditingTitle && _titleCtrl.text != itemTitle) {
          final cursorAtEnd = _titleCtrl.selection.baseOffset == _titleCtrl.text.length;
          _titleCtrl.text = itemTitle;
          if (cursorAtEnd) {
            _titleCtrl.selection = TextSelection.collapsed(offset: _titleCtrl.text.length);
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (_isSaving) return;
            final nav = Navigator.of(context);
            await _saveOrDelete();
            if (mounted) nav.pop();
          },
          child: ResponsiveLayout(
            mobile: _buildMobileLayout(context, item),
            tablet: _buildTabletLayout(context, item),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, Item item) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, item),
      body: _NoteBody(
        item: item,
        titleCtrl: _titleCtrl,
        onTitleChange: _onTitleChanged,
        isSaving: _isSaving,
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, Item item) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, item),
      body: Row(
        children: [
          SizedBox(
            width: 260,
            child: _MetadataPanel(item: item),
          ),
          VerticalDivider(width: 1, color: ColorsUI.getBorder(context.brightness)),
          Expanded(
            child: _NoteBody(
              item: item,
              titleCtrl: _titleCtrl,
              onTitleChange: _onTitleChanged,
              isSaving: _isSaving,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, Item item) {
    return AppBar(
      backgroundColor: context.cBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleSpacing: 0,
      actionsPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: _isSaving
          ? Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: context.cText2),
        ),
        const SizedBox(width: Spacing.xs),
        Text('Αποθήκευση...', style: context.bodySm.withColor(context.cText2)),
      ])
          : null,
      actions: [
        // Save
        // Save
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.save_rounded, color: context.cPrimary, size: 20),
          tooltip: 'Αποθήκευση',
          onPressed: _isSaving
              ? null
              : () async {
            if (_titleCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Παρακαλώ προσθέστε τίτλο')),
              );
              return;
            }
            _saveDebounce?.cancel();
            final nav = Navigator.of(context);
            setState(() => _isSaving = true);
            try {
              await _saveTitle(_titleCtrl.text.trim());
              if (mounted) nav.pop();
            } catch (e) {
              DebugConfig.error('NoteDetail save button', e);
              if (mounted) {
                setState(() => _isSaving = false);
                if (!context.mounted)return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Σφάλμα αποθήκευσης: ${e.toString()}')),
                );
              }
            }
          },
        ),
        // Reminder
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.notifications_none_rounded, color: context.cText2, size: 20),
          onPressed: _showReminderDialog,
          tooltip: 'Υπενθύμιση',
        ),
        // Favorite
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            item.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: item.favorite
                ? ColorsUI.getWarning(context.brightness)
                : context.cText,
            size: 20,
          ),
          onPressed: () => _toggleFav(item),
          tooltip: item.favorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
        ),
        // Pin
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: item.pinned
                ? context.cPrimary
                : context.cText,
            size: 20,
          ),
          onPressed: () => _togglePin(item),
          tooltip: item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
        ),
        // Archive
        // Archive
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            item.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
            color: context.cText2,
            size: 20,
          ),
          tooltip: item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση',
          onPressed: () => handleArchive(
            context: context,
            ref: ref,
            itemId: item.id,
            isArchived: item.archived,
            label: ItemLabel.note,
          ),
        ),
        // Delete
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.delete_outline_rounded, color: context.cError, size: 20),
          tooltip: 'Διαγραφή',
          onPressed: () => _deleteNote(context, item),
        ),
      ],
    );
  }

  Widget _buildLoading() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildError() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: EmptyState.error(onRetry: () => ref.invalidate(itemStreamProvider(widget.itemId))),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: const EmptyState(
      icon: Icons.note_alt_outlined,
      title: 'Η σημείωση δεν βρέθηκε',
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// NOTE BODY — title + blocks
// ════════════════════════════════════════════════════════════════

class _NoteBody extends ConsumerWidget {
  final Item item;
  final TextEditingController titleCtrl;
  final ValueChanged<String> onTitleChange;
  final bool isSaving;

  const _NoteBody({
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
                      onPressed: () => _showTagPicker(context, ref, item.id),
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
                      final tag = tags.firstWhere((t) => t.name == name, orElse: () => tags.first);
                      await ref.read(tagNotifierProvider.notifier).removeFromItem(item.id, tag.id);
                    },
                    onAdd: () => _showTagPicker(context, ref, item.id),
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

  void _showTagPicker(BuildContext context, WidgetRef ref, int itemId) {
    showTagPickerSheet(context, itemId);
  }
}

// ════════════════════════════════════════════════════════════════
// METADATA PANEL (tablet)
// ════════════════════════════════════════════════════════════════

class _MetadataPanel extends ConsumerWidget {
  final Item item;
  const _MetadataPanel({required this.item});

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
