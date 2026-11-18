// lib/core/utils/cache_cleanup.dart
//
// S-19 (security v2) — SPoT καθαρισμού των προσωρινών αντιγράφων που
// δημιουργούν τα plugins και μένουν πίσω τους:
//   • `share_plus`  → `<cache>/share_plus/` (αντίγραφα για τον παραλήπτη)
//   • `file_picker` → `<cache>/file_picker/<ts>/<name>` (picked αρχεία)
//   • `image_picker`→ `<cache>/<uuid>/<name>` (Android) / tmp (iOS)
//   • `BackupService` → `<temp>/_backup_share_*`, `<temp>/_restore_prepare_*`
//
// ΚΑΝΟΝΕΣ (εγκεκριμένοι S-19):
//  • Διαγράφουμε ΜΟΝΟ μέσα στο temp root (λεξικός έλεγχος normalize+isWithin,
//    ίδιος με το `AttachmentPathGuard`). Οτιδήποτε άλλο → no-op.
//  • Στο desktop οι pickers επιστρέφουν την ΑΡΧΙΚΗ διαδρομή του χρήστη (δεν
//    αντιγράφουν). Αν αυτή βρίσκεται μέσα στο `%TEMP%`, το απλό guard θα την
//    έσβηνε → γι' αυτό τα picked αρχεία περνούν από το [deletePickedFile],
//    που επιτρέπει διαγραφή μόνο σε Android/iOS.
//  • Καμία public μέθοδος δεν πετά: το `getTemporaryDirectory()` μπορεί να
//    αποτύχει (MissingPlugin/IO) και το cleanup δεν πρέπει να σπάσει
//    share/attachment/backup ροές.
//  • Το `share_plus` καθαρίζει το φάκελό του στην ΑΡΧΗ κάθε επόμενου share·
//    το [scheduleSharePlusCleanup] καλύπτει τη «σιωπή» (καμία επόμενη
//    κοινοποίηση). Generation token: διαδοχικά shares δεν πρέπει να σβήσει
//    παλιό timer τα νεότερα αντίγραφα.
import 'dart:async';
import 'dart:io' show Directory, File, Platform;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'debug_config.dart';
import 'string_utils.dart';

class CacheCleanup {
  CacheCleanup._();

  /// SPoT του ονόματος του φακέλου του `share_plus` (Share.kt:29).
  static const String sharePlusDirName = 'share_plus';

  /// Το αντίγραφο του share το διαβάζει ο παραλήπτης — όχι 10s όπως το
  /// workDir του backup. 1 const: αλλάζει εύκολα αν χρειαστεί.
  static const Duration shareDelay = Duration(seconds: 60);

  /// Το share sheet / SAF χρειάζεται το αρχείο ανοιχτό μετά το κλείσιμο.
  static const Duration backupTempDelay = Duration(seconds: 10);

  /// Seam για tests (default: `getTemporaryDirectory`).
  static Future<Directory> Function()? tempRootProvider;

  /// Seam για tests (default: `Platform.isAndroid || Platform.isIOS`).
  static bool Function()? pickerCopiesToTempProvider;

  static String? _rootCache;
  static int _shareGeneration = 0;
  static bool _warnedRootFailure = false;

  static bool get _pickerCopiesToTemp =>
      pickerCopiesToTempProvider?.call() ??
      (Platform.isAndroid || Platform.isIOS);

  /// Κανονικοποιημένο απόλυτο temp root, ή `null` αν δεν είναι διαθέσιμο.
  /// Το αποτέλεσμα cache-άρεται (μία κλήση platform channel ανά session).
  static Future<String?> tempRootPath() async {
    final cached = _rootCache;
    if (cached != null) return cached;
    try {
      final provider = tempRootProvider ?? getTemporaryDirectory;
      final dir = await provider();
      final normalized = p.normalize(dir.path);
      if (!p.isAbsolute(normalized)) {
        _warnRootFailure('non-absolute temp root');
        return null;
      }
      _rootCache = normalized;
      return normalized;
    } catch (e) {
      _warnRootFailure('$e');
      return null;
    }
  }

  /// Λεξικός έλεγχος (normalize + isWithin) — μηδέν I/O, ποτέ exception.
  /// Το ίδιο το root ΔΕΝ θεωρείται «μέσα» (δεν σβήνουμε ποτέ όλο το temp).
  static bool isWithinTemp(String? path, String? root) {
    if (path == null || path.isEmpty) return false;
    if (root == null || root.isEmpty) return false;
    if (!p.isAbsolute(path)) return false;
    return p.isWithin(root, p.normalize(path));
  }

  static Future<bool> isTempPath(String? path) async =>
      isWithinTemp(path, await tempRootPath());

  /// Διαγραφή αρχείου **μόνο** αν είναι μέσα στο temp. Επιστρέφει `true`
  /// μόνο όταν όντως διαγράφηκε. Καθαρίζει και τον άδειο γονικό φάκελο
  /// (π.χ. `<cache>/file_picker/<ts>/`).
  static Future<bool> deleteTempFile(String? path) async {
    if (!isWithinTemp(path, await tempRootPath())) return false;
    return _deleteFile(path!);
  }

  /// Όπως το [deleteTempFile], αλλά μόνο σε Android/iOS: εκεί ο picker
  /// επιστρέφει αντίγραφο στο temp. Στο desktop επιστρέφει την αρχική
  /// διαδρομή του χρήστη → δεν τη σβήνουμε ποτέ.
  static Future<bool> deletePickedFile(String? path) async {
    if (!_pickerCopiesToTemp) return false;
    return deleteTempFile(path);
  }

  /// Recursive διαγραφή φακέλου **μόνο** μέσα στο temp.
  static Future<bool> deleteTempDir(String? path) async {
    if (!isWithinTemp(path, await tempRootPath())) return false;
    final target = path!;
    try {
      final dir = Directory(target);
      if (!await dir.exists()) return false;
      await dir.delete(recursive: true);
      return true;
    } catch (e) {
      DebugConfig.warning('CacheCleanup: temp dir delete failed: '
          '${AppStringUtils.redact(target, label: 'path')} ($e)');
      return false;
    }
  }

  /// Καθαρισμός φακέλου που δημιουργήσαμε εμείς (backup workDir) μετά το
  /// κλείσιμο του share sheet. Fire-and-forget — ίδια συμπεριφορά με τον
  /// παλιό `BackupService._scheduleTempCleanup`.
  static void scheduleTempDir(String? path, {Duration delay = backupTempDelay}) {
    if (path == null || path.isEmpty) return;
    unawaited(Future<void>.delayed(delay, () async {
      final deleted = await deleteTempDir(path);
      if (deleted) DebugConfig.db('CacheCleanup: delayed temp dir deleted');
    }));
  }

  /// Διαγραφή των αντιγράφων του `share_plus` μετά [delay]. Το generation
  /// token ακυρώνει παλιά timers όταν μεσολάβησε νεότερο share.
  static void scheduleSharePlusCleanup({Duration delay = shareDelay}) {
    final generation = ++_shareGeneration;
    unawaited(Future<void>.delayed(delay, () async {
      if (generation != _shareGeneration) return;
      final root = await tempRootPath();
      if (root == null) return;
      final deleted = await deleteTempDir(p.join(root, sharePlusDirName));
      if (deleted) DebugConfig.db('CacheCleanup: share_plus copies deleted');
    }));
  }

  /// Μόνο για tests (tearDown) — καθαρίζει cache + seams + generation.
  static void reset() {
    _rootCache = null;
    _shareGeneration = 0;
    _warnedRootFailure = false;
    tempRootProvider = null;
    pickerCopiesToTempProvider = null;
  }

  static void _warnRootFailure(String reason) {
    if (_warnedRootFailure) return;
    _warnedRootFailure = true;
    DebugConfig.warning('CacheCleanup: temp root unavailable — no-op ($reason)');
  }

  static Future<bool> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      await file.delete();
      DebugConfig.db('CacheCleanup: temp file deleted ($path)');
      await _pruneEmptyParent(path);
      return true;
    } catch (e) {
      DebugConfig.warning('CacheCleanup: temp file delete failed: '
          '${AppStringUtils.redact(path, label: 'path')} ($e)');
      return false;
    }
  }

  /// Best effort: σβήνει τον άδειο γονικό (π.χ. `<ts>` του file_picker) —
  /// ποτέ το temp root, ποτέ φάκελο με άλλα αρχεία.
  static Future<void> _pruneEmptyParent(String path) async {
    try {
      final root = await tempRootPath();
      if (root == null) return;
      final parentPath = p.normalize(p.dirname(path));
      if (parentPath == root || !isWithinTemp(parentPath, root)) return;
      final parent = Directory(parentPath);
      if (!await parent.exists()) return;
      if (await parent.list().isEmpty) await parent.delete();
    } catch (_) {
      // Best effort — κανένα πρόβλημα αν μείνει άδειος φάκελος.
    }
  }
}
