// lib/features/settings/settings_backup.dart
//
// S253 (P2): export / import / wipe (split από settings_screen.dart).
// S-02: κρυπτογραφημένα αντίγραφα (.snb) + δύο φάσεις import
//       (prepare → confirm → restorePrepared).
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';
import '../../helpers/super_note_helper.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';
import 'backup_progress_dialog.dart';
import 'settings_backup_passphrase.dart';
import 'settings_pin_dialogs.dart';

Future<void> exportBackup(BuildContext context, WidgetRef ref) =>
    _runExport(context, ref, share: false);

/// S-307 (Δ2): ξεχωριστό tile «Κοινοποίηση» — ίδιο χτίσιμο, share sheet.
Future<void> shareBackup(BuildContext context, WidgetRef ref) =>
    _runExport(context, ref, share: true);

Future<void> _runExport(
  BuildContext context,
  WidgetRef ref, {
  required bool share,
}) async {
  DebugConfig.db('Settings: ${share ? 'share' : 'export'} backup');
  final messenger = ScaffoldMessenger.of(context);

  if (_isBusyNow()) {
    _showBusySnackBar(context, messenger);
    return;
  }

  // S-04: ευαίσθητη ενέργεια — βιομετρικό/PIN πριν από dialogs/αρχεία.
  if (!await confirmSensitiveAction(
    context,
    ref,
    reason: share
        ? 'Επιβεβαιώστε την ταυτότητά σας για κοινοποίηση αντιγράφου'
        : 'Επιβεβαιώστε την ταυτότητά σας για εξαγωγή αντιγράφου',
  )) {
    return;
  }
  if (!context.mounted) return;

  // Δ6: κωδικός ΜΟΝΟ όταν είναι ON το «Κλείδωμα αντιγράφου». Αλλιώς το
  // container χρησιμοποιεί το ενσωματωμένο κλειδί (Δ1) — μηδέν προτροπές.
  final settings = ref.read(settingsStreamProvider).valueOrNull;
  if (settings?.backupLockEnabled ?? false) {
    final passphrase = await ensureBackupPassphrase(
      context,
      requireConfirmation: !BackupPassphraseCache.instance.hasPassphrase,
    );
    if (passphrase == null || !context.mounted) return;
  }

  if (_isBusyNow()) {
    _showBusySnackBar(context, messenger);
    return;
  }

  final result = await showBackupProgressDialog<BackupExportResult>(
    context: context,
    title: share ? 'Κοινοποίηση αντιγράφου' : 'Εξαγωγή αντιγράφου',
    task: (controller) {
      bool isCancelled() => controller.isCancelled;
      return share
          ? BackupService.instance.exportWithShare(
              onProgress: controller.report,
              isCancelled: isCancelled,
            )
          : BackupService.instance.exportToDevice(
              onProgress: controller.report,
              isCancelled: isCancelled,
            );
    },
  );

  if (!context.mounted) return;
  if (result == null) {
    messenger.showSnackBar(SnackBar(
      content: const Text(AppErrors.exportFailed),
      backgroundColor: context.cError,
    ));
    return;
  }
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

/// S-307 (Δ4): busy = ροή αντιγράφου σε εξέλιξη ή restore/wipe (E33).
bool _isBusyNow() =>
    BackupService.instance.isBusy || BackupService.instance.isMaintenanceActive;

Future<void> importBackup(BuildContext context, WidgetRef ref,
    {String? fromPath}) async {
  DebugConfig.db('Settings: import backup');
  final messenger = ScaffoldMessenger.of(context);

  // S-04: ευαίσθητη ενέργεια — πύλη πριν από file picker/validation/restore.
  if (_isBusyNow()) {
    _showBusySnackBar(context, messenger);
    return;
  }
  if (!await confirmSensitiveAction(
    context,
    ref,
    reason: 'Επιβεβαιώστε την ταυτότητά σας για εισαγωγή αντιγράφου',
  )) {
    return;
  }
  if (!context.mounted) return;

  // 1. Επιλογή αρχείου (ή έτοιμο path από αυτόματα αντίγραφα)
  final srcPath = fromPath ?? await BackupService.instance.pickBackupFile();
  if (srcPath == null || !context.mounted) return;

  // 2. Μορφή από magic bytes — τα extensions δεν αρκούν (N1).
  final format = await BackupContainer.detectFormat(srcPath);
  if (!context.mounted) return;
  if (format == BackupFormat.unknown) {
    messenger.showSnackBar(SnackBar(
      content: const Text(AppErrors.backupInvalid),
      backgroundColor: context.cError,
    ));
    return;
  }

  // 3. Κωδικός ΜΟΝΟ για legacy/κλειδωμένα `.snb` (Δ1: τα νέα δεν τον έχουν).
  String? passphrase;
  if (format == BackupFormat.snb) {
    var requires = false;
    try {
      requires = await BackupContainer.requiresPassphrase(srcPath);
    } on SnbFormatException catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: context.cError,
      ));
      return;
    }
    if (!context.mounted) return;
    if (requires) {
      passphrase = await showBackupPassphraseDialog(
        context,
        title: 'Κωδικός αντιγράφου',
        message: 'Το αντίγραφο είναι κλειδωμένο.\n'
            'Εισάγετε τον κωδικό που χρησιμοποιήθηκε κατά την εξαγωγή.',
        confirmLabel: 'Έλεγχος',
        initial: BackupPassphraseCache.instance.passphrase,
      );
      if (passphrase == null || !context.mounted) return;
    }
  }

  // 4. Prepare (S-02): decrypt → allowlist extract → probe → strip lock.
  //    Δεν αγγίζει τη live DB — μια αποτυχία είναι πλήρως ασφαλής.
  final prep = await showBackupProgressDialog<BackupPrepareResult>(
    context: context,
    title: 'Έλεγχος αρχείου',
    task: (controller) => BackupService.instance.prepare(
      srcPath,
      passphrase: passphrase,
      onProgress: controller.report,
      isCancelled: () => controller.isCancelled,
    ),
  );

  if (!context.mounted) {
    final prepared = prep?.prepared;
    if (prepared != null) {
      await BackupService.instance.discardPrepared(prepared);
    }
    return;
  }
  if (prep == null) {
    messenger.showSnackBar(SnackBar(
      content: const Text(AppErrors.backupInvalid),
      backgroundColor: context.cError,
    ));
    return;
  }
  if (prep.cancelled) return;
  if (!prep.success) {
    messenger.showSnackBar(SnackBar(
      content: Text(prep.error ?? AppErrors.backupInvalid),
      backgroundColor: context.cError,
    ));
    return;
  }

  final prepared = prep.prepared!;
  if (!context.mounted) {
    await BackupService.instance.discardPrepared(prepared);
    return;
  }

  // 5. Διάλογος επιβεβαίωσης
  final lockNote = prepared.strippedAppLock
      ? '\n\nΤο κλείδωμα εφαρμογής και τα βιομετρικά του αντιγράφου '
          'δεν μεταφέρονται — θα χρειαστεί να τα ενεργοποιήσετε ξανά.'
      : '';
  final confirm = await ConfirmDialog.show(
    context,
    title: 'Εισαγωγή δεδομένων;',
    subtitle: 'Το backup είναι έγκυρο.\n\n'
        'Τα υπάρχοντα δεδομένα θα αντικατασταθούν.\n'
        'Η εφαρμογή θα τερματιστεί και θα χρειαστεί να την ξανανοίξετε.'
        '$lockNote',
    confirmLabel: 'Εισαγωγή',
    icon: Icons.download_rounded,
  );
  if (!confirm || !context.mounted) {
    await BackupService.instance.discardPrepared(prepared);
    return;
  }

  // 6. Atomic restore — progress dialog (μη ακυρώσιμο: μισο-επαναφορά =
  //    restartRequired, οπότε δεν επιτρέπουμε ακύρωση στη μέση).
  final result = await showBackupProgressDialog<BackupImportResult>(
    context: context,
    title: 'Επαναφορά αντιγράφου',
    task: (controller) => BackupService.instance.restorePrepared(
      prepared,
      onProgress: controller.report,
    ),
    cancellable: false,
  );

  if (!context.mounted) {
    if (result != null && (result.success || result.restartRequired)) exit(0);
    return;
  }
  if (result == null) {
    messenger.showSnackBar(SnackBar(
      content: const Text(AppErrors.restoreFailed),
      backgroundColor: context.cError,
    ));
    return;
  }

  final lockStrippedNote = prepared.strippedAppLock
      ? '\n\n${AppErrors.backupLockStripped}'
      : '';

  if (result.success) {
    await _showRestartDialog(
      context,
      title: 'Επιτυχής εισαγωγή',
      message: 'Η εφαρμογή θα τερματιστεί τώρα.\n\n'
          'Παρακαλώ ανοίξτε την ξανά για να συνεχίσετε.'
          '$lockStrippedNote',
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
  final messenger = ScaffoldMessenger.of(context);

  // S-04: ευαίσθητη ενέργεια — πύλη πριν από dialogs/wipe.
  if (BackupService.instance.isMaintenanceActive) {
    _showBusySnackBar(context, messenger);
    return;
  }
  if (!await confirmSensitiveAction(
    context,
    ref,
    reason: 'Επιβεβαιώστε την ταυτότητά σας για διαγραφή όλων των δεδομένων',
  )) {
    return;
  }
  if (!context.mounted) return;

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

    // S-01: η ενεργή ρίζα δεδομένων (legacy αν η μετανάστευση έκανε rollback).
    final dataRootPath = await AppPaths.activeDataRoot();
    final isarDir = Directory(dataRootPath);
    final isarFile = File('${isarDir.path}/${BackupService.dbFileName}');
    if (await isarFile.exists()) {
      await isarFile.delete();
      DebugConfig.db('Isar database file deleted');
    }

    // S-01: lock αρχείο του Isar = `<db>-lck` (όχι `.isar.lock`).
    try {
      final isarLock = File('${isarFile.path}-lck');
      if (await isarLock.exists()) await isarLock.delete();
    } catch (e) {
      DebugConfig.warning('Wipe: cleanup isar lock failed: $e');
    }

    // S-01: το legacy root (Documents στα Windows) — allowlist μόνο.
    await _deleteLegacyLeftovers();

    // E33 cleanup: leftovers από restore/rollback.
    await _deleteRestoreLeftovers(isarDir);

    // T3: live attachments — ορφανά μετά τη διαγραφή της DB.
    await _deleteLiveAttachments(isarDir);

    // T3/A: πλήρες wipe — app-owned cache artifacts + migration snapshots.
    await _deleteCacheArtifacts();
    await _deleteMigrationSafety(isarDir);
    // E50: τα auto backups ΔΕΝ είναι πλέον cache artifacts (support dir).
    await _deleteAutoBackups();

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
/// DB: file_picker αντίγραφα, παλιά validation/export temps, temp zip του
/// auto-backup κ.λπ. Ο temp φάκελος ξαναδημιουργείται ώστε να μην λείπει μέχρι
/// το restart.
///
/// E50: τα auto backups (`SuperNoteBackups`) **δεν** ζουν πλέον εδώ — είναι
/// στο support dir και καθαρίζονται ρητά από το [_deleteAutoBackups].
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

/// E50: διαγραφή των auto backups του support dir (`files/` στο Android).
/// **Μόνο** ο υποφάκελος `SuperNoteBackups` — ποτέ ολόκληρο το `files/`, που
/// περιέχει και άλλα app-owned αρχεία. Best-effort: δεν αποτυγχάνει το wipe.
Future<void> _deleteAutoBackups() async {
  try {
    final support = await getApplicationSupportDirectory();
    final dir =
        Directory('${support.path}/${BackupService.autoBackupDirName}');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      DebugConfig.db('Wipe: deleted auto backups directory');
    }
  } catch (e) {
    DebugConfig.warning('Wipe: cleanup auto backups failed: $e');
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

/// S-01: «Διαγραφή όλων» πρέπει να σβήνει και τα **legacy** δεδομένα
/// (Documents στα Windows), αλλιώς μένει βάση/συνημμένα στο προφίλ του χρήστη.
///
/// **Allowlist μόνο** — ποτέ recursive delete του legacy root:
///  • `<legacy>/super_note_db.isar`            (βάση)
///  • `<legacy>/super_note_db.isar-lck`        (lock του Isar)
///  • `<legacy>/.migration_safety/`            (snapshots της S-01 / schema)
///  • `<legacy>/.staging/`                     (ημιτελής μετανάστευση)
///  • `<legacy>/attachments/`                  (συνημμένα)
/// Αν η ενεργή ρίζα **είναι** η legacy (rolled-back migration, Android), τα
/// παραπάνω έχουν ήδη διαγραφεί από το κύριο flow — οι έλεγχοι ύπαρξης
/// κάνουν την κλήση no-op.
Future<void> _deleteLegacyLeftovers() async {
  final String? legacy;
  try {
    legacy = await AppPaths.legacyDataRoot();
  } catch (e) {
    DebugConfig.warning('Wipe: legacy root unavailable: $e');
    return;
  }
  if (legacy == null) return;

  try {
    final active = await AppPaths.activeDataRoot();
    if (AppPaths.sameRoot(active, legacy)) return;
    final legacyDir = Directory(legacy);
    if (!await legacyDir.exists()) return;

    final dbFile = File('${legacyDir.path}/${BackupService.dbFileName}');
    if (await dbFile.exists()) {
      await dbFile.delete();
      DebugConfig.db('Wipe: deleted legacy DB');
    }
    final lockFile = File('${dbFile.path}-lck');
    if (await lockFile.exists()) {
      await lockFile.delete();
      DebugConfig.db('Wipe: deleted legacy DB lock');
    }
    for (final name in <String>[
      AppPaths.migrationSafetyDirName,
      AppPaths.stagingDirName,
      AttachmentService.attachmentsDirName,
    ]) {
      final dir = Directory('${legacyDir.path}/$name');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        DebugConfig.db('Wipe: deleted legacy $name');
      }
    }
  } catch (e) {
    DebugConfig.warning('Wipe: legacy leftovers cleanup failed: $e');
  }
}
