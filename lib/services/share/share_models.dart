// lib/services/share/share_models.dart
//
// E39 — μοντέλα του share pipeline: Load → Collect → Choose → Render → Share.
//
// Καθαρό Dart: εξαρτάται μόνο από `models/` (καμία εξάρτηση από Flutter,
// Isar ή share_plus), ώστε να είναι unit-testable. Η μετατροπή σε `XFile`
// γίνεται αποκλειστικά στο `share_attachments.dart`.

import '../../models/item.dart';

/// Επιλογή χρήστη από το sheet κοινοποίησης.
enum ShareMode {
  /// Μόνο κείμενο — πάντα διαθέσιμο (δουλεύει και σε Linux / παλιά Windows).
  textOnly,

  /// Κείμενο + αρχεία — προσφέρεται μόνο όταν υπάρχουν αρχεία.
  textAndFiles,
}

/// Αποτέλεσμα της τελικής κλήσης κοινοποίησης.
///
/// Καθορίζει **αν** θα δείξουμε μήνυμα: το [unavailable] είναι σιωπή
/// (Linux / παλιά Windows δεν υποστηρίζουν αρχεία — δεν είναι σφάλμα).
enum ShareOutcome {
  /// Ολοκληρώθηκε ή ο χρήστης έκλεισε το system sheet — κανένα μήνυμα.
  shared,

  /// Ο χρήστης έκλεισε το options sheet πριν κοινοποιήσει — κανένα μήνυμα.
  cancelled,

  /// Η πλατφόρμα δεν υποστηρίζει την κοινοποίηση — σιωπή, όχι σφάλμα (D2).
  unavailable,

  /// Πραγματικό σφάλμα — μήνυμα στον χρήστη.
  failed,
}

/// Όρια κοινοποίησης (D1). Ό,τι ξεπερνά τα όρια κόβεται **σιωπηλά** και
/// αναφέρεται συγκεντρωτικά (ποτέ crash, ποτέ μπλοκάρισμα του UI).
class ShareLimits {
  ShareLimits._();

  /// Μέγιστο πλήθος αρχείων ανά κοινοποίηση.
  static const int maxFiles = 20;

  /// Μέγιστο συνολικό μέγεθος αρχείων (100 MB).
  static const int maxTotalBytes = 100 * 1024 * 1024;

  /// Μέγιστο μήκος κειμένου (100.000 χαρακτήρες).
  static const int maxTextChars = 100000;

  /// Μέγιστο πλήθος εγγραφών όταν κοινοποιείται ολόκληρη συλλογή.
  static const int maxCollectionEntries = 200;
}

/// Ένα αρχείο προς κοινοποίηση.
///
/// [displayName] είναι το «καθαρό» όνομα που εμφανίζεται **μόνο στο κείμενο**
/// (📎). Το όνομα που βλέπει ο παραλήπτης είναι το basename του [path]: το
/// `share_plus` αγνοεί `XFile.name` / `fileNameOverrides` για path-backed
/// αρχεία (απόφαση D9 — χωρίς αντιγραφή αρχείων στη v1).
class ShareFile {
  const ShareFile({
    required this.path,
    required this.displayName,
    this.mimeType,
    this.sizeBytes = 0,
  });

  /// Απόλυτο path στο documents/app storage.
  final String path;

  /// Καθαρό όνομα για το κείμενο της κοινοποίησης.
  final String displayName;

  /// MIME type (αν είναι γνωστό) — περνά αυτούσιο στο `XFile`.
  final String? mimeType;

  /// Μέγεθος σε bytes (0 = άγνωστο).
  final int sizeBytes;
}

/// Το πλήρες, έτοιμο-για-render payload ενός item.
class ShareBundle {
  const ShareBundle({
    required this.item,
    required this.text,
    this.files = const [],
    this.skippedFiles = 0,
  });

  final Item item;

  /// Πλήρες κείμενο, έτοιμο για `ShareParams.text`.
  final String text;

  /// Αρχεία που πέρασαν τα όρια (D1), με σειρά εμφάνισης.
  final List<ShareFile> files;

  /// Πόσα αρχεία κόπηκαν λόγω ορίων (πλήθος ή μεγέθους) — για ενημέρωση.
  final int skippedFiles;

  bool get hasFiles => files.isNotEmpty;

  int get totalBytes => files.fold<int>(0, (sum, f) => sum + f.sizeBytes);

  /// Αντίγραφο χωρίς αρχεία (για «Μόνο κείμενο» ή fallback πλατφόρμας).
  ShareBundle asTextOnly() =>
      ShareBundle(item: item, text: text, skippedFiles: skippedFiles);
}