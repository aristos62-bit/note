// lib/features/appointments/appointment_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import 'appointment_detail_screen.dart';

class AppointmentListScreen extends ConsumerStatefulWidget {
  const AppointmentListScreen({super.key});

  @override
  ConsumerState<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends ConsumerState<AppointmentListScreen> {
  int? _selectedFolderId;
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        title: const Text('Ραντεβού'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: _isGridView ? 'Λίστα' : 'Πλέγμα',
          ),
        ],
      ),
      body: Column(
        children: [
          foldersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (folders) {
              if (folders.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: _AppointmentFolderChips(
                  folders: folders,
                  selectedFolderId: _selectedFolderId,
                  onSelect: (id) {
                    setState(() => _selectedFolderId = id);
                    DebugConfig.nav('AppointmentList: select folder id=$id');
                  },
                ),
              );
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(itemNotifierProvider),
              child: itemsAsync.when(
                loading: () => const _LoadingList(),
                error: (e, _) {
                  DebugConfig.error('AppointmentList load failed', e);
                  return EmptyState.error(
                    onRetry: () => ref.invalidate(itemNotifierProvider),
                  );
                },
                data: (allItems) {
                  final appointments = allItems
                      .where((i) => i.type == ItemType.appointment)
                      .toList();

                  var filtered = appointments;
                  if (_selectedFolderId != null) {
                    filtered = filtered
                        .where((a) => a.folderId == _selectedFolderId)
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    if (_selectedFolderId == null) {
                      return EmptyState.forType(ItemType.appointment, onAction: null);
                    }
                    return EmptyState.forType(
                      ItemType.appointment,
                      onAction: _createAppointment,
                    );
                  }

                  if (_isGridView) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(Spacing.md),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: context.gridColumns,
                        mainAxisSpacing: Spacing.sm,
                        crossAxisSpacing: Spacing.sm,
                        mainAxisExtent: 100,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _AppointmentCard(
                        item: filtered[i],
                        onTap: () => _openDetail(filtered[i].id),
                        onLongPress: () => _showItemActions(context, filtered[i]),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(Spacing.md),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: _AppointmentCard(
                        item: filtered[i],
                        onTap: () => _openDetail(filtered[i].id),
                        onLongPress: () => _showItemActions(context, filtered[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedFolderId != null
          ? FloatingActionButton(
        onPressed: _createAppointment,
        tooltip: 'Νέο ραντεβού',
        child: const Icon(Icons.add_rounded),
      )
          : null,
    );
  }

  void _createAppointment() async {
    if (_selectedFolderId == null) return;

    final notifier = ref.read(itemNotifierProvider.notifier);
    final item = await notifier.create(
      type: ItemType.appointment,
      folderId: _selectedFolderId,
      title: '', // temporary title, will be edited in detail
    );

    if (item == null || !mounted) return;

    ref.invalidate(itemNotifierProvider);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(
          itemId: item.id,
          isNew: true,
        ),
      ),
    );
  }

  void _openDetail(int id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(itemId: id, isNew: false),
      ),
    );
  }

  void _showItemActions(BuildContext context, Item item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => _ItemActionsSheet(
        item: item,
        onPin: () => _togglePin(item),
        onFav: () => _toggleFav(item),
        onArchive: () => _archive(item),
        onDelete: () => _delete(item),
      ),
    );
  }

  Future<void> _togglePin(Item item) async {
    Navigator.pop(context);
    await ref
        .read(itemNotifierProvider.notifier)
        .togglePin(item.id, item.pinned);
    ref.invalidate(itemNotifierProvider);
  }

  Future<void> _toggleFav(Item item) async {
    Navigator.pop(context);
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleFavorite(item.id, item.favorite);
    ref.invalidate(itemNotifierProvider);
  }

  Future<void> _archive(Item item) async {
    Navigator.pop(context);
    final ok = await ConfirmDialog.archive(context);
    if (!ok || !mounted) return;
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleArchive(item.id, item.archived);
    ref.invalidate(itemNotifierProvider);
  }

  Future<void> _delete(Item item) async {
    Navigator.pop(context);
    final ok = await ConfirmDialog.delete(context, title: 'Διαγραφή ραντεβού;');
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    ref.invalidate(itemNotifierProvider);
  }
}

class _AppointmentFolderChips extends StatelessWidget {
  final List<Folder> folders;
  final int? selectedFolderId;
  final ValueChanged<int?> onSelect;

  const _AppointmentFolderChips({
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
        padding: EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
        itemCount: folders.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
        itemBuilder: (ctx, index) {
          if (index == 0) {
            return ChoiceChip(
              label: const Text('Όλοι'),
              selected: selectedFolderId == null,
              onSelected: (_) => onSelect(null),
            );
          }
          final folder = folders[index - 1];
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
            selected: selectedFolderId == folder.id,
            onSelected: (_) => onSelect(folder.id),
          );
        },
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  final Item item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AppointmentCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));

    return propsAsync.when(
      loading: () => _buildCard(context, subtitle: 'Φόρτωση...'),
      error: (_, __) => _buildCard(context, subtitle: 'Σφάλμα φόρτωσης'),
      data: (props) {
        final dateProp = props.firstWhere(
              (p) => p.key == 'date',
          orElse: () => ItemProperty(),
        );
        final timeProp = props.firstWhere(
              (p) => p.key == 'time',
          orElse: () => ItemProperty(),
        );

        String subtitle = '';
        final dateValue = dateProp.value;
        if (dateValue != null && dateValue.isNotEmpty) {
          DateTime? date;
          try {
            date = DateTime.parse(dateValue);
          } catch (_) {}
          if (date != null) {
            subtitle = DateFormat('dd/MM/yyyy').format(date);
          } else {
            subtitle = dateValue;
          }
          final timeValue = timeProp.value;
          if (timeValue != null && timeValue.isNotEmpty) {
            subtitle += ', $timeValue';
          }
        } else {
          subtitle = 'Ημερομηνία μη ορισμένη';
        }

        return _buildCard(context, subtitle: subtitle);
      },
    );
  }

  Widget _buildCard(BuildContext context, {required String subtitle}) {
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: Row(
            children: [
              const Icon(Icons.event_available_rounded),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title ?? 'Χωρίς τίτλο',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: context.cText2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (item.pinned) const Icon(Icons.push_pin, size: 16),
              if (item.favorite) const Icon(Icons.favorite, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemActionsSheet extends StatelessWidget {
  final Item item;
  final VoidCallback onPin;
  final VoidCallback onFav;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _ItemActionsSheet({
    required this.item,
    required this.onPin,
    required this.onFav,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
              horizontal: Spacing.lg,
              vertical: Spacing.xs,
            ),
            child: Text(
              item.title ?? 'Χωρίς τίτλο',
              style: context.titleMd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: item.pinned ? context.cPrimary : context.cText2,
            ),
            title: Text(item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα'),
            onTap: onPin,
          ),
          ListTile(
            leading: Icon(
              item.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: item.favorite
                  ? ColorsUI.getWarning(context.brightness)
                  : context.cText2,
            ),
            title: Text(item.favorite ? 'Αφαίρεση από αγαπημένα' : 'Αγαπημένο'),
            onTap: onFav,
          ),
          ListTile(
            leading: Icon(Icons.archive_rounded, color: context.cText2),
            title: Text(item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση'),
            onTap: onArchive,
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: context.cError),
            title: Text('Διαγραφή', style: TextStyle(color: context.cError)),
            onTap: onDelete,
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical: Spacing.sm,
      ),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, __) => const ItemCardSkeleton(),
    );
  }
}