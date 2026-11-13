// lib/core/utils/app_paths.dart
//
// S-01: SPoT της τοποθεσίας των δεδομένων της εφαρμογής.
//
// Γιατί υπάρχει: μέχρι το S-01 η βάση και τα συνημμένα ζούσαν στο
// `getApplicationDocumentsDirectory()` — στα Windows `%USERPROFILE%\Documents`,
// δηλαδή σε φάκελο που συγχρονίζεται (OneDrive), σαρώνεται (Search/backup) και
// είναι προσβάσιμος από κάθε διεργασία του χρήστη.
//
// Κανόνες (εγκεκριμένοι S-01):
//  • Windows: σταθερή, ρητή ρίζα `%LOCALAPPDATA%\SuperNoteData`.
//    - ΔΕΝ είναι το support dir (εξαρτάται από CompanyName/ProductName του exe).
//    - ΔΕΝ είναι το cache dir (`%LOCALAPPDATA%\com.example\super_note`) — είναι
//      «αναλώσιμο» από ορισμό.
//    - ΔΕΝ είναι ο φάκελος εγκατάστασης (`%LOCALAPPDATA%\SuperNote`), που τον
//      διαγράφει το uninstall.
//    - ΔΕΝ είναι `%APPDATA%\super_note` (το διαγράφει επίσης το uninstall).
//  • Android/iOS/desktop-εκτός-Windows: αμετάβλητο app documents ⇒
//    `dataRoot == legacy` και η μετανάστευση είναι no-op.
//
// Το `activeDataRoot()` είναι η ρίζα που χρησιμοποιείται ΤΩΡΑ (μπορεί να είναι
// το legacy root αν η μετανάστευση απέτυχε και έγινε rollback). Όλοι οι
// callers χρησιμοποιούν αυτό — ποτέ απευθείας `dataRoot()` μετά το init.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachment_path_guard.dart';
import 'debug_config.dart';

class AppPaths {
  AppPaths._();

  /// Όνομα του φακέλου δεδομένων στα Windows (κάτω από `%LOCALAPPDATA%`).
  static const String dataDirName = 'SuperNoteData';

  /// Όνομα της Isar βάσης (χωρίς επέκταση) — ίδιο με το `Isar.open(name:)`.
  static const String dbName = 'super_note_db';

  /// Πλήρες όνομα αρχείου βάσης. Το Isar γράφει `<directory>/<name>.isar`.
  static const String dbFileName = '$dbName.isar';

  /// Scratch φάκελος της μετανάστευσης (πάντα μέσα στη ρίζα ⇒ ίδιο volume).
  static const String stagingDirName = '.staging';

  /// Plaintext snapshots της `MigrationService` (schema migrations).
  static const String migrationSafetyDirName = '.migration_safety';

  static String? _cachedRoot;
  static String? _activeRoot;

  /// Η ρίζα που θα έπρεπε να χρησιμοποιεί η πλατφόρμα (χωρίς I/O πέρα από τα
  /// path_provider calls). Cached — μία φορά ανά process.
  static Future<String> dataRoot() async {
    final cached = _cachedRoot;
    if (cached != null) return cached;
    final root = await _resolve();
    _cachedRoot = root;
    DebugConfig.startup('AppPaths: dataRoot resolved');
    return root;
  }

  /// Η ρίζα που χρησιμοποιείται **τώρα**. Μετά το `SuperNoteHelper.init()`
  /// είναι πάντα το active root (νέο ή legacy μετά από rollback).
  static Future<String> activeDataRoot() async =>
      _activeRoot ?? await dataRoot();

  /// `null` όταν δεν έχει τρέξει ακόμη init (π.χ. σε tests).
  static String? get activeRootOrNull => _activeRoot;

  /// Καλείται **μόνο** από το `SuperNoteHelper.init()`.
  static void setActiveRoot(String root) {
    _activeRoot = p.normalize(root);
  }

  /// Μόνο για tests — καθαρίζει cache + active root.
  static void reset() {
    _cachedRoot = null;
    _activeRoot = null;
  }

  /// Το legacy (προ-S-01) root: app documents. `null` εκτός Windows, γιατί
  /// εκεί documents == dataRoot (καμία μετανάστευση).
  static Future<String?> legacyDataRoot() async {
    if (!Platform.isWindows) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      return p.normalize(docs.path);
    } catch (e) {
      DebugConfig.warning('AppPaths: legacy documents dir unavailable: $e');
      return null;
    }
  }

  /// Το support dir (E50 auto backups). Δεν αλλάζει με το S-01· υπάρχει εδώ
  /// ως SPoT για το S-09/S-10 (rebrand) και για διαγνωστικά UI.
  static Future<String?> supportRoot() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return p.normalize(dir.path);
    } catch (e) {
      DebugConfig.warning('AppPaths: support dir unavailable: $e');
      return null;
    }
  }

  /// Σύγκριση ριζών — case-insensitive στα Windows (το `p.equals` το χειρίζεται).
  static bool sameRoot(String a, String b) => p.equals(a, b);

  static String dbFileIn(String root) => p.join(root, dbFileName);

  static String attachmentsIn(String root) =>
      p.join(root, AttachmentPathGuard.dirName);

  static String stagingIn(String root) => p.join(root, stagingDirName);

  static String migrationSafetyIn(String root) =>
      p.join(root, migrationSafetyDirName);

  /// Pure — ελέγχεται από tests. Επιστρέφει `null` όταν δεν μπορεί να
  /// αποφασίσει (π.χ. Windows χωρίς `LOCALAPPDATA` και χωρίς fallback).
  static String? resolveRoot({
    required bool isWindows,
    String? localAppData,
    String? documentsPath,
    String? supportPath,
  }) {
    if (!isWindows) {
      return documentsPath == null ? null : p.normalize(documentsPath);
    }
    final local = (localAppData ?? '').trim();
    if (local.isNotEmpty) return p.normalize(p.join(local, dataDirName));
    if (supportPath != null) return p.normalize(supportPath);
    if (documentsPath != null) return p.normalize(documentsPath);
    return null;
  }

  static Future<String> _resolve() async {
    if (Platform.isWindows) {
      final direct = resolveRoot(
        isWindows: true,
        localAppData: Platform.environment['LOCALAPPDATA'],
      );
      if (direct != null) return direct;

      // Σπάνιο (υπηρεσία/περιορισμένο περιβάλλον): degraded mode.
      DebugConfig.warning('AppPaths: LOCALAPPDATA λείπει — fallback support');
      try {
        final support = await getApplicationSupportDirectory();
        final fallback =
            resolveRoot(isWindows: true, supportPath: support.path);
        if (fallback != null) return fallback;
      } catch (e) {
        DebugConfig.warning('AppPaths: support dir unavailable: $e');
      }
      DebugConfig.warning('AppPaths: fallback documents (no migration)');
    }
    final docs = await getApplicationDocumentsDirectory();
    return p.normalize(docs.path);
  }
}
