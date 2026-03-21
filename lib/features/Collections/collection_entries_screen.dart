// lib/features/collections/collection_entries_screen.dart
//
// Λίστα εγγραφών μιας συλλογής + detail screen εγγραφής.
// Εγγραφές = Item με ItemType.knowledge + property 'collection_id'.
// ✅ Dark mode
// ✅ DebugConfig
// ✅ Save pattern ίδιο με NoteDetailScreen
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'collections_screen.dart' show FieldDef, FieldType;

// ════════════════════════════════════════════════════════════════
// COLLECTION ENTRIES SCREEN
// ════════════════════════════════════════════════════════════════

class CollectionEntriesScreen extends ConsumerWidget {
  final Item collection;
  const CollectionEntriesScreen({super.key, required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    DebugConfig.provider('CollectionEntriesScreen build '
        'collectionId=${collection.id}');

    final allAsync   = ref.watch(itemsStreamProvider);
    final propsAsync = ref.watch(itemPropertiesProvider(collection.id));
    final schema     = propsAsync.valueOrNull
        ?.where((p) => p.key == 'schema')
        .firstOrNull?.value ?? '';
    final fields     = FieldDef.listFromJson(schema);

    final accentColor = _colorFromItem(collection);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor:        context.cBg,
        elevation:              0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Text(collection.icon ?? '📦',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: Spacing.sm),
            Text(collection.title ?? 'Συλλογή',
                style: context.titleMd),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createEntry(context, ref, fields),
        tooltip: 'Νέα εγγραφή',
        child: const Icon(Icons.add_rounded),
      ),
      body: allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => EmptyState.error(),
        data:    (allItems) {
          return _EntriesList(
            collectionId: collection.id,
            fields:       fields,
            accentColor:  accentColor,
            onCreateEntry: () => _createEntry(context, ref, fields),
          );
        },
      ),
    );
  }

  Future<void> _createEntry(BuildContext context, WidgetRef ref,
      List<FieldDef> fields) async {
    DebugConfig.nav('CollectionEntries: createEntry '
        'collectionId=${collection.id}');
    final item = await ref.read(itemNotifierProvider.notifier)
        .create(type: ItemType.knowledge);
    if (item == null || !context.mounted) return;

    // Σύνδεση με τη συλλογή
    await ref.read(propertyNotifierProvider(item.id).notifier)
        .setText('collection_id', collection.id.toString());

    ref.invalidate(itemNotifierProvider);
    // ignore: use_build_context_synchronously
    Navigator.of(context).push(AppTransitions.slideRoute(
        CollectionEntryDetailScreen(
          entryId:      item.id,
          collectionId: collection.id,
          fields:       fields,
          isNew:        true,
        )));
  }

  static Color _colorFromItem(Item item) {
    final hex = item.color;
    if (hex == null || hex.isEmpty) return const Color(0xFF6366F1);
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) { return const Color(0xFF6366F1); }
  }
}

// ════════════════════════════════════════════════════════════════
// ENTRIES LIST — φορτώνει μόνο entries αυτής της συλλογής
// ════════════════════════════════════════════════════════════════

class _EntriesList extends ConsumerWidget {
  final int collectionId;
  final List<FieldDef> fields;
  final Color accentColor;
  final VoidCallback onCreateEntry;

  const _EntriesList({
    required this.collectionId,
    required this.fields,
    required this.accentColor,
    required this.onCreateEntry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(itemsStreamProvider);
    final allItems = allAsync.valueOrNull ?? [];

    // Βρες entries αυτής της συλλογής
    // Δυστυχώς δεν μπορούμε να κάνουμε query by property εύκολα,
    // οπότε φιλτράρουμε στο UI
    final candidates = allItems
        .where((i) => i.type == ItemType.knowledge)
        .toList();

    return _FilteredEntriesList(
      candidates:   candidates,
      collectionId: collectionId,
      fields:       fields,
      accentColor:  accentColor,
      onCreateEntry: onCreateEntry,
    );
  }
}

class _FilteredEntriesList extends ConsumerWidget {
  final List<Item> candidates;
  final int collectionId;
  final List<FieldDef> fields;
  final Color accentColor;
  final VoidCallback onCreateEntry;

  const _FilteredEntriesList({
    required this.candidates,
    required this.collectionId,
    required this.fields,
    required this.accentColor,
    required this.onCreateEntry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Για κάθε candidate, ελέγχουμε αν έχει collection_id = collectionId
    final entries = <Item>[];
    for (final c in candidates) {
      final props = ref.watch(itemPropertiesProvider(c.id)).valueOrNull ?? [];
      final colId = props.where((p) => p.key == 'collection_id')
          .firstOrNull?.value;
      if (colId == collectionId.toString()) entries.add(c);
    }

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: context.responsivePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_rounded, size: 64, color: context.cDisabled),
              const SizedBox(height: Spacing.md),
              Text('Δεν υπάρχουν εγγραφές', style: context.titleMd),
              const SizedBox(height: Spacing.sm),
              Text('Πάτησε + για να προσθέσεις\nτην πρώτη εγγραφή',
                  style: context.bodyMd.withColor(context.cText2),
                  textAlign: TextAlign.center),
              const SizedBox(height: Spacing.xl),
              FilledButton.icon(
                onPressed: onCreateEntry,
                icon:  const Icon(Icons.add_rounded),
                label: const Text('Νέα εγγραφή'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical:   Spacing.sm,
      ),
      itemCount:        entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, i) => _EntryCard(
        entry:        entries[i],
        fields:       fields,
        accentColor:  accentColor,
        onTap: () => Navigator.of(context).push(AppTransitions.slideRoute(
            CollectionEntryDetailScreen(
              entryId:      entries[i].id,
              collectionId: collectionId,
              fields:       fields,
              isNew:        false,
            ))),
        onDelete: () async {
          final future = ConfirmDialog.delete(context,
              title: 'Διαγραφή εγγραφής;');
          final ok = await future;
          if (!ok || !context.mounted) return;
          await ref.read(itemNotifierProvider.notifier)
              .deleteItem(entries[i].id);
          ref.invalidate(itemNotifierProvider);
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ENTRY CARD
// ════════════════════════════════════════════════════════════════

class _EntryCard extends ConsumerWidget {
  final Item entry;
  final List<FieldDef> fields;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EntryCard({
    required this.entry,
    required this.fields,
    required this.accentColor,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(entry.id));
    final props      = propsAsync.valueOrNull ?? [];

    // Παίρνουμε τιμές για τα πρώτα 2-3 πεδία για preview
    final previewFields = fields.take(3).toList();

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color:        ColorsUI.getSurface(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(
              color: ColorsUI.getBorder(context.brightness)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Τίτλος
            Text(
              entry.title?.isNotEmpty == true
                  ? entry.title!
                  : '(χωρίς τίτλο)',
              style: context.titleSm.copyWith(
                color: entry.title?.isNotEmpty == true
                    ? context.cText : context.cDisabled,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            if (previewFields.isNotEmpty) ...[
              const SizedBox(height: Spacing.xs),
              ...previewFields.map((f) {
                final val = props.where((p) => p.key == f.key)
                    .firstOrNull?.value ?? '';
                if (val.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Icon(f.icon, size: 12, color: context.cText2),
                    const SizedBox(width: 4),
                    Text('${f.label}: ',
                        style: context.labelSm.withColor(context.cText2)),
                    Expanded(
                      child: Text(val,
                          style: context.labelSm,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        context.cBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title:   const Text('Επεξεργασία'),
              onTap: () { Navigator.pop(context); onTap(); },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: context.cError),
              title: Text('Διαγραφή',
                  style: TextStyle(color: context.cError)),
              onTap: () { Navigator.pop(context); onDelete(); },
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COLLECTION ENTRY DETAIL SCREEN
// ════════════════════════════════════════════════════════════════

class CollectionEntryDetailScreen extends ConsumerStatefulWidget {
  final int entryId;
  final int collectionId;
  final List<FieldDef> fields;
  final bool isNew;

  const CollectionEntryDetailScreen({
    super.key,
    required this.entryId,
    required this.collectionId,
    required this.fields,
    this.isNew = false,
  });

  @override
  ConsumerState<CollectionEntryDetailScreen> createState() =>
      _CollectionEntryDetailScreenState();
}

class _CollectionEntryDetailScreenState
    extends ConsumerState<CollectionEntryDetailScreen> {
  late final TextEditingController _titleCtrl;
  final Map<String, TextEditingController> _fieldCtrls = {};

  bool   _isSaving         = false;
  bool   _isEditingTitle   = false;
  String _lastSavedTitle   = '';
  bool   _hasEverBeenSaved = false;
  bool   _propsLoaded      = false;

  // State για toggle και date fields
  final Map<String, bool>     _boolValues = {};
  final Map<String, DateTime?> _dateValues = {};

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    for (final f in widget.fields) {
      if (f.type != FieldType.toggle && f.type != FieldType.date) {
        _fieldCtrls[f.key] = TextEditingController();
      }
    }
    DebugConfig.nav('EntryDetail init id=${widget.entryId} '
        'isNew=${widget.isNew}');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTitleChanged(String _) => _isEditingTitle = true;

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final title = _titleCtrl.text.trim();
    DebugConfig.db('EntryDetail save id=${widget.entryId}');

    // Τίτλος
    await ref.read(itemNotifierProvider.notifier)
        .updateItem(widget.entryId,
        title: title.isEmpty ? null : title);

    // Field values
    final notifier =
    ref.read(propertyNotifierProvider(widget.entryId).notifier);

    for (final f in widget.fields) {
      switch (f.type) {
        case FieldType.toggle:
          await notifier.setText(f.key,
              (_boolValues[f.key] ?? false) ? 'true' : 'false');
        case FieldType.date:
          await notifier.setDate(f.key, _dateValues[f.key]);
        default:
          final val = _fieldCtrls[f.key]?.text.trim() ?? '';
          await notifier.setText(f.key, val.isEmpty ? null : val);
      }
    }

    _lastSavedTitle   = title;
    _hasEverBeenSaved = true;
    _isEditingTitle   = false;

    if (!mounted) return;
    setState(() => _isSaving = false);
    ref.invalidate(itemNotifierProvider);
  }

  Future<bool> _onPopInvoked() async {
    if (widget.isNew && !_hasEverBeenSaved) {
      await ref.read(itemNotifierProvider.notifier)
          .deleteItem(widget.entryId);
      return true;
    }
    return true;
  }

  void _loadProps(List<ItemProperty> props) {
    if (_propsLoaded) return;
    for (final f in widget.fields) {
      final val = props.where((p) => p.key == f.key)
          .firstOrNull?.value ?? '';
      switch (f.type) {
        case FieldType.toggle:
          _boolValues[f.key] = val == 'true';
        case FieldType.date:
          _dateValues[f.key] = val.isNotEmpty
              ? DateTime.tryParse(val) : null;
        default:
          if (_fieldCtrls[f.key]?.text.isEmpty == true && val.isNotEmpty) {
            _fieldCtrls[f.key]?.text = val;
          }
      }
    }
    _propsLoaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync  = ref.watch(itemStreamProvider(widget.entryId));
    final propsAsync = ref.watch(itemPropertiesProvider(widget.entryId));

    if (propsAsync.valueOrNull != null) {
      _loadProps(propsAsync.valueOrNull!);
    }

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
        if (item == null) {
          return Scaffold(
            backgroundColor: context.cBg,
            appBar: AppBar(backgroundColor: context.cBg),
          );
        }

        if (!_isEditingTitle && _titleCtrl.text != (item.title ?? '')) {
          _titleCtrl.text = item.title ?? '';
          if (_lastSavedTitle.isEmpty && (item.title ?? '').isNotEmpty) {
            _lastSavedTitle = item.title ?? '';
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
          child: Scaffold(
            backgroundColor: context.cBg,
            appBar: AppBar(
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
                IconButton(
                  icon: Icon(Icons.save_rounded, color: context.cPrimary),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await _save();
                    if (widget.isNew && mounted) {
                      nav.pop();
                    }
                  },
                ),
              ],
            ),
            body: ListView(
              padding: EdgeInsets.fromLTRB(
                context.responsiveHPadding, Spacing.lg,
                context.responsiveHPadding, 80,
              ),
              children: [
                // Τίτλος
                TextField(
                  controller: _titleCtrl,
                  onChanged:  _onTitleChanged,
                  style: context.h2.copyWith(fontWeight: FontWeight.w600),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText:  'Τίτλος εγγραφής...',
                    hintStyle: context.h2.withColor(context.cDisabled),
                    border:    InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),

                Divider(color: ColorsUI.getBorder(context.brightness)),
                const SizedBox(height: Spacing.sm),

                // Dynamic fields
                ...widget.fields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: _FieldInput(
                    field:      f,
                    ctrl:       _fieldCtrls[f.key],
                    boolValue:  _boolValues[f.key] ?? false,
                    dateValue:  _dateValues[f.key],
                    onBoolChange: (v) => setState(
                            () => _boolValues[f.key] = v),
                    onDateChange: (v) => setState(
                            () => _dateValues[f.key] = v),
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FIELD INPUT — dynamic field renderer
// ════════════════════════════════════════════════════════════════

class _FieldInput extends StatelessWidget {
  final FieldDef field;
  final TextEditingController? ctrl;
  final bool boolValue;
  final DateTime? dateValue;
  final ValueChanged<bool> onBoolChange;
  final ValueChanged<DateTime?> onDateChange;

  const _FieldInput({
    required this.field,
    this.ctrl,
    required this.boolValue,
    required this.dateValue,
    required this.onBoolChange,
    required this.onDateChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(children: [
          Icon(field.icon, size: 14, color: context.cText2),
          const SizedBox(width: Spacing.xs),
          Text(field.label,
              style: context.labelMd.withColor(context.cText2)),
        ]),
        const SizedBox(height: Spacing.xs),

        // Input
        switch (field.type) {
          FieldType.toggle => SwitchListTile(
            value:           boolValue,
            onChanged:       onBoolChange,
            activeThumbColor: context.cPrimary,
            title:           Text(boolValue ? 'Ναι' : 'Όχι',
                style: context.bodyMd),
            contentPadding: EdgeInsets.zero,
          ),

          FieldType.date => GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context:     context,
                initialDate: dateValue ?? now,
                firstDate:   DateTime(1900),
                lastDate:    DateTime(now.year + 20),
                locale:      const Locale('el'),
              );
              if (picked != null) onDateChange(picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm + 4),
              decoration: BoxDecoration(
                color:        ColorsUI.getSurface(context.brightness),
                borderRadius: AppRadius.inputBR,
                border: Border.all(
                    color: ColorsUI.getBorder(context.brightness)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    dateValue != null
                        ? dateValue!.short
                        : 'Επιλογή ημερομηνίας',
                    style: context.bodyMd.withColor(
                        dateValue != null
                            ? context.cText : context.cDisabled),
                  ),
                ),
                if (dateValue != null)
                  GestureDetector(
                    onTap: () => onDateChange(null),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: context.cText2),
                  ),
              ]),
            ),
          ),

          FieldType.select => _SelectField(
            field: field,
            ctrl:  ctrl,
          ),

          _ => TextField(
            controller:   ctrl,
            keyboardType: field.type == FieldType.number
                ? TextInputType.number
                : field.type == FieldType.url
                ? TextInputType.url
                : TextInputType.text,
            maxLines:     field.type == FieldType.text ? null : 1,
            minLines:     1,
            style:        context.bodyMd,
            decoration: InputDecoration(
              hintText:  'Εισαγωγή ${field.label.toLowerCase()}...',
              hintStyle: context.bodyMd.withColor(context.cDisabled),
              filled:    true,
              fillColor: ColorsUI.getSurface(context.brightness),
              border: OutlineInputBorder(
                borderRadius: AppRadius.inputBR,
                borderSide: BorderSide(
                    color: ColorsUI.getBorder(context.brightness)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputBR,
                borderSide: BorderSide(
                    color: ColorsUI.getBorder(context.brightness)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputBR,
                borderSide: BorderSide(
                    color: context.cPrimary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm),
            ),
          ),
        },
      ],
    );
  }
}

class _SelectField extends StatefulWidget {
  final FieldDef field;
  final TextEditingController? ctrl;
  const _SelectField({required this.field, this.ctrl});

  @override
  State<_SelectField> createState() => _SelectFieldState();
}

class _SelectFieldState extends State<_SelectField> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.ctrl?.text;
    widget.ctrl?.addListener(() {
      if (mounted) setState(() => _selected = widget.ctrl?.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: widget.field.options.map((opt) {
        final isActive = _selected == opt;
        return GestureDetector(
          onTap: () {
            setState(() => _selected = isActive ? null : opt);
            widget.ctrl?.text = isActive ? '' : opt;
          },
          child: AnimatedContainer(
            duration: AppDuration.fast,
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm + 2, vertical: Spacing.xs + 2),
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
            child: Text(opt,
                style: context.bodyMd.withColor(
                    isActive ? context.cPrimary : context.cText)),
          ),
        );
      }).toList(),
    );
  }
}