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
          onPressed: () async {
            final wasArchived = item.archived;
            await ref.read(itemNotifierProvider.notifier).toggleArchive(item.id, wasArchived);
            // Αν μόλις αρχειοθετήσαμε (όχι unarchive), γυρνάμε πίσω
            if (!wasArchived && mounted) {
              Navigator.of(context).pop();
            }
          },
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
          data: (blocks) => _BlocksSliver(item: item, blocks: blocks),
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
// BLOCKS SLIVER + BLOCK EDITOR
// ════════════════════════════════════════════════════════════════

class _BlocksSliver extends ConsumerStatefulWidget {
  final Item item;
  final List<ItemBlock> blocks;

  const _BlocksSliver({required this.item, required this.blocks});

  @override
  ConsumerState<_BlocksSliver> createState() => _BlocksSliverState();
}

class _BlocksSliverState extends ConsumerState<_BlocksSliver> {
  int? _overrideBlockId;
  BlockType? _overrideType;

  @override
  void initState() {
    super.initState();
    // ✅ Διαγράφει μόνο text blocks που είναι κενά
    // Τα list/checklist/numbered/quote/code blocks δεν διαγράφονται
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final block in widget.blocks) {
        final isTextOnly = block.type == BlockType.text;
        if (isTextOnly && (block.text ?? '').trim().isEmpty) {
          await ref
              .read(blockNotifierProvider(widget.item.id).notifier)
              .delete(block.id);
        }
      }
    });
  }

  Future<void> _addBlock(BlockType type) async {
    if (widget.blocks.isNotEmpty) {
      final last = widget.blocks.last;
      final isEmpty = (last.text ?? '').trim().isEmpty;

      if (isEmpty) {
        setState(() {
          _overrideBlockId = last.id;
          _overrideType = type;
        });
        return;
      }
    }

    setState(() {
      _overrideBlockId = null;
      _overrideType = null;
    });

    await ref.read(blockNotifierProvider(widget.item.id).notifier).addBlock(type: type);
  }

  Future<void> _deleteBlock(int blockId) async {
    await ref.read(blockNotifierProvider(widget.item.id).notifier).delete(blockId);
  }

  Future<void> _toggleCheck(int blockId) async {
    await ref.read(blockNotifierProvider(widget.item.id).notifier).toggleCheck(blockId);
  }

  Future<void> _updateText(int blockId, String text) async {
    await ref.read(blockNotifierProvider(widget.item.id).notifier).updateText(blockId, text);
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(slivers: [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (ctx, i) {
              final numberedIndex = widget.blocks
                  .sublist(0, i)
                  .where((b) => b.type == BlockType.numbered)
                  .length;
              return _BlockTile(
                key: ValueKey(widget.blocks[i].id),   // ✅ μοναδικό key ανά block
                index: numberedIndex,
                block: widget.blocks[i],
                onDelete: () => _deleteBlock(widget.blocks[i].id),
                onToggleCheck: () => _toggleCheck(widget.blocks[i].id),
                onTextChanged: (t) => _updateText(widget.blocks[i].id, t),
                overrideType: _overrideBlockId == widget.blocks[i].id ? _overrideType : null,
              );
            },
            childCount: widget.blocks.length,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: _NewBlockBar(onAdd: _addBlock),
      ),
    ]);
  }
}

class _NewBlockBar extends StatelessWidget {
  final ValueChanged<BlockType> onAdd;

  const _NewBlockBar({required this.onAdd});

  static const _items = [
    (BlockType.text, Icons.text_fields_rounded, 'Κείμενο'),
    (BlockType.checklist, Icons.check_box_outlined, 'Λίστα'),
    (BlockType.bulletList, Icons.format_list_bulleted_rounded, 'Bullets'),
    (BlockType.numbered, Icons.format_list_numbered_rounded, 'Αριθμημένα'),
    (BlockType.quote, Icons.format_quote_rounded, 'Απόσπασμα'),
    (BlockType.code, Icons.code_rounded, 'Κώδικας'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorsUI.getSurface(context.brightness),
        border: Border(top: BorderSide(color: ColorsUI.getBorder(context.brightness))),
      ),
      padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: Spacing.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _items.map((t) {
            return Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: InkWell(
                borderRadius: AppRadius.buttonBR,
                onTap: () => onAdd(t.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$2, size: 20, color: context.cText2),
                      const SizedBox(height: 2),
                      Text(t.$3, style: context.labelSm.copyWith(fontSize: 11).withColor(context.cText2)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BLOCK TILE
// ════════════════════════════════════════════════════════════════

class _BlockTile extends StatefulWidget {
  final int index;
  final ItemBlock block;
  final VoidCallback onDelete;
  final VoidCallback onToggleCheck;
  final ValueChanged<String> onTextChanged;
  final BlockType? overrideType;

  const _BlockTile({
    super.key,                      // ✅ προσθήκη του key
    required this.index,
    required this.block,
    required this.onDelete,
    required this.onToggleCheck,
    required this.onTextChanged,
    this.overrideType,
  });

  @override
  State<_BlockTile> createState() => _BlockTileState();
}

class _BlockTileState extends State<_BlockTile> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;
  Timer? _debounce;
  BlockType get effectiveType => widget.overrideType ?? widget.block.type;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.block.text ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _ctrl.text.trim().isEmpty) {
        _debounce?.cancel();
        widget.onDelete();
      }
    });
  }

  @override
  void didUpdateWidget(_BlockTile old) {
    super.didUpdateWidget(old);
    if (!_ctrl.selection.isValid && widget.block.text != old.block.text) {
      _ctrl.text = widget.block.text ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChange(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (val.trim().isEmpty) {
        widget.onDelete();
      } else {
        widget.onTextChanged(val);
      }
    });
  }

  TextStyle _textStyle(BuildContext context) {
    switch (effectiveType) {
      case BlockType.heading1:
        return context.h2;
      case BlockType.heading2:
        return context.h3;
      case BlockType.heading3:
        return context.titleLg;
      case BlockType.code:
        return context.bodyMd.copyWith(
          fontFamily: 'monospace',
          backgroundColor: ColorsUI.getSurface(context.brightness),
        );
      case BlockType.quote:
        return context.bodyMd.withColor(context.cText2);
      default:
        return context.bodyMd;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveType = widget.overrideType ?? widget.block.type;
    final isChecklist = effectiveType == BlockType.checklist;
    final isQuote = effectiveType == BlockType.quote;
    final isBullet = effectiveType == BlockType.bulletList;
    final isNumbered = effectiveType == BlockType.numbered;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Prefix (checklist / bullet / numbered / quote) ──────
          if (isChecklist)
            GestureDetector(
              onTap: widget.onToggleCheck,
              child: Padding(
                padding: const EdgeInsets.only(top: 3, right: Spacing.sm),
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: widget.block.checked ? context.cPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                      color: widget.block.checked
                          ? context.cPrimary
                          : ColorsUI.getBorder(context.brightness),
                      width: 2,
                    ),
                  ),
                  child: widget.block.checked
                      ? Icon(Icons.check, size: 13,
                      color: ColorsUI.getAccessibleTextColor(context.cPrimary))
                      : null,
                ),
              ),
            )
          else if (isBullet)
            Padding(
              padding: const EdgeInsets.only(top: 9, right: Spacing.sm),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: context.cText2, shape: BoxShape.circle),
              ),
            )
          else if (isNumbered)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: Spacing.xs),
                child: SizedBox(
                  width: 24,
                  child: Text(
                    '${widget.index + 1}.',
                    style: context.bodyMd.withColor(context.cText2),
                    textAlign: TextAlign.right,
                  ),
                ),
              )
            else if (isQuote)
                Container(
                  width: 3,
                  margin: const EdgeInsets.only(right: Spacing.sm, top: 2),
                  decoration: BoxDecoration(
                    color: context.cPrimary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

          // ── TextField ────────────────────────────────────────────
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              onChanged: _onChange,
              style: _textStyle(context).copyWith(
                decoration: (isChecklist && widget.block.checked)
                    ? TextDecoration.lineThrough
                    : null,
                color: (isChecklist && widget.block.checked)
                    ? context.cDisabled
                    : null,
              ),
              maxLines: null,
              decoration: InputDecoration(
                hintText: _hintFor(widget.block.type),
                hintStyle: _textStyle(context).withColor(context.cDisabled),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // ✅ Delete icon — πάντα ορατό, κόκκινο κυκλάκι
          GestureDetector(
            onTap: () {
              _debounce?.cancel();
              widget.onDelete();
            },
            child: Container(
              margin: const EdgeInsets.only(left: Spacing.xs, top: 2),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.cError, width: 1.5),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: context.cError,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _hintFor(BlockType type) {
    type = effectiveType;
    switch (type) {
      case BlockType.heading1:
        return 'Επικεφαλίδα 1';
      case BlockType.heading2:
        return 'Επικεφαλίδα 2';
      case BlockType.heading3:
        return 'Επικεφαλίδα 3';
      case BlockType.checklist:
        return 'Στοιχείο λίστας';
      case BlockType.bulletList:
        return 'Στοιχείο λίστας';
      case BlockType.numbered:
        return 'Στοιχείο λίστας';
      case BlockType.quote:
        return 'Απόσπασμα';
      case BlockType.code:
        return 'Κώδικας';
      default:
        return '';
    }
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
