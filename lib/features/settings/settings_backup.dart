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

  final BackupExportResult result;
  if (choice == 'device') {
    result = await BackupService.instance.exportToDevice();
  } else {
    result = await BackupService.instance.exportWithShare();
  }

  if (!context.mounted) return;
  if (result.cancelled) return;
  if (result.success) {
    final msg = result.path != null
        ? AppErrors.exportSaved
        : AppErrors.exportOk;
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
    if (!context.mounted)return;
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

  // 5. Atomic restore
  final result = await BackupService.instance.restoreBackup(srcPath);
  if (!context.mounted) return;

  if (result.success) {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Επιτυχής εισαγωγή'),
        content: const Text('Η εφαρμογή θα τερματιστεί τώρα.\n\n'
            'Παρακαλώ ανοίξτε την ξανά για να συνεχίσετε.'),
        actions: [
          TextButton(onPressed: () => exit(0), child: const Text('OK')),
        ],
      ),
    );
  } else {
    messenger.showSnackBar(SnackBar(
      content: Text(result.error ?? AppErrors.restoreFailed),
      backgroundColor: context.cError,
    ));
  }
}

/// Φράση επιβεβαίωσης wipe (display + έλεγχος — μία πηγή).
const wipePhrase = 'ΔΙΑΓΡΑΦΗ ΟΛΩΝ';

Future<void> clearAllData(BuildContext context, WidgetRef ref) async {
  // Πρώτο βήμα: επιβεβαίωση διαγραφής
  final confirm = await ConfirmDialog.delete(
    context,
    title: 'Διαγραφή όλων των δεδομένων',
    subtitle: 'Όλες οι σημειώσεις, εργασίες, συνήθειες και ρυθμίσεις θα διαγραφούν ΟΡΙΣΤΙΚΑ.\n\nΑυτή η ενέργεια ΔΕΝ μπορεί να αναιρεθεί.',
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

  if (confirmationText == null || confirmationText.trim().toUpperCase() != wipePhrase) {
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

  try {
    await SuperNoteHelper.instance.close();

    final isarDir = await getApplicationDocumentsDirectory();
    final isarFile = File('${isarDir.path}/${BackupService.dbFileName}');
    if (await isarFile.exists()) {
      await isarFile.delete();
      DebugConfig.db('Isar database file deleted');
    }

    // E29: durable καθαρισμός OS alarms/tray μετά τη διαγραφή της DB.
    // Reuse του υπάρχοντος primitive (E15-F2): tray + AlarmManager + boot
    // cache. Το Isar.close() περιμένει τα active async txns
    // (isar_common.dart:181) → μετά το close() δεν ξεκινά νέο schedule· ό,τι
    // πρόλαβε έχει ήδη σταλεί στο channel πριν από αυτό το cancelAll.
    await NotificationService.instance.cancelAll();
    final osCache =
        (await NotificationService.instance.getPendingNotifications()).length;
    DebugConfig.notif('clearAllData: cancelAll done, osCache=$osCache');

    // Δεν κάνουμε SuperNoteHelper.init() εδώ – θα γίνει μετά την επανεκκίνηση
    // Εμφανίζουμε dialog και κλείνουμε την εφαρμογή
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Επιτυχής διαγραφή'),
          content: const Text('Όλα τα δεδομένα διαγράφηκαν.\n\nΗ εφαρμογή θα τερματιστεί. Παρακαλώ ανοίξτε την ξανά.'),
          actions: [
            TextButton(
              onPressed: () => exit(0),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // Αν το context δεν είναι mounted, φεύγουμε κατευθείαν
      exit(0);
    }
  } catch (e) {
    DebugConfig.error('Clear all data failed', e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppErrors.wipeFailed),
          backgroundColor: context.cError,
        ),
      );
    }
  }
}
