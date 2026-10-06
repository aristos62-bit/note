// lib/shared/widgets/folder_create_sheet.dart
//
// SPoT για το μενού δημιουργίας στοιχείου σε φάκελο.
// Ενοποιεί 2 byte-σχεδόν-identical sheets:
//   folder_browser_screen._showCreateMenu (7 εγγραφές, χωρίς appointment),
//   home_folder_view._showCreateMenu (8 εγγραφές, με appointment).
// Διαφορές που ΔΙΑΤΗΡΟΥΝΤΑΙ στους callers (όχι εδώ):
//   create/open logic + logs + isNew (browser extra:true vs home isNew:true).
// Το sheet επιστρέφει τον επιλεγμένο τύπο (null σε ακύρωση/dismiss),
// κατά το πρότυπο FolderFormDialog.show / showTagPickerSheet.
// Pixel-identical: ίδιο chrome, ίδια σειρά, ίδια emoji/labels.
//
// ΧΡΗΣΗ:
//   final type = await FolderCreateSheet.show(context, folderName: folder.name);
//   if (type == null || !mounted) return;
//   await _createItem(context, type);
//
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import 'sheet_handle.dart';

/// Κοινή λίστα τύπων δημιουργίας (byte-identical με την home-λίστα,
/// που ήταν η πλήρης — ο browser έχανε το appointment).
const kFolderCreateTypes = [
  (ItemType.note, '📝', 'Σημείωση'),
  (ItemType.task, '✅', 'Εργασία'),
  (ItemType.event, '📅', 'Συμβάν'),
  (ItemType.habit, '🔄', 'Συνήθεια'),
  (ItemType.journal, '📖', 'Ημερολόγιο'),
  (ItemType.contact, '👤', 'Επαφή'),
  (ItemType.project, '📦', 'Συλλογή'),
  (ItemType.appointment, '📅', 'Ραντεβού'),
];

class FolderCreateSheet extends StatelessWidget {
  final String folderName;

  const FolderCreateSheet({super.key, required this.folderName});

  /// Ανοίγει το sheet. Επιστρέφει null σε ακύρωση/dismiss.
  /// Το pop γίνεται με sheet-context (όχι blind pop caller).
  static Future<ItemType?> show(
    BuildContext context, {
    required String folderName,
  }) {
    DebugConfig.nav('FolderCreateSheet.show folder="$folderName"');
    return showModalBottomSheet<ItemType?>(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (_) => FolderCreateSheet(folderName: folderName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(
            margin: EdgeInsets.symmetric(vertical: Spacing.sm),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.xs),
            child: Text('Νέο στοιχείο σε "$folderName"',
                style: context.titleSm),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...kFolderCreateTypes.map((t) => ListTile(
                        leading:
                            Text(t.$2, style: const TextStyle(fontSize: 22)),
                        title: Text(t.$3, style: context.bodyMd),
                        trailing: Icon(Icons.chevron_right_rounded,
                            size: 18, color: context.cDisabled),
                        onTap: () {
                          DebugConfig.nav(
                              'FolderCreateSheet select=${t.$1.name}');
                          Navigator.pop(context, t.$1);
                        },
                      )),
                  const SizedBox(height: Spacing.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
