// lib/services/backup/backup_progress.dart
//
// S-307: κοινό μοντέλο προόδου για την εξαγωγή/επαναφορά αντιγράφου.
//
// Χωρίς Isar/plugins — pure Dart, ώστε να είναι testable και να μπορεί να
// χρησιμοποιηθεί από το service, το container και το zip layer.

/// Τα στάδια της ροής αντιγράφου (μία τιμή ανά ορατή φάση του dialog).
enum BackupPhase {
  snapshot,
  zip,
  encrypt,
  copy,
  decrypt,
  extract,
  verify,
  restore,
}

extension BackupPhaseLabel on BackupPhase {
  /// Ελληνική ετικέτα για το progress dialog.
  String get label {
    switch (this) {
      case BackupPhase.snapshot:
        return 'Λήψη στιγμιότυπου βάσης...';
      case BackupPhase.zip:
        return 'Δημιουργία αρχείου αντιγράφου...';
      case BackupPhase.encrypt:
        return 'Κρυπτογράφηση...';
      case BackupPhase.copy:
        return 'Αποθήκευση στον φάκελο...';
      case BackupPhase.decrypt:
        return 'Αποκρυπτογράφηση...';
      case BackupPhase.extract:
        return 'Εξαγωγή περιεχομένου...';
      case BackupPhase.verify:
        return 'Έλεγχος βάσης δεδομένων...';
      case BackupPhase.restore:
        return 'Επαναφορά δεδομένων...';
    }
  }
}

/// Κατάσταση προόδου ενός σταδίου.
///
/// [total] == 0 σημαίνει «άγνωστο σύνολο» → indeterminate indicator.
class BackupProgress {
  final BackupPhase phase;
  final int done;
  final int total;

  const BackupProgress(this.phase, this.done, this.total);

  /// Ποσοστό 0..1 ή null όταν το σύνολο δεν είναι γνωστό.
  double? get fraction {
    if (total <= 0) return null;
    final value = done / total;
    if (value <= 0) return 0;
    if (value >= 1) return 1;
    return value;
  }
}

/// Callback προόδου — καλείται από τα στάδια του backup.
typedef BackupProgressCallback = void Function(BackupProgress progress);

/// Ακύρωση από τον χρήστη (κουμπί «Ακύρωση» στο progress dialog).
///
/// Τα στάδια την πετούν σε κάθε ασφαλές σημείο· οι callers καθαρίζουν
/// partial/temp artifacts και επιστρέφουν «cancelled» (όχι error).
class BackupCancelledException implements Exception {
  const BackupCancelledException();
  @override
  String toString() => 'BackupCancelledException';
}

/// Ανεπαρκής ελεύθερος χώρος — ξεχωριστό από τα υπόλοιπα σφάλματα ώστε το UI
/// να δείχνει καθαρό, συγκεκριμένο μήνυμα.
class BackupSpaceException implements Exception {
  final String message;
  const BackupSpaceException(this.message);
  @override
  String toString() => 'BackupSpaceException: $message';
}
