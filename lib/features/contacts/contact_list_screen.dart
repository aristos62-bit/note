// lib/features/contacts/contact_list_screen.dart
//
// Λίστα επαφών με drag & drop folder selector.
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'contact_detail_screen.dart';
import '../../services/services.dart';
import '../../helpers/item_color_helper.dart';
import 'dart:convert';

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen>
    with FolderAutoSelectMixin {
  bool _showArchiveHintShown = false;

  Future<void> _createContact() async {
    final selectedFolderId = ref.read(selectedFolderIdProvider);
    if (selectedFolderId == null) return;
    final item = await ref.read(itemNotifierProvider.notifier).create(
      type: ItemType.contact,
      folderId: selectedFolderId,
    );
    if (item == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(itemId: item.id, isNew: true),
      ),
    );
  }

  void _openDetail(int id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(itemId: id, isNew: false),
      ),
    );
  }

  Future<void> _delete(Item item) async {
    final ok = await ConfirmDialog.delete(context, title: 'Διαγραφή επαφής;');
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(itemsStreamProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);

    // 🆕 Διαβάζουμε το επιλεγμένο folder από τον κεντρικό provider
    final selectedFolderId = ref.watch(selectedFolderIdProvider);

    tryAutoSelectFolder(
      foldersAsync: foldersAsync,
      settingsAsync: settingsAsync,
      debugLabel: 'ContactList',
    );

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(),
      floatingActionButton: selectedFolderId != null
          ? FloatingActionButton(
        onPressed: _createContact,
        tooltip: 'Νέα επαφή',
        child: const Icon(Icons.add_rounded),
      )
          : null,
      body: Column(
        children: [
          const DraggableFolderSelector(),
          const ViewModeToggle(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(itemNotifierProvider),
              child: allAsync.when(
                loading: () => _LoadingList(),
                error: (e, _) => EmptyState.error(
                  onRetry: () => ref.invalidate(itemNotifierProvider),
                ),
                data: (allItems) {
                  var contacts = allItems
                      .where((i) => i.type == ItemType.contact)
                      .toList();

                  if (selectedFolderId != null) {
                    contacts = contacts
                        .where((c) => c.folderId == selectedFolderId)
                        .toList();
                  }

                  final viewMode = ref.watch(listViewModeProvider);
                  switch (viewMode) {
                    case ListViewMode.pinned:
                      contacts = contacts.where((c) => c.pinned).toList();
                      break;
                    case ListViewMode.favorites:
                      contacts = contacts.where((c) => c.favorite).toList();
                      break;
                    case ListViewMode.all:
                      break;
                  }

                  contacts.sort((a, b) => (a.title ?? '').compareTo(b.title ?? ''));

                  final contactProps = <int, _ContactProps>{};
                  for (final c in contacts) {
                    final props = ref.read(itemPropertiesProvider(c.id)).valueOrNull;
                    if (props != null) {
                      contactProps[c.id] = _extractContactProps(props);
                    }
                  }

                  if (contacts.isEmpty) {
                    return EmptyState.forType(ItemType.contact, onAction: _createContact);
                  }

                  return ResponsiveLayout(
                    mobile: _ContactListMobile(contacts: contacts, contactProps: contactProps, onTap: _openDetail, onDelete: _delete, onShare: (item) => ShareService.shareItem(context, item.id)),
                    tablet: _ContactGrid(contacts: contacts, contactProps: contactProps, onTap: _openDetail, onDelete: _delete, onShare: (item) => ShareService.shareItem(context, item.id)),
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
  );
}

// ── Contact props helper ──────────────────────────────────────

typedef _ContactProps = ({String? phone, String? email});

_ContactProps _extractContactProps(List<ItemProperty> props) {
  String? phone;
  final phonesJson = props.where((p) => p.key == 'phones').firstOrNull?.value;
  if (phonesJson != null && phonesJson.isNotEmpty) {
    try {
      final decoded = jsonDecode(phonesJson);
      if (decoded is List && decoded.isNotEmpty) {
        phone = decoded.first.toString();
      }
    } catch (_) {}
  }
  phone ??= props.where((p) => p.key == 'phone').firstOrNull?.value;
  final email = props.where((p) => p.key == 'email').firstOrNull?.value;
  return (phone: phone, email: email);
}

// ──────────────────────────────────────────────
// Mobile list
// ──────────────────────────────────────────────
class _ContactListMobile extends StatelessWidget {
  final List<Item> contacts;
  final Map<int, _ContactProps> contactProps;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;
  final void Function(Item)? onShare;

  const _ContactListMobile({required this.contacts, required this.contactProps, required this.onTap, required this.onDelete, this.onShare});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Item>> groups = {};
    for (final c in contacts) {
      final letter = (c.title?.isNotEmpty == true) ? c.title![0].toUpperCase() : '#';
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
              padding: EdgeInsets.fromLTRB(context.responsiveHPadding, Spacing.md, context.responsiveHPadding, Spacing.xs),
              child: Text(letter, style: context.labelMd.withColor(context.cText2)),
            ),
            ...group.map((item) => Consumer(
              builder: (_, ref, __) {
                final overrideColor = ref.watch(itemTypeCardColorOverrideProvider(item.type));
                return _DraggableContactTile(
                  contact: item,
                  phone: contactProps[item.id]?.phone,
                  email: contactProps[item.id]?.email,
                  onTap: onTap,
                  onDelete: onDelete,
                  onShare: onShare != null ? () => onShare!(item) : null,
                  cardBackgroundColor: overrideColor,
                );
              },
            )),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// Tablet grid
// ──────────────────────────────────────────────
class _ContactGrid extends StatelessWidget {
  final List<Item> contacts;
  final Map<int, _ContactProps> contactProps;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;
  final void Function(Item)? onShare;

  const _ContactGrid({required this.contacts, required this.contactProps, required this.onTap, required this.onDelete, this.onShare});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: Spacing.sm),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.gridColumns,
        mainAxisSpacing: Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        mainAxisExtent: 90,
      ),
      itemCount: contacts.length,
      itemBuilder: (_, i) => Consumer(
        builder: (_, ref, __) {
          final overrideColor = ref.watch(itemTypeCardColorOverrideProvider(contacts[i].type));
          return _DraggableContactTile(
            contact: contacts[i],
            phone: contactProps[contacts[i].id]?.phone,
            email: contactProps[contacts[i].id]?.email,
            onTap: onTap,
            onDelete: onDelete,
            onShare: onShare != null ? () => onShare!(contacts[i]) : null,
            cardBackgroundColor: overrideColor,
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Draggable Contact Tile
// ──────────────────────────────────────────────
class _DraggableContactTile extends StatelessWidget {
  final Item contact;
  final String? phone;
  final String? email;
  final ValueChanged<int> onTap;
  final ValueChanged<Item> onDelete;
  final VoidCallback? onShare;
  final Color? cardBackgroundColor;

  const _DraggableContactTile({
    required this.contact,
    required this.phone,
    required this.email,
    required this.onTap,
    required this.onDelete,
    this.onShare,
    this.cardBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final name = contact.title ?? 'Χωρίς όνομα';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final backgroundColor = cardBackgroundColor ??
        ItemColorHelper.backgroundColorForType(ItemType.contact, context);
    final foregroundColor = ItemColorHelper.textColorForBackground(backgroundColor, context);
    final secondaryForeground = foregroundColor.withValues(alpha: 0.7);
    final accentColor = ItemColorHelper.iconColorForType(ItemType.contact, context);

    final tile = Container(
      margin: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: Spacing.xs / 2),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
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
                Text(name, style: context.titleSm.copyWith(color: foregroundColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (phone != null || email != null)
                  Text(phone ?? email ?? '', style: context.bodySm.copyWith(color: secondaryForeground), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (onShare != null)
            GestureDetector(
              onTap: onShare,
              child: Padding(
                padding: const EdgeInsets.only(left: Spacing.sm),
                child: Icon(Icons.share_rounded, size: 16, color: foregroundColor.withValues(alpha: 0.7)),
              ),
            ),
          if (contact.favorite)
            Icon(Icons.star_rounded, size: 16, color: ColorsUI.getWarning(context.brightness)),
        ],
      ),
    );

    return DraggableItemWrapper(
      itemId: contact.id,
      child: GestureDetector(
        onTap: () => onTap(contact.id),
        onLongPress: () => _showActions(context),
        child: tile,
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(AppRadius.bottomSheet), topRight: Radius.circular(AppRadius.bottomSheet)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: Spacing.sm), width: 40, height: 4, decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(2))),
            ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('Επεξεργασία'), onTap: () { Navigator.pop(context); onTap(contact.id); }),
            ListTile(leading: Icon(Icons.delete_outline_rounded, color: context.cError), title: Text('Διαγραφή', style: TextStyle(color: context.cError)), onTap: () { Navigator.pop(context); onDelete(contact); }),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Avatar, SearchBar, TagFilterRow, LoadingList
// ──────────────────────────────────────────────
class _ContactAvatar extends StatelessWidget {
  final String letter;
  final Color color;
  const _ContactAvatar({required this.letter, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
    child: Center(child: Text(letter, style: context.titleMd.copyWith(color: color))),
  );
}

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding, vertical: Spacing.sm),
    itemCount: 5,
    separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
    itemBuilder: (_, __) => const ItemCardSkeleton(),
  );
}