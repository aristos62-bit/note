// lib/features/notes/note_detail_screen.dart
//
// Detail screen σημείωσης: editable title + block editor.
// ✅ Responsive: single col mobile / two-panel tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
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
  final bool isNew; // <= ΠΡΟΣΘΗΚΗ

  const NoteDetailScreen({
    super.key,
    required this.itemId,
    this.isNew = false, // default για παλιές κλήσεις
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
  bool _hasEverBeenSaved = false;

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

  // ── Title change (μόνο local, χωρίς auto-save) ───────────────

  void _onTitleChanged(String value) {
    _isEditingTitle = true;
    _saveDebounce?.cancel();

    // Δεν κάνουμε πια κανένα save εδώ, κρατάμε μόνο local state.
    // Το _isEditingTitle μας βοηθά να μη μας πατήσει το stream.
  }


  Future<void> _saveTitle(String title) async {
    if (!mounted) return;

    if (title == _lastSavedTitle) {
      return;
    }

    setState(() => _isSaving = true);
    DebugConfig.db('NoteDetail saveTitle id=${widget.itemId} "$title"');

    await ref
        .read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId, title: title.isEmpty ? null : title);

    _lastSavedTitle = title;
    _hasEverBeenSaved = true; // <= σημαδεύουμε ότι έγινε manual save

    if (!mounted) return;
    setState(() => _isSaving = false);
  }


  // ── AppBar actions ───────────────────────────────────────────

  Future<void> _togglePin(Item item) async {
    DebugConfig.provider('NoteDetail togglePin id=${item.id}');
    await ref.read(itemNotifierProvider.notifier)
        .togglePin(item.id, item.pinned);
  }

  Future<void> _toggleFav(Item item) async {
    DebugConfig.provider('NoteDetail toggleFav id=${item.id}');
    await ref.read(itemNotifierProvider.notifier)
        .toggleFavorite(item.id, item.favorite);
  }

  Future<void> _deleteNote(BuildContext context, Item item) async {
    final future = ConfirmDialog.delete(
      context,
      title: 'Διαγραφή σημείωσης;',
    );
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('NoteDetail delete id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.of(context).pop();
  }

  // ── Pop guard — μόνο auto-delete εντελώς κενής σημείωσης ──────

  Future<bool> _onPopInvoked() async {
    _saveDebounce?.cancel();

    // Αν είναι νέα σημείωση ΚΑΙ δεν έχει γίνει ποτέ manual save,
    // τη θεωρούμε draft και τη διαγράφουμε πάντα όταν βγούμε.
    if (widget.isNew && !_hasEverBeenSaved) {
      DebugConfig.db(
        'NoteDetail auto-delete NEW note without manual save id=${widget.itemId}',
      );
      await ref
          .read(itemNotifierProvider.notifier)
          .deleteItem(widget.itemId);
      return true;
    }

    // Για υπάρχουσες σημειώσεις (ή νέες που έχουν ήδη σωθεί),
    // δεν κάνουμε ούτε save ούτε delete αυτόματα στο back.
    DebugConfig.nav('NoteDetail back keep note id=${widget.itemId}');
    return true;
  }



  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error:   (e, _) {
        DebugConfig.error('NoteDetail load failed', e);
        return _buildError();
      },
      data: (item) {
        if (item == null) return _buildNotFound();

        final itemTitle = item.title ?? '';

        // Κρατάμε _lastSavedTitle sync με το DB
        if (_lastSavedTitle.isEmpty && itemTitle.isNotEmpty) {
          _lastSavedTitle = itemTitle;
        }

        // Sync title ΜΟΝΟ αν δεν γράφει ο χρήστης
        if (!_isEditingTitle &&
            _titleCtrl.text != itemTitle) {

          final cursorAtEnd =
              _titleCtrl.selection.baseOffset == _titleCtrl.text.length;

          _titleCtrl.text = itemTitle;

          if (cursorAtEnd) {
            _titleCtrl.selection =
                TextSelection.collapsed(offset: _titleCtrl.text.length);
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final nav    = Navigator.of(context);
            final canPop = await _onPopInvoked();
            if (canPop) nav.pop();
          },
          child: ResponsiveLayout(
            mobile:  _buildMobileLayout(context, item),
            tablet:  _buildTabletLayout(context, item),
          ),
        );
      },
    );
  }

  // ── Mobile layout ────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context, Item item) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, item),
      body: _NoteBody(
        item:          item,
        titleCtrl:     _titleCtrl,
        onTitleChange: _onTitleChanged,
        isSaving:      _isSaving,
      ),
    );
  }

  // ── Tablet layout — two panel ────────────────────────────────

  Widget _buildTabletLayout(BuildContext context, Item item) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, item),
      body: Row(
        children: [
          // Left panel: metadata
          SizedBox(
            width: 260,
            child: _MetadataPanel(item: item),
          ),
          VerticalDivider(width: 1, color: ColorsUI.getBorder(context.brightness)),
          // Right panel: content
          Expanded(
            child: _NoteBody(
              item:          item,
              titleCtrl:     _titleCtrl,
              onTitleChange: _onTitleChanged,
              isSaving:      _isSaving,
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
      title: _isSaving
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.cText2,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            'Αποθήκευση...',
            style: context.bodySm.withColor(context.cText2),
          ),
        ],
      )
          : null,
      actions: [
        // Save
        IconButton(
          icon: Icon(
            Icons.save_rounded,
            color: context.cPrimary,
          ),
          tooltip: 'Αποθήκευση',
          onPressed: () async {
            final title = _titleCtrl.text.trim();
            DebugConfig.db(
                'NoteDetail manual save pressed id=${item.id} title="$title"');
            await _saveTitle(title);

            // Μετά από save γύρνα πάντα πίσω
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
        ),

        // Favorite
        IconButton(
          icon: Icon(
            item.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: item.favorite
                ? ColorsUI.getWarning(context.brightness)
                : context.cText2,
          ),
          onPressed: () => _toggleFav(item),
          tooltip: item.favorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
        ),

        // Pin
        IconButton(
          icon: Icon(
            item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: item.pinned ? context.cPrimary : context.cText2,
          ),
          onPressed: () => _togglePin(item),
          tooltip: item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
        ),

        // Delete (αντί για 3 τελείες)
        IconButton(
          icon: Icon(
            Icons.delete_outline_rounded,
            color: context.cError,
          ),
          tooltip: 'Διαγραφή',
          onPressed: () => _deleteNote(context, item),
        ),
      ],
    );
  }


  // ── Fallback screens ─────────────────────────────────────────

  Widget _buildLoading() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildError() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: EmptyState.error(onRetry: () => ref.invalidate(
        itemStreamProvider(widget.itemId))),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: const EmptyState(
      icon:  Icons.note_alt_outlined,
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
    final tagsAsync   = ref.watch(itemTagsProvider(item.id));

    return CustomScrollView(
      slivers: [
        // ── Title ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.md,
              context.responsiveHPadding, Spacing.xs,
            ),
            child: TextField(
              controller:  titleCtrl,
              onChanged:   onTitleChange,
              style:       context.h2.copyWith(fontWeight: FontWeight.w600),
              maxLines:    null,
              decoration:  InputDecoration(
                hintText:       'Τίτλος...',
                hintStyle:      context.h2.withColor(context.cDisabled),
                border:         InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),

        // ── Meta: updated at + tags ──────────────────────────────
        // ── Meta: updated at + tags + content header ────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Updated at
                if (item.updatedAt != null)
                  Text(
                    'Τελ. τροποποίηση ${item.updatedAt!.relative}',
                    style: context.bodySm.withColor(context.cDisabled),
                  ),

                const SizedBox(height: Spacing.sm),

                // Tags header + add button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tags',
                      style: context.labelSm.withColor(context.cText2),
                    ),
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

                // Tags list
                tagsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                  data: (tags) => TagChipList.interactive(
                    tagNames:   tags.map((t) => t.name).toList(),
                    tagColors:  tags.map((t) => t.color).toList(),
                    onTagDelete: (name) async {
                      final tag = tags.firstWhere((t) => t.name == name,
                          orElse: () => tags.first);
                      DebugConfig.db('NoteDetail removeTag ${tag.id}');
                      await ref.read(tagNotifierProvider.notifier)
                          .removeFromItem(item.id, tag.id);
                    },
                    onAdd: () => _showTagPicker(context, ref, item.id),
                  ),
                ),

                const SizedBox(height: Spacing.md),

                // Content header + quick actions
                Row(
                  children: [
                    Text(
                      'Περιεχόμενο',
                      style: context.labelSm.withColor(context.cText2),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.text_fields_rounded, size: 18),
                      tooltip: 'Προσθήκη κειμένου',
                      onPressed: () {
                        DebugConfig.db('NoteDetail quickAdd text');
                        ref
                            .read(blockNotifierProvider(item.id).notifier)
                            .addBlock(type: BlockType.text);
                      },
                    ),
                    const SizedBox(width: Spacing.xs),
                    IconButton.outlined(
                      icon: const Icon(Icons.check_box_outlined, size: 18),
                      tooltip: 'Προσθήκη λίστας',
                      onPressed: () {
                        DebugConfig.db('NoteDetail quickAdd checklist');
                        ref
                            .read(blockNotifierProvider(item.id).notifier)
                            .addBlock(type: BlockType.checklist);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: Spacing.sm),
                Divider(color: ColorsUI.getBorder(context.brightness)),
              ],
            ),
          ),
        ),


        // ── Blocks ──────────────────────────────────────────────
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

        // Bottom padding για FAB
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  void _showTagPicker(BuildContext context, WidgetRef ref, int itemId) {
    DebugConfig.nav('NoteDetail showTagPicker id=$itemId');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => _TagPickerSheet(itemId: itemId),
    );
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

  Future<void> _addBlock(BlockType type) async {
    DebugConfig.db('NoteDetail addBlock type=${type.name} itemId=${widget.item.id}');
    await ref.read(blockNotifierProvider(widget.item.id).notifier)
        .addBlock(type: type);
  }

  Future<void> _deleteBlock(int blockId) async {
    DebugConfig.db('NoteDetail deleteBlock id=$blockId');
    await ref.read(blockNotifierProvider(widget.item.id).notifier)
        .delete(blockId);
  }

  Future<void> _toggleCheck(int blockId) async {
    DebugConfig.db('NoteDetail toggleCheck blockId=$blockId');
    await ref.read(blockNotifierProvider(widget.item.id).notifier)
        .toggleCheck(blockId);
  }

  Future<void> _updateText(int blockId, String text) async {
    await ref.read(blockNotifierProvider(widget.item.id).notifier)
        .updateText(blockId, text);
  }

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(slivers: [
      // Block list
      SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (ctx, i) => _BlockTile(
              block:         widget.blocks[i],
              onDelete:      () => _deleteBlock(widget.blocks[i].id),
              onToggleCheck: () => _toggleCheck(widget.blocks[i].id),
              onTextChanged: (t) => _updateText(widget.blocks[i].id, t),
            ),
            childCount: widget.blocks.length,
          ),
        ),
      ),

      // Empty hint
      if (widget.blocks.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHPadding,
              vertical:   Spacing.lg,
            ),
            child: Card(
              color: ColorsUI.getSurface(context.brightness),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Νέα σημείωση',
                      style: context.titleMd,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Γράψε έναν τίτλο ή πρόσθεσε ένα πρώτο μπλοκ για να ξεκινήσεις.',
                      style: context.bodySm.withColor(context.cDisabled),
                    ),
                    const SizedBox(height: Spacing.md),
                    Wrap(
                      spacing: Spacing.sm,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.text_fields_rounded, size: 18),
                          label: const Text('Κείμενο'),
                          onPressed: () => _addBlock(BlockType.text),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.check_box_outlined, size: 18),
                          label: const Text('Λίστα'),
                          onPressed: () => _addBlock(BlockType.checklist),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

      // Add block toolbar
      SliverToBoxAdapter(
        child: _AddBlockToolbar(onAdd: _addBlock),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// BLOCK TILE — εμφανίζει ένα block για επεξεργασία
// ════════════════════════════════════════════════════════════════

class _BlockTile extends StatefulWidget {
  final ItemBlock block;
  final VoidCallback onDelete;
  final VoidCallback onToggleCheck;
  final ValueChanged<String> onTextChanged;

  const _BlockTile({
    required this.block,
    required this.onDelete,
    required this.onToggleCheck,
    required this.onTextChanged,
  });

  @override
  State<_BlockTile> createState() => _BlockTileState();
}

class _BlockTileState extends State<_BlockTile> {
  late final TextEditingController _ctrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.block.text ?? '');
  }

  @override
  void didUpdateWidget(_BlockTile old) {
    super.didUpdateWidget(old);
    // Ενημέρωσε μόνο αν ο χρήστης δεν γράφει
    if (!_ctrl.selection.isValid &&
        widget.block.text != old.block.text) {
      _ctrl.text = widget.block.text ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChange(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onTextChanged(val);
    });
  }

  TextStyle _textStyle(BuildContext context) {
    switch (widget.block.type) {
      case BlockType.heading1: return context.h2;
      case BlockType.heading2: return context.h3;
      case BlockType.heading3: return context.titleLg;
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
    final isChecklist = widget.block.type == BlockType.checklist;
    final isQuote     = widget.block.type == BlockType.quote;
    final isBullet    = widget.block.type == BlockType.bulletList;
    final isNumbered  = widget.block.type == BlockType.numbered;

    return Dismissible(
      key: ValueKey(widget.block.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Spacing.md),
        color: context.cError.withValues(alpha:0.1),
        child: Icon(Icons.delete_outline_rounded, color: context.cError),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs / 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Block prefix ─────────────────────────────────────
            if (isChecklist)
              GestureDetector(
                onTap: widget.onToggleCheck,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3, right: Spacing.sm),
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: widget.block.checked
                          ? context.cPrimary : Colors.transparent,
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
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: context.cText2,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else if (isNumbered)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: Spacing.xs),
                  child: SizedBox(
                    width: 24,
                    child: Text('•', // simplified — θα γίνει dynamic αριθμός
                        style: context.bodyMd.withColor(context.cText2),
                        textAlign: TextAlign.right),
                  ),
                )
              else if (isQuote)
                  Container(
                    width: 3,
                    margin: const EdgeInsets.only(right: Spacing.sm, top: 2),
                    decoration: BoxDecoration(
                      color: context.cPrimary.withValues(alpha:0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

            // ── Text field ────────────────────────────────────────
            Expanded(
              child: TextField(
                controller: _ctrl,
                onChanged:  _onChange,
                style: _textStyle(context).copyWith(
                  decoration: (isChecklist && widget.block.checked)
                      ? TextDecoration.lineThrough : null,
                  color: (isChecklist && widget.block.checked)
                      ? context.cDisabled : null,
                ),
                maxLines:  null,
                decoration: InputDecoration(
                  hintText: _hintFor(widget.block.type),
                  hintStyle: _textStyle(context).withColor(context.cDisabled),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hintFor(BlockType type) {
    switch (type) {
      case BlockType.heading1:  return 'Επικεφαλίδα 1';
      case BlockType.heading2:  return 'Επικεφαλίδα 2';
      case BlockType.heading3:  return 'Επικεφαλίδα 3';
      case BlockType.checklist: return 'Στοιχείο λίστας';
      case BlockType.bulletList:return 'Στοιχείο λίστας';
      case BlockType.numbered:  return 'Στοιχείο λίστας';
      case BlockType.quote:     return 'Απόσπασμα';
      case BlockType.code:      return 'Κώδικας';
      default:                  return '';
    }
  }
}

// ════════════════════════════════════════════════════════════════
// ADD BLOCK TOOLBAR
// ════════════════════════════════════════════════════════════════

class _AddBlockToolbar extends StatelessWidget {
  final ValueChanged<BlockType> onAdd;
  const _AddBlockToolbar({required this.onAdd});

  static const _quickTypes = [
    (BlockType.text,      Icons.text_fields_rounded,    'Κείμενο'),
    (BlockType.heading1,  Icons.title_rounded,          'Επικεφαλίδα'),
    (BlockType.checklist, Icons.check_box_outlined,     'Λίστα'),
    (BlockType.bulletList,Icons.format_list_bulleted_rounded, 'Bullet'),
    (BlockType.quote,     Icons.format_quote_rounded,   'Απόσπασμα'),
    (BlockType.code,      Icons.code_rounded,           'Κώδικας'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:  ColorsUI.getSurface(context.brightness),
        border: Border(top: BorderSide(color: ColorsUI.getBorder(context.brightness))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical:   Spacing.xs,
        ),
        child: Row(
          children: _quickTypes.map((t) => Padding(
            padding: const EdgeInsets.only(right: Spacing.xs),
            child: Tooltip(
              message: t.$3,
              child: IconButton(
                icon:     Icon(t.$2, size: 20, color: context.cText2),
                onPressed: () {
                  DebugConfig.print('AddBlock: ${t.$1.name}');
                  onAdd(t.$1);
                },
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonBR,
                  ),
                ),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// METADATA PANEL — tablet/desktop μόνο
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
          // Type
          _MetaRow(
            icon:  ItemTypeIcon.iconDataFor(ItemType.note),
            label: 'Τύπος',
            value: ItemTypeIcon.labelFor(ItemType.note),
          ),

          // Status
          _MetaRow(
            icon:  Icons.info_outline_rounded,
            label: 'Κατάσταση',
            value: AppStringUtils.statusLabel(item.status.name),
          ),

          // Priority
          if (item.priority != ItemPriority.none) ...[
            const SizedBox(height: Spacing.sm),
            Row(children: [
              Icon(PriorityBadge.iconFor(item.priority),
                  size: 16, color: context.cText2),
              const SizedBox(width: Spacing.sm),
              PriorityBadge(priority: item.priority, size: BadgeSize.medium),
            ]),
          ],

          const Divider(height: Spacing.xl),

          // Dates
          _MetaRow(
            icon:  Icons.calendar_today_rounded,
            label: 'Δημιουργία',
            value: item.createdAt.short,
          ),
          if (item.updatedAt != null)
            _MetaRow(
              icon:  Icons.edit_calendar_rounded,
              label: 'Τροποποίηση',
              value: item.updatedAt!.relative,
            ),

          const Divider(height: Spacing.xl),

          // Tags
          Text('Tags', style: context.labelMd.withColor(context.cText2)),
          const SizedBox(height: Spacing.sm),
          tagsAsync.when(
            loading: () => const SizedBox.shrink(),
            error:   (_, __) => const SizedBox.shrink(),
            data: (tags) => TagChipList.readOnly(
              tagNames:  tags.map((t) => t.name).toList(),
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
                Text(label,
                    style: context.labelSm.withColor(context.cDisabled)),
                Text(value, style: context.bodyMd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAG PICKER SHEET
// ════════════════════════════════════════════════════════════════

class _TagPickerSheet extends ConsumerStatefulWidget {
  final int itemId;
  const _TagPickerSheet({required this.itemId});

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addTag(String name) async {
    if (name.trim().isEmpty) return;
    DebugConfig.db('TagPicker addTag "$name" to item=${widget.itemId}');
    final tag = await ref.read(tagNotifierProvider.notifier)
        .createOrGet(name.trim());
    if (tag == null || !mounted) return;
    await ref.read(tagNotifierProvider.notifier)
        .addToItem(widget.itemId, tag.id);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync     = ref.watch(tagsProvider);
    final itemTagsAsync = ref.watch(itemTagsProvider(widget.itemId));
    final itemTagIds    = itemTagsAsync.valueOrNull
        ?.map((t) => t.id).toSet() ?? {};

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: context.cBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),

            Text('Προσθήκη Tag', style: context.titleMd),
            const SizedBox(height: Spacing.md),

            // New tag input
            TextField(
              controller: _ctrl,
              autofocus:  true,
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

            // Existing tags
            tagsAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data: (tags) {
                final available = tags
                    .where((t) => !itemTagIds.contains(t.id))
                    .toList();
                if (available.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: available.map((t) => TagChip(
                    name:  t.name,
                    color: t.color,
                    onTap: () async {
                      DebugConfig.db('TagPicker existing tag="${t.name}"');
                      final nav = Navigator.of(context); // cache πριν το await
                      await ref.read(tagNotifierProvider.notifier)
                          .addToItem(widget.itemId, t.id);
                      nav.pop();
                    },
                  )).toList(),
                );
              },
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + Spacing.sm),
          ],
        ),
      ),
    );
  }
}