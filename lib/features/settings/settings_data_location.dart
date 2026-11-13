// lib/features/settings/settings_data_location.dart
//
// S-01 (D6): read-only tile «Τοποθεσία δεδομένων».
//
// Δείχνει πού ζουν **τώρα** η βάση και τα συνημμένα (π.χ.
// `C:\Users\<user>\AppData\Local\SuperNoteData`) και αντιγράφει τη διαδρομή.
// Δεν αλλάζει τίποτα: η τοποθεσία αποφασίζεται από το [AppPaths] (S-01) και
// δεν είναι επιλέξιμη από τον χρήστη.
//
// Χρήση: `SettingsCard(child: SettingsDataLocationTile())`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/core.dart';

/// Πληροφοριακό tile με την ενεργή ρίζα δεδομένων.
class SettingsDataLocationTile extends StatefulWidget {
  const SettingsDataLocationTile({super.key});

  @override
  State<SettingsDataLocationTile> createState() =>
      _SettingsDataLocationTileState();
}

class _SettingsDataLocationTileState extends State<SettingsDataLocationTile> {
  /// Η ρίζα που χρησιμοποιείται τώρα (legacy μετά από rollback migration).
  String? _active;

  /// true όταν υπάρχουν ακόμη αρχεία στο legacy root (π.χ. μετανάστευση
  /// δεν έγινε ή «Διαγραφή όλων» δεν έχει τρέξει).
  bool _legacyLeftovers = false;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? active;
    var leftovers = false;
    try {
      active = await AppPaths.activeDataRoot();
      final legacy = await AppPaths.legacyDataRoot();
      if (legacy != null && !AppPaths.sameRoot(legacy, active)) {
        leftovers = await File(AppPaths.dbFileIn(legacy)).exists() ||
            await Directory(AppPaths.attachmentsIn(legacy)).exists();
      }
    } catch (e) {
      DebugConfig.warning('SettingsDataLocationTile: resolve failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _active = active;
      _legacyLeftovers = leftovers;
      _loaded = true;
    });
  }

  Future<void> _copy() async {
    final path = _active;
    if (path == null) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppErrors.dataLocationCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = _active;
    final subtitle = <String>[
      if (!_loaded)
        '…'
      else if (path == null)
        AppErrors.dataLocationUnavailable
      else
        path,
      if (_legacyLeftovers) AppErrors.dataLocationLegacyLeft,
    ].join('\n');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      leading: Icon(Icons.folder_rounded, color: context.cPrimary, size: 22),
      title: Text(AppErrors.dataLocationTitle, style: context.bodyMd),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            subtitle,
            style: context.bodySm.withColor(
              _legacyLeftovers ? context.cError : context.cText2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppErrors.dataLocationHint,
            style: context.bodySm.withColor(context.cDisabled),
          ),
        ],
      ),
      trailing: Icon(
        Icons.copy_rounded,
        size: 18,
        color: context.cDisabled,
      ),
      onTap: path == null ? null : _copy,
    );
  }
}
