// lib/features/settings/settings_contacts_flow.dart
//
// S253 (P2): ροή εισαγωγής/διαχείρισης επαφών (split από settings_screen.dart).
//
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';
import 'selection_list_dialog.dart';
import 'settings_contacts_dialogs.dart';

/// Κύρια ροή import: permission → fetch → contact selection → field selection → folder picker → import → summary
Future<void> importContactsFromDevice(BuildContext context, WidgetRef ref) async {
  final granted = await ContactImportService.instance.requestPermission();
  if (!granted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.contactsPermission)),
      );
    }
    return;
  }

  if (!context.mounted) return;

  // Fetch
  final List<Contact> contacts;
  try {
    contacts = await ContactImportService.instance.fetchContacts();
  } catch (e) {
    DebugConfig.error('Settings fetch contacts', e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.contactsReadFailed)),
      );
    }
    return;
  }
  if (contacts.isEmpty || !context.mounted) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.contactsNoneFound)),
      );
    }
    return;
  }

  // Επιλογή επαφών
  final selectedContacts = await showContactSelectionDialog(context, contacts);
  if (selectedContacts == null || selectedContacts.isEmpty || !context.mounted) {
    return;
  }

  // Επιλογή πεδίων
  final selectedFields = await showFieldSelectionDialog(context);
  if (selectedFields == null || selectedFields.isEmpty || !context.mounted) {
    return;
  }

  // Επιλογή φακέλου
  final folderId = await showFolderPickerDialog(context, ref);
  // folderId == null σημαίνει ακύρωσε → σταματάμε
  if (folderId == null || !context.mounted) return;

  final wsId = ref.read(activeWorkspaceIdProvider);
  if (wsId == null) return;

  // Import με progress
  final result = await showDialog<ImportResult>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => SettingsImportProgressDialog(
      contacts: selectedContacts,
      fields: selectedFields,
      workspaceId: wsId,
      folderId: folderId,
    ),
  );

  if (result != null && context.mounted) {
    showImportSummary(context, result);
  }
}

/// Διάλογος επιλογής φακέλου για την εισαγωγή επαφών
Future<int?> showFolderPickerDialog(BuildContext context, WidgetRef ref) async {
  final folders = await ref.read(foldersProvider.future);
  if (!context.mounted) return null;

  // Αν υπάρχει preferredFolderId από ρυθμίσεις, το προ-επιλέγουμε
  final preferredId = ref.read(settingsNotifierProvider).valueOrNull?.preferredFolderId;

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
                leading: Text(folder.icon ?? '📁', style: const TextStyle(fontSize: 20)),
                title: Text(folder.name),
                selected: folder.id == preferredId,
                trailing: folder.id == preferredId
                    ? Icon(Icons.check, color: context.cPrimary)
                    : null,
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

/// Διάλογος διαχείρισης εισαγμένων επαφών
Future<void> showImportedContactsDialog(BuildContext context, WidgetRef ref) async {
  final List<int> importedIds;
  try {
    importedIds = await ContactImportService.instance.getImportedContactIds();
  } catch (e) {
    DebugConfig.error('Settings imported contacts load', e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.contactsLoadFailed)),
      );
    }
    return;
  }
  if (importedIds.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.contactsNoneImported)),
      );
    }
    return;
  }

  if (!context.mounted) return;

  final items = (await ref.read(dbProvider).items.getByIds(importedIds.toList()))
      .where((i) => i.deletedAt == null)
      .toList();

  if (!context.mounted) return;

  DebugConfig.nav('Settings: open imported contacts');

  await showSelectionListDialog<Item>(
    context: context,
    icon: Icons.person_remove_rounded,
    title: (n) => 'Εισαγμένες Επαφές ($n)',
    items: items,
    idOf: (item) => item.id,
    rowTitle: (ctx, item) => Text(
      item.title ?? '(χωρίς τίτλο)',
      style: ctx.bodyMd,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    rowSecondary: (ctx, item, controller) => IconButton(
      icon: Icon(Icons.delete_outline, color: ctx.cError, size: 20),
      tooltip: 'Διαγραφή',
      onPressed: () async {
        await ContactImportService.instance.deleteImported({item.id});
        controller.remove(
          {item.id},
          onApplied: () => ref.invalidate(itemNotifierProvider),
        );
      },
    ),
    actions: (ctx, controller) {
      final count = controller.selectedCount;
      return [
        if (count > 0)
          FilledButton.tonal(
            onPressed: () async {
              final confirm = await ConfirmDialog.delete(
                ctx,
                title: 'Διαγραφή επιλεγμένων;',
                subtitle: 'Θα διαγραφούν $count επαφές.',
                confirmLabel: 'Διαγραφή',
              );
              if (!confirm) return;
              final ids = controller.selected;
              await ContactImportService.instance.deleteImported(ids);
              controller.remove(
                ids,
                onApplied: () => ref.invalidate(itemNotifierProvider),
              );
            },
            child: Text('Επιλεγμένες ($count)'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ctx.cError,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final confirm = await ConfirmDialog.delete(
              ctx,
              title: 'Διαγραφή όλων;',
              subtitle:
                  'Θα διαγραφούν όλες οι ${controller.items.length} εισαγμένες επαφές.',
              confirmLabel: 'Ναι, διαγραφή όλων',
            );
            if (!confirm) return;
            final ids = controller.items.map((i) => i.id).toSet();
            await ContactImportService.instance.deleteImported(ids);
            controller.remove(
              ids,
              onApplied: () => ref.invalidate(itemNotifierProvider),
            );
          },
          child: const Text('Διαγραφή όλων'),
        ),
      ];
    },
  );
}
