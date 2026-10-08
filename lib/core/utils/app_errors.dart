// lib/core/utils/app_errors.dart
//
// SPoT για όλα τα user-facing μηνύματα σφαλμάτων/επιβεβαιώσεων (Φ4a βήμα 5).
// Ενοποιεί ~35 διάσπαρτα strings (31 SnackBars + mixin + dialogs).
// Κανόνας: ίδια κείμενα byte-identical — μοναδικές αλλαγές:
//   browser raw `e.toString()` → saveFailed (leak-fix),
//   drop `:$e` suffixes (λεπτομέρειες μένουν στο DebugConfig.error log).
// Styling (backgroundColor/duration) μένει στους callers.
//
// ΧΡΗΣΗ:
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(content: Text(AppErrors.saveFailed)),
//   );
//
class AppErrors {
  AppErrors._();

  // ── Validation ───────────────────────────────────────────────
  static const needTitle = 'Παρακαλώ προσθέστε τίτλο';
  static const dateRequired = 'Επιλέξτε ημερομηνία';

  // ── PIN ────────────────────────────────────────────────────
  static const pinTooShort = 'Το PIN πρέπει να έχει τουλάχιστον 4 ψηφία';
  static const pinMismatch = 'Τα PIN δεν ταιριάζουν';
  static const pinWrong = 'Το PIN δεν είναι σωστό';

  // ── Save ─────────────────────────────────────────────────────
  static const saveFailed = 'Σφάλμα κατά την αποθήκευση';
  static const attachSaveFailed = 'Αποτυχία αποθήκευσης';

  // ── Archive (label = πεζό ουσιαστικό, π.χ. 'σημείωση') ─────────
  static String archived(String label) => 'Η $label αρχειοθετήθηκε';
  static String restored(String label) => 'Η $label επαναφέρθηκε';
  static const longPressRestoreHint =
      'Πατήστε παρατεταμένα (long press) στο στοιχείο για επαναφορά';

  // ── Move ─────────────────────────────────────────────────────
  static String movedToFolder(String label) =>
      'Μετακινήθηκε στον φάκελο "$label"';

  // ── Attachments ──────────────────────────────────────────────
  static String attachMaxFiles(int max, String label) =>
      'Μέγιστο όριο $max αρχείων για το πεδίο "$label"';
  static String attachExists(String fileName) =>
      'Το αρχείο "$fileName" υπάρχει ήδη';
  static const attachOpenFailed = 'Αδυναμία ανοίγματος του αρχείου';
  static const attachNotFound = 'Το αρχείο δεν βρέθηκε';
  static String attachSaved(String fileName) => 'Αποθηκεύτηκε: $fileName';

  // ── Share / intent ───────────────────────────────────────────
  static const shareFailed = 'Αποτυχία κοινοποίησης';
  static String oversizeSkipped(int n) =>
      '$n αρχείο(α) παραλείφθηκαν (όριο μεγέθους)';

  // ── Backup / restore / wipe ──────────────────────────────────
  static const exportOk = 'Εξαγωγή επιτυχής';
  static const exportSaved = 'Αντίγραφο αποθηκεύτηκε';
  static const exportFailed = 'Σφάλμα εξαγωγής';
  static const backupNotFound = 'Το αρχείο backup δεν βρέθηκε';
  static const backupInvalid = 'Μη έγκυρο αρχείο backup';
  static const restoreFailed = 'Σφάλμα επαναφοράς';
  static const wipeFailed = 'Σφάλμα κατά τη διαγραφή';
  static const wipeConfirmMismatch =
      'Η φράση επιβεβαίωσης δεν είναι σωστή. Η διαγραφή ακυρώθηκε.';

  // ── Contacts / import ────────────────────────────────────────
  static const contactsPermission = 'Χρειάζεται άδεια πρόσβασης στις επαφές';
  static const contactsReadFailed = 'Σφάλμα ανάγνωσης επαφών';
  static const contactsNoneFound = 'Δεν βρέθηκαν επαφές στο κινητό';
  static const contactsLoadFailed = 'Σφάλμα φόρτωσης επαφών';
  static const contactsNoneImported = 'Δεν υπάρχουν εισαγμένες επαφές';

  // ── Loading / lists ──────────────────────────────────────────
  static const loadFailed = 'Σφάλμα φόρτωσης';
  static const noPastReminders = 'Δεν υπάρχουν παρελθούσες υπενθυμίσεις.';
  static const noArchivedItems = 'Δεν υπάρχουν αρχειοθετημένα στοιχεία.';

  // ── Birthday ─────────────────────────────────────────────────
  static String birthdayReplaced(String name) =>
      'Αντικαταστάθηκε η υπενθύμιση γενεθλίων για $name';
  static String birthdayCreated(String name) =>
      'Δημιουργήθηκε ετήσια υπενθύμιση γενεθλίων για $name';

  // ── Calendar ─────────────────────────────────────────────────
  static const eventCreateFailed = 'Σφάλμα δημιουργίας συμβάντος';
}
