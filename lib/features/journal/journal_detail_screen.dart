// lib/features/journal/journal_detail_screen.dart
//
// Detail screen ημερολογίου — ακολουθεί τη νέα λογική save:
//   isNew=true  → manual Save button → αν δεν πατηθεί, auto-delete on back
//   isNew=false → Save button αποθηκεύει, back δεν κάνει τίποτα αυτόματα
// ✅ Responsive: single col mobile / two-panel tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
//
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

class _JournalDetailScreenState
    extends ConsumerState<JournalDetailScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  // ── Νέα λογική save (ίδια με NoteDetailScreen) ────────────────
  bool   _isSaving         = false;
  bool   _isEditingTitle   = false;
  bool   _isEditingContent = false;
  String _lastSavedTitle   = '';
  String _lastSavedContent = '';
  bool   _hasEverBeenSaved = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl   = TextEditingController();
    _contentCtrl = TextEditingController();
    DebugConfig.nav(
        'JournalDetailScreen init id=${widget.itemId} isNew=${widget.isNew}');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // ── Title / Content change — local only, χωρίς auto-save ────

  void _onTitleChanged(String value) {
    _isEditingTitle = true;
  }

  void _onContentChanged(String value) {
    _isEditingContent = true;
  }

  // ── Manual save ──────────────────────────────────────────────

  Future<void> _save() async {
    if (!mounted) return;

    final title   = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    // Έλεγχος αν άλλαξε κάτι
    final titleChanged   = title != _lastSavedTitle;
    final contentChanged = content != _lastSavedContent;

    if (!titleChanged && !contentChanged && _hasEverBeenSaved) {
      DebugConfig.db('JournalDetail save: no changes, skip');
      return;
    }

    setState(() => _isSaving = true);
    DebugConfig.db('JournalDetail save id=${widget.itemId} '
        'title="$title"');

    // Αποθήκευση τίτλου
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId,
        title: title.isEmpty ? null : title);

    // Αποθήκευση content ως property
    if (contentChanged) {
      await ref.read(propertyNotifierProvider(widget.itemId).notifier)
          .setText('content', content.isEmpty ? null : content);
    }

    _lastSavedTitle   = title;
    _lastSavedContent = content;
    _hasEverBeenSaved = true;
    _isEditingTitle   = false;
    _isEditingContent = false;

    if (!mounted) return;
    setState(() => _isSaving = false);

    ref.invalidate(itemNotifierProvider);

    DebugConfig.db('JournalDetail saved successfully');
  }

  // ── Pop guard — ίδια λογική με NoteDetailScreen ─────────────

  Future<bool> _onPopInvoked() async {
    // Νέα καταχώρηση χωρίς manual save → auto-delete
    if (widget.isNew && !_hasEverBeenSaved) {
      DebugConfig.db(
          'JournalDetail auto-delete NEW entry id=${widget.itemId}');
      await ref.read(itemNotifierProvider.notifier)
          .deleteItem(widget.itemId);
      return true;
    }

    DebugConfig.nav('JournalDetail back keep id=${widget.itemId}');
    return true;
  }

  // ── Delete ───────────────────────────────────────────────────

  Future<void> _delete(BuildContext context) async {
    final future = ConfirmDialog.delete(context,
        title: 'Διαγραφή καταχώρησης;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('JournalDetail delete id=${widget.itemId}');
    await ref.read(itemNotifierProvider.notifier)
        .deleteItem(widget.itemId);
    if (!mounted) return;
    ref.invalidate(itemNotifierProvider);
    // ignore: use_build_context_synchronously
    Navigator.of(context).pop();
  }

  // ── Toggle favorite ──────────────────────────────────────────

  Future<void> _toggleFav(Item item) async {
    DebugConfig.provider('JournalDetail toggleFav id=${item.id}');
    await ref.read(itemNotifierProvider.notifier)
        .toggleFavorite(item.id, item.favorite);
  }

  // ── Build ────────────────────────────────────────────────────

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

        // Sync τίτλος — μόνο αν ο χρήστης δεν γράφει
        if (!_isEditingTitle) {
          final dbTitle = item.title ?? '';
          if (_titleCtrl.text != dbTitle) {
            _titleCtrl.text = dbTitle;
            _titleCtrl.selection = TextSelection.collapsed(
                offset: _titleCtrl.text.length);
          }
          // Κρατάμε _lastSavedTitle sync με DB
          if (_lastSavedTitle.isEmpty && dbTitle.isNotEmpty) {
            _lastSavedTitle = dbTitle;
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav    = Navigator.of(context);
            final canPop = await _onPopInvoked();
            if (canPop) nav.pop();
          },
          child: ResponsiveLayout(
            mobile: _buildMobile(context, item),
            tablet: _buildTablet(context, item),
          ),
        );
      },
    );
  }

  // ── Mobile ───────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context, Item item) => Scaffold(
    backgroundColor: context.cBg,
    appBar: _buildAppBar(context, item),
    body: _JournalBody(
      item:             item,
      titleCtrl:        _titleCtrl,
      contentCtrl:      _contentCtrl,
      isSaving:         _isSaving,
      onTitleChanged:   _onTitleChanged,
      onContentChanged: _onContentChanged,
    ),
  );

  // ── Tablet ───────────────────────────────────────────────────

  Widget _buildTablet(BuildContext context, Item item) => Scaffold(
    backgroundColor: context.cBg,
    appBar: _buildAppBar(context, item),
    body: Row(
      children: [
        SizedBox(
          width: context.isDesktop ? 280 : 240,
          child: _JournalMetaPanel(item: item),
        ),
        VerticalDivider(
            width: 1, color: ColorsUI.getBorder(context.brightness)),
        Expanded(
          child: _JournalBody(
            item:             item,
            titleCtrl:        _titleCtrl,
            contentCtrl:      _contentCtrl,
            isSaving:         _isSaving,
            onTitleChanged:   _onTitleChanged,
            onContentChanged: _onContentChanged,
          ),
        ),
      ],
    ),
  );

  // ── AppBar ───────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context, Item item) {
    return AppBar(
      backgroundColor:        context.cBg,
      elevation:              0,
      scrolledUnderElevation: 1,
      title: _isSaving
          ? Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: context.cText2),
        ),
        const SizedBox(width: Spacing.xs),
        Text('Αποθήκευση...',
            style: context.bodySm.withColor(context.cText2)),
      ])
          : null,
      actions: [
        // ── Save button — κύρια ενέργεια ─────────────────────
        IconButton(
          icon: Icon(Icons.save_rounded, color: context.cPrimary),
          tooltip: 'Αποθήκευση',
          onPressed: () async {
            DebugConfig.db(
                'JournalDetail manual save pressed id=${widget.itemId}');
            await _save();
            // Αν είναι νέα καταχώρηση, μετά το πρώτο save γύρνα πίσω
            if (widget.isNew && mounted) {
              Navigator.of(context).pop();
            }
          },
        ),

        // ── Favorite ─────────────────────────────────────────
        IconButton(
          icon: Icon(
            item.favorite
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            color: item.favorite
                ? ColorsUI.getWarning(context.brightness)
                : context.cText2,
          ),
          onPressed: () => _toggleFav(item),
          tooltip: item.favorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
        ),

        // ── More ─────────────────────────────────────────────
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: context.cText2),
          onSelected: (v) {
            if (v == 'delete') _delete(context);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded,
                    color: context.cError, size: 18),
                const SizedBox(width: Spacing.sm),
                Text('Διαγραφή',
                    style: TextStyle(color: context.cError)),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  // ── Fallbacks ────────────────────────────────────────────────

  Widget _buildLoading() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildError() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: EmptyState.error(onRetry: () =>
        ref.invalidate(itemStreamProvider(widget.itemId))),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const EmptyState(
      icon:  Icons.auto_stories_rounded,
      title: 'Η καταχώρηση δεν βρέθηκε',
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// JOURNAL BODY — title + mood + content
// ════════════════════════════════════════════════════════════════

class _JournalBody extends ConsumerStatefulWidget {
  final Item item;
  final TextEditingController titleCtrl;
  final TextEditingController contentCtrl;
  final bool isSaving;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onContentChanged;

  const _JournalBody({
    required this.item,
    required this.titleCtrl,
    required this.contentCtrl,
    required this.isSaving,
    required this.onTitleChanged,
    required this.onContentChanged,
  });

  @override
  ConsumerState<_JournalBody> createState() => _JournalBodyState();
}

class _JournalBodyState extends ConsumerState<_JournalBody> {
  bool _contentLoaded = false;

  @override
  Widget build(BuildContext context) {
    final propsAsync = ref.watch(itemPropertiesProvider(widget.item.id));
    final props      = propsAsync.valueOrNull ?? [];
    final dbContent  = props
        .where((p) => p.key == 'content')
        .firstOrNull?.value ?? '';

    // Sync content — μόνο μια φορά αρχικά
    if (!_contentLoaded && dbContent.isNotEmpty) {
      widget.contentCtrl.text = dbContent;
      _contentLoaded = true;
    }

    final date  = widget.item.updatedAt ?? widget.item.createdAt;
    final color = ColorsUI.itemTypeColor(
        ItemType.journal, context.brightness);

    return CustomScrollView(
      slivers: [
        // ── Date badge ───────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.md,
              context.responsiveHPadding, Spacing.xs,
            ),
            child: Row(
              children: [
                Icon(Icons.auto_stories_rounded,
                    size: 16, color: color),
                const SizedBox(width: Spacing.xs),
                Text(date.dateTime,
                    style: context.bodySm.withColor(context.cText2)),
              ],
            ),
          ),
        ),

        // ── Title ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.responsiveHPadding),
            child: TextField(
              controller: widget.titleCtrl,
              onChanged:  widget.onTitleChanged,
              style: context.h2.copyWith(fontWeight: FontWeight.w600),
              maxLines:   null,
              decoration: InputDecoration(
                hintText:  'Τίτλος...',
                hintStyle: context.h2.withColor(context.cDisabled),
                border:    InputBorder.none,
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
              vertical:   Spacing.sm,
            ),
            child: _MoodPicker(itemId: widget.item.id),
          ),
        ),

        // ── Divider ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.responsiveHPadding),
            child: Divider(
                color: ColorsUI.getBorder(context.brightness)),
          ),
        ),

        // ── Content ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.md,
              context.responsiveHPadding, Spacing.sm,
            ),
            child: TextField(
              controller: widget.contentCtrl,
              onChanged:  widget.onContentChanged,
              style:      context.bodyLg,
              maxLines:   null,
              minLines:   10,
              decoration: InputDecoration(
                hintText:  'Γράψε τις σκέψεις σου...',
                hintStyle: context.bodyLg.withColor(context.cDisabled),
                border:    InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MOOD PICKER — emoji επιλογή διάθεσης
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
    final props      = propsAsync.valueOrNull ?? [];
    final current    = props
        .where((p) => p.key == 'mood')
        .firstOrNull?.value ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Διάθεση',
            style: context.labelMd.withColor(context.cText2)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xs,
          children: _moods.map((m) {
            final isSelected = current == m.$1;
            return GestureDetector(
              onTap: () async {
                DebugConfig.db('Journal mood: ${m.$1} id=$itemId');
                // Toggle — αν ίδιο emoji, αφαίρεσε
                final newMood = isSelected ? null : m.$1;
                await ref.read(
                    propertyNotifierProvider(itemId).notifier)
                    .setText('mood', newMood);
              },
              child: Tooltip(
                message: m.$2,
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  padding: const EdgeInsets.all(Spacing.sm),
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
                  child: Text(m.$1,
                      style: TextStyle(
                          fontSize: isSelected ? 22 : 18)),
                ),
              ),
            );
          }).toList(),
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
  const _JournalMetaPanel({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final props      = propsAsync.valueOrNull ?? [];
    final mood       = props.where((p) => p.key == 'mood')
        .firstOrNull?.value ?? '';

    final date = item.updatedAt ?? item.createdAt;

    return Container(
      color: ColorsUI.getSurface(context.brightness),
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Πληροφορίες', style: context.titleSm),
          const SizedBox(height: Spacing.md),

          // Date
          _MetaRow(
            icon:  Icons.calendar_today_rounded,
            label: 'Ημερομηνία',
            value: date.short,
          ),
          _MetaRow(
            icon:  Icons.access_time_rounded,
            label: 'Ώρα',
            value: date.timeOnly,
          ),

          if (mood.isNotEmpty) ...[
            const Divider(height: Spacing.xl),
            _MetaRow(
              icon:  Icons.mood_rounded,
              label: 'Διάθεση',
              value: mood,
            ),
          ],

          const Divider(height: Spacing.xl),

          // Mood picker
          _MoodPicker(itemId: item.id),
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
    required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(children: [
        Icon(icon, size: 15, color: context.cText2),
        const SizedBox(width: Spacing.sm),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: context.labelSm.withColor(context.cDisabled)),
            Text(value, style: context.bodyMd),
          ],
        )),
      ]),
    );
  }
}