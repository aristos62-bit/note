// lib/features/home/home_screen.dart
//
// Home Screen — refactored.
// Δομή:
//   1. AppBar (workspace name + search/notifications/settings)
//   2. Greeting
//   3. Folder selector tabs: "Όλοι" | φάκελοι | + νέος
//   4. Content:
//      - "Όλοι"   → pinned από ΟΛΟΥΣ τους φακέλους
//      - Φάκελος  → HomeFolderView (stats + σήμερα + πρόσφατα)
//
// ✅ Real-time (foldersStreamProvider + allPinnedStreamProvider)
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

          // Folder Selector
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

          // Content
          if (_selectedFolderId == null)
            _buildAllPinnedContent(context, ref, folders)
          else
            _buildFolderContent(context, folders),
        ],
      ),
    );
  }

  // ── "Όλοι" — pinned items ────────────────────────────────────

  Widget _buildAllPinnedContent(
      BuildContext context, WidgetRef ref, List<Folder> folders) {
    final pinnedAsync = ref.watch(allPinnedStreamProvider);

    return pinnedAsync.when(
      loading: () => const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) {
        DebugConfig.error('HomeScreen pinned', e);
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      },
      data: (pinned) {
        if (pinned.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.responsiveHPadding, Spacing.xl,
                context.responsiveHPadding, 0,
              ),
              child: Column(children: [
                Icon(Icons.push_pin_outlined,
                    size: 56, color: context.cDisabled),
                const SizedBox(height: Spacing.md),
                Text('Δεν υπάρχουν καρφιτσωμένα',
                    style: context.titleMd),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Καρφίτσωσε στοιχεία μέσα από τους φακέλους\n'
                      'για να τα βλέπεις εδώ.',
                  style: context.bodyMd.withColor(context.cText2),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          );
        }

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
                  child: _PinnedCard(
                    item:   pinned[i],
                    folder: _folderFor(pinned[i], folders),
                    onTap:  () => _openItem(context, pinned[i]),
                  ),
                ),
                childCount: pinned.length,
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
              crossAxisCount:   context.gridColumns,
              mainAxisSpacing:  Spacing.sm,
              crossAxisSpacing: Spacing.sm,
              mainAxisExtent:   120,
            ),
            delegate: SliverChildBuilderDelegate(
                  (_, i) => _PinnedCard(
                item:   pinned[i],
                folder: _folderFor(pinned[i], folders),
                onTap:  () => _openItem(context, pinned[i]),
              ),
              childCount: pinned.length,
            ),
          ),
        );
      },
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
    DebugConfig.nav('HomeScreen → \${item.type.name} id=\${item.id}');
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

  // ── Edit folder (only if empty) ─────────────────────────────

  Future<void> _editFolder(
      BuildContext context, WidgetRef ref, Folder folder) async {
    final ctrl           = TextEditingController(text: folder.name);
    String selectedIcon  = folder.icon  ?? '📁';
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
                  controller:  ctrl,
                  autofocus:   true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText:  'Όνομα φακέλου...',
                    filled:    true,
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
                  spacing: Spacing.xs, runSpacing: Spacing.xs,
                  children: _kFolderIcons.map((e) =>
                      GestureDetector(
                        onTap: () => setDialog(() => selectedIcon = e),
                        child: AnimatedContainer(
                          duration: AppDuration.fast,
                          width: 40, height: 40,
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
                      ),
                  ).toList(),
                ),
                const SizedBox(height: Spacing.md),
                Text('Χρώμα',
                    style: ctx.labelMd.withColor(ctx.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.sm, runSpacing: Spacing.sm,
                  children: _kFolderColors.map((hex) {
                    final c = Color(int.parse(
                        'FF${hex.replaceAll('#', '')}', radix: 16));
                    final isActive = selectedColor == hex;
                    return GestureDetector(
                      onTap: () =>
                          setDialog(() => selectedColor = hex),
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? ctx.cText : Colors.transparent,
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

  Future<void> _showCreateFolderDialog(
      BuildContext context, WidgetRef ref) async {
    final ctrl           = TextEditingController();
    String selectedIcon  = '📁';
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
                  controller:  ctrl,
                  autofocus:   true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText:  'Όνομα φακέλου...',
                    filled:    true,
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
                  spacing: Spacing.xs, runSpacing: Spacing.xs,
                  children: _kFolderIcons.map((e) =>
                      GestureDetector(
                        onTap: () => setDialog(() => selectedIcon = e),
                        child: AnimatedContainer(
                          duration: AppDuration.fast,
                          width: 40, height: 40,
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
                      ),
                  ).toList(),
                ),
                const SizedBox(height: Spacing.md),
                Text('Χρώμα',
                    style: ctx.labelMd.withColor(ctx.cText2)),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.sm, runSpacing: Spacing.sm,
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
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? ctx.cText : Colors.transparent,
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
      backgroundColor:        context.cBg,
      surfaceTintColor:       Colors.transparent,
      floating:               true,
      snap:                   true,
      elevation:              0,
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
// GREETING
// ════════════════════════════════════════════════════════════════

class _GreetingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now  = DateTime.now();
    final hour = now.hour;

    final String   greeting;
    final IconData greetIcon;
    if (hour < 12) {
      greeting  = 'Καλημέρα!';
      greetIcon = Icons.wb_sunny_rounded;
    } else if (hour < 18) {
      greeting  = 'Καλό απόγευμα!';
      greetIcon = Icons.wb_cloudy_rounded;
    } else {
      greeting  = 'Καλησπέρα!';
      greetIcon = Icons.nights_stay_rounded;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.responsiveHPadding, Spacing.md,
        context.responsiveHPadding, Spacing.xs,
      ),
      child: Row(children: [
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
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FOLDER SELECTOR
// ════════════════════════════════════════════════════════════════

class _FolderSelector extends StatelessWidget {
  final List<Folder> folders;
  final int?         selectedFolderId;
  final ValueChanged<int?> onSelect;
  final VoidCallback  onCreateFolder;
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
    } catch (_) { return fallback; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Spacing.sm),
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
              label:      'Όλοι',
              icon:       '🗂️',
              isSelected: selectedFolderId == null,
              color:      context.cPrimary,
              onTap:      () => onSelect(null),
            ),
            const SizedBox(width: Spacing.xs),

            // Folders
            ...folders.map((f) => Padding(
              padding: const EdgeInsets.only(right: Spacing.xs),
              child: _Tab(
                label:      f.name,
                icon:       f.icon ?? '📁',
                isSelected: selectedFolderId == f.id,
                color:      _colorFromHex(f.color, context.cPrimary),
                onTap:     () => onSelect(f.id),
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
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String icon;
  final bool   isSelected;
  final Color  color;
  final VoidCallback  onTap;
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
// PINNED CARD — με ένδειξη φακέλου
// ════════════════════════════════════════════════════════════════

class _PinnedCard extends StatelessWidget {
  final Item    item;
  final Folder? folder;
  final VoidCallback onTap;

  const _PinnedCard({
    required this.item,
    required this.folder,
    required this.onTap,
  });

  static Color _colorFromHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(
          int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) { return fallback; }
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
          color:        ColorsUI.getCard(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(
              color: itemColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type + pin
            Row(children: [
              ItemTypeIcon(item.type, size: 13, color: itemColor),
              const SizedBox(width: Spacing.xs),
              Text(ItemTypeIcon.labelFor(item.type),
                  style: context.labelSm.withColor(itemColor)),
              const Spacer(),
              Icon(Icons.push_pin_rounded,
                  size: 12, color: context.cDisabled),
            ]),
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