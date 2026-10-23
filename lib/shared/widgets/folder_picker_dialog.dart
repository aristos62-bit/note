// lib/shared/widgets/folder_picker_dialog.dart
//
// S272 (E38): κοινός folder picker + helper επιλογής φακέλου για νέα items.
// SPoT: όλες οι οθόνες δημιουργίας (7 λίστες + Ημερολόγιο) δείχνουν τον ίδιο διάλογο.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

/// Επιλογή φακέλου για νέο item.
///
/// - Αν υπάρχει έγκυρη επιλογή → επιστρέφει αυτήν **χωρίς** διάλογο.
/// - Αν «Όλοι» (null) → ανοίγει τον picker.
/// - `null` = ακύρωση (δεν δημιουργείται item).
///
/// Δεν αλλάζει το `selectedFolderIdProvider` (η επιλογή «Όλοι» μένει κοινή).
Future<int?> resolveFolderForNewItem(BuildContext context, WidgetRef ref) async {
  final current = ref.read(selectedFolderIdProvider);
  if (current != null) {
    final known = ref.read(foldersStreamProvider).valueOrNull;
    if (known == null || known.any((f) => f.id == current)) return current;
    // Ο επιλεγμένος φάκελος διαγράφηκε → καθάρισε και ζήτα νέο.
    ref.read(selectedFolderIdProvider.notifier).state = null;
  }
  return showFolderPickerDialog(context, ref);
}

/// Διάλογος επιλογής φακέλου (χωρίς preselect). `null` = ακύρωση.
Future<int?> showFolderPickerDialog(BuildContext context, WidgetRef ref) async {
  final List<Folder> folders;
  try {
    folders = await ref
        .read(foldersProvider.future)
        .timeout(const Duration(seconds: 5));
  } on TimeoutException {
    DebugConfig.warning('showFolderPickerDialog: timeout');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.loadFailed)),
      );
    }
    return null;
  } catch (e, s) {
    DebugConfig.error('showFolderPickerDialog', e, s);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.loadFailed)),
      );
    }
    return null;
  }
  if (!context.mounted) return null;

  return showDialog<int?>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.folder_rounded),
          SizedBox(width: Spacing.sm),
          Expanded(child: Text('Επιλογή φακέλου')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (folders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(Spacing.md),
                child: Text('Δεν υπάρχουν φάκελοι. Δημιουργήστε έναν πρώτα.'),
              )
            else
              ...folders.map((folder) => ListTile(
                    leading: Text(folder.icon ?? '📁',
                        style: const TextStyle(fontSize: 20)),
                    title: Text(folder.name),
                    onTap: () => Navigator.pop(ctx, folder.id),
                  )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Ακύρωση'),
        ),
      ],
    ),
  );
}
