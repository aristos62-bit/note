// lib/features/collections/collection_detail_screen.dart
//
// Δημιουργία/επεξεργασία συλλογής: όνομα, εικονίδιο, χρώμα, πεδία.
// ✅ Save pattern ίδιο με NoteDetailScreen (isNew + manual save)
// ✅ Auto‑save στον τίτλο όταν πατάς back (αν υπάρχει τίτλος)
// ✅ Auto‑save και κατά την επεξεργασία (αν υπάρχουν αλλαγές)
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
    extends ConsumerState<CollectionDetailScreen>
    with DetailScreenMixin<CollectionDetailScreen> {
  late final TextEditingController _titleCtrl;

  @override
  TextEditingController get titleCtrl => _titleCtrl;

  // Save state
  bool   _isEditingTitle   = false;
  String _lastSavedTitle   = '';

  // Ανίχνευση αλλαγών για επεξεργασία
  bool   _hasChanges       = false;

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
    initScreen(itemId: widget.collectionId, isNew: widget.isNew);
  }

  @override
  void dispose() {
    disposeScreen();
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── Save ─────────────────────────────────────────────────────

  void _onTitleChanged(String _) {
    _isEditingTitle = true;
    _hasChanges = true;
  }

  Future<void> _saveData() async {
    final title = _titleCtrl.text.trim();
    DebugConfig.db('CollectionDetail save id=${widget.collectionId} title="$title"');

    // 1. ??? + ?�?��? στο Item model (??α να το διαβ?�?ει το card)
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(widget.collectionId,
      title: title.isEmpty ? 'Νέα Συλλογή' : title,
      color: _color,
    );

    // 2. Schema + icon + color παράλληλα
    final notifier = ref.read(
        propertyNotifierProvider(widget.collectionId).notifier);
    final schemaJson = FieldDef.listToJson(_fields);
    DebugConfig.db('CollectionDetail schema=$schemaJson');
    await Future.wait([
      notifier.setText('schema', schemaJson),
      notifier.setText('icon', _icon),
      notifier.setText('color', _color),
    ]);

    _lastSavedTitle = title;
    _isEditingTitle = false;
    _hasChanges     = false;
    DebugConfig.db('CollectionDetail save done');
  }

  /// ??? wrapper ??? executeSave + pop
  Future<void> _save() async {
    final ok = await executeSave(() => _saveData());
    if (ok && mounted) safePop();
  }

  /// ??? logic ??? back arrow (auto-save ?? pop)
  Future<bool> _onPopInvoked() async {
    final title = titleCtrl.text.trim();
    if (title.isEmpty && !widget.isNew) {
      final hasEntries = await _hasCollectionEntries();
      if (!mounted) return true;
      final subtitle = hasEntries
          ? 'Παρακαλώ δώστε τίτλο στη Συλλογή γιατί έχει περιεχόμενο το οποίο θα χαθεί αν συνεχίσετε.'
          : 'Η Συλλογή δεν έχει τίτλο. Αν συνεχίσετε θα διαγραφεί.';
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Η Συλλογή δεν έχει τίτλο',
        subtitle: subtitle,
        confirmLabel: 'Συνέχεια',
        cancelLabel: 'Ακυρο',
        icon: Icons.warning_rounded,
        isDestructive: true,
      );
      if (!confirmed || !mounted) return true;
      if (hasEntries) await _deleteCollectionEntries();
      await ref.read(itemNotifierProvider.notifier).deleteItem(widget.collectionId);
      return true;
    }
    await executeSaveOrDelete(
      saveFn: () async {
        if (_hasChanges) {
          await _saveData();
        } else {
          DebugConfig.db('CollectionDetail no changes, skip save');
        }
      },
      deleteFn: () => ref.read(itemNotifierProvider.notifier).deleteItem(widget.collectionId),
    );
    return true;
  }

  Future<bool> _hasCollectionEntries() async {
    final allItems = ref.read(itemsStreamProvider).valueOrNull ?? [];
    for (final entry in allItems.where((i) => i.type == ItemType.knowledge)) {
      final props = await ref.read(itemPropertiesProvider(entry.id).future);
      final colId = props.where((p) => p.key == 'collection_id').firstOrNull?.value;
      if (colId == widget.collectionId.toString()) return true;
    }
    return false;
  }

  Future<void> _deleteCollectionEntries() async {
    final allItems = ref.read(itemsStreamProvider).valueOrNull ?? [];
    for (final entry in allItems.where((i) => i.type == ItemType.knowledge)) {
      final props = await ref.read(itemPropertiesProvider(entry.id).future);
      final colId = props.where((p) => p.key == 'collection_id').firstOrNull?.value;
      if (colId == widget.collectionId.toString()) {
        await ref.read(itemNotifierProvider.notifier).deleteItem(entry.id);
      }
    }
  }

  // ── Favorite toggle ─────────────────────────────────────────

  Future<void> _toggleFavorite() async {
    DebugConfig.provider('CollectionDetail toggleFavorite id=${widget.collectionId}');
    await ref.read(itemNotifierProvider.notifier)
        .toggleFavorite(widget.collectionId, _isFavorite);
    setState(() => _isFavorite = !_isFavorite);
  }

  // ── Fields editing ───────────────────────────────────────────

  void _addField() {
    _showFieldEditor(null, -1);
    _hasChanges = true;
  }

  void _editField(int index) {
    _showFieldEditor(_fields[index], index);
    _hasChanges = true;
  }

  void _removeField(int index) {
    setState(() => _fields.removeAt(index));
    _hasChanges = true;
  }

  void _reorderFields(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final f = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, f);
    });
    _hasChanges = true;
  }

  void _showFieldEditor(FieldDef? existing, int index) {
    final labelCtrl = TextEditingController(
        text: existing?.label ?? '');
    FieldType selectedType = existing?.type ?? FieldType.text;
    final optionsCtrl = TextEditingController(
        text: existing?.options.join(', ') ?? '');
    final extensionsCtrl = TextEditingController(
        text: existing?.allowedExtensions.join(', ') ?? '');
    final maxFilesCtrl = TextEditingController(
        text: (existing?.maxFiles ?? 0) > 0 ? existing!.maxFiles.toString() : '');
    final activePresets = <String>{};
    final extList = existing?.allowedExtensions ?? [];
    if (extList.isNotEmpty &&
        FieldDef.imagesExt.every((e) => extList.contains(e))) {
      activePresets.add('Εικόνες');
    }
    if (extList.isNotEmpty &&
        FieldDef.documentsExt.every((e) => extList.contains(e))) {
      activePresets.add('Έγγραφα');
    }

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

              // Options for select
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

              // Extensions for attachment
              if (selectedType == FieldType.attachment) ...[
                const SizedBox(height: Spacing.md),
                Text('Επιτρεπόμενοι τύποι αρχείων',
                    style: context.labelMd.withColor(context.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.xs,
                  children: [
                    FilterChip(
                      label: const Text('Εικόνες'),
                      selected: activePresets.contains('Εικόνες'),
                      onSelected: (sel) {
                        _togglePresetExts(
                          sel, 'Εικόνες', FieldDef.imagesExt,
                          activePresets, extensionsCtrl);
                        setModal(() {});
                      },
                    ),
                    FilterChip(
                      label: const Text('Έγγραφα'),
                      selected: activePresets.contains('Έγγραφα'),
                      onSelected: (sel) {
                        _togglePresetExts(
                          sel, 'Έγγραφα', FieldDef.documentsExt,
                          activePresets, extensionsCtrl);
                        setModal(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                TextField(
                  controller: extensionsCtrl,
                  decoration: InputDecoration(
                    labelText: 'Επεκτάσεις (χωρισμένες με κόμμα)',
                    hintText:  'κενό = όλοι οι τύποι',
                    filled:    true,
                    fillColor: ColorsUI.getSurface(context.brightness),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputBR,
                      borderSide: BorderSide(
                          color: ColorsUI.getBorder(context.brightness)),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                TextField(
                  controller: maxFilesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Μέγιστος αριθμός αρχείων',
                    hintText: '1 έως 10',
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
                      String key = label
                          .toLowerCase()
                          .replaceAll(' ', '_')
                          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
                      if (key.isEmpty) key = 'field_${DateTime.now().millisecondsSinceEpoch}';
                      // Avoid duplicate keys
                      while (_fields.any((f) => f.key == key)) {
                        key = '${key}_${DateTime.now().millisecondsSinceEpoch}';
                      }
                      final options = selectedType == FieldType.select
                          ? optionsCtrl.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList()
                          : <String>[];
                      final extensions = selectedType == FieldType.attachment
                          ? extensionsCtrl.text
                          .split(',')
                          .map((s) => s.trim().toLowerCase())
                          .where((s) => s.isNotEmpty)
                          .toList()
                          : <String>[];
                      final maxFiles = selectedType == FieldType.attachment
                          ? (int.tryParse(maxFilesCtrl.text.trim()) ?? 1).clamp(1, 10)
                          : 0;
                      if (selectedType == FieldType.attachment) {
                        DebugConfig.db('maxFiles: "${maxFilesCtrl.text}" clamped → $maxFiles');
                      }
                      final field = FieldDef(
                          key:     index >= 0
                              ? _fields[index].key : key,
                          label:   label,
                          type:    selectedType,
                          options: options,
                          allowedExtensions: extensions,
                          maxFiles: maxFiles);
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

        // Sync schema from DB only once
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
          // Reset changes flag after loading existing data
          _hasChanges = false;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _onPopInvoked();
            if (mounted) safePop();
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
    title: null,
    actions: [
      // Save button
      IconButton(
        icon: Icon(Icons.save_rounded, color: context.cPrimary),
        tooltip: 'Αποθήκευση',
        onPressed: _save,
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
              onTap: () {
                setState(() => _color = hex);
                _hasChanges = true;
              },
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
            onReorderItem:  _reorderFields,
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

  void _togglePresetExts(
    bool selected,
    String presetName,
    List<String> extList,
    Set<String> activePresets,
    TextEditingController ctrl,
  ) {
    final current = ctrl.text
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (selected) {
      activePresets.add(presetName);
      for (final ext in extList) {
        if (!ext.startsWith('.')) {
          current.add(ext);
        }
      }
    } else {
      activePresets.remove(presetName);
      for (final ext in extList) {
        current.remove(ext.startsWith('.') ? ext.substring(1) : ext);
      }
    }
    ctrl.text = (current.toList()..sort()).join(', ');
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
                  setState(() {
                    _icon = emoji;
                    _hasChanges = true;
                  });
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