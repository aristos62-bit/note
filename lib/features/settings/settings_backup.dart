// lib/features/settings/settings_backup.dart
//
// S253 (P2): export / import / wipe (split από settings_screen.dart).
//
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/core.dart';
import '../../helpers/super_note_helper.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';

Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  DebugConfig.db('Settings: export backup');
  final messenger = ScaffoldMessenger.of(context);

  if (BackupService.instance.isMaintenanceActive) {
    _showBusySnackBar(context, messenger);
    return;
  }

  final choice = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Εξαγωγή αντιγράφου'),
      content: const Text('Πώς θέλετε να αποθηκεύσετε το αντίγραφο ασφαλείας;'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'device'),
          child: const Text('Αποθήκευση στη συσκευή'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, 'share'),
          child: const Text('Κοινοποίηση'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Ακύρωση'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;

  if (BackupService.instance.isMaintenanceActive) {
    _showBusySnackBar(context, messenger);
    return;
  }

  final BackupExportResult result;
  if (choice == 'device') {
    result = await BackupService.instance.exportToDevice();
  } else {
    result = await BackupService.instance.exportWithShare();
  }

  if (!context.mounted) return;
  if (result.cancelled) return;
  if (result.success) {
    final msg =
        result.path != null ? AppErrors.exportSaved : AppErrors.exportOk;
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: context.cSuccess,
      duration: const Duration(seconds: 4),
    ));
  } else {
    messenger.showSnackBar(SnackBar(
      content: Text(result.error ?? AppErrors.exportFailed),
      backgroundColor: context.cError,
    ));
  }
}

void _showBusySnackBar(
  BuildContext context,
  ScaffoldMessengerState messenger,
) {
  messenger.showSnackBar(SnackBar(
    content: const Text(AppErrors.backupBusy),
    backgroundColor: context.cError,
  ));
}

Future<void> importBackup(BuildContext context, WidgetRef ref,
    {String? fromPath}) async {
  DebugConfig.db('Settings: import backup');
  final messenger = ScaffoldMessenger.of(context);

  // 1. Επιλογή αρχείου (ή έτοιμο path από αυτόματα αντίγραφα)
  final srcPath = fromPath ?? await BackupService.instance.pickBackupFile();
  if (srcPath == null || !context.mounted) return;

  // 2. Προέλεγχος (υπάρχει / μέγεθος)
  final srcFile = File(srcPath);
  if (!await srcFile.exists()) {
    messenger.showSnackBar(const SnackBar(
      content: Text(AppErrors.backupNotFound),
      backgroundColor: Colors.red,
    ));
    return;
  }

  // 3. Deep validation (προσωρινό Isar instance)
  if (!context.mounted) return;
  // S253 (F11): αν ο χρήστης κλείσει το loading με back, ΜΗΝ ποπάρεις το Settings.
  final navigator = Navigator.of(context, rootNavigator: true);
  var loadingOpen = true;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: Spacing.md),
          Text('Έλεγχος αρχείου backup...'),
        ],
      ),
    ),
  ).whenComplete(() => loadingOpen = false);

  final validation = await BackupService.instance.validateBackupFile(srcPath);

  if (loadingOpen) {
    navigator.pop();
  }

  if (!validation.valid || !context.mounted) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(validation.reason ?? AppErrors.backupInvalid),
      backgroundColor: context.cError,
    ));
    return;
  }

  // 4. Διάλογος επιβεβαίωσης
  final confirm = await ConfirmDialog.show(
    context,
    title: 'Εισαγωγή δεδομένων;',
    subtitle: 'Το backup είναι έγκυρο.\n\n'
        'Τα υπάρχοντα δεδομένα θα αντικατασταθούν.\n'
        'Η εφαρμογή θα τερματιστεί και θα χρειαστεί να την ξανανοίξετε.',
    confirmLabel: 'Εισαγωγή',
    icon: Icons.download_rounded,
  );
  if (!confirm || !context.mounted) return;

  // 5. Atomic restore — barrier dialog ώστε να μη γίνει write όσο κλείνει η DB.
  final restoreNavigator = Navigator.of(context, rootNavigator: true);
  var restoreDialogOpen = true;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: Spacing.md),
            Expanded(child: Text('Επαναφορά αντιγράφου ασφαλείας...')),
          ],
        ),
      ),
    ),
  ).whenComplete(() => restoreDialogOpen = false);

  final result = await BackupService.instance.restoreBackup(srcPath);

  if (restoreDialogOpen) {
    restoreNavigator.pop();
  }

  if (!context.mounted) {
    if (result.success || result.restartRequired) exit(0);
    return;
  }

  if (result.success) {
    await _showRestartDialog(
      context,
      title: 'Επιτυχής εισαγωγή',
      message: 'Η εφαρμογή θα τερματιστεί τώρα.\n\n'
          'Παρακαλώ ανοίξτε την ξανά για να συνεχίσετε.',
    );
  } else if (result.restartRequired) {
    await _showRestartDialog(
      context,
      title: 'Η επαναφορά δεν ολοκληρώθηκε',
      message: '${result.error ?? AppErrors.restoreFailed}\n\n'
          'Η εφαρμογή θα τερματιστεί για να μη συνεχίσει με '
          'μισο-επαναφερμένη βάση.\n'
          'Παρακαλώ ανοίξτε την ξανά.',
    );
  } else {
    messenger.showSnackBar(SnackBar(
      content: Text(result.error ?? AppErrors.restoreFailed),
      backgroundColor: context.cError,
    ));
  }
}

/// Δείχνει restart dialog και τερματίζει ΠΑΝΤΑ την εφαρμογή.
/// Χρησιμοποιείται μετά από restore που άγγιξε τη DB (success ή failure).
Future<void> _showRestartDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  if (!context.mounted) exit(0);
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } finally {
    exit(0);
  }
}

/// Φράση επιβεβαίωσης wipe (display + έλεγχος — μία πηγή).
const wipePhrase = 'ΔΙΑΓΡΑΦΗ ΟΛΩΝ';

Future<void> clearAllData(BuildContext context, WidgetRef ref) async {
  // Πρώτο βήμα: επιβεβαίωση διαγραφής
  final confirm = await ConfirmDialog.delete(
    context,
    title: 'Διαγραφή όλων των δεδομένων',
    subtitle:
        'Όλες οι σημειώσεις, εργασίες, συνήθειες και ρυθμίσεις θα διαγραφούν ΟΡΙΣΤΙΚΑ.\n\nΑυτή η ενέργεια ΔΕΝ μπορεί να αναιρεθεί.',
    confirmLabel: 'Συνέχεια',
  );
  if (!confirm || !context.mounted) return;

  // Δεύτερο βήμα: εισαγωγή επιβεβαιωτικής φράσης
  // Σκόπιμα χωρίς dispose: ο controller πεθαίνει μαζί με το subtree (GC).
  // Πρόωρο dispose (finally/.then) έσκασε σε S120 — use-after-dispose
  // στο pop-animation + keyboard rebuilds.
  final controller = TextEditingController();
  DebugConfig.nav('Settings: open wipe confirm');
  final confirmationText = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: const Text('ΤΕΛΙΚΗ ΕΠΙΒΕΒΑΙΩΣΗ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Για να συνεχίσετε, πληκτρολογήστε την παρακάτω φράση:',
            style: ctx.bodyMd,
          ),
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: ColorsUI.getSurface(ctx.brightness),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: ctx.cError),
            ),
            child: Text(
              wipePhrase,
              style: ctx.titleSm.copyWith(
                color: ctx.cError,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Πληκτρολογήστε εδώ...',
              border: OutlineInputBorder(
                borderRadius: AppRadius.inputBR,
              ),
            ),
            onSubmitted: (_) => Navigator.pop(ctx, controller.text),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('ΑΚΥΡΟ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('ΕΠΙΒΕΒΑΙΩΣΗ'),
        ),
      ],
    ),
  );

  if (confirmationText == null ||
      confirmationText.trim().toUpperCase() != wipePhrase) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppErrors.wipeConfirmMismatch)),
      );
    }
    return;
  }

  // Τρίτο βήμα: πραγματική διαγραφή
  if (!context.mounted) return;
  DebugConfig.db('Settings: starting full database wipe');

  final messenger = ScaffoldMessenger.of(context);
  final wipeNavigator = Navigator.of(context, rootNavigator: true);
  var wipeDialogOpen = true;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: Spacing.md),
            Expanded(child: Text('Διαγραφή δεδομένων...')),
          ],
        ),
      ),
    ),
  ).whenComplete(() => wipeDialogOpen = false);

  var maintenanceOwned = false;
  var dbTouched = false;
  try {
    // E33: gates + drain πριν κλείσει η DB. Αποτυχία → abort ΧΩΡΙΣ close.
    final bool drained;
    try {
      drained = await BackupService.instance.beginDbMaintenance();
    } catch (e) {
      BackupService.instance.endDbMaintenance();
      rethrow;
    }
    if (!drained) {
      if (wipeDialogOpen) wipeNavigator.pop();
      if (context.mounted) _showBusySnackBar(context, messenger);
      return;
    }
    maintenanceOwned = true;

    // Από εδώ και πέρα κάθε αποτυχία → restart.
    dbTouched = true;
    await SuperNoteHelper.instance.close();

    final isarDir = await getApplicationDocumentsDirectory();
    final isarFile = File('${isarDir.path}/${BackupService.dbFileName}');
    if (await isarFile.exists()) {
      await isarFile.delete();
      DebugConfig.db('Isar database file deleted');
    }

    // E33 cleanup: leftovers από restore/rollback.
    await _deleteRestoreLeftovers(isarDir);

    // T3: live attachments — ορφανά μετά τη διαγραφή της DB.
    await _deleteLiveAttachments(isarDir);

    // T3/A: πλήρες wipe — app-owned cache artifacts + migration snapshots.
    await _deleteCacheArtifacts();
    await _deleteMigrationSafety(isarDir);

    // E29: durable καθαρισμός OS alarms/tray μετά τη διαγραφή της DB.
    // Reuse του υπάρχοντος primitive (E15-F2): tray + AlarmManager + boot
    // cache. Το Isar.close() περιμένει τα active async txns
    // (isar_common.dart:181) → μετά το close() δεν ξεκινά νέο schedule· ό,τι
    // πρόλαβε έχει ήδη σταλεί στο channel πριν από αυτό το cancelAll.
    await NotificationService.instance.cancelAll();
    final osCache =
        (await NotificationService.instance.getPendingNotifications()).length;
    DebugConfig.notif('clearAllData: cancelAll done, osCache=$osCache');

    // Δεν κάνουμε SuperNoteHelper.init() εδώ – θα γίνει μετά την επανεκκίνηση.
    if (wipeDialogOpen) wipeNavigator.pop();
    if (!context.mounted) exit(0);
    await _showRestartDialog(
      context,
      title: 'Επιτυχής διαγραφή',
      message: 'Όλα τα δεδομένα διαγράφηκαν.\n\n'
          'Η εφαρμογή θα τερματιστεί. Παρακαλώ ανοίξτε την ξανά.',
    );
  } catch (e) {
    DebugConfig.error('Clear all data failed', e);
    if (wipeDialogOpen) wipeNavigator.pop();

    if (!dbTouched) {
      // Abort πριν το close — η DB είναι άθικτη, άνοιξε τα gates.
      if (maintenanceOwned) {
        BackupService.instance.endDbMaintenance();
      }
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(
          content: const Text(AppErrors.wipeFailed),
          backgroundColor: context.cError,
        ));
      }
    } else {
      // Μετά το close — restart, χωρίς resume των gates.
      if (!context.mounted) exit(0);
      await _showRestartDialog(
        context,
        title: 'Η διαγραφή δεν ολοκληρώθηκε',
        message: '${AppErrors.wipeFailed}\n\n'
            'Η εφαρμογή θα τερματιστεί για να μη συνεχίσει με '
            'κλειστή ή μερικώς διαγραμμένη βάση.\n'
            'Παρακαλώ ανοίξτε την ξανά.',
      );
    }
  }
}

/// Best-effort καθαρισμός αρχείων που μπορεί να άφησε restore/rollback.
/// Δεν αποτυγχάνει το wipe αν κάποιο delete αποτύχει.
Future<void> _deleteRestoreLeftovers(Directory dir) async {
  final safety = File('${dir.path}/_pre_restore_backup.isar');
  final swap = File('${dir.path}/_restore_swap.isar');
  final attSafety = Directory('${dir.path}/_pre_restore_attachments');

  try {
    if (await safety.exists()) {
      await safety.delete();
      DebugConfig.db('Wipe: deleted _pre_restore_backup.isar');
    }
  } catch (e) {
    DebugConfig.warning('Wipe: cleanup _pre_restore_backup.isar failed: $e');
  }

  try {
    if (await swap.exists()) {
      await swap.delete();
      DebugConfig.db('Wipe: deleted _restore_swap.isar');
    }
  } catch (e) {
    DebugConfig.warning('Wipe: cleanup _restore_swap.isar failed: $e');
  }

  try {
    if (await attSafety.exists()) {
      await attSafety.delete(recursive: true);
      DebugConfig.db('Wipe: deleted _pre_restore_attachments');
    }
  } catch (e) {
    DebugConfig.warning('Wipe: cleanup _pre_restore_attachments failed: $e');
  }
}

/// Best-effort καθαρισμός των live attachments μετά τη διαγραφή της DB.
/// Τα αρχεία είναι πλέον ορφανά· ο φάκελος ξαναδημιουργείται on-demand
/// (AttachmentService._getAttachmentsDir). Δεν αποτυγχάνει το wipe αν
/// κάποιο delete αποτύχει.
Future<void> _deleteLiveAttachments(Directory dir) async {
  final attDir =
  Directory('${dir.path}/${AttachmentService.attachmentsDirName}');
  try {
    if (await attDir.exists()) {
      await attDir.delete(recursive: true);
      DebugConfig.db('Wipe: deleted live attachments directory');
    }
  } catch (e) {
    DebugConfig.warning('Wipe: cleanup live attachments failed: $e');
  }
}

/// Best-effort καθαρισμός των app-owned cache artifacts μετά τη διαγραφή της
/// DB: auto backups (SuperNoteBackups), file_picker αντίγραφα, παλιά
/// validation temps κ.λπ. Ο temp φάκελος ξαναδημιουργείται ώστε να μην
/// λείπει μέχρι το restart.
Future<void> _deleteCacheArtifacts() async {
  try {
    final cacheDir = await getTemporaryDirectory();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      DebugConfig.db('Wipe: cache directory deleted');
    }
    await cacheDir.create(recursive: true);
  } catch (e) {
    DebugConfig.warning('Wipe: cleanup cache failed: $e');
  }
}

/// Best-effort καθαρισμός των stale migration safety snapshots (docs dir).
Future<void> _deleteMigrationSafety(Directory dir) async {
  final safetyDir = Directory('${dir.path}/.migration_safety');
  try {
    if (await safetyDir.exists()) {
      await safetyDir.delete(recursive: true);
      DebugConfig.db('Wipe: deleted .migration_safety');
    }
  } catch (e) {
    DebugConfig.warning('Wipe: cleanup .migration_safety failed: $e');
  }
}
