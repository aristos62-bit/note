// lib/core/utils/attachment_path_guard.dart
//
// S-18 (security v2) — SPoT για το «πού επιτρέπεται» ένα attachment path.
//
// Επιτρεπτό root: <documents>/attachments (βλ. [dirName]).
// Ο έλεγχος είναι ΛΕΞΙΚΟΣ (normalize + isWithin) — χωρίς I/O και χωρίς
// symlink resolution (residual R1), ώστε να καλείται άφοβα μέσα σε build().
//
// Fail-closed: unconfigured root, μη-απόλυτο ή σχετικό path, οτιδήποτε εκτός
// root → null. Ο caller δείχνει placeholder ή AppErrors.attachNotFound.
//
// ΧΡΗΣΗ:
//   AttachmentPathGuard.configure(documentsDir: dir);  // SuperNoteHelper.init()
//   final path = AttachmentPathGuard.resolve(attachment.localPath);
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

  /// root = normalize(join(documentsDir, [dirName])).
  /// Idempotent — ξανακαλείται μετά από restore/wipe.
  static void configure({required String documentsDir}) {
    _warnedUnconfigured = false;
    _warnedRejected = false;

    // Το isWithin() αυτο-απολυτοποιεί τη σχετική πλευρά με το CWD
    // (path 1.9.x, context.dart) → ένα σχετικό root θα ήταν CWD-εξαρτώμενο.
    if (!p.isAbsolute(documentsDir)) {
      _root = null;
      DebugConfig.warning(
          'AttachmentPathGuard: non-absolute documentsDir — fail-closed');
      return;
    }

    final next = p.normalize(p.join(documentsDir, dirName));
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
