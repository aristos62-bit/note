// lib/features/journal/journal_detail_screen.dart
//
// Detail screen ημερολογίου – πλήρως ευθυγραμμισμένο με το NoteDetailScreen.
// ✅ AppBar: Αποθήκευση, Υπενθύμιση, Αγαπημένο, Pin, Αρχειοθέτηση, Διαγραφή
// ✅ Αυτόματο save / delete άδειων νέων καταχωρήσεων
// ✅ Επιλογή ημερομηνίας καταχώρησης (entry_date) & mood picker
// ✅ Tags: προβολή, προσθήκη, αφαίρεση (ίδιο pattern)
// ✅ Reminder bottom sheet
// ✅ Responsive: single column mobile / two‑panel tablet+desktop
// ✅ Dark mode + DebugConfig
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';

class JournalDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  final bool isNew;

  const JournalDetailScreen({
    super.key,
    required this.itemId,
    this.isNew = false,
  });

  @override
  ConsumerState<JournalDetailScreen> createState() =>
      _JournalDetailScreenState();
}

class _JournalDetailScreenState extends ConsumerState<JournalDetailScreen>
    with DetailScreenMixin<JournalDetailScreen> {
  late final TextEditingController _titleCtrl;

  @override
  TextEditingController get titleCtrl => _titleCtrl;

  // ── Save state ──────────────────
  bool _isEditingTitle = false;
  String _lastSavedTitle = '';
  String _pendingContent = '';
  bool _hasEverBeenSaved = false;

  // ── Entry date state ───────────────────────────────────────
  DateTime? _entryDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    initScreen(itemId: widget.itemId, isNew: widget.isNew);
    _loadEntryDate();
  }

  @override
  void dispose() {
    disposeScreen();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    _isEditingTitle = true;
  }

  void _onContentChanged(String value) {
    _pendingContent = value;
  }

  Future<void> _onContentSaved(String content) async {
    DebugConfig.db('JournalDetail saveContent id=${widget.itemId}');
    try {
      await ref
          .read(propertyNotifierProvider(widget.itemId).notifier)
          .setText('content', content.isEmpty ? null : content);
    } catch (e) {
      DebugConfig.error('JournalDetail saveContent', e);
    }
  }

  /// ?�?��?�?�? ?? save logic (no ?�?U?I management)
  Future<void> _saveData() async {
    final title = _titleCtrl.text.trim();

    if (title == _lastSavedTitle && _pendingContent.isEmpty && _hasEverBeenSaved) {
      DebugConfig.db('JournalDetail save: no changes, skip');
      return;
    }

    DebugConfig.db('JournalDetail save id=${widget.itemId} title="$title"');

    await ref
        .read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId, title: title.isEmpty ? null : title);

    if (_pendingContent.isNotEmpty) {
      if (!mounted) return;
      await _onContentSaved(_pendingContent);
    }

    _lastSavedTitle = title;
    _hasEverBeenSaved = true;
    _isEditingTitle = false;
    DebugConfig.db('JournalDetail saved successfully');
  }

  /// ??? wrapper ?�? executeSave + pop
  Future<void> _save() async {
    final ok = await executeSave(() => _saveData());
    if (ok && mounted) safePop();
  }

  /// ??? logic ??? back arrow (auto-save ?? pop)
  Future<bool> _onPopInvoked() async {
    await executeSaveOrDelete(
      saveFn: _saveData,
      deleteFn: () => ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId),
    );
    return true;
  }
  Future<void> _delete(BuildContext context) async {
    final ok = await ConfirmDialog.delete(context, title: 'Διαγραφή καταχώρησης;');
    if (!ok || !mounted) return;
    DebugConfig.db('JournalDetail delete id=${widget.itemId}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _togglePin(Item item) async {
    await ref.read(itemNotifierProvider.notifier).togglePin(item.id, item.pinned);
  }

  Future<void> _toggleFav(Item item) async {
    await ref.read(itemNotifierProvider.notifier).toggleFavorite(item.id, item.favorite);
  }

  Future<void> _toggleArchive(Item item) async {
    await handleArchive(
      context: context,
      ref: ref,
      itemId: widget.itemId,
      isArchived: item.archived,
      label: ItemLabel.journal,
    );
  }

  Future<void> _loadEntryDate() async {
    final props = await ref.read(itemPropertiesProvider(widget.itemId).future);
    final dateStr = props.where((p) => p.key == 'entry_date').firstOrNull?.value;
    if (dateStr != null && mounted) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) setState(() => _entryDate = parsed);
    } else if (widget.isNew && mounted) {
      final now = DateTime.now();
      await _setEntryDate(now);
    }
  }

  Future<void> _setEntryDate(DateTime? date) async {
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
        .setDate('entry_date', date);
    if (mounted) setState(() => _entryDate = date);
  }

  // ── Reminder bottom sheet (ίδιο με NoteDetailScreen) ──────
  Future<void> _showReminderDialog() async {
    final title = _titleCtrl.text.trim().isEmpty ? 'Καταχώρηση' : _titleCtrl.text.trim();
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

  // ── Tag picker (αντιγραφή από NoteDetailScreen για αυτονομία) ─
  void _showTagPicker(BuildContext context, WidgetRef ref, int itemId) {
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
      builder: (ctx) => _TagPickerSheet(itemId: itemId),
    );
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('JournalDetailScreen build id=${widget.itemId}');
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) {
        DebugConfig.error('JournalDetail load failed', e);
        return _buildError();
      },
      data: (item) {
        if (item == null) return _buildNotFound();

        if (!_isEditingTitle) {
          final dbTitle = item.title ?? '';
          if (_titleCtrl.text != dbTitle) {
            _titleCtrl.text = dbTitle;
            _titleCtrl.selection =
                TextSelection.collapsed(offset: _titleCtrl.text.length);
          }
          if (_lastSavedTitle.isEmpty && dbTitle.isNotEmpty) {
            _lastSavedTitle = dbTitle;
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _onPopInvoked();
            if (mounted) safePop();
          },
          child: ResponsiveLayout(
            mobile: _buildMobile(context, item),
            tablet: _buildTablet(context, item),
          ),
        );
      },
    );
  }

  Widget _buildMobile(BuildContext context, Item item) => Scaffold(
    backgroundColor: context.cBg,
    appBar: _buildAppBar(context, item),
    body: _JournalBody(
      item: item,
      titleCtrl: _titleCtrl,
      onTitleChanged: _onTitleChanged,
      onContentChanged: _onContentChanged,
      onContentSaved: _onContentSaved,
      entryDate: _entryDate,
      onSetEntryDate: _setEntryDate,
      onShowReminder: _showReminderDialog,
      onShowTagPicker: () => _showTagPicker(context, ref, widget.itemId),
    ),
  );

  Widget _buildTablet(BuildContext context, Item item) => Scaffold(
    backgroundColor: context.cBg,
    appBar: _buildAppBar(context, item),
    body: Row(
      children: [
        SizedBox(
          width: context.isDesktop ? 280 : 240,
          child: _JournalMetaPanel(
            item: item,
            entryDate: _entryDate,
            onShowTagPicker: () => _showTagPicker(context, ref, widget.itemId),
          ),
        ),
        VerticalDivider(
            width: 1, color: ColorsUI.getBorder(context.brightness)),
        Expanded(
          child: _JournalBody(
            item: item,
            titleCtrl: _titleCtrl,
            onTitleChanged: _onTitleChanged,
            onContentChanged: _onContentChanged,
            onContentSaved: _onContentSaved,
            entryDate: _entryDate,
            onSetEntryDate: _setEntryDate,
            onShowReminder: _showReminderDialog,
            onShowTagPicker: () => _showTagPicker(context, ref, widget.itemId),
          ),
        ),
      ],
    ),
  );

  AppBar _buildAppBar(BuildContext context, Item item) {
    return AppBar(
      backgroundColor: context.cBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: null,
      actions: [
        // Save
        IconButton(
          icon: Icon(Icons.save_rounded, color: context.cPrimary),
          tooltip: 'Αποθήκευση',
          onPressed: _save,
        ),
        // Reminder
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: context.cText2),
          onPressed: _showReminderDialog,
          tooltip: 'Υπενθύμιση',
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
        // Archive
        IconButton(
          icon: Icon(
            item.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
            color: context.cText2,
          ),
          tooltip: item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση',
          onPressed: () => _toggleArchive(item),
        ),
        // Delete
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: context.cError),
          tooltip: 'Διαγραφή',
          onPressed: () => _delete(context),
        ),
      ],
    );
  }

  Widget _buildLoading() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildError() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: EmptyState.error(
        onRetry: () => ref.invalidate(itemStreamProvider(widget.itemId))),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const EmptyState(
        icon: Icons.auto_stories_rounded,
        title: 'Η καταχώρηση δεν βρέθηκε'),
  );
}

// ════════════════════════════════════════════════════════════════
// JOURNAL BODY
// ════════════════════════════════════════════════════════════════

class _JournalBody extends ConsumerStatefulWidget {
  final Item item;
  final TextEditingController titleCtrl;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onContentChanged;
  final ValueChanged<String> onContentSaved;
  final DateTime? entryDate;
  final ValueChanged<DateTime?> onSetEntryDate;
  final VoidCallback onShowReminder;
  final VoidCallback onShowTagPicker;

  const _JournalBody({
    required this.item,
    required this.titleCtrl,
    required this.onTitleChanged,
    required this.onContentChanged,
    required this.onContentSaved,
    this.entryDate,
    required this.onSetEntryDate,
    required this.onShowReminder,
    required this.onShowTagPicker,
  });

  @override
  ConsumerState<_JournalBody> createState() => _JournalBodyState();
}

class _JournalBodyState extends ConsumerState<_JournalBody> {
  @override
  Widget build(BuildContext context) {
    final propsAsync = ref.watch(itemPropertiesProvider(widget.item.id));
    final props = propsAsync.valueOrNull ?? [];
    final dbContent =
        props.where((p) => p.key == 'content').firstOrNull?.value ?? '';

    // Tags για το body section
    final tagsAsync = ref.watch(itemTagsProvider(widget.item.id));

    return CustomScrollView(
      slivers: [
        // ── Entry date picker ─────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHPadding,
              vertical: Spacing.sm,
            ),
            child: _EntryDatePicker(
              entryDate: widget.entryDate,
              onSetDate: widget.onSetEntryDate,
            ),
          ),
        ),

        // ── Title ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding:
            EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
            child: TextField(
              controller: widget.titleCtrl,
              onChanged: widget.onTitleChanged,
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

        // ── Mood picker ──────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHPadding,
              vertical: Spacing.sm,
            ),
            child: _MoodPicker(itemId: widget.item.id),
          ),
        ),

        // ── Divider ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding:
            EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
            child: Divider(color: ColorsUI.getBorder(context.brightness)),
          ),
        ),

        // ── Content ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding,
              Spacing.md,
              context.responsiveHPadding,
              Spacing.sm,
            ),
            child: ContentFieldWidget(
              initialText: dbContent,
              hintText: 'Γράψε τις σκέψεις σου...',
              style: context.bodyLg,
              onChanged: widget.onContentChanged,
              onSaved: widget.onContentSaved,
              debounce: const Duration(milliseconds: 500),
            ),
          ),
        ),

        // ── Tags section (ίδιο με NoteDetailScreen) ─────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Spacing.lg),
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
                      onPressed: widget.onShowTagPicker,
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
                      await ref.read(tagNotifierProvider.notifier).removeFromItem(widget.item.id, tag.id);
                    },
                    onAdd: widget.onShowTagPicker,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ENTRY DATE PICKER
// ════════════════════════════════════════════════════════════════

class _EntryDatePicker extends StatelessWidget {
  final DateTime? entryDate;
  final ValueChanged<DateTime?> onSetDate;

  const _EntryDatePicker({
    required this.entryDate,
    required this.onSetDate,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = entryDate != null
        ? '${entryDate!.day}/${entryDate!.month}/${entryDate!.year}'
        : 'Επιλογή ημερομηνίας';

    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final initialDate = entryDate ?? now;
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: now,
          locale: const Locale('el', 'GR'),
        );
        if (picked != null) {
          onSetDate(picked);
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 20, color: context.cText2),
              const SizedBox(width: Spacing.sm),
              Text(
                formattedDate,
                style: context.titleMd.copyWith(
                  color: entryDate != null ? context.cText : context.cText2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (entryDate != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => onSetDate(null),
              tooltip: 'Αφαίρεση ημερομηνίας',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MOOD PICKER
// ════════════════════════════════════════════════════════════════

class _MoodPicker extends ConsumerWidget {
  final int itemId;
  const _MoodPicker({required this.itemId});

  static const _moods = [
    ('😊', 'Χαρούμενος/η'),
    ('😐', 'Ουδέτερος/η'),
    ('😔', 'Λυπημένος/η'),
    ('😤', 'Αγχωμένος/η'),
    ('😴', 'Κουρασμένος/η'),
    ('🔥', 'Ενεργητικός/ή'),
    ('🤒', 'Άρρωστος/η'),
    ('🥰', 'Ευγνώμων'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(itemId));
    final props = propsAsync.valueOrNull ?? [];
    final current =
        props.where((p) => p.key == 'mood').firstOrNull?.value ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Διάθεση', style: context.labelMd.withColor(context.cText2)),
        const SizedBox(height: Spacing.xs),
        SizedBox(
          height: 92,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _moods.map((m) {
                final isSelected = current == m.$1;

                return Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: GestureDetector(
                    onTap: () async {
                      DebugConfig.db('Journal mood: ${m.$1} id=$itemId');

                      final newMood = isSelected ? null : m.$1;

                      await ref
                          .read(propertyNotifierProvider(itemId).notifier)
                          .setText('mood', newMood);
                    },
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      width: 72,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.cPrimary.withValues(alpha: 0.12)
                            : ColorsUI.getSurface(context.brightness),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isSelected
                              ? context.cPrimary.withValues(alpha: 0.4)
                              : ColorsUI.getBorder(context.brightness),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m.$1,
                            style: TextStyle(
                              fontSize: isSelected ? 22 : 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: context.labelSm.copyWith(
                              fontSize: 11,
                              color: isSelected
                                  ? context.cPrimary
                                  : context.cText2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// JOURNAL META PANEL — tablet left panel
// ════════════════════════════════════════════════════════════════

class _JournalMetaPanel extends ConsumerWidget {
  final Item item;
  final DateTime? entryDate;
  final VoidCallback onShowTagPicker;

  const _JournalMetaPanel({
    required this.item,
    this.entryDate,
    required this.onShowTagPicker,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final props = propsAsync.valueOrNull ?? [];
    final mood = props.where((p) => p.key == 'mood').firstOrNull?.value ?? '';
    final tagsAsync = ref.watch(itemTagsProvider(item.id));

    return Container(
      color: ColorsUI.getSurface(context.brightness),
      padding: const EdgeInsets.all(Spacing.md),
      child: ListView(
        children: [
          Text('Πληροφορίες', style: context.titleSm),
          const SizedBox(height: Spacing.md),

          _MetaRow(
            icon: Icons.edit_calendar_rounded,
            label: 'Ημερομηνία καταχώρησης',
            value: entryDate != null
                ? '${entryDate!.day}/${entryDate!.month}/${entryDate!.year}'
                : 'μη ορισμένη',
          ),
          if (mood.isNotEmpty) ...[
            const Divider(height: Spacing.xl),
            _MetaRow(icon: Icons.mood_rounded, label: 'Διάθεση', value: mood),
          ],

          const Divider(height: Spacing.xl),

          _MoodPicker(itemId: item.id),

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
          const SizedBox(height: Spacing.sm),
          TextButton.icon(
            onPressed: onShowTagPicker,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Προσθήκη Tag'),
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
  const _MetaRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(children: [
        Icon(icon, size: 15, color: context.cText2),
        const SizedBox(width: Spacing.sm),
        Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.labelSm.withColor(context.cDisabled)),
                Text(value, style: context.bodyMd),
              ],
            )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAG PICKER SHEET (αντιγραφή για αυτονομία)
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
    final tag = await ref.read(tagNotifierProvider.notifier).createOrGet(name.trim());
    if (tag == null || !mounted) return;
    await ref.read(tagNotifierProvider.notifier).addToItem(widget.itemId, tag.id);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final itemTagsAsync = ref.watch(itemTagsProvider(widget.itemId));
    final itemTagIds = itemTagsAsync.valueOrNull?.map((t) => t.id).toSet() ?? {};

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    borderRadius: BorderRadius.circular(2)),
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
                final available = tags.where((t) => !itemTagIds.contains(t.id)).toList();
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
                height:
                MediaQuery.of(context).padding.bottom + Spacing.sm),
          ],
        ),
      ),
    );
  }
}