import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/item_block.dart';
import '../../providers/providers.dart';
import 'content_field_widget.dart';

/// Full block editor for rich content (notes).
///
/// Features:
/// - Multiple block types: text, heading, checklist, bullet, numbered, quote, code
/// - Auto-delete empty text blocks on init
/// - Override type on existing empty blocks
/// - Each block uses [ContentFieldWidget] for consistent field behavior
class BlockEditorWidget extends ConsumerStatefulWidget {
  final int itemId;
  final List<ItemBlock> blocks;

  const BlockEditorWidget({
    super.key,
    required this.itemId,
    required this.blocks,
  });

  @override
  ConsumerState<BlockEditorWidget> createState() => _BlockEditorWidgetState();
}

class _BlockEditorWidgetState extends ConsumerState<BlockEditorWidget> {
  int? _overrideBlockId;
  BlockType? _overrideType;
  int? _newBlockId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final block in widget.blocks) {
        if (block.type == BlockType.text && (block.text ?? '').trim().isEmpty) {
          await ref
              .read(blockNotifierProvider(widget.itemId).notifier)
              .delete(block.id);
        }
      }
    });
  }

  @override
  void didUpdateWidget(BlockEditorWidget old) {
    super.didUpdateWidget(old);
    if (widget.blocks.length > old.blocks.length) {
      _newBlockId = widget.blocks.last.id;
    } else if (widget.blocks.length < old.blocks.length) {
      _newBlockId = null;
    }
  }

  Future<void> _addBlock(BlockType type) async {
    if (widget.blocks.isNotEmpty) {
      final last = widget.blocks.last;
      if ((last.text ?? '').trim().isEmpty) {
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
    await ref
        .read(blockNotifierProvider(widget.itemId).notifier)
        .addBlock(type: type);
  }

  Future<void> _deleteBlock(int blockId) async {
    await ref
        .read(blockNotifierProvider(widget.itemId).notifier)
        .delete(blockId);
  }

  Future<void> _toggleCheck(int blockId) async {
    await ref
        .read(blockNotifierProvider(widget.itemId).notifier)
        .toggleCheck(blockId);
  }

  Future<void> _updateText(int blockId, String text) async {
    await ref
        .read(blockNotifierProvider(widget.itemId).notifier)
        .updateText(blockId, text);
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
              return BlockTileWidget(
                key: ValueKey(widget.blocks[i].id),
                index: numberedIndex,
                block: widget.blocks[i],
                onDelete: () => _deleteBlock(widget.blocks[i].id),
                onToggleCheck: () => _toggleCheck(widget.blocks[i].id),
                onTextChanged: (t) =>
                    _updateText(widget.blocks[i].id, t),
                overrideType: _overrideBlockId == widget.blocks[i].id
                    ? _overrideType
                    : null,
                autoFocus: widget.blocks[i].id == _newBlockId,
              );
            },
            childCount: widget.blocks.length,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: NewBlockBar(onAdd: _addBlock),
      ),
    ]);
  }
}

/// A single block tile: prefix icon + text field + delete button.
///
/// Prefix changes based on block type:
/// - checklist: tappable checkbox
/// - bulletList: bullet dot
/// - numbered: auto-incrementing number
/// - quote: vertical accent bar
class BlockTileWidget extends StatefulWidget {
  final int index;
  final ItemBlock block;
  final VoidCallback onDelete;
  final VoidCallback onToggleCheck;
  final ValueChanged<String> onTextChanged;
  final BlockType? overrideType;
  final bool autoFocus;

  const BlockTileWidget({
    super.key,
    required this.index,
    required this.block,
    required this.onDelete,
    required this.onToggleCheck,
    required this.onTextChanged,
    this.overrideType,
    this.autoFocus = false,
  });

  @override
  State<BlockTileWidget> createState() => _BlockTileWidgetState();
}

class _BlockTileWidgetState extends State<BlockTileWidget> {
  BlockType get effectiveType => widget.overrideType ?? widget.block.type;

  @override
  Widget build(BuildContext context) {
    final isChecklist = effectiveType == BlockType.checklist;
    final isQuote = effectiveType == BlockType.quote;
    final isBullet = effectiveType == BlockType.bulletList;
    final isNumbered = effectiveType == BlockType.numbered;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Prefix ──
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
                    color: widget.block.checked
                        ? context.cPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                      color: widget.block.checked
                          ? context.cPrimary
                          : context.cBorder,
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
                decoration: BoxDecoration(
                    color: context.cText2, shape: BoxShape.circle),
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

          // ── ContentFieldWidget (shared text input) ──
          Expanded(
            child: ContentFieldWidget(
              initialText: widget.block.text ?? '',
              hintText: _hintFor(effectiveType),
              style: _styleFor(context),
              onSaved: (text) {
                widget.onTextChanged(text);
              },
              onDeleteEmpty: widget.onDelete,
              debounce: const Duration(milliseconds: 500),
              cursorAtStart: true,
              autoFocus: widget.autoFocus,
            ),
          ),

          // ── Delete button ──
          GestureDetector(
            onTap: () {
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

  TextStyle _styleFor(BuildContext context) {
    final checked = widget.block.checked;
    switch (effectiveType) {
      case BlockType.heading1:
        return checked
            ? context.h2.copyWith(
                decoration: TextDecoration.lineThrough, color: context.cDisabled)
            : context.h2;
      case BlockType.heading2:
        return checked
            ? context.h3.copyWith(
                decoration: TextDecoration.lineThrough, color: context.cDisabled)
            : context.h3;
      case BlockType.heading3:
        return checked
            ? context.titleLg.copyWith(
                decoration: TextDecoration.lineThrough, color: context.cDisabled)
            : context.titleLg;
      case BlockType.code:
        return context.bodyMd.copyWith(
          fontFamily: 'monospace',
          backgroundColor: context.cSurface,
        );
      case BlockType.quote:
        return context.bodyMd.withColor(context.cText2);
      case BlockType.checklist:
        if (checked) {
          return context.bodyMd.copyWith(
            decoration: TextDecoration.lineThrough,
            color: context.cDisabled,
          );
        }
        return context.bodyMd;
      default:
        return context.bodyMd;
    }
  }

  String _hintFor(BlockType type) {
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

/// Horizontal bar at the bottom of the block editor to add new blocks.
class NewBlockBar extends StatelessWidget {
  final ValueChanged<BlockType> onAdd;

  const NewBlockBar({super.key, required this.onAdd});

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
        color: context.cSurface,
        border: Border(
            top: BorderSide(color: context.cBorder)),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding, vertical: Spacing.xs),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm, vertical: Spacing.xs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$2, size: 20, color: context.cText2),
                      const SizedBox(height: 2),
                      Text(t.$3,
                          style: context.labelSm
                              .copyWith(fontSize: 11)
                              .withColor(context.cText2)),
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
