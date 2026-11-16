// lib/services/share/inbound_share.dart
//
// S-13 — καθαρή λογική του **εισερχόμενου** share intent (άλλη εφαρμογή →
// SuperNote). Χωρίς Flutter/Isar/DB: μόνο `path` + προαιρετικό I/O (injected
// στα tests), ώστε να είναι πλήρως unit-testable.
//
// Γιατί ξεχωριστό αρχείο: το `SharedIntentService` κρατά orchestration
// (DB, callbacks, rollback) και έτσι μένει κάτω από ~450 γραμμές.
//
// S-13b: το `receive_sharing_intent` δίνει `type=text` και για **αρχεία**
// `text/*` (txt/md/csv/json/html) που ήρθαν με `EXTRA_STREAM` — στο `path`
// μπαίνει το cache path. Η ταξινόμηση γίνεται με έλεγχο ύπαρξης, αλλιώς θα
// γράφαμε εσωτερικό path ως σώμα σημείωσης και θα χάναμε το αρχείο.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/core.dart';
import 'share_models.dart';

/// Λόγος που ένα αρχείο δεν μπήκε στο πλάνο αποθήκευσης.
enum InboundSkip {
  /// Το αρχείο δεν διαβάζεται/δεν υπάρχει (π.χ. content-URI χωρίς πρόσβαση).
  missing,

  /// Ξεπερνά το όριο **ανά αρχείο** (ρύθμιση χρήστη, ceiling 100 MB).
  tooLarge,

  /// Ξεπεράστηκε το πλήθος (`ShareLimits.maxFiles`).
  tooMany,

  /// Ξεπεράστηκε το **συνολικό** μέγεθος (`ShareLimits.maxTotalBytes`).
  overTotal,
}

/// Υποψήφιο αρχείο με το πραγματικό μέγεθος από τον δίσκο (E09).
class InboundFile {
  const InboundFile({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;
}

/// Αποτέλεσμα ταξινόμησης: κείμενο + πραγματικά αρχεία (σειρά εισόδου).
class InboundContent {
  const InboundContent({required this.text, required this.filePaths});

  final String text;
  final List<String> filePaths;
}

/// Αποτέλεσμα του πλάνου ορίων. Ντετερμινιστικό (greedy, σειρά εισόδου).
class InboundPlan {
  const InboundPlan({required this.accepted, required this.skipped});

  final List<InboundFile> accepted;
  final List<InboundSkip> skipped;

  int get skippedCount => skipped.length;

  /// Παραλείψεις που οφείλονται σε όρια (για μήνυμα) — όχι `missing`.
  int get limitSkippedCount =>
      skipped.where((s) => s != InboundSkip.missing).length;

  bool get hasLimitSkips => limitSkippedCount > 0;
}

/// Κείμενο μετά το clamp + σημαία περικοπής (για ενημέρωση χρήστη).
class ClampedText {
  const ClampedText({required this.text, required this.truncated});

  final String text;
  final bool truncated;
}

class InboundShare {
  InboundShare._();

  // ── ΤΑΞΙΝΟΜΗΣΗ (S-13b) ─────────────────────────────────────

  /// Χωρίζει το intent σε `text` και `filePaths`.
  ///
  /// Ένα `type=text|url` μετράει ως **αρχείο** μόνο όταν το `path` είναι
  /// απόλυτο **και** υπάρχει στον δίσκο — τότε είναι το cache αντίγραφο
  /// αρχείου `text/*` (S-13b). Αλλιώς είναι το ίδιο το κείμενο/URL.
  static Future<InboundContent> classify(
    List<SharedMediaFile> files, {
    Future<bool> Function(String path)? exists,
  }) async {
    final hasFile = exists ?? _defaultExists;
    final textParts = <String>[];
    final filePaths = <String>[];

    for (final f in files) {
      final raw = f.path.trim();
      if (raw.isNotEmpty) {
        if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
          if (p.isAbsolute(raw) && await hasFile(raw)) {
            if (!filePaths.contains(raw)) filePaths.add(raw);
          } else if (!textParts.contains(raw)) {
            textParts.add(raw);
          }
        } else if (!filePaths.contains(raw)) {
          filePaths.add(raw);
        }
      }
      final msg = f.message?.trim() ?? '';
      if (msg.isNotEmpty && !textParts.contains(msg)) textParts.add(msg);
    }

    return InboundContent(
      text: textParts.join('\n').trim(),
      filePaths: filePaths,
    );
  }

  // ── ΠΛΑΝΟ ΟΡΙΩΝ ────────────────────────────────────────────

  /// Μετράει τα αρχεία και εφαρμόζει τα όρια (μία διέλευση, greedy).
  ///
  /// [sizeOf] επιστρέφει το μέγεθος ή `null` όταν το αρχείο δεν διαβάζεται
  /// (→ [InboundSkip.missing]). Στα tests δίνεται stub — κανένα I/O.
  static Future<InboundPlan> planFor(
    List<String> paths, {
    required int perFileBytes,
    int maxFiles = ShareLimits.maxFiles,
    int maxTotalBytes = ShareLimits.maxTotalBytes,
    Future<int?> Function(String path)? sizeOf,
  }) async {
    final measure = sizeOf ?? _defaultSize;
    final candidates = <InboundFile>[];
    final missing = <InboundSkip>[];

    for (final path in paths) {
      final size = await measure(path);
      if (size == null || size < 0) {
        missing.add(InboundSkip.missing);
        continue;
      }
      candidates.add(InboundFile(path: path, sizeBytes: size));
    }

    final body = plan(
      candidates,
      perFileBytes: perFileBytes,
      maxFiles: maxFiles,
      maxTotalBytes: maxTotalBytes,
    );
    return InboundPlan(
      accepted: body.accepted,
      skipped: <InboundSkip>[...missing, ...body.skipped],
    );
  }

  /// Καθαρό πλάνο πάνω σε ήδη μετρημένα αρχεία (χωρίς I/O).
  static InboundPlan plan(
    List<InboundFile> candidates, {
    required int perFileBytes,
    int maxFiles = ShareLimits.maxFiles,
    int maxTotalBytes = ShareLimits.maxTotalBytes,
  }) {
    final accepted = <InboundFile>[];
    final skipped = <InboundSkip>[];
    var total = 0;

    for (final f in candidates) {
      if (f.sizeBytes > perFileBytes) {
        skipped.add(InboundSkip.tooLarge);
        continue;
      }
      if (accepted.length >= maxFiles) {
        skipped.add(InboundSkip.tooMany);
        continue;
      }
      if (total + f.sizeBytes > maxTotalBytes) {
        skipped.add(InboundSkip.overTotal);
        continue;
      }
      accepted.add(f);
      total += f.sizeBytes;
    }

    return InboundPlan(accepted: accepted, skipped: skipped);
  }

  // ── ΚΕΙΜΕΝΟ ────────────────────────────────────────────────

  /// Περιορίζει το κείμενο στο [maxChars] (ίδιο όριο με το εξερχόμενο share).
  /// Χωρίς ellipsis: το μήκος είναι **ακριβώς** το όριο.
  static ClampedText clampText(
    String raw, {
    int maxChars = ShareLimits.maxTextChars,
  }) {
    if (raw.length <= maxChars) {
      return ClampedText(text: raw, truncated: false);
    }
    return ClampedText(
      text: AppStringUtils.truncate(raw, maxChars, ellipsis: ''),
      truncated: true,
    );
  }

  // ── I/O DEFAULTS ───────────────────────────────────────────

  static Future<bool> _defaultExists(String path) async {
    try {
      return await File(path).exists();
    } catch (e) {
      DebugConfig.warning('InboundShare.exists failed (${e.runtimeType})');
      return false;
    }
  }

  static Future<int?> _defaultSize(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      return await f.length();
    } catch (e) {
      DebugConfig.warning('InboundShare.size failed (${e.runtimeType})');
      return null;
    }
  }
}
