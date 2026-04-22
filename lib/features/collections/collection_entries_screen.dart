// lib/features/collections/collection_entries_screen.dart
//
// Λίστα εγγραφών μιας συλλογής + detail screen εγγραφής.
// Εγγραφές = Item με ItemType.knowledge + property 'collection_id'.
// ✅ Dark mode
// ✅ DebugConfig
// ✅ Save pattern ίδιο με NoteDetailScreen
// ✅ Υποστήριξη bulletList και numberedList (δυναμικές λίστες)
// ✅ Πολυγραμμικό κείμενο για πεδίο text
// ✅ Χρήση ItemColorHelper για background & contrast
// ✅ ViewMode toggle (pinned/favorites/all) για φιλτράρισμα εγγραφών
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import '../../helpers/item_color_helper.dart';
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

    final allAsync = ref.watch(itemsStreamProvider);
    final propsAsync = ref.watch(itemPropertiesProvider(collection.id));
    final schema = propsAsync.valueOrNull
        ?.where((p) => p.key == 'schema')
        .firstOrNull
        ?.value ??
        '';
    final fields = FieldDef.listFromJson(schema);

    final accentColor = _colorFromItem(collection);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Text(collection.icon ?? '📦', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: Spacing.sm),
            Text(collection.title ?? 'Συλλογή', style: context.titleMd),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createEntry(context, ref, fields),
        tooltip: 'Νέα εγγραφή',
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // View mode toggle (pinned/favorites/all)
          const ViewModeToggle(),
          Expanded(
            child: allAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState.error(),
              data: (allItems) {
                return _EntriesList(
                  collectionId: collection.id,
                  fields: fields,
                  accentColor: accentColor,
                  onCreateEntry: () => _createEntry(context, ref, fields),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createEntry(
      BuildContext context, WidgetRef ref, List<FieldDef> fields) async {
    DebugConfig.nav('CollectionEntries: createEntry '
        'collectionId=${collection.id}');
    final item = await ref
        .read(itemNotifierProvider.notifier)
        .create(type: ItemType.knowledge);
    if (item == null || !context.mounted) return;

    // Σύνδεση με τη συλλογή
    await ref
        .read(propertyNotifierProvider(item.id).notifier)
        .setText('collection_id', collection.id.toString());

    ref.invalidate(itemNotifierProvider);
    // ignore: use_build_context_synchronously
    Navigator.of(context)
        .push(AppTransitions.slideRoute(CollectionEntryDetailScreen(
      entryId: item.id,
      collectionId: collection.id,
      fields: fields,
      isNew: true,
    )));
  }

  static Color _colorFromItem(Item item) {
    final hex = item.color;
    if (hex == null || hex.isEmpty) return const Color(0xFF6366F1);
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
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

    final candidates =
    allItems.where((i) => i.type == ItemType.knowledge).toList();

    return _FilteredEntriesList(
      candidates: candidates,
      collectionId: collectionId,
      fields: fields,
      accentColor: accentColor,
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
    // Αρχικά φιλτράρουμε όλες τις εγγραφές της συλλογής
    final allEntries = <Item>[];
    for (final c in candidates) {
      final props = ref.watch(itemPropertiesProvider(c.id)).valueOrNull ?? [];
      final colId =
          props.where((p) => p.key == 'collection_id').firstOrNull?.value;
      if (colId == collectionId.toString()) allEntries.add(c);
    }

    // 🔹 Φιλτράρισμα view mode (pinned / favorites / all)
    final viewMode = ref.watch(listViewModeProvider);
    var entries = allEntries;
    switch (viewMode) {
      case ListViewMode.pinned:
        entries = entries.where((e) => e.pinned).toList();
        break;
      case ListViewMode.favorites:
        entries = entries.where((e) => e.favorite).toList();
        break;
      case ListViewMode.all:
        break;
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
                icon: const Icon(Icons.add_rounded),
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
        vertical: Spacing.sm,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, i) => _EntryCard(
        entry: entries[i],
        fields: fields,
        accentColor: accentColor,
        onTap: () => Navigator.of(context)
            .push(AppTransitions.slideRoute(CollectionEntryDetailScreen(
          entryId: entries[i].id,
          collectionId: collectionId,
          fields: fields,
          isNew: false,
        ))),
        onDelete: () async {
          final future =
          ConfirmDialog.delete(context, title: 'Διαγραφή εγγραφής;');
          final ok = await future;
          if (!ok || !context.mounted) return;
          await ref
              .read(itemNotifierProvider.notifier)
              .deleteItem(entries[i].id);
          ref.invalidate(itemNotifierProvider);
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ENTRY CARD — με χρήση ItemColorHelper (ίδιο)
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
    final props = propsAsync.valueOrNull ?? [];

    final previewFields = fields.take(3).toList();

    final backgroundColor =
    ItemColorHelper.backgroundColorForType(ItemType.knowledge, context);
    final foregroundColor =
    ItemColorHelper.textColorForBackground(backgroundColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha:0.7);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.cardBR,
          border: Border.all(color: ColorsUI.getBorder(context.brightness)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges row
            Row(
              children: [
                if (entry.pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin_rounded,
                        size: 12, color: context.cPrimary),
                  ),
                if (entry.favorite)
                  Icon(Icons.star_rounded,
                      size: 12, color: ColorsUI.getWarning(context.brightness)),
              ],
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              entry.title?.isNotEmpty == true
                  ? entry.title!
                  : '(χωρίς τίτλο)',
              style: context.titleSm.copyWith(
                color: entry.title?.isNotEmpty == true
                    ? foregroundColor
                    : secondaryForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (previewFields.isNotEmpty) ...[
              const SizedBox(height: Spacing.xs),
              ...previewFields.map((f) {
                String val = '';
                if (f.type == FieldType.bulletList ||
                    f.type == FieldType.numberedList) {
                  final listJson =
                      props.where((p) => p.key == f.key).firstOrNull?.value ??
                          '';
                  if (listJson.isNotEmpty) {
                    try {
                      final list = jsonDecode(listJson) as List;
                      if (list.isNotEmpty) val = '${list.length} στοιχεία';
                    } catch (_) {}
                  }
                } else {
                  val = props.where((p) => p.key == f.key).firstOrNull?.value ??
                      '';
                }
                if (val.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Icon(f.icon, size: 12, color: secondaryForeground),
                    const SizedBox(width: 4),
                    Text('${f.label}: ',
                        style: context.labelSm.copyWith(color: secondaryForeground)),
                    Expanded(
                      child: Text(val,
                          style: context.labelSm.copyWith(color: foregroundColor),
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
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.cBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Επεξεργασία'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
            ListTile(
              leading:
              Icon(Icons.delete_outline_rounded, color: context.cError),
              title: Text('Διαγραφή', style: TextStyle(color: context.cError)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COLLECTION ENTRY DETAIL SCREEN (unchanged)
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
  final Map<String, List<String>> _listValues = {};

  bool _isSaving = false;
  bool _isEditingTitle = false;
  String _lastSavedTitle = '';
  bool _hasEverBeenSaved = false;
  bool _propsLoaded = false;
  bool _isFavorite = false;
  bool _isPinned = false;

  final Map<String, bool> _boolValues = {};
  final Map<String, DateTime?> _dateValues = {};

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    for (final f in widget.fields) {
      if (f.type == FieldType.bulletList || f.type == FieldType.numberedList) {
        _listValues[f.key] = [];
      } else if (f.type != FieldType.toggle && f.type != FieldType.date) {
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

  void _addListItem(String key) {
    setState(() {
      _listValues.putIfAbsent(key, () => []);
      _listValues[key]!.add('');
    });
  }

  void _removeListItem(String key, int index) {
    setState(() {
      if (_listValues[key] != null && index < _listValues[key]!.length) {
        _listValues[key]!.removeAt(index);
      }
    });
  }

  void _updateListItem(String key, int index, String value) {
    setState(() {
      if (_listValues[key] != null && index < _listValues[key]!.length) {
        _listValues[key]![index] = value;
      }
    });
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final title = _titleCtrl.text.trim();
    DebugConfig.db('EntryDetail save id=${widget.entryId}');

    await ref
        .read(itemNotifierProvider.notifier)
        .updateItem(widget.entryId, title: title.isEmpty ? null : title);

    final notifier =
    ref.read(propertyNotifierProvider(widget.entryId).notifier);

    for (final f in widget.fields) {
      if (f.key.isEmpty) continue;
      switch (f.type) {
        case FieldType.toggle:
          await notifier.setText(
              f.key, (_boolValues[f.key] ?? false) ? 'true' : 'false');
        case FieldType.date:
          await notifier.setDate(f.key, _dateValues[f.key]);
        case FieldType.bulletList:
        case FieldType.numberedList:
          final list = _listValues[f.key] ?? [];
          final json = jsonEncode(list);
          DebugConfig.db('💾 Saving ${f.key} (${f.type}): $json');
          await notifier.setText(f.key, json);
          break;
        default:
          final val = _fieldCtrls[f.key]?.text.trim() ?? '';
          await notifier.setText(f.key, val.isEmpty ? null : val);
      }
    }

    _lastSavedTitle = title;
    _hasEverBeenSaved = true;
    _isEditingTitle = false;

    if (!context.mounted) return;
    setState(() => _isSaving = false);
    ref.invalidate(itemNotifierProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggleFavorite() async {
    await ref.read(itemNotifierProvider.notifier)
        .toggleFavorite(widget.entryId, _isFavorite);
    setState(() => _isFavorite = !_isFavorite);
  }

  Future<void> _togglePin() async {
    await ref.read(itemNotifierProvider.notifier)
        .togglePin(widget.entryId, _isPinned);
    setState(() => _isPinned = !_isPinned);
  }

  Future<void> _deleteEntry() async {
    final confirm = await ConfirmDialog.delete(
      context,
      title: 'Διαγραφή εγγραφής;',
    );
    if (!confirm || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(widget.entryId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _onPopInvoked() async {
    if (widget.isNew && !_hasEverBeenSaved) {
      await ref.read(itemNotifierProvider.notifier).deleteItem(widget.entryId);
      return true;
    }
    return true;
  }

  void _loadProps(List<ItemProperty> props) {
    if (_propsLoaded) return;
    DebugConfig.db('🔵 _loadProps: loading for entry ${widget.entryId}');
    for (final f in widget.fields) {
      final prop = props.where((p) => p.key == f.key).firstOrNull;
      final val = prop?.value ?? '';
      DebugConfig.db('   Field: ${f.key}, type: ${f.type}, value: $val');
      if (f.key.isEmpty) {
        DebugConfig.db('⚠️ Skipping save for field with empty key: label="${f.label}"');
        continue;
      }
      switch (f.type) {
        case FieldType.toggle:
          _boolValues[f.key] = val == 'true';
          break;
        case FieldType.date:
          _dateValues[f.key] = val.isNotEmpty ? DateTime.tryParse(val) : null;
          break;
        case FieldType.bulletList:
        case FieldType.numberedList:
          if (val.isNotEmpty) {
            try {
              final list = jsonDecode(val) as List;
              _listValues[f.key] = list.map((e) => e.toString()).toList();
              DebugConfig.db('   ✅ Loaded list: ${_listValues[f.key]}');
            } catch (_) {
              _listValues[f.key] = [];
              DebugConfig.db('   ⚠️ Failed to decode JSON for ${f.key}');
            }
          } else {
            _listValues[f.key] = [];
          }
          break;
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
    final itemAsync = ref.watch(itemStreamProvider(widget.entryId));
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
          if (_isFavorite != item.favorite) {
            _isFavorite = item.favorite;
          }
          if (_isPinned != item.pinned) {
            _isPinned = item.pinned;
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav = Navigator.of(context);
            final canPop = await _onPopInvoked();
            if (canPop) nav.pop();
          },
          child: Scaffold(
            backgroundColor: context.cBg,
            appBar: AppBar(
              backgroundColor: context.cBg,
              elevation: 0,
              scrolledUnderElevation: 1,
              title: _isSaving
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 14,
                  height: 14,
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
                  icon: Icon(
                    _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    color: _isPinned ? context.cPrimary : context.cText2,
                  ),
                  onPressed: _togglePin,
                  tooltip: _isPinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
                ),
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: _isFavorite
                        ? ColorsUI.getWarning(context.brightness)
                        : context.cText2,
                  ),
                  onPressed: _toggleFavorite,
                  tooltip: _isFavorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
                ),
                IconButton(
                  icon: Icon(Icons.save_rounded, color: context.cPrimary),
                  onPressed: () async {
                    await _save();
                    if (!context.mounted) return;
                    if (mounted) Navigator.of(context).pop();
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: context.cError),
                  onPressed: () => _deleteEntry(),
                  tooltip: 'Διαγραφή',
                ),
              ],
            ),
            body: ListView(
              padding: EdgeInsets.fromLTRB(
                context.responsiveHPadding,
                Spacing.lg,
                context.responsiveHPadding,
                80,
              ),
              children: [
                TextField(
                  controller: _titleCtrl,
                  onChanged: _onTitleChanged,
                  style: context.h2.copyWith(fontWeight: FontWeight.w600),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Τίτλος εγγραφής...',
                    hintStyle: context.h2.withColor(context.cDisabled),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Divider(color: ColorsUI.getBorder(context.brightness)),
                const SizedBox(height: Spacing.sm),
                ...widget.fields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: _FieldInput(
                    field: f,
                    ctrl: _fieldCtrls[f.key],
                    boolValue: _boolValues[f.key] ?? false,
                    dateValue: _dateValues[f.key],
                    listItems: _listValues[f.key] ?? [],
                    onBoolChange: (v) =>
                        setState(() => _boolValues[f.key] = v),
                    onDateChange: (v) =>
                        setState(() => _dateValues[f.key] = v),
                    onAddListItem: () => _addListItem(f.key),
                    onRemoveListItem: (index) =>
                        _removeListItem(f.key, index),
                    onUpdateListItem: (index, val) =>
                        _updateListItem(f.key, index, val),
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
// FIELD INPUT, _SelectField, _ListField (unchanged)
// ════════════════════════════════════════════════════════════════

class _FieldInput extends StatelessWidget {
  final FieldDef field;
  final TextEditingController? ctrl;
  final bool boolValue;
  final DateTime? dateValue;
  final List<String> listItems;
  final ValueChanged<bool> onBoolChange;
  final ValueChanged<DateTime?> onDateChange;
  final VoidCallback onAddListItem;
  final ValueChanged<int> onRemoveListItem;
  final void Function(int, String) onUpdateListItem;

  const _FieldInput({
    required this.field,
    this.ctrl,
    required this.boolValue,
    required this.dateValue,
    required this.listItems,
    required this.onBoolChange,
    required this.onDateChange,
    required this.onAddListItem,
    required this.onRemoveListItem,
    required this.onUpdateListItem,
  });

  @override
  Widget build(BuildContext context) {
    if (field.key.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(field.icon, size: 14, color: context.cText2),
          const SizedBox(width: Spacing.xs),
          Text(field.label, style: context.labelMd.withColor(context.cText2)),
        ]),
        const SizedBox(height: Spacing.xs),
        switch (field.type) {
          FieldType.toggle => SwitchListTile(
            value: boolValue,
            onChanged: onBoolChange,
            activeThumbColor: context.cPrimary,
            title: Text(boolValue ? 'Ναι' : 'Όχι', style: context.bodyMd),
            contentPadding: EdgeInsets.zero,
          ),
          FieldType.date => GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: dateValue ?? now,
                firstDate: DateTime(1900),
                lastDate: DateTime(now.year + 20),
                locale: const Locale('el'),
              );
              if (picked != null) onDateChange(picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm + 4),
              decoration: BoxDecoration(
                color: ColorsUI.getSurface(context.brightness),
                borderRadius: AppRadius.inputBR,
                border:
                Border.all(color: ColorsUI.getBorder(context.brightness)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    dateValue != null
                        ? dateValue!.short
                        : 'Επιλογή ημερομηνίας',
                    style: context.bodyMd.withColor(dateValue != null
                        ? context.cText
                        : context.cDisabled),
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
            ctrl: ctrl,
          ),
          FieldType.bulletList => _ListField(
            field: field,
            items: listItems,
            onAdd: onAddListItem,
            onRemove: onRemoveListItem,
            onUpdate: onUpdateListItem,
            isNumbered: false,
          ),
          FieldType.numberedList => _ListField(
            field: field,
            items: listItems,
            onAdd: onAddListItem,
            onRemove: onRemoveListItem,
            onUpdate: onUpdateListItem,
            isNumbered: true,
          ),
          _ => TextField(
            controller: ctrl,
            keyboardType: field.type == FieldType.number
                ? TextInputType.number
                : field.type == FieldType.url
                ? TextInputType.url
                : TextInputType.multiline,
            maxLines: field.type == FieldType.text ? null : 1,
            minLines: field.type == FieldType.text ? 1 : null,
            textInputAction: field.type == FieldType.text
                ? TextInputAction.newline
                : TextInputAction.done,
            style: context.bodyMd,
            decoration: InputDecoration(
              hintText: 'Εισαγωγή ${field.label.toLowerCase()}...',
              hintStyle: context.bodyMd.withColor(context.cDisabled),
              filled: true,
              fillColor: ColorsUI.getSurface(context.brightness),
              border: OutlineInputBorder(
                borderRadius: AppRadius.inputBR,
                borderSide:
                BorderSide(color: ColorsUI.getBorder(context.brightness)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputBR,
                borderSide:
                BorderSide(color: ColorsUI.getBorder(context.brightness)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputBR,
                borderSide: BorderSide(color: context.cPrimary, width: 1.5),
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
                style: context.bodyMd
                    .withColor(isActive ? context.cPrimary : context.cText)),
          ),
        );
      }).toList(),
    );
  }
}

class _ListField extends StatelessWidget {
  final FieldDef field;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int, String) onUpdate;
  final bool isNumbered;

  const _ListField({
    required this.field,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdate,
    required this.isNumbered,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final val = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Row(
              children: [
                if (isNumbered)
                  SizedBox(
                    width: 24,
                    child: Text('${idx + 1}.',
                        style: context.bodyMd.withColor(context.cText2)),
                  )
                else
                  SizedBox(
                    width: 20,
                    child: Icon(Icons.circle_rounded,
                        size: 6, color: context.cText2),
                  ),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: TextFormField(
                    initialValue: val,
                    onChanged: (newVal) => onUpdate(idx, newVal),
                    style: context.bodyMd,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: Spacing.xs),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                            color: ColorsUI.getBorder(context.brightness)),
                      ),
                      filled: true,
                      fillColor: ColorsUI.getSurface(context.brightness),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline,
                      size: 18, color: context.cError),
                  onPressed: () => onRemove(idx),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: Spacing.xs),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Προσθήκη στοιχείου',
              style: context.labelSm.withColor(context.cPrimary)),
        ),
      ],
    );
  }
}