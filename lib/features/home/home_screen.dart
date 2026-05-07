// lib/features/home/home_screen.dart
//
// Home Screen — refactored with Pinned/Favorites toggle.
// ✅ ViewMode: pinned | favorites | both
// ✅ Badges on cards (pin and/or star)
// ✅ Real-time (foldersStreamProvider + pinnedItemsStreamProvider + favoriteItemsStreamProvider)
// ✅ Responsive: mobile / tablet
// ✅ Dark mode + DebugConfig
// ✅ Square cards with type-specific background colors, 3 per row on tablet, 2 per row on mobile
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import '../search/search.dart';
import '../settings/settings.dart';
import '../collections/collections.dart';
import 'home_folder_view.dart';
import 'package:go_router/go_router.dart';
import '../../helpers/item_color_helper.dart';

// ── View Mode for Home Screen ─────────────────────────────────
enum ViewMode { pinned, favorites, both }

// ── Εικονίδια για νέο φάκελο (24) ─────────────────────────────
const _kFolderIcons = [
  '📁',
  '💼',
  '🏠',
  '📚',
  '🎵',
  '🎮',
  '⚽',
  '🌍',
  '🔬',
  '🎨',
  '✈️',
  '🍕',
  '🏆',
  '🖼️',
  '📝',
  '⭐',
  '🎬',
  '💡',
  '🛒',
  '🏋️',
  '🌱',
  '📊',
  '🔐',
  '🎯',
];

const _kFolderColors = [
  '#6366F1',
  '#8B5CF6',
  '#EC4899',
  '#EF4444',
  '#F97316',
  '#EAB308',
  '#22C55E',
  '#14B8A6',
  '#06B6D4',
  '#3B82F6',
  '#64748B',
  '#E11D48',
];

// ════════════════════════════════════════════════════════════════
// HOME SCREEN
// ════════════════════════════════════════════════════════════════

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // View mode for "Όλοι" section
  ViewMode _viewMode = ViewMode.both;

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('HomeScreen build');

    final folders = ref.watch(
      foldersStreamProvider.select((async) => async.valueOrNull ?? const <Folder>[]),
    );

    // Διαβάζουμε την επιλογή από τον provider
    final selectedFolderId = ref.watch(homeSelectedFolderProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      // ✅ FAB για δημιουργία νέου φακέλου
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateFolderDialog(context, ref),
        tooltip: 'Νέος φάκελος',
        backgroundColor: context.cPrimary,
        foregroundColor: context.cOnPrimary,
        child: const Icon(Icons.create_new_folder_rounded),
      ),
      body: CustomScrollView(
        slivers: [
          // AppBar
          const _HomeAppBar(),

          // Greeting
          SliverToBoxAdapter(child: _GreetingSection()),

          // Folder Selector (μόνο folders, χωρίς items)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.responsiveHPadding,
                    vertical: Spacing.xs,
                  ),
                  child: Text(
                    'Φάκελοι',
                    style: context.labelLg.withColor(context.cText2),
                  ),
                ),
                // ❌ Αφαιρέθηκε το chip "Νέος" – πλέον υπάρχει FAB
                FolderChipSelector(
                  folders: folders,
                  selectedFolderId: selectedFolderId,
                  onSelect: (id) {
                    ref.read(homeSelectedFolderProvider.notifier).state = id;
                  },
                  onFolderLongPress: (folder) {
                    // Διαβάζουμε τα items ΜΟΝΟ την ώρα του long press
                    final allItems = ref.read(itemsStreamProvider).valueOrNull ?? [];
                    _showFolderOptions(context, ref, folder, allItems);
                  },
                ),
              ],
            ),
          ),
          // View Mode Toggle (μόνο όταν είναι σε "Όλοι")
          if (selectedFolderId == null)
            SliverToBoxAdapter(
              child: _ViewModeToggle(
                current: _viewMode,
                onChanged: (mode) {
                  DebugConfig.nav('Home: view mode changed to $mode');
                  setState(() => _viewMode = mode);
                },
              ),
            ),

          // Content
          if (selectedFolderId == null)
            _buildContentView(context, ref, folders)
          else
            _buildFolderContent(context, folders),
        ],
      ),
    );
  }

  // ── Content for "Όλοι" — pinned/favorites/both ───────────────

  Widget _buildContentView(
      BuildContext context,
      WidgetRef ref,
      List<Folder> folders,
      ) {
    final asyncData = ref.watch(pinnedAndFavoritesProvider);

    return asyncData.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: EmptyState.error(
          onRetry: () => ref.invalidate(pinnedAndFavoritesProvider),
        ),
      ),
      data: (data) {
        final pinned = data.pinned;
        final favorites = data.favorites;

        DebugConfig.db('HOME pinned count=${pinned.length}');
        DebugConfig.db('HOME favorites count=${favorites.length}');

        // both mode
        if (_viewMode == ViewMode.both) {
          final combined = <Item>[...pinned];

          for (final fav in favorites) {
            if (!combined.any((i) => i.id == fav.id)) {
              combined.add(fav);
            }
          }

          combined.sort((a, b) {
            if (a.pinned && !b.pinned) return -1;
            if (!a.pinned && b.pinned) return 1;

            final aDate = a.updatedAt ?? a.createdAt;
            final bDate = b.updatedAt ?? b.createdAt;

            return bDate.compareTo(aDate);
          });

          if (combined.isEmpty) {
            return _buildEmptyState(context);
          }

          return _buildItemsGrid(
            context,
            combined,
            folders: folders,
            isPinnedMode: false,
          );
        }

        // pinned mode
        if (_viewMode == ViewMode.pinned) {
          if (pinned.isEmpty) return _buildEmptyState(context);

          return _buildItemsGrid(
            context,
            pinned,
            folders: folders,
            isPinnedMode: true,
          );
        }

        // favorites mode
        if (favorites.isEmpty) return _buildEmptyState(context);

        return _buildItemsGrid(
          context,
          favorites,
          folders: folders,
          isPinnedMode: false,
        );
      },
    );
  }

  // ── Build items grid (square cards, responsive columns) ─────

  Widget _buildItemsGrid(
      BuildContext context,
      List<Item> items, {
        required List<Folder> folders,
        required bool isPinnedMode,
      }) {
    if (items.isEmpty) {
      return _buildEmptyState(context);
    }

    // Responsive columns: 3 on tablet/desktop, 2 on mobile
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : 4;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding,
        Spacing.md,
        context.responsiveHPadding,
        Spacing.md + MediaQuery.of(context).padding.bottom + 80,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: Spacing.sm,
          crossAxisSpacing: Spacing.sm,
          childAspectRatio: 1.0, // τετράγωνα
        ),
        delegate: SliverChildBuilderDelegate(
              (_, i) => _SquareItemCard(
            item: items[i],
            folder: _folderFor(items[i], folders),
            onTap: () => _openItem(context, items[i]),
          ),
          childCount: items.length,
        ),
      ),
    );
  }

  // ── Empty state for "Όλοι" section ───────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    String message;
    IconData icon;

    switch (_viewMode) {
      case ViewMode.pinned:
        message = 'Δεν υπάρχουν καρφιτσωμένα στοιχεία';
        icon = Icons.push_pin_outlined;
        break;
      case ViewMode.favorites:
        message = 'Δεν υπάρχουν αγαπημένα στοιχεία';
        icon = Icons.star_outline_rounded;
        break;
      case ViewMode.both:
        message = 'Δεν υπάρχουν στοιχεία';
        icon = Icons.inbox_rounded;
        break;
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.responsiveHPadding,
          Spacing.xl,
          context.responsiveHPadding,
          0,
        ),
        child: Column(children: [
          Icon(icon, size: 56, color: context.cDisabled),
          const SizedBox(height: Spacing.md),
          Text(message, style: context.titleMd),
          const SizedBox(height: Spacing.sm),
          Text(
            switch (_viewMode) {
              ViewMode.pinned =>
              'Δημιούργησε φακέλους\nκαρφίτσωσε στοιχεία για να τα βλέπεις εδώ.',
              ViewMode.favorites =>
              'Δημιούργησε φακέλους\nπρόσθεσε αγαπημένα για να τα βλέπεις εδώ.',
              ViewMode.both =>
              'Δημιούργησε φακέλους\nκαρφίτσωσε ή αποθήκευσε στοιχεία ως αγαπημένα\nγια να τα βλέπεις εδώ.',
            },
            style: context.bodyMd.withColor(context.cText2),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  // ── Folder content ───────────────────────────────────────────

  Widget _buildFolderContent(BuildContext context, List<Folder> folders) {
    final selectedId = ref.watch(homeSelectedFolderProvider);
    final folder = folders.where((f) => f.id == selectedId).firstOrNull;
    if (folder == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverFillRemaining(
      child: HomeFolderView(folder: folder),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Folder? _folderFor(Item item, List<Folder> folders) {
    if (item.folderId == null) return null;
    return folders.where((f) => f.id == item.folderId).firstOrNull;
  }

  void _openItem(BuildContext context, Item item) {
    DebugConfig.nav('HomeScreen → ${item.type.name} id=${item.id}');
    switch (item.type) {
      case ItemType.task:
        context.push(AppRoutes.task(item.id));
        break;
      case ItemType.contact:
        context.push(AppRoutes.contact(item.id));
        break;
      case ItemType.journal:
        context.push(AppRoutes.journal_(item.id));
        break;
      case ItemType.habit:
        context.push(AppRoutes.habit(item.id));
        break;
      case ItemType.event:
        context.push('/calendar/${item.id}');
        break;
      case ItemType.project:
        context.push('/collections/${item.id}');
        break;
      case ItemType.appointment:
        context.push('/appointments/${item.id}');
        break;
      case ItemType.knowledge:
        _openKnowledgeEntry(item);
        break;
      default:
        context.push(AppRoutes.note(item.id));
    }
  }

  Future<void> _openKnowledgeEntry(Item entry) async {
    // Βρίσκουμε τη συλλογή στην οποία ανήκει η εγγραφή μέσω property 'collection_id'
    final props = await ref.read(itemPropertiesProvider(entry.id).future);
    final collectionIdStr =
        props.where((p) => p.key == 'collection_id').firstOrNull?.value;
    if (collectionIdStr == null) {
      DebugConfig.error('Knowledge entry without collection_id', null);
      return;
    }
    final collectionId = int.tryParse(collectionIdStr);
    if (collectionId == null) return;
    final collection = await ref.read(itemByIdProvider(collectionId).future);
    if (collection == null) return;

    // Φόρτωση schema της συλλογής
    final collectionProps =
    await ref.read(itemPropertiesProvider(collectionId).future);
    final schemaJson =
        collectionProps.where((p) => p.key == 'schema').firstOrNull?.value ??
            '';
    final fields = FieldDef.listFromJson(schemaJson);

    if (mounted) {
      Navigator.of(context)
          .push(AppTransitions.slideRoute(CollectionEntryDetailScreen(
        entryId: entry.id,
        collectionId: collectionId,
        fields: fields,
        isNew: false,
      )));
    }
  }

  // ── Create folder dialog ─────────────────────────────────────

  Future<void> _showCreateFolderDialog(
      BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    String selectedIcon = '📁';
    String selectedColor = '#6366F1';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: ColorsUI.getSurface(ctx.brightness),
          title: const Text('Νέος Φάκελος'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Όνομα φακέλου...',
                    filled: true,
                    fillColor: ColorsUI.getBackground(ctx.brightness),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputBR,
                      borderSide:
                      BorderSide(color: ColorsUI.getBorder(ctx.brightness)),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Text('Εικονίδιο', style: ctx.labelMd.withColor(ctx.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: _kFolderIcons
                      .map((e) => GestureDetector(
                    onTap: () => setDialog(() => selectedIcon = e),
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedIcon == e
                            ? ctx.cPrimary.withValues(alpha: 0.12)
                            : ColorsUI.getSurface(ctx.brightness),
                        borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: selectedIcon == e
                              ? ctx.cPrimary
                              : ColorsUI.getBorder(ctx.brightness),
                        ),
                      ),
                      child: Center(
                          child: Text(e,
                              style: const TextStyle(fontSize: 20))),
                    ),
                  ))
                      .toList(),
                ),
                const SizedBox(height: Spacing.md),
                Text('Χρώμα', style: ctx.labelMd.withColor(ctx.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: _kFolderColors.map((hex) {
                    final c = Color(
                        int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                    final isActive = selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setDialog(() => selectedColor = hex),
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive ? ctx.cText : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isActive
                            ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Άκυρο'),
            ),
            FilledButton(
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                DebugConfig.db('Home createFolder "$name"');
                await ref
                    .read(folderNotifierProvider.notifier)
                    .create(name, icon: selectedIcon, color: selectedColor);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Δημιουργία'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit folder (only if empty) ─────────────────────────────

  Future<void> _editFolder(
      BuildContext context, WidgetRef ref, Folder folder) async {
    final ctrl = TextEditingController(text: folder.name);
    String selectedIcon = folder.icon ?? '📁';
    String selectedColor = folder.color ?? '#6366F1';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: ColorsUI.getSurface(ctx.brightness),
          title: const Text('Επεξεργασία Φακέλου'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Όνομα φακέλου...',
                    filled: true,
                    fillColor: ColorsUI.getBackground(ctx.brightness),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputBR,
                      borderSide:
                      BorderSide(color: ColorsUI.getBorder(ctx.brightness)),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Text('Εικονίδιο', style: ctx.labelMd.withColor(ctx.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: _kFolderIcons
                      .map((e) => GestureDetector(
                    onTap: () => setDialog(() => selectedIcon = e),
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedIcon == e
                            ? ctx.cPrimary.withValues(alpha: 0.12)
                            : ColorsUI.getSurface(ctx.brightness),
                        borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: selectedIcon == e
                              ? ctx.cPrimary
                              : ColorsUI.getBorder(ctx.brightness),
                        ),
                      ),
                      child: Center(
                          child: Text(e,
                              style: const TextStyle(fontSize: 20))),
                    ),
                  ))
                      .toList(),
                ),
                const SizedBox(height: Spacing.md),
                Text('Χρώμα', style: ctx.labelMd.withColor(ctx.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: _kFolderColors.map((hex) {
                    final c = Color(
                        int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                    final isActive = selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setDialog(() => selectedColor = hex),
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive ? ctx.cText : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isActive
                            ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Άκυρο'),
            ),
            FilledButton(
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                await ref.read(folderNotifierProvider.notifier).rename(
                    folder.id,
                    name: name,
                    icon: selectedIcon,
                    color: selectedColor);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Αποθήκευση'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFolder(
      BuildContext context, WidgetRef ref, Folder folder) async {
    final future = ConfirmDialog.delete(
      context,
      title: 'Διαγραφή φακέλου "${folder.name}";',
    );
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('Home deleteFolder id=${folder.id}');
    await ref.read(folderNotifierProvider.notifier).delete(folder.id);
    // Deselect αν ήταν επιλεγμένος
    if (ref.read(homeSelectedFolderProvider) == folder.id) {
      ref.read(homeSelectedFolderProvider.notifier).state = null;
    }
  }

  // ── Show folder options (long press on tab) ───────────────────

  void _showFolderOptions(
      BuildContext context, WidgetRef ref, Folder folder, List<Item> allItems) {
    // Έλεγχος αν ο φάκελος είναι άδειος
    final folderItems = allItems
        .where((i) => i.folderId == folder.id && i.deletedAt == null)
        .toList();
    final isEmpty = folderItems.isEmpty;

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
              child: Row(children: [
                Text(folder.icon ?? '📁', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: Spacing.sm),
                Text(folder.name, style: context.titleSm),
                if (!isEmpty) ...[
                  const SizedBox(width: Spacing.sm),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.cText2.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                    ),
                    child: Text('${folderItems.length} στοιχεία',
                        style: context.labelSm.withColor(context.cText2)),
                  ),
                ],
              ]),
            ),
            const Divider(),

            // ── Επεξεργασία (πάντα διαθέσιμη) ─────────────────
            ListTile(
              leading: Icon(Icons.edit_rounded, color: context.cText),
              title: Text('Επεξεργασία', style: context.bodyMd),
              onTap: () {
                Navigator.pop(context);
                _editFolder(context, ref, folder);
              },
            ),

            // ── Διαγραφή ή ενημερωτικό μήνυμα ─────────────────
            if (!folder.isSystem) ...[
              // Κανονικός φάκελος: εμφάνιση delete αν είναι άδειος
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: isEmpty ? context.cError : context.cDisabled),
                title: Text('Διαγραφή',
                    style: context.bodyMd
                        .withColor(isEmpty ? context.cError : context.cDisabled)),
                subtitle: !isEmpty
                    ? Text('Αδείασε πρώτα τον φάκελο',
                    style: context.bodySm.withColor(context.cText2))
                    : null,
                onTap: isEmpty
                    ? () {
                  Navigator.pop(context);
                  _deleteFolder(context, ref, folder);
                }
                    : null,
              ),
            ] else ...[
              // System φάκελος: ενημέρωση ότι δεν διαγράφεται
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: context.cText2),
                title: Text(
                  'Ο φάκελος "Γενικά" δεν διαγράφεται',
                  style: context.bodyMd.withColor(context.cText2),
                ),
                subtitle: Text(
                  'Είναι ο προεπιλεγμένος φάκελος του συστήματος',
                  style: context.bodySm.withColor(context.cDisabled),
                ),
                enabled: false,  // Μη επιλέξιμο
              ),
            ],

            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// VIEW MODE TOGGLE (pinned / favorites / both)
// ════════════════════════════════════════════════════════════════

class _ViewModeToggle extends StatelessWidget {
  final ViewMode current;
  final ValueChanged<ViewMode> onChanged;

  const _ViewModeToggle({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Spacing.sm),
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ToggleButton(
            icon: Icons.push_pin_rounded,
            tooltip: 'Καρφιτσωμένα',
            isSelected: current == ViewMode.pinned,
            activeColor: Colors.red,
            onTap: () => onChanged(ViewMode.pinned),
          ),
          const SizedBox(width: Spacing.md),
          _ToggleButton(
            icon: Icons.star_rounded,
            tooltip: 'Αγαπημένα',
            isSelected: current == ViewMode.favorites,
            activeColor: Colors.amber,
            onTap: () => onChanged(ViewMode.favorites),
          ),
          const SizedBox(width: Spacing.md),
          _ToggleButton(
            icon: Icons.merge_type_rounded,
            tooltip: 'Όλα',
            isSelected: current == ViewMode.both,
            activeColor: Colors.green,
            onTap: () => onChanged(ViewMode.both),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? activeColor : context.cText2;
    final bgColor = isSelected
        ? activeColor.withValues(alpha: 0.12)
        : ColorsUI.getSurface(context.brightness);
    final borderColor =
    isSelected ? activeColor : ColorsUI.getBorder(context.brightness);

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HOME APP BAR
// ════════════════════════════════════════════════════════════════

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsName = ref.watch(
      defaultWorkspaceProvider.select((async) => async.valueOrNull?.name),
    ) ?? 'Προσωπικός Βοηθός';
    DebugConfig.db('Home wsName="$wsName"');

    return SliverAppBar(
      backgroundColor: context.cBg,
      surfaceTintColor: Colors.transparent,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          wsName,
          style: context.titleLg,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: context.cText2),
          onPressed: () {
            DebugConfig.nav('🔍 HomeAppBar search button pressed');
            Navigator.push(
              context,
              AppTransitions.fadeRoute(const SearchScreen()),
            );
          },
          tooltip: 'Αναζήτηση',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            AppTransitions.slideUpRoute(const SettingsScreen()),
          ),
        ),
      ],
    );
  }
}


// ════════════════════════════════════════════════════════════════
// GREETING (με εικονίδιο εφαρμογής στα δεξιά)
// ════════════════════════════════════════════════════════════════

class _GreetingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;

    final String greeting;
    final IconData greetIcon;
    if (hour < 12) {
      greeting = 'Καλημέρα!';
      greetIcon = Icons.wb_sunny_rounded;
    } else if (hour < 18) {
      greeting = 'Καλό απόγευμα!';
      greetIcon = Icons.wb_cloudy_rounded;
    } else {
      greeting = 'Καλησπέρα!';
      greetIcon = Icons.nights_stay_rounded;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding,
        Spacing.md,
        context.responsiveHPadding,
        Spacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Αριστερή πλευρά: εικονίδιο καιρού + κείμενο
          Expanded(
            child: Row(
              children: [
                Icon(greetIcon,
                    size: 22, color: ColorsUI.getWarning(context.brightness)),
                const SizedBox(width: Spacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting, style: context.titleLg),
                    Text(now.dateTime,
                        style: context.bodySm.withColor(context.cText2)),
                  ],
                ),
              ],
            ),
          ),
          // Δεξιά πλευρά: εικονίδιο εφαρμογής
          ClipOval(
            child: Image.asset(
              'assets/icons/app_icon.webp',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.cSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SQUARE ITEM CARD with type-specific background color
// and auto-contrast text color, fixed overflow
// ════════════════════════════════════════════════════════════════

class _SquareItemCard extends StatelessWidget {
  final Item item;
  final Folder? folder;
  final VoidCallback onTap;

  const _SquareItemCard({
    required this.item,
    required this.folder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = ItemColorHelper.backgroundColorForType(item.type, context);
    final textColor = ItemColorHelper.textColorForBackground(backgroundColor, context);
    final typeColor = ItemColorHelper.iconColorForType(item.type, context);


    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.cardBR,
          border: Border.all(
            color: typeColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ItemTypeIcon(item.type, size: 14, color: typeColor),
                  const SizedBox(width: Spacing.xs),
                  Flexible(
                    child: Text(
                      ItemTypeIcon.labelFor(item.type),
                      style: context.labelSm.copyWith(color: textColor),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (item.pinned)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.push_pin_rounded, size: 12, color: textColor),
                    ),
                  if (item.favorite)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(Icons.star_rounded, size: 12, color: textColor),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Expanded(
                child: Text(
                  item.title ?? 'Χωρίς τίτλο',
                  style: context.bodyMd.copyWith(color: textColor, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (folder != null) ...[
                const SizedBox(height: Spacing.xs),
                Row(
                  children: [
                    Text(folder!.icon ?? '📁', style: TextStyle(fontSize: 11, color: textColor)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        folder!.name,
                        style: context.labelSm.copyWith(color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}