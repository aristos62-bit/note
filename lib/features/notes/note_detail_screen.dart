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
import 'note_detail_widgets.dart';

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

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen>
    with DetailScreenMixin<NoteDetailScreen> {
  late final TextEditingController _titleCtrl;
  Timer? _saveDebounce;
  bool _isSaving = false;
  bool _isEditingTitle = false;
  String _lastSavedTitle = '';

  @override
  TextEditingController get titleCtrl => _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    initScreen(itemId: widget.itemId, isNew: widget.isNew);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    disposeScreen();
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
            _saveDebounce?.cancel();
            await executeSaveOrDelete(
              saveFn: () => _saveTitle(titleCtrl.text.trim()),
              deleteFn: () => ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId),
            );
            if (mounted) safePop();
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
      body: NoteDetailBody(
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
            child: NoteDetailMetadata(item: item),
          ),
          VerticalDivider(width: 1, color: ColorsUI.getBorder(context.brightness)),
          Expanded(
            child: NoteDetailBody(
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
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.save_rounded, color: context.cPrimary, size: 20),
          tooltip: 'Αποθήκευση',
          onPressed: _isSaving
              ? null
              : () async {
            _saveDebounce?.cancel();
            final saved = await executeSave(
              () => _saveTitle(titleCtrl.text.trim()),
            );
            if (saved) safePop();
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
