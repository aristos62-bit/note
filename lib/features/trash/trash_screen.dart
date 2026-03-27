// lib/features/trash/trash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  int? _selectedFolderId;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  // Multi‑selection state
  Set<int> _selectedIds = {};

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
      setState(() {
        _searchQuery = value.trim();
        _clearSelection(); // φιλτράρισμα αλλάζει λίστα → άκυρη επιλογή
      });
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<Item> items) {
    setState(() {
      _selectedIds = items.map((i) => i.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _restoreSelected(List<Item> allItems) async {
    if (_selectedIds.isEmpty) return;
    final confirm = await ConfirmDialog.show(
      context,
      title: 'Επαναφορά επιλεγμένων',
      subtitle: 'Θα επαναφερθούν ${_selectedIds.length} στοιχεία.',
      confirmLabel: 'Επαναφορά',
    );
    if (!confirm) return;

    final idsToRestore = _selectedIds.toList();
    for (final id in idsToRestore) {
      await ref.read(itemNotifierProvider.notifier).restoreItem(id);
    }
    _clearSelection();
    ref.invalidate(trashedItemsStreamProvider);
  }

  Future<void> _permanentDeleteSelected(List<Item> allItems) async {
    if (_selectedIds.isEmpty) return;
    final confirm = await ConfirmDialog.delete(
      context,
      title: 'Οριστική διαγραφή',
      subtitle: 'Θα διαγραφούν οριστικά ${_selectedIds.length} στοιχεία.',
    );
    if (!confirm) return;

    final idsToDelete = _selectedIds.toList();
    for (final id in idsToDelete) {
      await ref.read(itemNotifierProvider.notifier).permanentDelete(id);
    }
    _clearSelection();
    ref.invalidate(trashedItemsStreamProvider);
  }

  Future<void> _restoreSingle(Item item) async {
    await ref.read(itemNotifierProvider.notifier).restoreItem(item.id);
    _clearSelection();
    ref.invalidate(trashedItemsStreamProvider);
  }

  Future<void> _permanentDeleteSingle(Item item) async {
    final confirm = await ConfirmDialog.delete(
      context,
      title: 'Οριστική διαγραφή;',
      subtitle: 'Η ενέργεια δεν μπορεί να αναιρεθεί.',
    );
    if (!confirm) return;
    await ref.read(itemNotifierProvider.notifier).permanentDelete(item.id);
    _clearSelection();
    ref.invalidate(trashedItemsStreamProvider);
  }

  @override
  Widget build(BuildContext context) {
    final trashedAsync = ref.watch(trashedItemsStreamProvider);
    final foldersAsync = ref.watch(foldersStreamProvider);

    // Reset selection when folder changes
    void onFolderChanged(int? id) {
      setState(() {
        _selectedFolderId = id;
        _clearSelection();
      });
    }

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg,
        title: const Text('Κάδος Ανακύκλωσης'),
        actions: [
          // Select all / Clear selection
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_all_rounded, color: context.cText2),
              tooltip: 'Αποεπιλογή',
              onPressed: _clearSelection,
            ),
          if (!_selectedIds.isNotEmpty)
            IconButton(
              icon: Icon(Icons.select_all_rounded, color: context.cText2),
              tooltip: 'Επιλογή όλων',
              onPressed: () {
                final items = trashedAsync.valueOrNull ?? [];
                final filtered = _filterItems(items);
                _selectAll(filtered);
              },
            ),
          // Batch actions
          if (_selectedIds.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.restore_rounded, color: context.cSuccess),
              tooltip: 'Επαναφορά επιλεγμένων',
              onPressed: () => _restoreSelected(trashedAsync.valueOrNull ?? []),
            ),
            IconButton(
              icon: Icon(Icons.delete_forever_rounded, color: context.cError),
              tooltip: 'Οριστική διαγραφή επιλεγμένων',
              onPressed: () => _permanentDeleteSelected(trashedAsync.valueOrNull ?? []),
            ),
          ],
          // Empty trash (always visible)
          IconButton(
            icon: Icon(Icons.delete_sweep_rounded, color: context.cError),
            tooltip: 'Άδειασμα κάδου',
            onPressed: () async {
              final confirm = await ConfirmDialog.delete(
                context,
                title: 'Άδειασμα κάδου;',
                subtitle: 'Όλα τα στοιχεία θα διαγραφούν οριστικά.',
              );
              if (!confirm) return;
              final trashed = trashedAsync.valueOrNull ?? [];
              for (final item in trashed) {
                await ref.read(itemNotifierProvider.notifier)
                    .permanentDelete(item.id);
              }
              _clearSelection();
              ref.invalidate(trashedItemsStreamProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding, Spacing.sm,
              context.responsiveHPadding, Spacing.xs,
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              style: context.bodyMd,
              decoration: InputDecoration(
                hintText: 'Αναζήτηση διαγραμμένων...',
                prefixIcon: Icon(Icons.search_rounded, color: context.cText2),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.close_rounded, color: context.cText2),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                )
                    : null,
                filled: true,
                fillColor: ColorsUI.getSurface(context.brightness),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputBR,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Folder selector
          foldersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (folders) {
              if (folders.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: _TrashFolderChips(
                  folders: folders,
                  selectedFolderId: _selectedFolderId,
                  onSelect: onFolderChanged,
                ),
              );
            },
          ),
          // Trashed items list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(trashedItemsStreamProvider);
                _clearSelection();
              },
              child: trashedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EmptyState.error(),
                data: (trashed) {
                  final filtered = _filterItems(trashed);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 64, color: context.cDisabled),
                          const SizedBox(height: Spacing.md),
                          Text('Ο κάδος είναι άδειος', style: context.titleMd),
                        ],
                      ),
                    );
                  }

                  // Mobile list / Tablet grid
                  if (context.isMobile) {
                    return ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.responsiveHPadding,
                        vertical: Spacing.sm,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
                      itemBuilder: (_, i) => _TrashCard(
                        item: filtered[i],
                        selected: _selectedIds.contains(filtered[i].id),
                        onToggleSelect: () => _toggleSelection(filtered[i].id),
                        onRestore: () => _restoreSingle(filtered[i]),
                        onDelete: () => _permanentDeleteSingle(filtered[i]),
                      ),
                    );
                  } else {
                    return GridView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.responsiveHPadding,
                        vertical: Spacing.sm,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: context.gridColumns,
                        mainAxisSpacing: Spacing.sm,
                        crossAxisSpacing: Spacing.sm,
                        mainAxisExtent: 130, // λίγο μεγαλύτερο για checkbox
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _TrashCard(
                        item: filtered[i],
                        selected: _selectedIds.contains(filtered[i].id),
                        onToggleSelect: () => _toggleSelection(filtered[i].id),
                        onRestore: () => _restoreSingle(filtered[i]),
                        onDelete: () => _permanentDeleteSingle(filtered[i]),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Item> _filterItems(List<Item> all) {
    var filtered = all;
    if (_selectedFolderId != null) {
      filtered = filtered.where((i) => i.folderId == _selectedFolderId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((i) => (i.title ?? '').toLowerCase().contains(q)).toList();
    }
    filtered.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return filtered;
  }
}

// ── Folder chips (ίδια όπως πριν) ────────────────────────────
class _TrashFolderChips extends StatelessWidget {
  final List<Folder> folders;
  final int? selectedFolderId;
  final ValueChanged<int?> onSelect;

  const _TrashFolderChips({
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

// ── Κάρτα διαγραμμένου στοιχείου με checkbox ────────────────
class _TrashCard extends StatelessWidget {
  final Item item;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _TrashCard({
    required this.item,
    required this.selected,
    required this.onToggleSelect,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorsUI.itemTypeColor(item.type, context.brightness);
    final deletedDate = item.deletedAt ?? item.updatedAt ?? item.createdAt;

    // Χρώματα checkbox
    final checkboxBorderColor = selected
        ? context.cPrimary
        : context.cBorder;
    final checkboxBackgroundColor = selected
        ? context.cPrimary
        : Colors.transparent;
    final checkIconColor = selected
        ? ColorsUI.getAccessibleTextColor(context.cPrimary)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: ColorsUI.getSurface(context.brightness),
        borderRadius: AppRadius.cardBR,
        border: Border.all(
          color: selected
              ? context.cPrimary
              : ColorsUI.getBorder(context.brightness),
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox (κύκλος με tick)
          GestureDetector(
            onTap: onToggleSelect,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? context.cPrimary
                    : ColorsUI.getPrimary(context.brightness), // φόντο unchecked = επιφάνεια κάρτας
                border: Border.all(
                  color: selected
                      ? context.cPrimary
                      : context.cBorder.withValues(alpha: 0.7), // λίγο πιο σκούρο περίγραμμα
                  width: selected ? 2 : 1.5,
                ),
              ),
              child: selected
                  ? Icon(
                Icons.check,
                size: 14,
                color: ColorsUI.getAccessibleTextColor(context.cPrimary),
              )
                  : null,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          // Περιεχόμενο (όπως πριν)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ItemTypeIcon(item.type, size: 13, color: color),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      ItemTypeIcon.labelFor(item.type),
                      style: context.labelSm.withColor(color),
                    ),
                    const Spacer(),
                    Text(
                      'Διαγράφηκε ${deletedDate.relative}',
                      style: context.labelSm.withColor(context.cDisabled),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  item.title ?? 'Χωρίς τίτλο',
                  style: context.bodyMd,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Spacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onRestore,
                      icon: Icon(Icons.restore_rounded, size: 16, color: context.cSuccess),
                      label: Text('Επαναφορά', style: context.labelSm.withColor(context.cSuccess)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                    const SizedBox(width: Spacing.sm),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_forever_rounded, size: 16, color: context.cError),
                      label: Text('Οριστική', style: context.labelSm.withColor(context.cError)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}