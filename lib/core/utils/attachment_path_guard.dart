// lib/core/utils/attachment_path_guard.dart
//
// S-18 (security v2) — SPoT για το «πού επιτρέπεται» ένα attachment path.
// S-25 (security v2) — και «αν το άνοιγμά του εκτελεί κώδικα» (Windows).
//
// Επιτρεπτό root: <appDataDir>/attachments (βλ. [dirName]).
// Ο έλεγχος είναι ΛΕΞΙΚΟΣ (normalize + isWithin) — χωρίς I/O και χωρίς
// symlink resolution (residual R1), ώστε να καλείται άφοβα μέσα σε build().
//
// Fail-closed: unconfigured root, μη-απόλυτο ή σχετικό path, οτιδήποτε εκτός
// root → null. Ο caller δείχνει placeholder ή AppErrors.attachNotFound.
//
// ΧΡΗΣΗ:
//   AttachmentPathGuard.configure(appDataDir: dir);  // SuperNoteHelper.init()
//   final path = AttachmentPathGuard.resolve(attachment.localPath);
import 'dart:io' show Platform;

import 'package:path/path.dart' as p;

import 'debug_config.dart';
import 'string_utils.dart';

class AttachmentPathGuard {
  AttachmentPathGuard._();

  /// SPoT του ονόματος του υποφακέλου μέσα στο app documents.
  /// Το `AttachmentService.attachmentsDirName` το delegate-άρει.
  static const String dirName = 'attachments';

  static String? _root;

  // Μία φορά ανά «γενιά» (configure/reset): ο guard καλείται μέσα σε build()
  // και τα warning γράφουν πάντα (και σε release) — χωρίς flag θα γέμιζε το
  // logcat σε κάθε frame.
  static bool _warnedUnconfigured = false;
  static bool _warnedRejected = false;

  /// root = normalize(join(appDataDir, [dirName])).
  /// Idempotent — ξανακαλείται μετά από restore/wipe.
  static void configure({required String appDataDir}) {
    _warnedUnconfigured = false;
    _warnedRejected = false;

    // Το isWithin() αυτο-απολυτοποιεί τη σχετική πλευρά με το CWD
    // (path 1.9.x, context.dart) → ένα σχετικό root θα ήταν CWD-εξαρτώμενο.
    if (!p.isAbsolute(appDataDir)) {
      _root = null;
      DebugConfig.warning(
          'AttachmentPathGuard: non-absolute appDataDir — fail-closed');
      return;
    }

    final next = p.normalize(p.join(appDataDir, dirName));
    final wasConfigured = _root != null;
    _root = next;
    if (wasConfigured) {
      DebugConfig.db('AttachmentPathGuard: re-configured');
    } else {
      DebugConfig.startup('AttachmentPathGuard: root configured');
    }
  }

  /// Canonical path αν είναι ΕΝΤΟΣ root, αλλιώς null. Pure: μηδέν I/O,
  /// ποτέ exception.
  static String? resolve(String? localPath) {
    if (localPath == null || localPath.isEmpty) return null;

    final root = _root;
    if (root == null) {
      if (!_warnedUnconfigured) {
        _warnedUnconfigured = true;
        DebugConfig.warning('AttachmentPathGuard: not configured — fail-closed');
      }
      return null;
    }

    // Ίδιος λόγος με το configure: χωρίς absolute, το isWithin συγκρίνει με
    // CWD-εξαρτώμενο path. Fail-closed.
    if (!p.isAbsolute(localPath)) {
      _reject(localPath, 'relative path');
      return null;
    }

    final normalized = p.normalize(localPath);
    if (!p.isWithin(root, normalized)) {
      _reject(localPath, 'outside root');
      return null;
    }
    return normalized;
  }

  /// S-25 — επεκτάσεις που το ShellExecute (Windows) **εκτελεί** αντί να
  /// προβάλει. Denylist (όχι πλήρης): συντηρείται εδώ, σε ένα σημείο.
  /// Δεν γίνεται reuse του [AppStringUtils.sanitizeFileName]: εκείνο αλλάζει
  /// το όνομα και κάνει `:` → `_`, κρύβοντας το `file.exe::$DATA` (ADS).
  static const Set<String> launchRiskExtensions = {
    '.exe', '.com', '.scr', '.pif', '.bat', '.cmd', '.msi', '.msp',
    '.msix', '.appx', '.appinstaller', '.application', '.ps1', '.vbs',
    '.vbe', '.js', '.jse', '.ws', '.wsf', '.wsh', '.hta', '.lnk', '.url',
    '.scf', '.reg', '.cpl', '.msc', '.jar', '.chm', '.gadget', '.diagcab',
    '.appref-ms', '.settingcontent-ms',
  };

  /// true όταν το άνοιγμα του [path] στα Windows θα εκτελούσε κώδικα.
  /// Pure: μηδέν I/O, ποτέ exception. `null`/κενό → false (το [resolve]
  /// είναι ήδη fail-closed). Εκτός Windows πάντα false (Android: καμία
  /// αλλαγή). [windows] μόνο για tests — `Platform.isWindows` δεν είναι I/O.
  static bool isRiskyToLaunch(String? path, {bool? windows}) {
    if (path == null || path.isEmpty) return false;
    if (!(windows ?? Platform.isWindows)) return false;
    // Windows: τελικές τελείες/κενά αγνοούνται (`evil.exe.` ≡ `evil.exe`)
    // και το `:` ξεκινά ADS (`evil.exe::$DATA` = ροή του `evil.exe`).
    var name = p.basename(path);
    final colon = name.indexOf(':');
    if (colon != -1) name = name.substring(0, colon);
    name = name.replaceAll(RegExp(r'[. ]+$'), '');
    final dot = name.lastIndexOf('.');
    if (dot == -1) return false;
    return launchRiskExtensions.contains(name.substring(dot).toLowerCase());
  }

  /// Μόνο για tests (tearDown) — καθαρίζει root + flags.
  static void reset() {
    _root = null;
    _warnedUnconfigured = false;
    _warnedRejected = false;
  }

  static void _reject(String path, String reason) {
    if (_warnedRejected) return;
    _warnedRejected = true;
    DebugConfig.warning('AttachmentPathGuard: rejected ($reason) '
        '${AppStringUtils.redact(path, label: 'path')}');
  }
}
