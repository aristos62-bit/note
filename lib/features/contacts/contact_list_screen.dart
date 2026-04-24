// lib/features/contacts/contact_list_screen.dart
//
// Λίστα επαφών με folder selector, search, real-time updates.
// ✅ Folder-based: FAB μόνο όταν επιλεγεί φάκελος
// ✅ Responsive: list mobile / grid tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions + ItemColorHelper
// ✅ DebugConfig: nav, db, provider logs
// ✅ ViewMode toggle (pinned/favorites/all) ενσωματωμένο
// ✅ Αυτόματη επιλογή φακέλου βάσει ρυθμίσεων (προεπιλεγμένος ή "Γενικά")
// ✅ Περιμένει τα settings πριν επιλέξει φάκελο (διορθωμένο)
// ✅ Filter tags
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'contact_detail_screen.dart';
import '../../helpers/item_color_helper.dart';

final _contactSearchQueryProvider = StateProvider<String>((ref) => '');
final _contactTagFilterProvider = StateProvider<Set<String>>((ref) => {});

// ════════════════════════════════════════════════════════════════
// CONTACT LIST SCREEN
// ════════════════════════════════════════════════════════════════

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() =>
      _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;
  Timer? _debounce;
  int? _selectedFolderId;
  Set<String> _visibleTagNames = {};

  // ✅ Αν ο χρήστης έχει κάνει χειροκίνητη επιλογή, δεν ξαναβάζουμε system folder
  bool _userExplicitlySelected = false;
  bool _autoSelectDone = false;  // ✅ προστέθηκε

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
      DebugConfig.search('ContactList search: "$value"');
      ref.read(_contactSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _searchCtrl.clear();
        ref.read(_contactSearchQueryProvider.notifier).state = '';
        ref.read(_contactTagFilterProvider.notifier).state = {};
      }
    });
    if (_searchActive) {
      Future.microtask(() => _searchFocus.requestFocus());
    }
    DebugConfig.nav('ContactList toggleSearch: $_searchActive');
  }

  Future<void> _createContact() async {
    if (_selectedFolderId == null) {
      DebugConfig.error('ContactList: createContact without selected folder');
      return;
    }

    DebugConfig.nav(
        'ContactList: create contact in folder id=$_selectedFolderId');

    final item = await ref.read(itemNotifierProvider.notifier).create(
      type: ItemType.contact,
      folderId: _selectedFolderId,
    );

    if (item == null || !mounted) return;

    ref.invalidate(itemNotifierProvider);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(
          itemId: item.id,
          isNew: true,
        ),
      ),
    );
  }

  void _openDetail(int id) {
    DebugConfig.nav('ContactList → ContactDetail id=$id');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(
          itemId: id,
          isNew: false,
        ),
      ),
    );
  }

  Future<void> _delete(Item item) async {
    final future =
    ConfirmDialog.delete(context, title: 'Διαγραφή επαφής;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('ContactList delete id=${item.id}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    ref.invalidate(itemNotifierProvider);
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('ContactListScreen build');

    final allAsync = ref.watch(itemsStreamProvider);
    final searchQuery = ref.watch(_contactSearchQueryProvider);
    final activeTags = ref.watch(_contactTagFilterProvider);
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
            DebugConfig.nav('ContactList: auto-selected folder id=$targetId (preferredId=$preferredId)');
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(),
      floatingActionButton: _selectedFolderId != null ? _buildFab() : null,
      body: Column(
        children: [
          if (_searchActive)
            _SearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
            ),

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
                      _userExplicitlySelected = true;   // ο χρήστης επέλεξε χειροκίνητα
                    });
                    DebugConfig.nav('ContactList: select folder id=$id');
                  },
                ),
              );
            },
          ),

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
                    'Επιλέξτε tag για φιλτράρισμα επαφών',
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
                          ref.read(_contactTagFilterProvider);
                          final newSet = {...current};
                          if (newSet.contains(name)) {
                            newSet.remove(name);
                          } else {
                            newSet.add(name);
                          }
                          ref.read(_contactTagFilterProvider.notifier)
                              .state = newSet;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

          const ViewModeToggle(),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(itemNotifierProvider),
              child: allAsync.when(
                loading: () => _LoadingList(),
                error: (e, _) {
                  DebugConfig.error('ContactList load failed', e);
                  return EmptyState.error(
                      onRetry: () => ref.invalidate(itemNotifierProvider));
                },
                data: (allItems) {
                  var contacts = allItems
                      .where((i) => i.type == ItemType.contact)
                      .toList();

                  if (_selectedFolderId != null) {
                    contacts = contacts
                        .where((c) => c.folderId == _selectedFolderId)
                        .toList();
                  }

                  final viewMode = ref.watch(listViewModeProvider);
                  switch (viewMode) {
                    case ListViewMode.pinned:
                      contacts = contacts.where((c) => c.pinned).toList();
                      break;
                    case ListViewMode.favorites:
                      contacts =
                          contacts.where((c) => c.favorite).toList();
                      break;
                    case ListViewMode.all:
                      break;
                  }

                  if (searchQuery.isNotEmpty) {
                    final q = searchQuery.toLowerCase();
                    contacts = contacts
                        .where((c) =>
                        (c.title ?? '').toLowerCase().contains(q))
                        .toList();
                  }

                  if (activeTags.isNotEmpty) {
                    contacts = contacts.where((c) {
                      final tagsAsync =
                          ref.watch(itemTagsProvider(c.id)).valueOrNull ?? [];
                      return tagsAsync
                          .any((tag) => activeTags.contains(tag.name));
                    }).toList();
                  }

                  final visibleTagNames = <String>{};
                  for (final c in contacts) {
                    final tagsAsync =
                        ref.watch(itemTagsProvider(c.id)).valueOrNull ?? [];
                    for (final t in tagsAsync) {
                      visibleTagNames.add(t.name);
                    }
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (!const SetEquality<String>()
                        .equals(_visibleTagNames, visibleTagNames)) {
                      setState(() => _visibleTagNames = visibleTagNames);
                    }
                  });

                  contacts.sort(
                          (a, b) => (a.title ?? '').compareTo(b.title ?? ''));

                  if (contacts.isEmpty) {
                    if (searchQuery.isNotEmpty || activeTags.isNotEmpty) {
                      return EmptyState.search(query: searchQuery);
                    }
                    return EmptyState.forType(ItemType.contact,
                        onAction: _createContact);
                  }

                  return ResponsiveLayout(
                    mobile: _ContactListMobile(
                      contacts: contacts,
                      onTap: (id) => _openDetail(id),
                      onDelete: _delete,
                    ),
                    tablet: _ContactGrid(
                      contacts: contacts,
                      onTap: (id) => _openDetail(id),
                      onDelete: _delete,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: context.cBg,
    elevation: 0,
    scrolledUnderElevation: 1,
    title: const Text('Επαφές'),
    actions: [
      IconButton(
        icon: Icon(_searchActive
            ? Icons.search_off_rounded
            : Icons.search_rounded),
        onPressed: _toggleSearch,
        tooltip: _searchActive ? 'Κλείσιμο αναζήτησης' : 'Αναζήτηση',
      ),
    ],
  );

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: _createContact,
      tooltip: 'Νέα επαφή',
      child: const Icon(Icons.person_add_rounded),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MOBILE LIST — αλφαβητικές ομάδες
// ════════════════════════════════════════════════════════════════

class _ContactListMobile extends StatelessWidget {
  final List<Item> contacts;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;

  const _ContactListMobile({
    required this.contacts,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Item>> groups = {};
    for (final c in contacts) {
      final letter =
      (c.title?.isNotEmpty == true) ? c.title![0].toUpperCase() : '#';
      groups.putIfAbsent(letter, () => []).add(c);
    }
    final letters = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: Spacing.xs),
      itemCount: letters.length,
      itemBuilder: (_, i) {
        final letter = letters[i];
        final group = groups[letter]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.responsiveHPadding,
                Spacing.md,
                context.responsiveHPadding,
                Spacing.xs,
              ),
              child: Text(letter,
                  style: context.labelMd.withColor(context.cText2)),
            ),
            ...group.map((item) => _ContactTile(
              contact: item,
              onTap: () => onTap(item.id),
              onDelete: () => onDelete(item),
            )),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TABLET GRID
// ════════════════════════════════════════════════════════════════

class _ContactGrid extends StatelessWidget {
  final List<Item> contacts;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;

  const _ContactGrid({
    required this.contacts,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.sm,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.gridColumns,
        mainAxisSpacing: Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        mainAxisExtent: 90,
      ),
      itemCount: contacts.length,
      itemBuilder: (_, i) => _ContactTile(
        contact: contacts[i],
        onTap: () => onTap(contacts[i].id),
        onDelete: () => onDelete(contacts[i]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CONTACT TILE — με χρήση ItemColorHelper
// ════════════════════════════════════════════════════════════════

class _ContactTile extends ConsumerWidget {
  final Item contact;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ContactTile({
    required this.contact,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(contact.id));
    final props = propsAsync.valueOrNull ?? [];
    final phone = props.where((p) => p.key == 'phone').firstOrNull?.value;
    final email = props.where((p) => p.key == 'email').firstOrNull?.value;

    final name = contact.title ?? 'Χωρίς όνομα';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final backgroundColor =
    ItemColorHelper.backgroundColorForType(ItemType.contact, context);
    final foregroundColor =
    ItemColorHelper.textColorForBackground(backgroundColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha: 0.7);
    final accentColor =
    ItemColorHelper.iconColorForType(ItemType.contact, context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical: Spacing.xs / 2,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.cardBR,
          border: Border.all(color: ColorsUI.getBorder(context.brightness)),
        ),
        child: Row(
          children: [
            _ContactAvatar(letter: letter, color: accentColor),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: context.titleSm.copyWith(color: foregroundColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (phone != null || email != null)
                    Text(
                      phone ?? email ?? '',
                      style:
                      context.bodySm.copyWith(color: secondaryForeground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (contact.favorite)
              Icon(Icons.star_rounded,
                  size: 16, color: ColorsUI.getWarning(context.brightness)),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: secondaryForeground),
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
// CONTACT AVATAR
// ════════════════════════════════════════════════════════════════

class _ContactAvatar extends StatelessWidget {
  final String letter;
  final Color color;
  const _ContactAvatar({required this.letter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          letter,
          style: context.titleMd.copyWith(color: color),
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
          hintText: 'Αναζήτηση επαφών...',
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
// LOADING LIST
// ════════════════════════════════════════════════════════════════

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.sm,
      ),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, __) => const ItemCardSkeleton(),
    );
  }
}