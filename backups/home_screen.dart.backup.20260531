// lib/features/home/home_screen.dart
//
// Home Screen — refactored with Pinned/Favorites toggle.
// ✅ ViewMode: pinned | favorites | both
// ✅ Badges on cards (pin and/or star)
// ✅ Real-time (foldersStreamProvider + pinnedItemsStreamProvider + favoriteItemsStreamProvider)
// ✅ Responsive: mobile / tablet
// ✅ Dark mode + DebugConfig
// ✅ Square cards with type-specific background colors, 3 per row on tablet, 2 per row on mobile
// ✅ Reorderable pinned/favorites (drag & drop)
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
import 'package:reorderable_grid/reorderable_grid.dart';


// ── View Mode for Home Screen ─────────────────────────────────
enum ViewMode { pinned, favorites, both }

// ── Εικονίδια για νέο φάκελο (24) ─────────────────────────────
const _kFolderIcons = [
  '📁',  '💼',  '🏠',  '📚',  '🎵',  '🎮',  '⚽',  '🌍',  '🔬',
  '✈️',  '🍕',  '🏆',  '🖼️',  '📝',  '⭐',  '🎬',  '💡',  '🛒',
  '🏋️',  '🌱',  '📊',  '🔐',  '🎯','😊', '👤', '👥', '🧠', '🗣️',
  '🛠️', '⚙️', '🔧', '🧰', '📐',  '💻', '📱', '📋', '🏷️', '🔔',
  '⏰', '💬', '🚀', '🔑', '🎉','🎨','👦', '👧', '👴', '👵', '👨',
  '👩', '👶', '🧑', '👪', '🧠','🛠️', '⚙️', '🔧', '🧰', '📐',
  '💻', '📱', '🔑', '🚀', '🎉',
];

const _kFolderColors = [
  // Σκούρο → Ανοιχτό
  '#6366F1', '#A1A3F7',   // Indigo
  '#8B5CF6', '#B99DFA',   // Purple
  '#EC4899', '#F491C2',   // Pink
  '#EF4444', '#F58F8F',   // Red
  '#F97316', '#FBAB73',   // Orange
  '#EAB308', '#F2D16B',   // Yellow
  '#22C55E', '#7ADC9E',   // Green
  '#14B8A6', '#72D4CA',   // Teal
  '#06B6D4', '#6AD3E5',   // Cyan
  '#3B82F6', '#89B4FA',   // Blue
  '#64748B', '#A2ACB9',   // Slate
  '#E11D48', '#ED7791',   // Rose
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
      floatingActionButton: selectedFolderId == null
          ? FloatingActionButton(
        onPressed: () => _showCreateFolderDialog(context, ref),
        tooltip: 'Νέος φάκελος',
        backgroundColor: context.cPrimary,
        foregroundColor: context.cOnPrimary,
        child: const Icon(Icons.add_rounded),
      )
          : null,  // ❌ κανένα FAB – το HomeFolderView έχει το δικό του για νέα items
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

          // Content — ξεχωριστό ConsumerWidget για αποφυγή rebuild ολόκληρου HomeScreen
          if (selectedFolderId == null)
            SliverToBoxAdapter(
              child: _PinnedFavoritesSection(
                folders: folders,
                viewMode: _viewMode,
                onOpenItem: (item) => _openItem(context, item),
                onRetry: () => ref.invalidate(pinnedAndFavoritesProvider),
              ),
            )
          else
            _buildFolderContent(context, folders),
        ],
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
                    Color c;
                    try {
                      c = Color(
                          int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                    } catch (_) {
                      c = const Color(0xFF6366F1);
                    }
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
                    Color c;
                    try {
                      c = Color(int.parse(
                          'FF${hex.replaceAll('#', '')}', radix: 16));
                    } catch (_) {
                      c = const Color(0xFF6366F1);
                    }
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
// PINNED & FAVORITES SECTION with REORDERABLE GRID
// ════════════════════════════════════════════════════════════════

class _PinnedFavoritesSection extends ConsumerStatefulWidget {
  final List<Folder> folders;
  final ViewMode viewMode;
  final void Function(Item) onOpenItem;
  final VoidCallback onRetry;

  const _PinnedFavoritesSection({
    required this.folders,
    required this.viewMode,
    required this.onOpenItem,
    required this.onRetry,
  });

  @override
  ConsumerState<_PinnedFavoritesSection> createState() => _PinnedFavoritesSectionState();
}

class _PinnedFavoritesSectionState extends ConsumerState<_PinnedFavoritesSection> {
  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(pinnedAndFavoritesProvider);

    return asyncData.when(
      loading: () => _LoadingSkeleton(),
      error: (e, _) => EmptyState.error(onRetry: widget.onRetry),
      data: (data) {
        final pinned = data.pinned;
        final favorites = data.favorites;

        DebugConfig.print('📊 FAVORITES COUNT: ${favorites.length}');
        for (var f in favorites) {
          DebugConfig.print('   - ${f.title} (folderId: ${f.folderId})');
        }

        List<Item> items;
        switch (widget.viewMode) {
          case ViewMode.both:
            final combined = <Item>[...pinned];
            for (final fav in favorites) {
              if (!combined.any((i) => i.id == fav.id)) {
                combined.add(fav);
              }
            }
            // Νέος unified sort: χρησιμοποιεί pinnedOrder για ΟΛΑ τα items.
            // Δεν υπάρχει πλέον αναγκαστική σειρά pinned-πριν-fav.
            // Τα items με pinnedOrder=null (νέα / ποτέ reordered) πάνε στο τέλος.
            combined.sort((a, b) {
              final aO = a.pinnedOrder;
              final bO = b.pinnedOrder;
              if (aO == null && bO == null) {
                return (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt);
              }
              if (aO == null) return 1;
              if (bO == null) return -1;
              return aO.compareTo(bO);
            });
            items = combined;
            break;
          case ViewMode.pinned:
            items = pinned;
            break;
          case ViewMode.favorites:
            items = favorites;
            break;
        }

        if (items.isEmpty) return _buildEmpty(context, widget.viewMode);

        return _ReorderableGrid(
          items: items,
          viewMode: widget.viewMode,
          folders: widget.folders,
          onOpenItem: widget.onOpenItem,
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, ViewMode mode) {
    final (icon, title, subtitle) = switch (mode) {
      ViewMode.pinned => (
      Icons.push_pin_outlined,
      'Δεν υπάρχουν καρφιτσωμένα στοιχεία',
      'Καρφίτσωσε στοιχεία για να τα βλέπεις εδώ.',
      ),
      ViewMode.favorites => (
      Icons.star_outline_rounded,
      'Δεν υπάρχουν αγαπημένα στοιχεία',
      'Πρόσθεσε αγαπημένα για να τα βλέπεις εδώ.',
      ),
      ViewMode.both => (
      Icons.inbox_rounded,
      'Δεν υπάρχουν στοιχεία',
      'Καρφίτσωσε ή αποθήκευσε στοιχεία ως αγαπημένα\nγια να τα βλέπεις εδώ.',
      ),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding,
        Spacing.xl,
        context.responsiveHPadding,
        0,
      ),
      child: Column(children: [
        Icon(icon, size: 56, color: context.cDisabled),
        const SizedBox(height: Spacing.md),
        Text(title, style: context.titleMd),
        const SizedBox(height: Spacing.sm),
        Text(
          subtitle,
          style: context.bodyMd.withColor(context.cText2),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// REORDERABLE GRID (με drag & drop) – Fixed height issue
// ════════════════════════════════════════════════════════════════

class _ReorderableGrid extends ConsumerStatefulWidget {
  final List<Item> items;
  final ViewMode viewMode;
  final List<Folder> folders;
  final void Function(Item) onOpenItem;

  const _ReorderableGrid({
    required this.items,
    required this.viewMode,
    required this.folders,
    required this.onOpenItem,
  });

  @override
  ConsumerState<_ReorderableGrid> createState() => _ReorderableGridState();
}

class _ReorderableGridState extends ConsumerState<_ReorderableGrid> {
  late List<Item> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant _ReorderableGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Fingerprint: id + flags + pinnedOrder (χρησιμοποιείται ως unified order σε ViewMode.both)
    String fingerprint(List<Item> items) =>
        items.map((i) => '${i.id}:${i.pinned}:${i.favorite}:${i.pinnedOrder}').join(',');

    final streamFp = fingerprint(widget.items);
    final oldFp    = fingerprint(oldWidget.items);

    if (oldFp != streamFp) {
      setState(() => _items = List.from(widget.items));
    }
  }

  void _handleReorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;

    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });

    if (widget.viewMode == ViewMode.both) {
      // ViewMode.both: ενοποιημένη αναδιάταξη — pinnedOrder για ΟΛΑ τα items.
      // Ένα transaction → ένα stream event → χωρίς intermediate state που
      // ακύρωνε το drag (αιτία του bug).
      // Δεν υπάρχει πλέον αναγκαστική σειρά pinned-πριν-fav.
      final allIds = _items.map((i) => i.id).toList();
      DebugConfig.print('🔄 reorderCombined (ViewMode.both): $allIds');
      ref.read(itemNotifierProvider.notifier).reorderCombined(allIds);
    } else {
      // ViewMode.pinned / ViewMode.favorites: αναδιάταξη μόνο στην αντίστοιχη ενότητα
      final pinnedIds   = _items.where((i) => i.pinned).map((i) => i.id).toList();
      final favoriteIds = _items.where((i) => i.favorite && !i.pinned).map((i) => i.id).toList();

      if (pinnedIds.isNotEmpty) {
        ref.read(itemNotifierProvider.notifier).reorderPinned(pinnedIds);
      }
      if (favoriteIds.isNotEmpty) {
        DebugConfig.print('🔄 reorderFavorites: $favoriteIds');
        ref.read(itemNotifierProvider.notifier).reorderFavorites(favoriteIds);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : 4;
    const  spacing = Spacing.sm; // 8.0
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
      child: ReorderableGridView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 1.0,
        ),
        onReorder: _handleReorder,
          itemBuilder: (context, index) {
            final item = _items[index];
            final folder = widget.folders.where((f) => f.id == item.folderId).firstOrNull;
            return Container(
              key: ValueKey(item.id),
              child: _SquareItemCard(
                item: item,
                folder: folder,
                onTap: () => widget.onOpenItem(item),
              ),
            );
          },
          itemCount: _items.length,
        ),
    );
  }
}


// ════════════════════════════════════════════════════════════════
// LOADING SKELETON for PinnedFavoritesSection
// ════════════════════════════════════════════════════════════════

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : 4;
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 16,
            decoration: BoxDecoration(
              color: placeholderColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: Spacing.sm,
              crossAxisSpacing: Spacing.sm,
              childAspectRatio: 1.0,
            ),
            itemCount: crossAxisCount * 2,
            itemBuilder: (_, __) => Container(
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: AppRadius.cardBR,
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