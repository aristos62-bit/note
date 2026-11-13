// lib/services/backup/backup_passphrase_cache.dart
//
// S-02 (D2=i, D8): ο κωδικός του αντιγράφου ζει ΜΟΝΟ στη μνήμη της
// τρέχουσας συνεδρίας. Δεν γράφεται σε Keystore/secure storage/DB/αρχείο.
//
// Χρήση:
//  • export (device/share) → αποθηκεύεται μετά από επιτυχημένη προτροπή
//  • auto-backup → διαβάζει το cached κλειδί· αν λείπει, σκιπάρει (D8)
//  • gate εκκίνησης → μία προτροπή ανά εκκίνηση όταν auto-backup ON
class BackupPassphraseCache {
  BackupPassphraseCache._();
  static final BackupPassphraseCache instance = BackupPassphraseCache._();

  String? _passphrase;

  /// Αυξάνεται σε κάθε αλλαγή — επιτρέπει σε callers να ανιχνεύσουν
  /// ακύρωση/αντικατάσταση κλειδιού όσο έτρεχε μια εργασία.
  int _generation = 0;

  String? get passphrase => _passphrase;
  bool get hasPassphrase => _passphrase != null && _passphrase!.isNotEmpty;
  int get generation => _generation;

  void setPassphrase(String value) {
    if (value.isEmpty) return;
    if (_passphrase == value) return;
    _passphrase = value;
    _generation++;
  }

  /// Καθαρισμός (π.χ. wipe / restore — νέο session semantics).
  void clear() {
    if (_passphrase == null) return;
    _passphrase = null;
    _generation++;
  }
}
