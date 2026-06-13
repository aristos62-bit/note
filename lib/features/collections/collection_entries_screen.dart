// lib/features/collections/collection_entries_screen.dart
//
// Λίστα εγγραφών μιας συλλογής + detail screen εγγραφής.
// Εγγραφές = Item με ItemType.knowledge + property 'collection_id'.
// ✅ Dark mode
// ✅ DebugConfig
// ✅ Save pattern ίδιο με NoteDetailScreen
// ✅ Auto‑save κατά την επεξεργασία (back arrow) αν υπάρχουν αλλαγές
// ✅ Υποστήριξη bulletList και numberedList (δυναμικές λίστες)
// ✅ Πολυγραμμικό κείμενο για πεδίο text
// ✅ Χρήση ItemColorHelper για background & contrast
// ✅ ViewMode toggle (pinned/favorites/all) για φιλτράρισμα εγγραφών
// ✅ Αναζήτηση, φίλτρο tags, υπενθύμιση, πλήρες AppBar (ίδιο με NoteDetailScreen)
//
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import '../../services/services.dart';
import '../../helpers/item_color_helper.dart';
import '../../helpers/super_note_helper.dart';
import 'collections_screen.dart' show FieldDef, FieldType;

// Τοπικοί providers για search & tags στη λίστα εγγραφών
final _entriesSearchQueryProvider = StateProvider<String>((ref) => '');
final _entriesTagFilterProvider = StateProvider<Set<String>>((ref) => {});

/// Batch provider: collection_id για όλα τα knowledge items — 1 DB call
final _batchColIdProvider = FutureProvider.autoDispose<Map<int, String>>((ref) async {
  final itemsAsync = ref.watch(itemsStreamProvider);
  final entries = itemsAsync.valueOrNull
      ?.where((i) => i.type == ItemType.knowledge)
      .toList() ?? [];
  final ids = entries.map((e) => e.id).toList();
  if (ids.isEmpty) return {};
  DebugConfig.db('_batchColIdProvider: ids=${ids.length}');
  final result = await SuperNoteHelper.instance.properties.getCollectionIds(ids);
  DebugConfig.db('_batchColIdProvider: found=${result.length}');
  return result;
});

// ════════════════════════════════════════════════════════════════
// COLLECTION ENTRIES SCREEN
// ════════════════════════════════════════════════════════════════

class CollectionEntriesScreen extends ConsumerStatefulWidget {
  final Item collection;
  const CollectionEntriesScreen({super.key, required this.collection});

  @override
  ConsumerState<CollectionEntriesScreen> createState() =>
      _CollectionEntriesScreenState();
}

class _CollectionEntriesScreenState
    extends ConsumerState<CollectionEntriesScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;
  bool _showArchiveHintShown = false;
  Timer? _debounce;

  Set<String> _visibleTagNames = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_entriesSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _toggleSearch() {
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      ref.read(_entriesSearchQueryProvider.notifier).state = '';
      ref.read(_entriesTagFilterProvider.notifier).state = {};
    } else {
      Future.microtask(() => _searchFocus.requestFocus());
    }
  }

  Future<void> _createEntry(
      BuildContext context, WidgetRef ref, List<FieldDef> fields) async {
    DebugConfig.nav(
        'CollectionEntries: createEntry collectionId=${widget.collection.id}');
    final item = await ref
        .read(itemNotifierProvider.notifier)
        .create(type: ItemType.knowledge);
    if (item == null || !context.mounted) return;

    await ref
        .read(propertyNotifierProvider(item.id).notifier)
        .setText('collection_id', widget.collection.id.toString());

    if (!context.mounted) return;
    Navigator.of(context)
        .push(AppTransitions.slideRoute(CollectionEntryDetailScreen(
      entryId: item.id,
      collectionId: widget.collection.id,
      fields: fields,
      isNew: true,
    )));
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider(
        'CollectionEntriesScreen build collectionId=${widget.collection.id}');

    final allAsync = ref.watch(itemsStreamProvider);
    final propsAsync = ref.watch(itemPropertiesProvider(widget.collection.id));
    final schema = propsAsync.valueOrNull
        ?.where((p) => p.key == 'schema')
        .firstOrNull
        ?.value ??
        '';
    final fields = FieldDef.listFromJson(schema);
    final searchQuery = ref.watch(_entriesSearchQueryProvider);
    final activeTags = ref.watch(_entriesTagFilterProvider);
    final collectionAsync = ref.watch(itemStreamProvider(widget.collection.id));
    final collection = collectionAsync.valueOrNull ?? widget.collection;
    final accentColor = _colorFromItem(collection);
    DebugConfig.print('ENTRIES COLOR CHECK: collection.id=${collection.id} color="${collection.color}" accentColor=$accentColor');

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Text(widget.collection.icon ?? '📦',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: Spacing.sm),
            Text(widget.collection.title ?? 'Συλλογή',
                style: context.titleMd),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_searchActive
                ? Icons.search_off_rounded
                : Icons.search_rounded),
            onPressed: _toggleSearch,
            tooltip: _searchActive ? 'Κλείσιμο αναζήτησης' : 'Αναζήτηση',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'archived') {
                final show = ref.read(showArchivedProvider);
                ref.read(showArchivedProvider.notifier).state = !show;
                if (!show && !_showArchiveHintShown) {
                  _showArchiveHintShown = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Πατήστε παρατεταμένα (long press) στο στοιχείο για επαναφορά')),
                      );
                    }
                  });
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archived',
                child: Row(children: [
                  const Icon(Icons.archive_rounded, size: 18),
                  const SizedBox(width: Spacing.sm),
                  Text(ref.watch(showArchivedProvider) ? 'Απόκρυψη συμπιεσμένων αρχείων' : 'Εμφάνιση συμπιεσμένων αρχείων'),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createEntry(context, ref, fields),
        tooltip: 'Νέα εγγραφή',
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // Search bar
          if (_searchActive)
            _SearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
            ),

          // Tag filter chips
          if (_visibleTagNames.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.responsiveHPadding,
                    0,
                    context.responsiveHPadding,
                    Spacing.xs,
                  ),
                  child: Text(
                    'Επιλέξτε tag για φιλτράρισμα εγγραφών',
                    style: context.labelSm.withColor(context.cText2),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                        horizontal: context.responsiveHPadding),
                    itemCount: _visibleTagNames.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(width: Spacing.xs),
                    itemBuilder: (_, i) {
                      final name = _visibleTagNames.elementAt(i);
                      final selected = activeTags.contains(name);
                      return TagChip(
                        name: name,
                        color: null,
                        compact: true,
                        selected: selected,
                        onTap: () {
                          final current =
                          ref.read(_entriesTagFilterProvider);
                          final newSet = {...current};
                          if (newSet.contains(name)) {
                            newSet.remove(name);
                          } else {
                            newSet.add(name);
                          }
                          ref.read(_entriesTagFilterProvider.notifier)
                              .state = newSet;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

          // View mode toggle
          const ViewModeToggle(),

          Expanded(
            child: allAsync.when(
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState.error(),
              data: (allItems) {
                return _EntriesList(
                  key: ValueKey('entries_${accentColor.toARGB32()}'),
                  collectionId: widget.collection.id,
                  fields: fields,
                  accentColor: accentColor,
                  searchQuery: searchQuery,
                  activeTags: activeTags,
                  onCreateEntry: () =>
                      _createEntry(context, ref, fields),
                  onVisibleTagsChanged: (tags) {
                    if (!const SetEquality<String>()
                        .equals(_visibleTagNames, tags)) {
                      setState(() => _visibleTagNames = tags);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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
  final String searchQuery;
  final Set<String> activeTags;
  final VoidCallback onCreateEntry;
  final ValueChanged<Set<String>> onVisibleTagsChanged;

  const _EntriesList({
    super.key,
    required this.collectionId,
    required this.fields,
    required this.accentColor,
    required this.searchQuery,
    required this.activeTags,
    required this.onCreateEntry,
    required this.onVisibleTagsChanged,
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
      searchQuery: searchQuery,
      activeTags: activeTags,
      onCreateEntry: onCreateEntry,
      onVisibleTagsChanged: onVisibleTagsChanged,
    );
  }
}

class _FilteredEntriesList extends ConsumerWidget {
  final List<Item> candidates;
  final int collectionId;
  final List<FieldDef> fields;
  final Color accentColor;
  final String searchQuery;
  final Set<String> activeTags;
  final VoidCallback onCreateEntry;
  final ValueChanged<Set<String>> onVisibleTagsChanged;

  const _FilteredEntriesList({
    required this.candidates,
    required this.collectionId,
    required this.fields,
    required this.accentColor,
    required this.searchQuery,
    required this.activeTags,
    required this.onCreateEntry,
    required this.onVisibleTagsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Φιλτράρουμε όλες τις εγγραφές της συλλογής — 1 batch DB call
    final allEntries = <Item>[];
    final colIdMap = ref.watch(_batchColIdProvider).valueOrNull ?? {};
    for (final c in candidates) {
      final colIdStr = colIdMap[c.id];
      if (colIdStr == collectionId.toString()) allEntries.add(c);
    }

    // View mode
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

    // Search
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      entries = entries
          .where((e) => (e.title ?? '').toLowerCase().contains(q))
          .toList();
    }

    // Tag filter
    if (activeTags.isNotEmpty) {
      entries = entries.where((e) {
        final tags =
            ref.watch(itemTagsProvider(e.id)).valueOrNull ?? [];
        return tags.any((t) => activeTags.contains(t.name));
      }).toList();
    }

    // Συγκέντρωση visible tag names
    final visibleTagNames = <String>{};
    for (final e in entries) {
      final tags =
          ref.watch(itemTagsProvider(e.id)).valueOrNull ?? [];
      for (final t in tags) {
        visibleTagNames.add(t.name);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onVisibleTagsChanged(visibleTagNames);
    });

    if (entries.isEmpty) {
      if (searchQuery.isNotEmpty || activeTags.isNotEmpty) {
        return EmptyState.search(query: searchQuery);
      }
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

    return ReorderableItemList(
      items: entries,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex == newIndex) return;
        final reordered = List<Item>.from(entries);
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        ref.read(itemNotifierProvider.notifier).reorder(reordered);
      },
      itemBuilder: (ctx, entry, index) => _EntryCard(
        entry: entry,
        fields: fields,
        accentColor: accentColor,
        onTap: () => Navigator.of(context)
            .push(AppTransitions.slideRoute(CollectionEntryDetailScreen(
          entryId: entry.id,
          collectionId: collectionId,
          fields: fields,
          isNew: false,
        ))),
        onShare: () => ShareService.shareItem(context, entry.id),
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
  final VoidCallback? onShare;

  const _EntryCard({
    required this.entry,
    required this.fields,
    required this.accentColor,
    required this.onTap,
    this.onShare,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(entry.id));
    final props = propsAsync.valueOrNull ?? [];

    final previewFields = fields.take(3).toList();

    final backgroundColor = accentColor.withValues(alpha: 0.85);
    final foregroundColor =
    ItemColorHelper.textColorForBackground(accentColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha: 0.85);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.cardBR,
          border: Border.all(color: accentColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      size: 12,
                      color: ColorsUI.getWarning(context.brightness)),
                if (onShare != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: onShare,
                    child: Icon(Icons.share_rounded, size: 14,
                        color: foregroundColor.withValues(alpha: 0.6)),
                  ),
                ],
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
                } else if (f.type == FieldType.attachment) {
                  final idsJson =
                      props.where((p) => p.key == f.key).firstOrNull?.value ?? '';
                  if (idsJson.isNotEmpty) {
                    try {
                      final ids = jsonDecode(idsJson) as List;
                      if (ids.isNotEmpty) {
                        val = ids.length == 1 ? '1 συνημμένο' : '${ids.length} συνημμένα';
                      }
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
                        style: context.labelSm
                            .copyWith(color: secondaryForeground)),
                    Expanded(
                      child: Text(val,
                          style: context.labelSm
                              .copyWith(color: foregroundColor),
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

}

// ════════════════════════════════════════════════════════════════
// COLLECTION ENTRY DETAIL SCREEN (εμπλουτισμένο)
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
    extends ConsumerState<CollectionEntryDetailScreen>
    with DetailScreenMixin<CollectionEntryDetailScreen> {
  late final TextEditingController _titleCtrl;

  @override
  TextEditingController get titleCtrl => _titleCtrl;

  final Map<String, TextEditingController> _fieldCtrls = {};
  final Map<String, List<String>> _listValues = {};

  bool _isEditingTitle = false;
  String _lastSavedTitle = '';
  bool _propsLoaded = false;
  bool _isFavorite = false;
  bool _isPinned = false;
  bool _isArchived = false;

  // Ανίχνευση αλλαγών (για auto‑save σε επεξεργασία)
  bool _hasChanges = false;

  final Map<String, bool> _boolValues = {};
  final Map<String, DateTime?> _dateValues = {};
  final Map<String, List<int>> _fieldAttachmentIds = {};

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    for (final f in widget.fields) {
      if (f.type == FieldType.bulletList || f.type == FieldType.numberedList) {
        _listValues[f.key] = [];
      } else if (f.type != FieldType.toggle && f.type != FieldType.date && f.type != FieldType.attachment) {
        _fieldCtrls[f.key] = TextEditingController();
      }
    }
    initScreen(itemId: widget.entryId, isNew: widget.isNew);
  }

  @override
  void dispose() {
    disposeScreen();
    _titleCtrl.dispose();
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTitleChanged(String _) {
    _isEditingTitle = true;
    _hasChanges = true;
  }

  void _addListItem(String key) {
    setState(() {
      _listValues.putIfAbsent(key, () => []);
      _listValues[key]!.add('');
      _hasChanges = true;
    });
  }

  void _removeListItem(String key, int index) {
    setState(() {
      if (_listValues[key] != null && index < _listValues[key]!.length) {
        _listValues[key]!.removeAt(index);
        _hasChanges = true;
      }
    });
  }

  void _updateListItem(String key, int index, String value) {
    setState(() {
      if (_listValues[key] != null && index < _listValues[key]!.length) {
        _listValues[key]![index] = value;
        _hasChanges = true;
      }
    });
  }

  Future<void> _saveData() async {
    final title = _titleCtrl.text.trim();
    DebugConfig.db('EntryDetail save id=${widget.entryId} title="$title"');

    // 1. ??lo?
    await ref
        .read(itemNotifierProvider.notifier)
        .updateItem(widget.entryId, title: title.isEmpty ? null : title);

    // 2. ?�λα τα properties παράλληλα
    final notifier = ref.read(propertyNotifierProvider(widget.entryId).notifier);
    await Future.wait(widget.fields.where((f) => f.key.isNotEmpty).map((f) {
      switch (f.type) {
        case FieldType.toggle:
          return notifier.setText(f.key, (_boolValues[f.key] ?? false) ? 'true' : 'false');
        case FieldType.date:
          return notifier.setDate(f.key, _dateValues[f.key]);
        case FieldType.bulletList:
        case FieldType.numberedList:
          return notifier.setText(f.key, jsonEncode(_listValues[f.key] ?? []));
        case FieldType.attachment: {
          final ids = _fieldAttachmentIds[f.key] ?? [];
          return notifier.setText(f.key, ids.isNotEmpty ? jsonEncode(ids) : null);
        }
        default:
          final val = _fieldCtrls[f.key]?.text.trim() ?? '';
          return notifier.setText(f.key, val.isEmpty ? null : val);
      }
    }));

    _lastSavedTitle = title;
    _isEditingTitle = false;
    _hasChanges     = false;
    DebugConfig.db('EntryDetail saved');
  }

  /// ??? wrapper ??? executeSave + pop
  Future<void> _save() async {
    final ok = await executeSave(() => _saveData());
    if (ok && mounted) safePop();
  }

  /// ??? logic ??? back arrow (auto-save ?? pop)
  Future<bool> _onPopInvoked() async {
    await executeSaveOrDelete(
      saveFn: () async {
        if (_hasChanges) {
          await _saveData();
        } else {
          DebugConfig.db('EntryDetail no changes, skip save');
        }
      },
      deleteFn: () => ref.read(itemNotifierProvider.notifier).deleteItem(widget.entryId),
    );
    return true;
  }

  Future<void> _toggleFavorite() async {
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleFavorite(widget.entryId, _isFavorite);
    setState(() {
      _isFavorite = !_isFavorite;
      _hasChanges = true;
    });
  }

  Future<void> _togglePin() async {
    await ref
        .read(itemNotifierProvider.notifier)
        .togglePin(widget.entryId, _isPinned);
    setState(() {
      _isPinned = !_isPinned;
      _hasChanges = true;
    });
  }

  Future<void> _toggleArchive() async {
    await handleArchive(
      context: context,
      ref: ref,
      itemId: widget.entryId,
      isArchived: _isArchived,
      label: ItemLabel.entry,
    );
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

  Future<void> _addAttachment(String fieldKey) async {
    try {
      final field = widget.fields.firstWhere((f) => f.key == fieldKey);

      if (field.maxFiles > 0) {
        final current = _fieldAttachmentIds[fieldKey]?.length ?? 0;
        DebugConfig.db('_addAttachment maxFiles check: field="${field.label}" current=$current max=${field.maxFiles}');
        if (current >= field.maxFiles) {
          if (mounted) showSnackBar('Μέγιστο όριο ${field.maxFiles} αρχείων για το πεδίο "${field.label}"');
          return;
        }
      }

      final settings = await SuperNoteHelper.instance.settings.get();
      final maxMB = settings.maxAttachmentSizeMB;
      final maxBytes = maxMB > 0 ? maxMB * 1024 * 1024 : null;
      final attachment = await AttachmentService.instance.pickAndSave(
        itemId: widget.entryId,
        allowedExtensions: field.allowedExtensions.isNotEmpty
            ? field.allowedExtensions
            : null,
        maxSizeBytes: maxBytes,
      );
      if (attachment != null && mounted) {
        if (_fieldAttachmentIds.values.any((ids) => ids.contains(attachment.id))) {
          if (mounted) showSnackBar('Το αρχείο "${attachment.fileName}" υπάρχει ήδη');
          return;
        }
        ref.invalidate(attachmentsProvider(widget.entryId));
        setState(() {
          _fieldAttachmentIds.putIfAbsent(fieldKey, () => []);
          _fieldAttachmentIds[fieldKey]!.add(attachment.id);
          _hasChanges = true;
        });
      }
    } on FormatException catch (e) {
      if (mounted) showSnackBar(e.message);
    } catch (e) {
      debugPrint('[_addAttachment] error: $e');
    }
  }

  Future<void> _removeAttachment(String fieldKey, int attachmentId) async {
    await AttachmentService.instance.delete(attachmentId);
    if (mounted) {
      ref.invalidate(attachmentsProvider(widget.entryId));
      setState(() {
        _fieldAttachmentIds[fieldKey]?.remove(attachmentId);
        _hasChanges = true;
      });
    }
  }

  Future<void> _openAttachment(Attachment attachment) async {
    DebugConfig.db('_openAttachment id=${attachment.id} type=${attachment.mimeType}');
    if (attachment.isImage) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.file(
                    File(attachment.localPath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48, color: Colors.white54),
                          SizedBox(height: 8),
                          Text('Αδυναμία προβολής', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    try {
      final result = await OpenFilex.open(attachment.localPath);
      if (result.type != ResultType.done && mounted) {
        DebugConfig.db('_openAttachment failed: ${result.type} ${result.message}');
        showSnackBar('Αδυναμία ανοίγματος του αρχείου');
      }
    } catch (e) {
      DebugConfig.error('_openAttachment', e);
      if (mounted) showSnackBar('Αδυναμία ανοίγματος του αρχείου');
    }
  }

  Future<void> _saveAttachment(Attachment attachment) async {
    DebugConfig.db('_saveAttachment id=${attachment.id} file="${attachment.fileName}"');
    try {
      final file = File(attachment.localPath);
      if (!await file.exists()) {
        DebugConfig.db('_saveAttachment file not found');
        if (mounted) showSnackBar('Το αρχείο δεν βρέθηκε');
        return;
      }
      final bytes = await file.readAsBytes();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Αποθήκευση αρχείου',
        fileName: attachment.fileName,
        bytes: bytes,
      );
      if (path != null && mounted) {
        DebugConfig.db('_saveAttachment saved to "$path"');
        showSnackBar('Αποθηκεύτηκε: ${attachment.fileName}');
      } else {
        DebugConfig.db('_saveAttachment cancelled');
      }
    } catch (e) {
      DebugConfig.error('_saveAttachment', e);
      if (mounted) showSnackBar('Αποτυχία αποθήκευσης');
    }
  }

  // ── Reminder bottom sheet ──────────────────────────────────
  Future<void> _showReminderDialog() async {
    final title =
    _titleCtrl.text.trim().isEmpty ? 'Εγγραφή' : _titleCtrl.text.trim();
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
          itemId: widget.entryId,
          itemTitle: title,
          defaultStartTime: null,
        ),
      ),
    );
  }

  // ── Tag picker sheet ───────────────────────────────────────
  void _showTagPicker() {
    showTagPickerSheet(context, widget.entryId);
  }

  void _loadProps(List<ItemProperty> props) {
    if (_propsLoaded) return;
    DebugConfig.db('🔵 _loadProps: loading for entry ${widget.entryId}');
    for (final f in widget.fields) {
      final prop = props.where((p) => p.key == f.key).firstOrNull;
      final val = prop?.value ?? '';
      if (f.key.isEmpty) continue;
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
            } catch (_) {
              _listValues[f.key] = [];
            }
          } else {
            _listValues[f.key] = [];
          }
          break;
        case FieldType.attachment:
          if (val.isNotEmpty) {
            try {
              final list = jsonDecode(val) as List;
              _fieldAttachmentIds[f.key] =
                  list.map((e) => (e as num).toInt()).toList();
            } catch (_) {
              _fieldAttachmentIds[f.key] = [];
            }
          } else {
            _fieldAttachmentIds[f.key] = [];
          }
          break;
        default:
          if (_fieldCtrls[f.key]?.text.isEmpty == true && val.isNotEmpty) {
            // ✅ Χρησιμοποιούμε .value αντί .text για να τοποθετήσουμε
            // τον κέρσορα στο τέλος — το .text = val επιλέγει ΟΛΟ το κείμενο
            _fieldCtrls[f.key]?.value = TextEditingValue(
              text: val,
              selection: TextSelection.collapsed(offset: val.length),
            );
          }
      }
    }
    _propsLoaded = true;
    // Αφού φορτώθηκαν τα existing props, δεν υπάρχουν αλλαγές ακόμα
    _hasChanges = false;
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemStreamProvider(widget.entryId));
    final propsAsync = ref.watch(itemPropertiesProvider(widget.entryId));
    final allAttachmentsAsync = ref.watch(attachmentsProvider(widget.entryId));

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
          final newTitle = item.title ?? '';
          // ✅ Κέρσορας στο τέλος — αποφεύγουμε select-all
          _titleCtrl.value = TextEditingValue(
            text: newTitle,
            selection: TextSelection.collapsed(offset: newTitle.length),
          );
          if (_lastSavedTitle.isEmpty && newTitle.isNotEmpty) {
            _lastSavedTitle = item.title ?? '';
          }
          if (_isFavorite != item.favorite) {
            _isFavorite = item.favorite;
          }
          if (_isPinned != item.pinned) {
            _isPinned = item.pinned;
          }
          if (_isArchived != item.archived) {
            _isArchived = item.archived;
          }
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
            appBar: AppBar(
              backgroundColor: context.cBg,
              elevation: 0,
              scrolledUnderElevation: 1,
              title: null,
              actions: [
                // Save button
                IconButton(
                  icon: Icon(Icons.save_rounded, color: context.cPrimary),
                  tooltip: 'Αποθήκευση',
                  onPressed: _save,
                ),
                // Reminder
                IconButton(
                  icon: Icon(Icons.notifications_none_rounded,
                      color: context.cText2),
                  onPressed: _showReminderDialog,
                  tooltip: 'Υπενθύμιση',
                ),
                // Favorite
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
                  tooltip: _isFavorite
                      ? 'Αφαίρεση αγαπημένου'
                      : 'Αγαπημένο',
                ),
                // Pin
                IconButton(
                  icon: Icon(
                    _isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    color: _isPinned ? context.cPrimary : context.cText2,
                  ),
                  onPressed: _togglePin,
                  tooltip: _isPinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
                ),
                // Archive
                IconButton(
                  icon: Icon(
                    _isArchived
                        ? Icons.unarchive_rounded
                        : Icons.archive_rounded,
                    color: context.cText2,
                  ),
                  onPressed: _toggleArchive,
                  tooltip: _isArchived ? 'Επαναφορά' : 'Αρχειοθέτηση',
                ),
                // Delete
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: context.cError),
                  onPressed: _deleteEntry,
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
                // Title field
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
                // Fields
                ...widget.fields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: _FieldInput(
                    field: f,
                    ctrl: _fieldCtrls[f.key],
                    boolValue: _boolValues[f.key] ?? false,
                    onAnyChange: () {
                      _hasChanges = true;
                    },
                    dateValue: _dateValues[f.key],
                    listItems: _listValues[f.key] ?? [],
                    attachments: f.type == FieldType.attachment
                        ? (allAttachmentsAsync.valueOrNull ?? [])
                            .where((a) => _fieldAttachmentIds[f.key]?.contains(a.id) ?? false)
                            .toList()
                        : const [],
                    onBoolChange: (v) {
                      setState(() {
                        _boolValues[f.key] = v;
                        _hasChanges = true;
                      });
                    },
                    onDateChange: (v) {
                      setState(() {
                        _dateValues[f.key] = v;
                        _hasChanges = true;
                      });
                    },
                    onAddListItem: () => _addListItem(f.key),
                    onRemoveListItem: (index) => _removeListItem(f.key, index),
                    onUpdateListItem: (index, val) => _updateListItem(f.key, index, val),
                    onAddAttachment: () => _addAttachment(f.key),
                    onRemoveAttachment: (id) => _removeAttachment(f.key, id),
                    onOpenAttachment: (a) => _openAttachment(a),
                    onSaveAttachment: (a) => _saveAttachment(a),
                  ),
                )),
                // Tags section
                const SizedBox(height: Spacing.lg),
                _TagsSection(
                  itemId: widget.entryId,
                  onAddTag: _showTagPicker,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAGS SECTION (για το detail screen)
// ════════════════════════════════════════════════════════════════

class _TagsSection extends ConsumerWidget {
  final int itemId;
  final VoidCallback onAddTag;

  const _TagsSection({required this.itemId, required this.onAddTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(itemTagsProvider(itemId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onPressed: onAddTag,
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
              final tag = tags.firstWhere((t) => t.name == name,
                  orElse: () => tags.first);
              await ref
                  .read(tagNotifierProvider.notifier)
                  .removeFromItem(itemId, tag.id);
            },
            onAdd: onAddTag,
          ),
        ),
      ],
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
  final List<Attachment> attachments;
  final ValueChanged<bool> onBoolChange;
  final VoidCallback onAnyChange;
  final ValueChanged<DateTime?> onDateChange;
  final VoidCallback onAddListItem;
  final ValueChanged<int> onRemoveListItem;
  final void Function(int, String) onUpdateListItem;
  final VoidCallback onAddAttachment;
  final ValueChanged<int> onRemoveAttachment;
  final ValueChanged<Attachment> onOpenAttachment;
  final ValueChanged<Attachment> onSaveAttachment;

  const _FieldInput({
    required this.field,
    this.ctrl,
    required this.boolValue,
    required this.dateValue,
    required this.listItems,
    required this.attachments,
    required this.onBoolChange,
    required this.onAnyChange,
    required this.onDateChange,
    required this.onAddListItem,
    required this.onRemoveListItem,
    required this.onUpdateListItem,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
    required this.onOpenAttachment,
    required this.onSaveAttachment,
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
                border: Border.all(
                    color: ColorsUI.getBorder(context.brightness)),
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
          FieldType.attachment => _AttachmentField(
            attachments: attachments,
            onAdd: onAddAttachment,
            onRemove: onRemoveAttachment,
            onOpen: onOpenAttachment,
            onSave: onSaveAttachment,
          ),
          _ => TextField(
            controller: ctrl,
            onChanged: (v) {
              DebugConfig.db('FIELD CHANGE key=${field.key} value=$v');
              onAnyChange();
            },
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
                borderSide:
                BorderSide(color: context.cPrimary, width: 1.5),
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

class _AttachmentField extends StatelessWidget {
  final List<Attachment> attachments;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<Attachment> onOpen;
  final ValueChanged<Attachment> onSave;

  const _AttachmentField({
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
    required this.onOpen,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = ColorsUI.getBorder(context.brightness);
    final surface = ColorsUI.getSurface(context.brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...attachments.map((a) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onOpen(a),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm, vertical: Spacing.xs),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: AppRadius.inputBR,
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          if (a.isImage)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                              child: Image.file(
                                File(a.localPath),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_rounded,
                                    size: 24,
                                    color: context.cText2),
                              ),
                            )
                          else
                            Icon(
                              a.isVideo
                                  ? Icons.video_file_rounded
                                  : a.isAudio
                                  ? Icons.audio_file_rounded
                                  : Icons.insert_drive_file_rounded,
                              size: 24,
                              color: context.cText2,
                            ),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.fileName,
                                    style: context.labelSm,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text(a.readableSize,
                                    style: context.labelSm.withColor(context.cText2)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => onSave(a),
                            child: Icon(Icons.download_rounded,
                                size: 18, color: context.cPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onRemove(a.id),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: context.cError),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.attach_file_rounded, size: 16),
          label: Text('Προσθήκη αρχείου',
              style: context.labelSm.withColor(context.cPrimary)),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SEARCH BAR (για τη λίστα)
// ════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cBg,
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding,
        Spacing.sm,
        context.responsiveHPadding,
        Spacing.sm,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: context.bodyMd,
        decoration: InputDecoration(
          hintText: 'Αναζήτηση εγγραφών...',
          hintStyle: context.bodyMd.withColor(context.cDisabled),
          prefixIcon: Icon(Icons.search_rounded, color: context.cText2),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.close_rounded, color: context.cText2),
            onPressed: () {
              controller.clear();
              onChanged('');
            },
          )
              : null,
          filled: true,
          fillColor: ColorsUI.getSurface(context.brightness),
          border: OutlineInputBorder(
            borderRadius: AppRadius.inputBR,
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
        ),
      ),
    );
  }
}