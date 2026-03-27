// lib/features/home/home_screen.dart
//
// Home Screen — refactored with Pinned/Favorites toggle.
// ✅ ViewMode: pinned | favorites | both
// ✅ Badges on cards (pin and/or star)
// ✅ Real-time (foldersStreamProvider + allPinnedStreamProvider + allFavoritesStreamProvider)
// ✅ Responsive: mobile / tablet
// ✅ Dark mode + DebugConfig
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import '../search/search.dart';
import '../settings/settings.dart';
import '../notes/note_detail_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../habits/habit_detail_screen.dart';
import '../calendar/event_detail_screen.dart';
import '../contacts/contact_detail_screen.dart';
import '../journal/journal_detail_screen.dart';
import '../collections/collection_detail_screen.dart';
import 'home_folder_view.dart';

// ── View Mode for Home Screen ─────────────────────────────────
enum ViewMode { pinned, favorites, both }

// ── Εικονίδια για νέο φάκελο (24) ─────────────────────────────
const _kFolderIcons = [
  '📁','💼','🏠','📚','🎵','🎮','⚽','🌍',
  '🔬','🎨','✈️','🍕','🏆','🖼️','📝','⭐',
  '🎬','💡','🛒','🏋️','🌱','📊','🔐','🎯',
];

const _kFolderColors = [
  '#6366F1','#8B5CF6','#EC4899','#EF4444',
  '#F97316','#EAB308','#22C55E','#14B8A6',
  '#06B6D4','#3B82F6','#64748B','#E11D48',
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
  // null = "Όλοι", int = folder id
  int? _selectedFolderId;

  // View mode for "Όλοι" section
  ViewMode _viewMode = ViewMode.pinned;

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('HomeScreen build');

    final foldersAsync = ref.watch(foldersStreamProvider);
    final folders      = foldersAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: context.cBg,
      body: CustomScrollView(
        slivers: [
          // AppBar
          const _HomeAppBar(),

          // Greeting
          SliverToBoxAdapter(child: _GreetingSection()),

          // Folder Selector (with heading)
          SliverToBoxAdapter(
            child: Consumer(
              builder: (context, ref, _) {
                final allItems = ref.watch(itemsStreamProvider).valueOrNull ?? [];
                return _FolderSelector(
                  folders:          folders,
                  selectedFolderId: _selectedFolderId,
                  onSelect: (id) {
                    DebugConfig.nav('Home: select folder id=$id');
                    setState(() => _selectedFolderId = id);
                  },
                  onCreateFolder: () =>
                      _showCreateFolderDialog(context, ref),
                  onFolderLongPress: (folder) =>
                      _showFolderOptions(context, ref, folder, allItems),
                );
              },
            ),
          ),

          // View Mode Toggle (μόνο όταν είναι σε "Όλοι")
          if (_selectedFolderId == null)
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
          if (_selectedFolderId == null)
            _buildContentView(context, ref)
          else
            _buildFolderContent(context, folders),
        ],
      ),
    );
  }

  // ── Content for "Όλοι" — pinned/favorites/both ───────────────

  Widget _buildContentView(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(allPinnedStreamProvider);
    final favoritesAsync = ref.watch(allFavoritesStreamProvider);

    // Για both mode, συνδυάζουμε τα streams
    if (_viewMode == ViewMode.both) {
      return _buildCombinedContent(context, pinnedAsync, favoritesAsync);
    }

    // pinned mode
    if (_viewMode == ViewMode.pinned) {
      return pinnedAsync.when(
        loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator())),
        error: (e, _) {
          DebugConfig.error('HomeScreen pinned', e);
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        },
        data: (items) => _buildItemsList(context, items, isPinnedMode: true),
      );
    }

    // favorites mode
    return favoritesAsync.when(
      loading: () => const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) {
        DebugConfig.error('HomeScreen favorites', e);
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
      data: (items) => _buildItemsList(context, items, isPinnedMode: false),
    );
  }

  // ── Combined view (both pinned and favorites) ────────────────

  Widget _buildCombinedContent(
      BuildContext context,
      AsyncValue<List<Item>> pinnedAsync,
      AsyncValue<List<Item>> favoritesAsync,
      ) {
    final pinned = pinnedAsync.valueOrNull ?? [];
    final favorites = favoritesAsync.valueOrNull ?? [];

    // Συνδυασμός χωρίς duplicates (αν ένα item είναι και pinned και favorite)
    final combined = <Item>[...pinned];
    for (final fav in favorites) {
      if (!combined.any((i) => i.id == fav.id)) {
        combined.add(fav);
      }
    }

    // Ταξινόμηση: pinned first, then favorites (by updatedAt)
    combined.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      final aDate = a.updatedAt ?? a.createdAt;
      final bDate = b.updatedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });

    final isLoading = pinnedAsync.isLoading && favoritesAsync.isLoading;
    final hasError = pinnedAsync.hasError || favoritesAsync.hasError;

    if (isLoading) {
      return const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator()));
    }

    if (hasError) {
      DebugConfig.error('HomeScreen combined view', pinnedAsync.error ?? favoritesAsync.error);
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (combined.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildItemsList(context, combined, isPinnedMode: false);
  }

  // ── Build items list (mobile list / tablet grid) ─────────────

  Widget _buildItemsList(BuildContext context, List<Item> items, {required bool isPinnedMode}) {
    if (items.isEmpty) {
      return _buildEmptyState(context);
    }

    final folders = ref.watch(foldersStreamProvider).valueOrNull ?? [];

    if (context.isMobile) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(
          context.responsiveHPadding, Spacing.md,
          context.responsiveHPadding, 100,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _ItemCardWithBadges(
                item: items[i],
                folder: _folderFor(items[i], folders),
                onTap: () => _openItem(context, items[i]),
              ),
            ),
            childCount: items.length,
          ),
        ),
      );
    }

    // Tablet grid
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.md,
        context.responsiveHPadding, 100,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: context.gridColumns,
          mainAxisSpacing: Spacing.sm,
          crossAxisSpacing: Spacing.sm,
          mainAxisExtent: 120,
        ),
        delegate: SliverChildBuilderDelegate(
              (_, i) => _ItemCardWithBadges(
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
        message = 'Δεν υπάρχουν καρφιτσωμένα ή αγαπημένα στοιχεία';
        icon = Icons.inbox_rounded;
        break;
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.responsiveHPadding, Spacing.xl,
          context.responsiveHPadding, 0,
        ),
        child: Column(children: [
          Icon(icon, size: 56, color: context.cDisabled),
          const SizedBox(height: Spacing.md),
          Text(message, style: context.titleMd),
          const SizedBox(height: Spacing.sm),
          Text(
            _viewMode == ViewMode.pinned
                ? 'Καρφίτσωσε στοιχεία μέσα από τους φακέλους\nγια να τα βλέπεις εδώ.'
                : 'Πρόσθεσε αγαπημένα στοιχεία μέσα από τους φακέλους\nγια να τα βλέπεις εδώ.',
            style: context.bodyMd.withColor(context.cText2),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  // ── Folder content ───────────────────────────────────────────

  Widget _buildFolderContent(
      BuildContext context, List<Folder> folders) {
    final folder = folders.where((f) => f.id == _selectedFolderId)
        .firstOrNull;
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
        Navigator.of(context).push(AppTransitions.slideRoute(
            TaskDetailScreen(itemId: item.id)));
      case ItemType.contact:
        Navigator.of(context).push(AppTransitions.slideRoute(
            ContactDetailScreen(itemId: item.id)));
      case ItemType.journal:
        Navigator.of(context).push(AppTransitions.slideRoute(
            JournalDetailScreen(itemId: item.id)));
      case ItemType.habit:
        Navigator.of(context).push(AppTransitions.slideRoute(
            HabitDetailScreen(itemId: item.id)));
      case ItemType.event:
        Navigator.of(context).push(AppTransitions.slideRoute(
            EventDetailScreen(itemId: item.id)));
      case ItemType.project:
        Navigator.of(context).push(AppTransitions.slideRoute(
            CollectionDetailScreen(collectionId: item.id)));
      default:
        Navigator.of(context).push(AppTransitions.slideRoute(
            NoteDetailScreen(itemId: item.id)));
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
                      borderSide: BorderSide(
                          color: ColorsUI.getBorder(ctx.brightness)),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Text('Εικονίδιο',
                    style: ctx.labelMd.withColor(ctx.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: _kFolderIcons.map((e) => GestureDetector(
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
                      child: Center(child: Text(e,
                          style: const TextStyle(fontSize: 20))),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: Spacing.md),
                Text('Χρώμα',
                    style: ctx.labelMd.withColor(ctx.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: _kFolderColors.map((hex) {
                    final c = Color(int.parse(
                        'FF${hex.replaceAll('#', '')}',
                        radix: 16));
                    final isActive = selectedColor == hex;
                    return GestureDetector(
                      onTap: () =>
                          setDialog(() => selectedColor = hex),
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? ctx.cText
                                : Colors.transparent,
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
                await ref.read(folderNotifierProvider.notifier)
                    .create(name,
                    icon: selectedIcon, color: selectedColor);
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
                      borderSide: BorderSide(
                          color: ColorsUI.getBorder(ctx.brightness)),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Text('Εικονίδιο',
                    style: ctx.labelMd.withColor(ctx.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: _kFolderIcons.map((e) => GestureDetector(
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
                      child: Center(child: Text(e,
                          style: const TextStyle(fontSize: 20))),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: Spacing.md),
                Text('Χρώμα',
                    style: ctx.labelMd.withColor(ctx.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: _kFolderColors.map((hex) {
                    final c = Color(int.parse(
                        'FF${hex.replaceAll('#', '')}', radix: 16));
                    final isActive = selectedColor == hex;
                    return GestureDetector(
                      onTap: () =>
                          setDialog(() => selectedColor = hex),
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? ctx.cText
                                : Colors.transparent,
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
                await ref.read(folderNotifierProvider.notifier)
                    .rename(folder.id,
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
    if (_selectedFolderId == folder.id) {
      setState(() => _selectedFolderId = null);
    }
  }

  // ── Show folder options (long press on tab) ───────────────────

  void _showFolderOptions(BuildContext context, WidgetRef ref,
      Folder folder, List<Item> allItems) {
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
                Text(folder.icon ?? '📁',
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: Spacing.sm),
                Text(folder.name, style: context.titleSm),
                if (!isEmpty) ...[
                  const SizedBox(width: Spacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
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
            // Edit — πάντα διαθέσιμο
            ListTile(
              leading: Icon(Icons.edit_rounded, color: context.cText),
              title: Text('Επεξεργασία', style: context.bodyMd),
              onTap: () {
                Navigator.pop(context);
                _editFolder(context, ref, folder);
              },
            ),
            // Delete — μόνο αν άδειος
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: isEmpty ? context.cError : context.cDisabled),
              title: Text('Διαγραφή',
                  style: context.bodyMd.withColor(
                      isEmpty ? context.cError : context.cDisabled)),
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
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          // Pinned button
          _ToggleButton(
            icon: Icons.push_pin_rounded,
            label: 'Καρφιτσωμένα',
            isSelected: current == ViewMode.pinned,
            onTap: () => onChanged(ViewMode.pinned),
          ),
          const SizedBox(width: Spacing.xs),
          // Favorites button
          _ToggleButton(
            icon: Icons.star_rounded,
            label: 'Αγαπημένα',
            isSelected: current == ViewMode.favorites,
            onTap: () => onChanged(ViewMode.favorites),
          ),
          const SizedBox(width: Spacing.xs),
          // Both button
          _ToggleButton(
            icon: Icons.merge_type_rounded,
            label: 'Όλα',
            isSelected: current == ViewMode.both,
            onTap: () => onChanged(ViewMode.both),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? context.cPrimary : context.cText2;
    final bgColor = isSelected
        ? context.cPrimary.withValues(alpha: 0.12)
        : ColorsUI.getSurface(context.brightness);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm + 2,
          vertical: Spacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.badge),
          border: Border.all(
            color: isSelected ? color : ColorsUI.getBorder(context.brightness),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.labelSm.withColor(color),
            ),
          ],
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
    final workspaceAsync = ref.watch(defaultWorkspaceProvider);
    final wsName = workspaceAsync.valueOrNull?.name ?? 'SuperNote';

    return SliverAppBar(
      backgroundColor: context.cBg,
      surfaceTintColor: Colors.transparent,
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Text(wsName, style: context.titleLg),
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: context.cText2),
          onPressed: () => Navigator.push(context,
              AppTransitions.fadeRoute(const SearchScreen())),
          tooltip: 'Αναζήτηση',
        ),
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: context.cText2),
          onPressed: () =>
              DebugConfig.nav('Home: notifications (TODO)'),
          tooltip: 'Ειδοποιήσεις',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(context,
              AppTransitions.slideUpRoute(const SettingsScreen())),
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
        context.responsiveHPadding, Spacing.md,
        context.responsiveHPadding, Spacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Αριστερή πλευρά: εικονίδιο καιρού + κείμενο
          Expanded(
            child: Row(
              children: [
                Icon(greetIcon, size: 22,
                    color: ColorsUI.getWarning(context.brightness)),
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
                width: 44,
                height: 44,
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
// FOLDER SELECTOR (με επικεφαλίδα "Φάκελοι")
// ════════════════════════════════════════════════════════════════

class _FolderSelector extends StatelessWidget {
  final List<Folder> folders;
  final int? selectedFolderId;
  final ValueChanged<int?> onSelect;
  final VoidCallback onCreateFolder;
  final ValueChanged<Folder> onFolderLongPress;

  const _FolderSelector({
    required this.folders,
    required this.selectedFolderId,
    required this.onSelect,
    required this.onCreateFolder,
    required this.onFolderLongPress,
  });

  static Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(
          int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Επικεφαλίδα "Φάκελοι"
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsiveHPadding,
            vertical: Spacing.xs,
          ),
          child: Text(
            'Φάκελοι',
            style: context.labelMd.withColor(context.cText2),
          ),
        ),
        // Τα ταμπάκια
        Container(
          margin: const EdgeInsets.only(top: Spacing.xs),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: ColorsUI.getBorder(context.brightness),
              ),
            ),
          ),
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                  horizontal: context.responsiveHPadding),
              children: [
                // "Όλοι"
                _Tab(
                  label: 'Όλοι',
                  icon: '🗂️',
                  isSelected: selectedFolderId == null,
                  color: context.cPrimary,
                  onTap: () => onSelect(null),
                ),
                const SizedBox(width: Spacing.xs),

                // Folders
                ...folders.map((f) => Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: _Tab(
                    label: f.name,
                    icon: f.icon ?? '📁',
                    isSelected: selectedFolderId == f.id,
                    color: _colorFromHex(f.color, context.cPrimary),
                    onTap: () => onSelect(f.id),
                    onMoreTap: () => onFolderLongPress(f),
                  ),
                )),

                // "+ Νέος"
                GestureDetector(
                  onTap: onCreateFolder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm, vertical: Spacing.xs),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.create_new_folder_rounded,
                          size: 16, color: context.cText2),
                      const SizedBox(width: 4),
                      Text('Νέος',
                          style:
                          context.labelMd.withColor(context.cText2)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: EdgeInsets.only(
            left: Spacing.sm + 2, top: Spacing.xs, bottom: Spacing.xs,
            right: onMoreTap != null ? 2 : Spacing.sm + 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.labelMd.copyWith(
              color: isSelected ? color : context.cText2,
              fontWeight:
              isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          // ⋯ button
          if (onMoreTap != null) ...[
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onMoreTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 4),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 14,
                  color: isSelected ? color : context.cText2,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ITEM CARD WITH BADGES (pin + favorite indicators)
// ════════════════════════════════════════════════════════════════

class _ItemCardWithBadges extends StatelessWidget {
  final Item item;
  final Folder? folder;
  final VoidCallback onTap;

  const _ItemCardWithBadges({
    required this.item,
    required this.folder,
    required this.onTap,
  });

  static Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(
          int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemColor =
    ColorsUI.itemTypeColor(item.type, context.brightness);
    final folderColor = folder != null
        ? _colorFromHex(folder!.color, context.cText2)
        : context.cText2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: ColorsUI.getCard(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(
              color: itemColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type + Badges (pinned & favorite)
            Row(
              children: [
                ItemTypeIcon(item.type, size: 13, color: itemColor),
                const SizedBox(width: Spacing.xs),
                Text(ItemTypeIcon.labelFor(item.type),
                    style: context.labelSm.withColor(itemColor)),
                const Spacer(),
                // Badges
                if (item.pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin_rounded,
                        size: 12, color: context.cPrimary),
                  ),
                if (item.favorite)
                  Icon(Icons.star_rounded,
                      size: 12, color: ColorsUI.getWarning(context.brightness)),
              ],
            ),
            const SizedBox(height: Spacing.xs),

            // Τίτλος
            Text(
              item.title ?? 'Χωρίς τίτλο',
              style: context.bodyMd,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Folder badge
            if (folder != null) ...[
              const SizedBox(height: Spacing.xs),
              Row(children: [
                Text(folder!.icon ?? '📁',
                    style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(folder!.name,
                      style:
                      context.labelSm.withColor(folderColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}