// lib/features/collections/collection_detail_screen.dart
//
// Δημιουργία/επεξεργασία συλλογής: όνομα, εικονίδιο, χρώμα, πεδία.
// ✅ Save pattern ίδιο με NoteDetailScreen (isNew + manual save)
// ✅ Favorite toggle στο AppBar
// ✅ Dark mode
// ✅ DebugConfig
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'collections_screen.dart' show FieldDef, FieldType;

// Διαθέσιμα χρώματα
const _kColors = [
  '#6366F1', '#8B5CF6', '#EC4899', '#EF4444',
  '#F97316', '#EAB308', '#22C55E', '#14B8A6',
  '#06B6D4', '#3B82F6', '#64748B', '#000000',
];

// Διαθέσιμα εικονίδια
const _kIcons = [
  '📦', '🎵', '📚', '🎬', '🎮', '🍷', '⚽', '🏆',
  '🌍', '💼', '🖼️', '🎨', '🔬', '🍕', '✈️', '🏠',
];

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final int  collectionId;
  final bool isNew;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    this.isNew = false,
  });

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  late final TextEditingController _titleCtrl;

  // Save state
  bool   _isSaving         = false;
  bool   _isEditingTitle   = false;
  String _lastSavedTitle   = '';
  bool   _hasEverBeenSaved = false;

  // Favorite state
  bool _isFavorite = false;

  // Collection state
  List<FieldDef> _fields    = [];
  String         _icon      = '📦';
  String         _color     = '#6366F1';
  bool           _schemaLoaded = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    DebugConfig.nav('CollectionDetail init id=${widget.collectionId} '
        'isNew=${widget.isNew}');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── Save ─────────────────────────────────────────────────────

  void _onTitleChanged(String _) => _isEditingTitle = true;

  Future<void> _save() async {
    if (!mounted) return;
    final title = _titleCtrl.text.trim();

    setState(() => _isSaving = true);
    DebugConfig.db('CollectionDetail save id=${widget.collectionId} '
        'title="$title" fields=${_fields.length}');

    // 1. Τίτλος
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(widget.collectionId,
        title: title.isEmpty ? 'Νέα Συλλογή' : title);

    // 2. Schema (JSON)
    await ref.read(propertyNotifierProvider(widget.collectionId).notifier)
        .setText('schema', FieldDef.listToJson(_fields));

    // 3. Icon + color ως properties
    await ref.read(propertyNotifierProvider(widget.collectionId).notifier)
        .setText('icon', _icon);
    await ref.read(propertyNotifierProvider(widget.collectionId).notifier)
        .setText('color', _color);

    // 4. Ενημέρωσε και το item.icon + item.color αν υπάρχουν
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(widget.collectionId);

    _lastSavedTitle   = title;
    _hasEverBeenSaved = true;
    _isEditingTitle   = false;

    if (!mounted) return;
    setState(() => _isSaving = false);
    ref.invalidate(itemNotifierProvider);
    DebugConfig.db('CollectionDetail saved');
  }

  // ── Favorite toggle ─────────────────────────────────────────

  Future<void> _toggleFavorite() async {
    DebugConfig.provider('CollectionDetail toggleFavorite id=${widget.collectionId}');
    await ref.read(itemNotifierProvider.notifier)
        .toggleFavorite(widget.collectionId, _isFavorite);
    setState(() => _isFavorite = !_isFavorite);
    ref.invalidate(itemNotifierProvider);
  }

  // ── Pop guard ────────────────────────────────────────────────

  Future<bool> _onPopInvoked() async {
    if (widget.isNew && !_hasEverBeenSaved) {
      DebugConfig.db(
          'CollectionDetail auto-delete NEW id=${widget.collectionId}');
      await ref.read(itemNotifierProvider.notifier)
          .deleteItem(widget.collectionId);
      return true;
    }
    return true;
  }

  // ── Fields editing ───────────────────────────────────────────

  void _addField() {
    _showFieldEditor(null, -1);
  }

  void _editField(int index) {
    _showFieldEditor(_fields[index], index);
  }

  void _removeField(int index) {
    setState(() => _fields.removeAt(index));
  }

  void _reorderFields(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final f = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, f);
    });
  }

  void _showFieldEditor(FieldDef? existing, int index) {
    final labelCtrl = TextEditingController(
        text: existing?.label ?? '');
    FieldType selectedType = existing?.type ?? FieldType.text;
    final optionsCtrl = TextEditingController(
        text: existing?.options.join(', ') ?? '');

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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.md,
            left:  Spacing.lg, right: Spacing.lg, top: Spacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Νέο Πεδίο' : 'Επεξεργασία Πεδίου',
                  style: context.titleMd),
              const SizedBox(height: Spacing.md),

              // Label
              TextField(
                controller: labelCtrl,
                autofocus:  true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Όνομα πεδίου',
                  filled:    true,
                  fillColor: ColorsUI.getSurface(context.brightness),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.inputBR,
                    borderSide: BorderSide(
                        color: ColorsUI.getBorder(context.brightness)),
                  ),
                ),
              ),

              const SizedBox(height: Spacing.md),

              // Type
              Text('Τύπος πεδίου',
                  style: context.labelMd.withColor(context.cText2)),
              const SizedBox(height: Spacing.xs),
              Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: FieldType.values.map((t) {
                  final isActive = t == selectedType;
                  return GestureDetector(
                    onTap: () => setModal(() => selectedType = t),
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: Spacing.xs),
                      decoration: BoxDecoration(
                        color: isActive
                            ? context.cPrimary.withValues(alpha: 0.12)
                            : ColorsUI.getSurface(context.brightness),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                        border: Border.all(
                          color: isActive
                              ? context.cPrimary
                              : ColorsUI.getBorder(context.brightness),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FieldDef(key: '', label: '',
                              type: t).icon, size: 14,
                              color: isActive
                                  ? context.cPrimary : context.cText2),
                          const SizedBox(width: 4),
                          Text(FieldDef(key: '', label: '',
                              type: t).typeName,
                              style: context.labelSm.withColor(
                                  isActive ? context.cPrimary
                                      : context.cText2)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Options για select
              if (selectedType == FieldType.select) ...[
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: optionsCtrl,
                  decoration: InputDecoration(
                    labelText: 'Επιλογές (χωρισμένες με κόμμα)',
                    hintText:  'Rock, Jazz, Classical',
                    filled:    true,
                    fillColor: ColorsUI.getSurface(context.brightness),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputBR,
                      borderSide: BorderSide(
                          color: ColorsUI.getBorder(context.brightness)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: Spacing.lg),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Άκυρο'),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final label = labelCtrl.text.trim();
                      if (label.isEmpty) return;
                      final key = label
                          .toLowerCase()
                          .replaceAll(' ', '_')
                          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
                      final options = selectedType == FieldType.select
                          ? optionsCtrl.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList()
                          : <String>[];
                      final field = FieldDef(
                          key:     index >= 0
                              ? _fields[index].key : key,
                          label:   label,
                          type:    selectedType,
                          options: options);
                      setState(() {
                        if (index >= 0) {
                          _fields[index] = field;
                        } else {
                          _fields.add(field);
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Αποθήκευση'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemStreamProvider(widget.collectionId));

    return itemAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.cBg,
        appBar: AppBar(backgroundColor: context.cBg),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: context.cBg,
        appBar: AppBar(backgroundColor: context.cBg),
        body: EmptyState.error(),
      ),
      data: (item) {
        if (item == null) {return Scaffold(
          backgroundColor: context.cBg,
          appBar: AppBar(backgroundColor: context.cBg),
          body: const EmptyState(icon: Icons.inventory_2_rounded,
              title: 'Η συλλογή δεν βρέθηκε'),
        );}

        // Sync title
        if (!_isEditingTitle && _titleCtrl.text != (item.title ?? '')) {
          _titleCtrl.text = item.title ?? '';
          if (_lastSavedTitle.isEmpty && (item.title ?? '').isNotEmpty) {
            _lastSavedTitle = item.title ?? '';
          }
        }

        // Sync favorite state
        if (_isFavorite != item.favorite) {
          _isFavorite = item.favorite;
        }

        // Sync schema από DB (μόνο μια φορά)
        final propsAsync = ref.watch(itemPropertiesProvider(item.id));
        final props      = propsAsync.valueOrNull ?? [];
        if (!_schemaLoaded && props.isNotEmpty) {
          final schema = props.where((p) => p.key == 'schema')
              .firstOrNull?.value ?? '';
          final icon   = props.where((p) => p.key == 'icon')
              .firstOrNull?.value;
          final color  = props.where((p) => p.key == 'color')
              .firstOrNull?.value;
          _fields      = FieldDef.listFromJson(schema);
          if (icon  != null) _icon  = icon;
          if (color != null) _color = color;
          _schemaLoaded = true;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav    = Navigator.of(context);
            final canPop = await _onPopInvoked();
            if (canPop) nav.pop();
          },
          child: Scaffold(
            backgroundColor: context.cBg,
            appBar: _buildAppBar(context, item),
            body: _buildBody(context),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, Item item) => AppBar(
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
      // Save button
      IconButton(
        icon: Icon(Icons.save_rounded, color: context.cPrimary),
        tooltip: 'Αποθήκευση',
        onPressed: () async {
          await _save();
          if(!context.mounted)return;
          if (mounted) Navigator.of(context).pop();
        },
      ),
      // Favorite button
      IconButton(
        icon: Icon(
          _isFavorite
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          color: _isFavorite
              ? ColorsUI.getWarning(context.brightness)
              : context.cText2,
        ),
        onPressed: _toggleFavorite,
        tooltip: _isFavorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
      ),
    ],
  );

  Widget _buildBody(BuildContext context) {
    final accentColor = Color(
        int.parse('FF${_color.replaceAll('#', '')}', radix: 16));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.lg,
        context.responsiveHPadding, 80,
      ),
      children: [
        // ── Icon + Title ────────────────────────────────────
        Row(
          children: [
            // Icon picker
            GestureDetector(
              onTap: () => _pickIcon(context),
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color:        accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Stack(
                  children: [
                    Center(child: Text(_icon,
                        style: const TextStyle(fontSize: 30))),
                    Positioned(
                      right: 2, bottom: 2,
                      child: Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color:  accentColor,
                          shape:  BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded,
                            size: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),

            // Title
            Expanded(
              child: TextField(
                controller: _titleCtrl,
                onChanged:  _onTitleChanged,
                style: context.h2.copyWith(fontWeight: FontWeight.w700),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText:  'Όνομα συλλογής...',
                  hintStyle: context.h2.withColor(context.cDisabled),
                  border:    InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: Spacing.md),

        // ── Color picker ─────────────────────────────────────
        Text('Χρώμα',
            style: context.labelMd.withColor(context.cText2)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: _kColors.map((hex) {
            final c       = Color(int.parse(
                'FF${hex.replaceAll('#', '')}', radix: 16));
            final isActive = _color == hex;
            return GestureDetector(
              onTap: () => setState(() => _color = hex),
              child: AnimatedContainer(
                duration: AppDuration.fast,
                width:  36, height: 36,
                decoration: BoxDecoration(
                  color:  c,
                  shape:  BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? context.cText
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: isActive
                    ? const Icon(Icons.check_rounded, size: 18,
                    color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: Spacing.xl),
        Divider(color: ColorsUI.getBorder(context.brightness)),

        // ── Fields ───────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Πεδία', style: context.titleSm),
            TextButton.icon(
              onPressed: _addField,
              icon:  Icon(Icons.add_rounded, size: 16,
                  color: context.cPrimary),
              label: Text('Προσθήκη',
                  style: context.labelMd.withColor(context.cPrimary)),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),

        if (_fields.isEmpty)
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color:        ColorsUI.getSurface(context.brightness),
              borderRadius: AppRadius.cardBR,
              border: Border.all(
                  color: ColorsUI.getBorder(context.brightness),
                  style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.table_chart_outlined,
                    size: 40, color: context.cDisabled),
                const SizedBox(height: Spacing.sm),
                Text('Δεν υπάρχουν πεδία',
                    style: context.bodyMd.withColor(context.cDisabled)),
                const SizedBox(height: Spacing.xs),
                Text('Πρόσθεσε πεδία για να ορίσεις\n'
                    'τη δομή των εγγραφών σου',
                    style: context.bodySm.withColor(context.cDisabled),
                    textAlign: TextAlign.center),
              ],
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics:    const NeverScrollableScrollPhysics(),
            onReorder:  _reorderFields,
            itemCount:  _fields.length,
            itemBuilder: (_, i) {
              final f = _fields[i];
              return Container(
                key: ValueKey(f.key + i.toString()),
                margin: const EdgeInsets.only(bottom: Spacing.sm),
                decoration: BoxDecoration(
                  color:        ColorsUI.getSurface(context.brightness),
                  borderRadius: AppRadius.cardBR,
                  border: Border.all(
                      color: ColorsUI.getBorder(context.brightness)),
                ),
                child: ListTile(
                  leading: Icon(f.icon, size: 20, color: context.cText2),
                  title:   Text(f.label, style: context.bodyMd),
                  subtitle: Text(f.typeName,
                      style: context.labelSm.withColor(context.cText2)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            size: 18, color: context.cText2),
                        onPressed: () => _editField(i),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 18, color: context.cError),
                        onPressed: () => _removeField(i),
                      ),
                      Icon(Icons.drag_handle_rounded,
                          size: 20, color: context.cDisabled),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _pickIcon(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Επιλογή εικονιδίου', style: context.titleSm),
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.md, runSpacing: Spacing.md,
              children: _kIcons.map((emoji) => GestureDetector(
                onTap: () {
                  setState(() => _icon = emoji);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _icon == emoji
                        ? context.cPrimary.withValues(alpha: 0.12)
                        : ColorsUI.getSurface(context.brightness),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: _icon == emoji
                          ? context.cPrimary
                          : ColorsUI.getBorder(context.brightness),
                    ),
                  ),
                  child: Center(child: Text(emoji,
                      style: const TextStyle(fontSize: 26))),
                ),
              )).toList(),
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}