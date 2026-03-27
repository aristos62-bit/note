// lib/features/collections/collections_screen.dart
//
// Αρχική σελίδα Συλλογών — εμφανίζει όλες τις συλλογές του χρήστη.
// ✅ Folder-based: FAB μόνο όταν επιλεγεί φάκελος
// ✅ Responsive: grid mobile / grid tablet
// ✅ Dark mode
// ✅ DebugConfig
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'collection_detail_screen.dart';
import 'collection_entries_screen.dart';

// ── Field types ───────────────────────────────────────────────

enum FieldType { text, number, date, select, toggle, url }

class FieldDef {
  final String key;
  final String label;
  final FieldType type;
  final List<String> options; // για select

  const FieldDef({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
  });

  Map<String, dynamic> toJson() => {
    'key':     key,
    'label':   label,
    'type':    type.name,
    'options': options,
  };

  factory FieldDef.fromJson(Map<String, dynamic> j) => FieldDef(
    key:     j['key'] as String,
    label:   j['label'] as String,
    type:    FieldType.values.firstWhere(
            (t) => t.name == j['type'],
        orElse: () => FieldType.text),
    options: (j['options'] as List?)
        ?.map((e) => e.toString()).toList() ?? [],
  );

  static List<FieldDef> listFromJson(String json) {
    if (json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => FieldDef.fromJson(e as Map<String,dynamic>))
          .toList();
    } catch (_) { return []; }
  }

  static String listToJson(List<FieldDef> fields) =>
      jsonEncode(fields.map((f) => f.toJson()).toList());

  IconData get icon => switch (type) {
    FieldType.text   => Icons.text_fields_rounded,
    FieldType.number => Icons.numbers_rounded,
    FieldType.date   => Icons.calendar_today_rounded,
    FieldType.select => Icons.list_rounded,
    FieldType.toggle => Icons.toggle_on_rounded,
    FieldType.url    => Icons.link_rounded,
  };

  String get typeName => switch (type) {
    FieldType.text   => 'Κείμενο',
    FieldType.number => 'Αριθμός',
    FieldType.date   => 'Ημερομηνία',
    FieldType.select => 'Επιλογή',
    FieldType.toggle => 'Ναι/Όχι',
    FieldType.url    => 'URL',
  };
}

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

  Future<void> _createCollection() async {
    if (_selectedFolderId == null) {
      DebugConfig.error('Collections: createCollection without selected folder');
      return;
    }

    DebugConfig.nav('Collections: create in folder id=$_selectedFolderId');
    final item = await ref.read(itemNotifierProvider.notifier)
        .create(
      type: ItemType.project,
      title: 'Νέα Συλλογή',
      folderId: _selectedFolderId,
    );
    if (item == null || !mounted) return;
    ref.invalidate(itemNotifierProvider);
    // ignore: use_build_context_synchronously
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
    // Οι εγγραφές διαγράφονται μέσω cascade στη DB
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    ref.invalidate(itemNotifierProvider);
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('CollectionsScreen build');
    final allAsync = ref.watch(itemsStreamProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor:        context.cBg,
        elevation:              0,
        scrolledUnderElevation: 1,
        title: const Text('Συλλογές'),
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
          // ── Folder selector ("Όλοι" ή συγκεκριμένος φάκελος) ──
          foldersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (folders) {
              if (folders.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: _CollectionFolderChips(
                  folders: folders,
                  selectedFolderId: _selectedFolderId,
                  onSelect: (id) {
                    setState(() => _selectedFolderId = id);
                    DebugConfig.nav('Collections: select folder id=$id');
                  },
                ),
              );
            },
          ),

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

                // Φιλτράρισμα: φάκελος ("Όλοι" ή συγκεκριμένος)
                if (_selectedFolderId != null) {
                  collections = collections
                      .where((c) => c.folderId == _selectedFolderId)
                      .toList();
                }

                collections.sort((a, b) =>
                    (a.title ?? '').compareTo(b.title ?? ''));

                if (collections.isEmpty) {
                  // Αν είμαστε σε "Όλοι" (null φάκελος) → χωρίς CTA
                  if (_selectedFolderId == null) {
                    return const _EmptyCollections(onCreate: null);
                  }
                  // Αν έχεις συγκεκριμένο φάκελο → δείξε CTA
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
// FOLDER CHIPS (ίδιο με NoteListScreen)
// ════════════════════════════════════════════════════════════════

class _CollectionFolderChips extends StatelessWidget {
  final List<Folder> folders;
  final int? selectedFolderId;
  final ValueChanged<int?> onSelect;

  const _CollectionFolderChips({
    required this.folders,
    required this.selectedFolderId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
        ),
        itemCount: folders.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
        itemBuilder: (ctx, index) {
          if (index == 0) {
            final isSelected = selectedFolderId == null;
            return ChoiceChip(
              label: const Text('Όλοι'),
              selected: isSelected,
              onSelected: (_) => onSelect(null),
            );
          }

          final folder = folders[index - 1];
          final isSelected = selectedFolderId == folder.id;

          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(folder.icon ?? '📁'),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    folder.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => onSelect(folder.id),
          );
        },
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
        context.responsiveHPadding, Spacing.md,
        context.responsiveHPadding, 80,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   cols,
        mainAxisSpacing:  Spacing.md,
        crossAxisSpacing: Spacing.md,
        mainAxisExtent:   150,
      ),
      itemCount: collections.length,
      itemBuilder: (_, i) => _CollectionCard(
        item:     collections[i],
        onTap:    () => onTap(collections[i]),
        onEdit:   () => onEdit(collections[i]),
        onDelete: () => onDelete(collections[i]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COLLECTION CARD
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
    final schema     = propsAsync.valueOrNull
        ?.where((p) => p.key == 'schema')
        .firstOrNull?.value ?? '';
    final fields     = FieldDef.listFromJson(schema);

    // Μέτρηση εγγραφών
    final allAsync   = ref.watch(itemsStreamProvider);
    final entryCount = allAsync.valueOrNull
        ?.where((i) =>
    i.type == ItemType.knowledge &&
        // entries που ανήκουν σε αυτή τη συλλογή βρίσκονται μέσω property
        true)
        .length ?? 0;

    final color = _colorFromString(item.color);
    final icon  = item.icon ?? '📦';

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Container(
        decoration: BoxDecoration(
          color:        ColorsUI.getSurface(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(
              color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + menu
              Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color:        color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(
                      child: Text(icon,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showActions(context),
                    child: Icon(Icons.more_vert_rounded,
                        size: 18, color: context.cText2),
                  ),
                ],
              ),
              const Spacer(),
              // Title
              Text(
                item.title ?? 'Χωρίς τίτλο',
                style: context.titleSm,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Fields count + entries
              Text(
                '${fields.length} πεδία  •  $entryCount εγγραφές',
                style: context.labelSm.withColor(context.cText2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFromString(String? hex) {
    if (hex == null || hex.isEmpty) {
      return const Color(0xFF6366F1); // default indigo
    }
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
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
              title:   const Text('Επεξεργασία συλλογής'),
              onTap: () { Navigator.pop(context); onEdit(); },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title:   const Text('Άνοιγμα'),
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
            Text('📦', style: TextStyle(
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

class _LoadingGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(context.responsiveHPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisExtent: 150,
          mainAxisSpacing: Spacing.md, crossAxisSpacing: Spacing.md),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color:        ColorsUI.getBorder(context.brightness)
              .withValues(alpha: 0.4),
          borderRadius: AppRadius.cardBR,
        ),
      ),
    );
  }
}