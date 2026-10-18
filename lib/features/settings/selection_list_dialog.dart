// lib/features/settings/selection_list_dialog.dart
//
// S254 (F16): κοινός shell για τα 3 list dialogs των Ρυθμίσεων
// (παρελθούσες υπενθυμίσεις / αρχειοθετημένα / εισαγμένες επαφές).
//
// SPoT: SelectionListDialog<T> + SelectionListController<T> +
// showSelectionListDialog<T>. Οι 3 διάλογοι είναι λεπτοί wrappers.
import 'package:flutter/material.dart';
import '../../core/core.dart';

/// Controller για το [SelectionListDialog].
///
/// Κεντρικοποιεί:
///  • επιλογή (toggle / toggleAll / isSelected)
///  • αφαίρεση γραμμών (per-row / bulk) με ΕΝΑΝ guard (S253 parity):
///    isMounted → rebuild → onApplied → auto-pop αν αδειάσει η λίστα.
class SelectionListController<T> {
  SelectionListController._({
    required List<T> items,
    required Set<int> selected,
    required int Function(T item) idOf,
    required void Function(void Function() fn) rebuild,
    required bool Function() isMounted,
    required void Function() pop,
  })  : _items = items,
        _selected = selected,
        _idOf = idOf,
        _rebuild = rebuild,
        _isMounted = isMounted,
        _pop = pop;

  final List<T> _items;
  final Set<int> _selected;
  final int Function(T item) _idOf;
  final void Function(void Function() fn) _rebuild;
  final bool Function() _isMounted;
  final void Function() _pop;

  /// Snapshot των τρεχουσών γραμμών (αντίγραφο).
  List<T> get items => List<T>.of(_items);

  /// Snapshot των επιλεγμένων ids (αντίγραφο).
  Set<int> get selected => Set<int>.of(_selected);

  int get selectedCount => _selected.length;

  bool get allSelected =>
      _items.isNotEmpty && _selected.length == _items.length;

  bool isSelected(T item) => _selected.contains(_idOf(item));

  /// Εναλλαγή μίας γραμμής.
  void toggle(T item) {
    _rebuild(() {
      final id = _idOf(item);
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  /// Επιλογή/αποεπιλογή όλων.
  void toggleAll(bool? value) {
    _rebuild(() {
      if (value == true) {
        _selected
          ..clear()
          ..addAll(_items.map(_idOf));
      } else {
        _selected.clear();
      }
    });
  }

  /// Αφαίρεση γραμμών μετά από async ενέργεια.
  ///
  /// S253 parity: 1 guard `isMounted` → rebuild → [onApplied] → auto-pop.
  /// Ο [onApplied] (π.χ. invalidate) τρέχει ΠΡΙΝ το pop (S251 parity).
  void remove(Iterable<int> ids, {void Function()? onApplied}) {
    if (!_isMounted()) return; // S253: το dialog έκλεισε κατά το await
    final idSet = ids.toSet();
    if (idSet.isEmpty) return;
    _rebuild(() {
      _items.removeWhere((i) => idSet.contains(_idOf(i)));
      _selected.removeAll(idSet);
    });
    onApplied?.call();
    if (_items.isEmpty) _pop();
  }
}

/// Διάλογος λίστας με checkbox επιλογή + bulk actions.
class SelectionListDialog<T> extends StatefulWidget {
  const SelectionListDialog({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    required this.items,
    required this.idOf,
    required this.rowTitle,
    this.rowSubtitle,
    this.rowSecondary,
    required this.actions,
    this.closeLabel = 'Κλείσιμο',
  });

  final IconData icon;
  final Color? iconColor;
  final String Function(int count) title;
  final List<T> items;
  final int Function(T item) idOf;
  final Widget Function(BuildContext ctx, T item) rowTitle;
  final Widget? Function(BuildContext ctx, T item)? rowSubtitle;
  final Widget? Function(
          BuildContext ctx, T item, SelectionListController<T> controller)?
      rowSecondary;
  final List<Widget> Function(
      BuildContext ctx, SelectionListController<T> controller) actions;
  final String closeLabel;

  @override
  State<SelectionListDialog<T>> createState() =>
      _SelectionListDialogState<T>();
}

class _SelectionListDialogState<T> extends State<SelectionListDialog<T>> {
  late final List<T> _items = List<T>.of(widget.items);
  final Set<int> _selected = <int>{};
  late final SelectionListController<T> _controller;
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    _controller = SelectionListController<T>._(
      items: _items,
      selected: _selected,
      idOf: widget.idOf,
      rebuild: (fn) => setState(fn),
      isMounted: () => mounted,
      pop: _popOnce,
    );
  }

  /// Auto-pop ΜΙΑ φορά.
  ///
  /// S254 (F11-class): αν ο χρήστης έκλεισε το dialog (back/barrier) ενώ
  /// έτρεχαν async ops, το route ΔΕΝ είναι πλέον current → ΜΗΝ ξανα-ποπάρεις
  /// (θα έκλεινε και τις Ρυθμίσεις). Το `_popping` καλύπτει close/auto-pop·
  /// το `isCurrent` καλύπτει back/barrier εν μέσω op.
  void _popOnce() {
    if (_popping) return;
    _popping = true;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return; // ήδη σε pop
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.icon, color: widget.iconColor),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              widget.title(_items.length),
              style: context.titleMd,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── "Επιλογή όλων" header ───────────────────────
            CheckboxListTile(
              value: _controller.allSelected,
              tristate: false,
              onChanged: _controller.toggleAll,
              title: Text(
                _controller.allSelected ? 'Αποεπιλογή όλων' : 'Επιλογή όλων',
                style:
                    context.bodyMd.copyWith(fontWeight: FontWeight.bold),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: Spacing.xs),
            ),
            const Divider(height: 1),
            // ── Λίστα ───────────────────────────────────────
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return CheckboxListTile(
                      value: _controller.isSelected(item),
                      onChanged: (_) => _controller.toggle(item),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.only(
                        left: Spacing.xs,
                        right: Spacing.xs,
                      ),
                      title: widget.rowTitle(context, item),
                      subtitle: widget.rowSubtitle?.call(context, item),
                      secondary:
                          widget.rowSecondary?.call(context, item, _controller),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _popOnce,
          child: Text(widget.closeLabel),
        ),
        ...widget.actions(context, _controller),
      ],
    );
  }
}

/// Άνοιγμα του [SelectionListDialog] (κεντρικοποιεί `useRootNavigator: true`).
Future<void> showSelectionListDialog<T>({
  required BuildContext context,
  required IconData icon,
  Color? iconColor,
  required String Function(int count) title,
  required List<T> items,
  required int Function(T item) idOf,
  required Widget Function(BuildContext ctx, T item) rowTitle,
  Widget? Function(BuildContext ctx, T item)? rowSubtitle,
  Widget? Function(
          BuildContext ctx, T item, SelectionListController<T> controller)?
      rowSecondary,
  required List<Widget> Function(
      BuildContext ctx, SelectionListController<T> controller) actions,
  String closeLabel = 'Κλείσιμο',
}) async {
  await showDialog<void>(
    context: context,
    useRootNavigator: true, // ✅ ρητά — αποφεύγουμε GoRouter confusion
    builder: (_) => SelectionListDialog<T>(
      icon: icon,
      iconColor: iconColor,
      title: title,
      items: items,
      idOf: idOf,
      rowTitle: rowTitle,
      rowSubtitle: rowSubtitle,
      rowSecondary: rowSecondary,
      actions: actions,
      closeLabel: closeLabel,
    ),
  );
}
