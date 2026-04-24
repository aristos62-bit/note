// lib/features/collections/collections_screen.dart
//
// Αρχική σελίδα Συλλογών — εμφανίζει όλες τις συλλογές του χρήστη.
// ✅ Folder‑based: FAB μόνο όταν επιλεγεί φάκελος
// ✅ Responsive: grid mobile / grid tablet
// ✅ Dark mode
// ✅ DebugConfig
// ✅ Χρήση ItemColorHelper για background & contrast
// ✅ Αυτόματη επιλογή φακέλου βάσει ρυθμίσεων (προεπιλεγμένος ή "Γενικά")
// ✅ Περιμένει τα settings πριν επιλέξει φάκελο (διορθωμένο)
// ✅ Search, filter tags, ViewMode toggle
//
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import '../../helpers/item_color_helper.dart';
import 'collection_detail_screen.dart';
import 'collection_entries_screen.dart';

// Provider για real‑time αντιστοίχηση collectionId -> πλήθος εγγραφών
final collectionEntriesCountProvider = FutureProvider<Map<int, int>>((ref) async {
  final items = await ref.watch(itemNotifierProvider.future);
  final Map<int, int> counts = {};
  for (final item in items.where((i) => i.type == ItemType.knowledge)) {
    final props = await ref.watch(itemPropertiesProvider(item.id).future);
    final colIdStr = props.where((p) => p.key == 'collection_id').firstOrNull?.value;
    if (colIdStr != null) {
      final colId = int.tryParse(colIdStr);
      if (colId != null) {
        counts[colId] = (counts[colId] ?? 0) + 1;
      }
    }
  }
  return counts;
});

// ── Field types ───────────────────────────────────────────────

enum FieldType {
  text,
  number,
  date,
  select,
  toggle,
  url,
  bulletList,
  numberedList
}

class FieldDef {
  final String key;
  final String label;
  final FieldType type;
  final List<String> options;

  const FieldDef({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.name,
    'options': options,
  };

  factory FieldDef.fromJson(Map<String, dynamic> j) => FieldDef(
    key: j['key'] as String,
    label: j['label'] as String,
    type: FieldType.values.firstWhere(
          (t) => t.name == j['type'],
      orElse: () => FieldType.text,
    ),
    options: (j['options'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        [],
  );

  static List<FieldDef> listFromJson(String json) {
    if (json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => FieldDef.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<FieldDef> fields) =>
      jsonEncode(fields.map((f) => f.toJson()).toList());

  IconData get icon => switch (type) {
    FieldType.text => Icons.text_fields_rounded,
    FieldType.number => Icons.numbers_rounded,
    FieldType.date => Icons.calendar_today_rounded,
    FieldType.select => Icons.list_rounded,
    FieldType.toggle => Icons.toggle_on_rounded,
    FieldType.url => Icons.link_rounded,
    FieldType.bulletList => Icons.format_list_bulleted_rounded,
    FieldType.numberedList => Icons.format_list_numbered_rounded,
  };

  String get typeName => switch (type) {
    FieldType.text => 'Κείμενο',
    FieldType.number => 'Αριθμός',
    FieldType.date => 'Ημερομηνία',
    FieldType.select => 'Επιλογή',
    FieldType.toggle => 'Ναι/Όχι',
    FieldType.url => 'URL',
    FieldType.bulletList => 'Λίστα (κουκκίδες)',
    FieldType.numberedList => 'Λίστα (αρίθμηση)',
  };
}

// Τοπικοί providers για search & tags (δεν χρειάζονται εκτός screen)
final _collectionSearchQueryProvider = StateProvider<String>((ref) => '');
final _collectionTagFilterProvider = StateProvider<Set<String>>((ref) => {});

// ════════════════════════════════════════════════════════════════
// COLLECTIONS SCREEN
// ════════════════════════════════════════════════════════════════

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  int? _selectedFolderId;
  Set<String> _visibleTagNames = {};

  // ✅ Αν ο χρήστης έχει κάνει χειροκίνητη επιλογή, δεν ξαναβάζουμε system folder
  bool _userExplicitlySelected = false;
  bool _autoSelectDone = false;  // ✅ προστέθηκε

  // Search
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;
  Timer? _debounce;

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
      ref.read(_collectionSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _toggleSearch() {
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      ref.read(_collectionSearchQueryProvider.notifier).state = '';
      ref.read(_collectionTagFilterProvider.notifier).state = {};
    } else {
      Future.microtask(() => _searchFocus.requestFocus());
    }
  }

  Future<void> _createCollection() async {
    if (_selectedFolderId == null) {
      DebugConfig.error('Collections: createCollection without selected folder');
      return;
    }

    DebugConfig.nav('Collections: create in folder id=$_selectedFolderId');
    final item = await ref.read(itemNotifierProvider.notifier).create(
      type: ItemType.project,
      title: 'Νέα Συλλογή',
      folderId: _selectedFolderId,
    );
    if (item == null || !mounted) return;
    ref.invalidate(itemNotifierProvider);
    Navigator.of(context).push(AppTransitions.slideRoute(
        CollectionDetailScreen(collectionId: item.id, isNew: true)));
  }

  void _openCollection(BuildContext context, Item item) {
    DebugConfig.nav('Collections: open id=${item.id}');
    Navigator.of(context).push(AppTransitions.slideRoute(
        CollectionEntriesScreen(collection: item)));
  }

  void _editCollection(BuildContext context, WidgetRef ref, Item item) {
    Navigator.of(context).push(AppTransitions.slideRoute(
        CollectionDetailScreen(collectionId: item.id, isNew: false)));
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Item item) async {
    final future = ConfirmDialog.delete(context,
        title: 'Διαγραφή συλλογής "${item.title ?? ''}";\n'
            'Θα διαγραφούν και όλες οι εγγραφές.');
    final ok = await future;
    if (!ok || !context.mounted) return;
    DebugConfig.db('Collections delete id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    ref.invalidate(itemNotifierProvider);
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('CollectionsScreen build');
    final allAsync = ref.watch(itemsStreamProvider);
    final searchQuery = ref.watch(_collectionSearchQueryProvider);
    final activeTags = ref.watch(_collectionTagFilterProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider); // ✅ προστέθηκε

    // ✅ Αυτόματη επιλογή φακέλου ΜΟΝΟ όταν φορτώσουν τα settings και οι φάκελοι
    if (!_userExplicitlySelected && !_autoSelectDone && settingsAsync.hasValue && foldersAsync.hasValue) {
      final folders = foldersAsync.value!;
      if (folders.isNotEmpty && mounted && _selectedFolderId == null) {
        final settings = settingsAsync.requireValue;
        final preferredId = settings.preferredFolderId;
        int? targetId = preferredId;
        if (targetId == null || !folders.any((f) => f.id == targetId)) {
          targetId = folders.firstWhere(
                (f) => f.isSystem,
            orElse: () => folders.first,
          ).id;
        }
        _autoSelectDone = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _selectedFolderId = targetId);
            DebugConfig.nav('Collections: auto-selected folder id=$targetId (preferredId=$preferredId)');
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text('Συλλογές'),
        actions: [
          IconButton(
            icon: Icon(_searchActive ? Icons.search_off_rounded : Icons.search_rounded),
            onPressed: _toggleSearch,
            tooltip: _searchActive ? 'Κλείσιμο αναζήτησης' : 'Αναζήτηση',
          ),
        ],
      ),
      floatingActionButton: _selectedFolderId != null
          ? FloatingActionButton.extended(
        onPressed: _createCollection,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Νέα Συλλογή'),
      )
          : null,
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────
          if (_searchActive)
            _SearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
            ),

          // ── Folder selector ───────────────────────────────────
          foldersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (folders) {
              if (folders.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: FolderChipSelector(
                  folders: folders,
                  selectedFolderId: _selectedFolderId,
                  onSelect: (id) {
                    setState(() {
                      _selectedFolderId = id;
                      _userExplicitlySelected = true;   // ✅ ο χρήστης επέλεξε χειροκίνητα
                    });
                    DebugConfig.nav('Collections: select folder id=$id');
                  },
                ),
              );
            },
          ),

          // ── Tag filter chips ──────────────────────────────────
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
                    'Επιλέξτε tag για φιλτράρισμα συλλογών',
                    style: context.labelSm.withColor(context.cText2),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
                    itemCount: _visibleTagNames.length,
                    separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
                    itemBuilder: (_, i) {
                      final name = _visibleTagNames.elementAt(i);
                      final selected = activeTags.contains(name);
                      return TagChip(
                        name: name,
                        color: null,
                        compact: true,
                        selected: selected,
                        onTap: () {
                          final current = ref.read(_collectionTagFilterProvider);
                          final newSet = {...current};
                          if (newSet.contains(name)) {
                            newSet.remove(name);
                          } else {
                            newSet.add(name);
                          }
                          ref.read(_collectionTagFilterProvider.notifier).state = newSet;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

          // ── View mode toggle ──────────────────────────────────
          const ViewModeToggle(),

          // ── Collections grid ───────────────────────────────────
          Expanded(
            child: allAsync.when(
              loading: () => _LoadingGrid(),
              error: (e, _) {
                DebugConfig.error('CollectionsScreen load', e);
                return EmptyState.error(
                    onRetry: () => ref.invalidate(itemNotifierProvider));
              },
              data: (allItems) {
                var collections = allItems
                    .where((i) => i.type == ItemType.project)
                    .toList();

                // Φάκελος
                if (_selectedFolderId != null) {
                  collections = collections
                      .where((c) => c.folderId == _selectedFolderId)
                      .toList();
                }

                // View mode
                final viewMode = ref.watch(listViewModeProvider);
                switch (viewMode) {
                  case ListViewMode.pinned:
                    collections = collections.where((c) => c.pinned).toList();
                    break;
                  case ListViewMode.favorites:
                    collections = collections.where((c) => c.favorite).toList();
                    break;
                  case ListViewMode.all:
                    break;
                }

                // Search
                if (searchQuery.isNotEmpty) {
                  final q = searchQuery.toLowerCase();
                  collections = collections
                      .where((c) => (c.title ?? '').toLowerCase().contains(q))
                      .toList();
                }

                // Tag filter
                if (activeTags.isNotEmpty) {
                  collections = collections.where((c) {
                    final tags = ref.watch(itemTagsProvider(c.id)).valueOrNull ?? [];
                    return tags.any((t) => activeTags.contains(t.name));
                  }).toList();
                }

                // Συγκέντρωση visible tag names
                final visibleTagNames = <String>{};
                for (final c in collections) {
                  final tags = ref.watch(itemTagsProvider(c.id)).valueOrNull ?? [];
                  for (final t in tags) {
                    visibleTagNames.add(t.name);
                  }
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (!const SetEquality<String>().equals(_visibleTagNames, visibleTagNames)) {
                    setState(() => _visibleTagNames = visibleTagNames);
                  }
                });

                collections.sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));

                if (collections.isEmpty) {
                  if (searchQuery.isNotEmpty || activeTags.isNotEmpty) {
                    return EmptyState.search(query: searchQuery);
                  }
                  return _EmptyCollections(onCreate: _createCollection);
                }

                return ResponsiveLayout(
                  mobile: _CollectionsGrid(
                    collections: collections,
                    cols: 2,
                    onTap: (item) => _openCollection(context, item),
                    onEdit: (item) => _editCollection(context, ref, item),
                    onDelete: (item) => _delete(context, ref, item),
                  ),
                  tablet: _CollectionsGrid(
                    collections: collections,
                    cols: context.gridColumns + 1,
                    onTap: (item) => _openCollection(context, item),
                    onEdit: (item) => _editCollection(context, ref, item),
                    onDelete: (item) => _delete(context, ref, item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COLLECTIONS GRID
// ════════════════════════════════════════════════════════════════

class _CollectionsGrid extends StatelessWidget {
  final List<Item> collections;
  final int cols;
  final ValueChanged<Item> onTap;
  final ValueChanged<Item> onEdit;
  final ValueChanged<Item> onDelete;

  const _CollectionsGrid({
    required this.collections,
    required this.cols,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding,
        Spacing.md,
        context.responsiveHPadding,
        80,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: Spacing.md,
        crossAxisSpacing: Spacing.md,
        mainAxisExtent: 150,
      ),
      itemCount: collections.length,
      itemBuilder: (_, i) => _CollectionCard(
        item: collections[i],
        onTap: () => onTap(collections[i]),
        onEdit: () => onEdit(collections[i]),
        onDelete: () => onDelete(collections[i]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COLLECTION CARD — με χρήση ItemColorHelper
// ════════════════════════════════════════════════════════════════

class _CollectionCard extends ConsumerWidget {
  final Item item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final schema = propsAsync.valueOrNull
        ?.where((p) => p.key == 'schema')
        .firstOrNull
        ?.value ??
        '';
    final fields = FieldDef.listFromJson(schema);

    final countsAsync = ref.watch(collectionEntriesCountProvider);

    final backgroundColor =
    ItemColorHelper.backgroundColorForType(ItemType.project, context);
    final foregroundColor =
    ItemColorHelper.textColorForBackground(backgroundColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha: 0.7);
    final customColor = _colorFromString(item.color);
    final accentColor =
        customColor ?? ItemColorHelper.iconColorForType(ItemType.project, context);

    final icon = item.icon ?? '📦';

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.cardBR,
          border:
          Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(
                        child: Text(icon, style: const TextStyle(fontSize: 22))),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showActions(context),
                    child: Icon(Icons.more_vert_rounded,
                        size: 18, color: secondaryForeground),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                item.title ?? 'Χωρίς τίτλο',
                style: context.titleSm.copyWith(color: foregroundColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              countsAsync.when(
                loading: () => Text(
                  '${fields.length} πεδία  •  ...',
                  style: context.labelSm.copyWith(color: secondaryForeground),
                ),
                error: (_, __) => Text(
                  '${fields.length} πεδία  •  ?',
                  style: context.labelSm.copyWith(color: secondaryForeground),
                ),
                data: (counts) => Text(
                  '${fields.length} πεδία  •  ${counts[item.id] ?? 0} εγγραφές',
                  style: context.labelSm.copyWith(color: secondaryForeground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _colorFromString(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return null;
    }
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
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.xs),
              child: Text(item.title ?? 'Χωρίς τίτλο',
                  style: context.titleSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: const Text('Επεξεργασία συλλογής'),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Άνοιγμα'),
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
// EMPTY STATE
// ════════════════════════════════════════════════════════════════

class _EmptyCollections extends StatelessWidget {
  final VoidCallback? onCreate;
  const _EmptyCollections({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📦',
                style: TextStyle(
                    fontSize: context.responsive(mobile: 72.0, tablet: 96.0))),
            const SizedBox(height: Spacing.md),
            Text('Δεν έχεις συλλογές', style: context.titleMd),
            const SizedBox(height: Spacing.sm),
            Text(
              'Δημιούργησε τη δική σου βάση δεδομένων.\nΔίσκοι, βιβλία, ταινίες — ό,τι θέλεις!',
              style: context.bodyMd.withColor(context.cText2),
              textAlign: TextAlign.center,
            ),
            if (onCreate != null) ...[
              const SizedBox(height: Spacing.xl),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Νέα Συλλογή'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SEARCH BAR
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
          hintText: 'Αναζήτηση συλλογών...',
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

// ════════════════════════════════════════════════════════════════
// LOADING GRID
// ════════════════════════════════════════════════════════════════

class _LoadingGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(context.responsiveHPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 150,
          mainAxisSpacing: Spacing.md,
          crossAxisSpacing: Spacing.md),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: ColorsUI.getBorder(context.brightness).withValues(alpha: 0.4),
          borderRadius: AppRadius.cardBR,
        ),
      ),
    );
  }
}