// lib/features/settings/settings_contacts_dialogs.dart
//
// S253 (P2): διάλογοι εισαγωγής επαφών (split από settings_screen.dart).
//
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../core/core.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';

/// Διάλογος επιλογής πεδίων προς import
Future<List<ContactField>?> showFieldSelectionDialog(BuildContext context) async {
  const allFields = ContactField.values;
  final selected = <ContactField>{...allFields};
  DebugConfig.nav('Settings: open field selection');

  return showDialog<List<ContactField>>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) => AlertDialog(
        title: const Text('Επιλογή πεδίων'),
        content: SafeDialogBody(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Επιλέξτε ποια πεδία θα εισαχθούν:',
                style: ctx.bodyMd,
              ),
              const SizedBox(height: Spacing.md),
              ...allFields.map((field) => CheckboxListTile(
                value: selected.contains(field),
                onChanged: (v) {
                  setModal(() {
                    if (v == true) {
                      selected.add(field);
                    } else {
                      selected.remove(field);
                    }
                  });
                },
                title: Text(field.label),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
            ],
          ),
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Άκυρο'),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(ctx, selected.toList()),
            child: Text('Εισαγωγή (${selected.length})'),
          ),
        ],
      ),
    ),
  );
}

/// Διάλογος επιλογής επαφών πριν το import
Future<List<Contact>?> showContactSelectionDialog(
  BuildContext context,
  List<Contact> allContacts,
) async {
  final selected = <Contact>{...allContacts};
  // Σκόπιμα χωρίς dispose: ο controller πεθαίνει μαζί με το subtree (GC).
  // Πρόωρο dispose (finally/.then) έσκασε σε S120 — use-after-dispose
  // στο pop-animation + keyboard rebuilds.
  final searchCtrl = TextEditingController();
  String query = '';
  DebugConfig.nav('Settings: open contact selection');

  return showDialog<List<Contact>?>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) {
        final filtered = query.isEmpty
            ? allContacts
            : allContacts
                .where((c) => (c.displayName ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()))
                .toList();

        return AlertDialog(
          title: const Text('Επιλογή επαφών'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchCtrl,
                  onChanged: (v) => setModal(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'Αναζήτηση...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: SearchClearButton(
                      controller: searchCtrl,
                      iconSize: 20,
                      onCleared: () => setModal(() => query = ''),
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputBR,
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: ColorsUI.getSurface(ctx.brightness),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm, vertical: Spacing.sm,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.select_all_rounded, size: 18),
                      label: const Text('Επιλογή όλων'),
                      onPressed: () => setModal(
                        () => selected.addAll(allContacts),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.deselect_rounded, size: 18),
                      label: const Text('Αποεπιλογή'),
                      onPressed: () => setModal(() => selected.clear()),
                    ),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final contact = filtered[i];
                      final name = contact.displayName ?? '(χωρίς όνομα)';
                      final phone = contact.phones.isNotEmpty
                          ? contact.phones.first.number
                          : null;
                      return CheckboxListTile(
                        value: selected.contains(contact),
                        onChanged: (v) {
                          setModal(() {
                            if (v == true) {
                              selected.add(contact);
                            } else {
                              selected.remove(contact);
                            }
                          });
                        },
                        title: Text(name, style: ctx.bodyMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: phone != null
                            ? Text(phone, style: ctx.bodySm.withColor(ctx.cText2))
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Άκυρο'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, selected.toList()),
              child: Text('Εισαγωγή (${selected.length})'),
            ),
          ],
        );
      },
    ),
  );
}

/// Διάλογος προόδου κατά την εισαγωγή
class SettingsImportProgressDialog extends StatefulWidget {
  final List<Contact> contacts;
  final List<ContactField> fields;
  final int workspaceId;
  final int? folderId;

  const SettingsImportProgressDialog({
    super.key,
    required this.contacts,
    required this.fields,
    required this.workspaceId,
    this.folderId,
  });

  @override
  State<SettingsImportProgressDialog> createState() => SettingsImportProgressDialogState();
}

class SettingsImportProgressDialogState extends State<SettingsImportProgressDialog> {
  ImportProgress _progress = const ImportProgress(
    current: 0, total: 0, status: 'Προετοιμασία...',
  );
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _startImport();
  }

  /// S256/F9: κλείνει το dialog ΜΙΑ φορά.
  ///
  /// Το pop ΔΕΝ γίνεται πλέον μέσα στο `build`: ένα rebuild κατά τη διάρκεια
  /// του pop-animation (media/theme/parent) ξανα-έτρεχε το `build` και
  /// ζητούσε 2ο pop → έκλεινε και το από-κάτω route (οι Ρυθμίσεις).
  /// Pattern parity με S254 `_popOnce` (`selection_list_dialog.dart`).
  ///
  /// Οι callers έχουν ήδη ελέγξει `mounted` (= δεν το έκλεισε ο χρήστης με
  /// back)· εδώ προστίθεται `isCurrent` (= το route δεν είναι ήδη σε
  /// pop-animation — F11-class, S253).
  void _popOnce(ImportResult? result) {
    if (_popped) return;
    _popped = true;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  Future<void> _startImport() async {
    try {
      final result = await ContactImportService.instance.importContacts(
        contacts: widget.contacts,
        fields: widget.fields,
        workspaceId: widget.workspaceId,
        folderId: widget.folderId,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      DebugConfig.nav('Settings: import done imported=${result.imported} '
          'skipped=${result.skipped} errors=${result.errors}');
      if (!mounted) return;
      _popOnce(result);
    } catch (e) {
      // S256/F9b: χωρίς αυτό το δίχτυο το παράθυρο έμενε ανοιχτό χωρίς
      // ενημέρωση. Ίδια SPoTs/μοτίβο με τη ροή (settings_contacts_flow.dart).
      DebugConfig.error('Settings: import contacts failed', e);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      _popOnce(null);
      messenger.showSnackBar(
        const SnackBar(content: Text(AppErrors.contactsImportFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SafeDialogBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Εισαγωγή επαφών...'),
            const SizedBox(height: Spacing.md),
            LinearProgressIndicator(
              value: _progress.total > 0 ? _progress.fraction : null,
            ),
            const SizedBox(height: Spacing.sm),
            if (_progress.contactName.isNotEmpty)
              Text(
                _progress.contactName,
                style: context.bodySm.withColor(context.cText2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (_progress.total > 0)
              Text(
                '${_progress.current} / ${_progress.total}',
                style: context.labelSm.withColor(context.cText2),
              ),
          ],
        ),
      ),
    );
  }
}

/// Διάλογος αποτελεσμάτων
void showImportSummary(BuildContext context, ImportResult result) {
  showDialog(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Αποτέλεσμα εισαγωγής'),
      content: SafeDialogBody(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSummaryRow(
            icon: Icons.check_circle_rounded,
            color: Colors.green,
            label: 'Εισήχθησαν',
            count: result.imported,
          ),
          const SizedBox(height: Spacing.sm),
          SettingsSummaryRow(
            icon: Icons.skip_next_rounded,
            color: Colors.orange,
            label: 'Παραλείφθηκαν (υπάρχουν ήδη)',
            count: result.skipped,
          ),
          const SizedBox(height: Spacing.sm),
          SettingsSummaryRow(
            icon: Icons.error_rounded,
            color: Colors.red,
            label: 'Σφάλματα',
            count: result.errors,
          ),
          if (result.errorDetails.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            const Text('Λεπτομέρειες:'),
            const SizedBox(height: Spacing.xs),
            ...result.errorDetails.take(5).map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  e,
                  style: ctx.bodySm.withColor(ctx.cError),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (result.errorDetails.length > 5)
              Text(
                '...και ${result.errorDetails.length - 5} ακόμα',
                style: ctx.bodySm.withColor(ctx.cText2),
              ),
          ],
        ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Widget γραμμής αποτελέσματος
class SettingsSummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  const SettingsSummaryRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: Spacing.sm),
        Expanded(child: Text(label, style: context.bodyMd)),
        Text('$count', style: context.titleSm),
      ],
    );
  }
}
