// lib/services/share_service.dart
//
// E39 — Orchestrator της κοινοποίησης: Load → Choose → Render → Share.
//
// Η λογική ζει πλέον σε μικρά, testable αρχεία:
//   share/share_models.dart            μοντέλα + όρια (D1)
//   share/share_text.dart              κείμενο ανά τύπο (D2–D7)
//   share/share_formatters.dart        μέγεθος / ονόματα / 📎 λίστα
//   share/share_loader.dart            batch φόρτωση (χωρίς N+1)
//   share/share_attachments.dart       φίλτρα + όρια + XFile
//   share/share_content_builder.dart   σύνθεση bundle
//   share/share_options_sheet.dart     επιλογή χρήστη
//
// Public API αμετάβλητο: `ShareService.shareItem(context, itemId)` (16 call sites).

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;

import '../core/core.dart';
import 'share/share_attachments.dart';
import 'share/share_content_builder.dart';
import 'share/share_models.dart';
import 'share/share_options_sheet.dart';

class ShareService {
  ShareService._();

  /// Re-entrancy guard: το `share_plus` επιστρέφει `unavailable` αν κληθεί
  /// ξανά όσο εκκρεμεί system sheet — δεν θέλουμε ούτε δεύτερο sheet ούτε
  /// «σβηστή» κοινοποίηση.
  static bool _sharing = false;

  static Future<void> shareItem(BuildContext context, int itemId) async {
    if (_sharing) {
      DebugConfig.nav('ShareService: ignored re-entrant call itemId=$itemId');
      return;
    }
    _sharing = true;
    try {
      final bundle = await ShareContentBuilder.loadAndBuild(itemId);
      if (bundle == null) return; // item δεν βρέθηκε (διαγραμμένο)

      // Guard: μετά το await το screen μπορεί να έχει φύγει (pop/route).
      if (!context.mounted) return;

      final mode = await _chooseMode(context, bundle);
      if (mode == null) return; // ο χρήστης έκλεισε το sheet

      // Το sheet έκλεισε — αν το screen έφυγε στο μεταξύ, σταματάμε.
      if (!context.mounted) return;

      await _share(context, bundle, mode);
    } catch (e, stack) {
      DebugConfig.error('ShareService.shareItem', e, stack);
      if (context.mounted) _showMessage(context, AppErrors.shareFailed);
    } finally {
      _sharing = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CHOOSE
  // ─────────────────────────────────────────────────────────────

  static Future<ShareMode?> _chooseMode(
      BuildContext context,
      ShareBundle bundle,
      ) async {
    // Χωρίς αρχεία — ή πλατφόρμα που δεν τα υποστηρίζει — καμία ερώτηση.
    if (!ShareContentBuilder.canOfferFiles(bundle)) return ShareMode.textOnly;
    return ShareOptionsSheet.show(context, bundle);
  }

  // ─────────────────────────────────────────────────────────────
  // RENDER + SHARE
  // ─────────────────────────────────────────────────────────────

  static Future<void> _share(
      BuildContext context,
      ShareBundle bundle,
      ShareMode mode,
      ) async {
    final subject = bundle.item.title ?? '';
    final text = ShareContentBuilder.textForMode(bundle, mode);
    final files = mode == ShareMode.textAndFiles
        ? ShareAttachments.toXFiles(bundle.files)
        : const <XFile>[];

    DebugConfig.print(
        '📤 Share itemId=${bundle.item.id} type=${bundle.item.type.name} '
            'mode=${mode.name} files=${files.length} skipped=${bundle.skippedFiles}');

    final origin = _originFor(context);

    try {
      final result = await SharePlus.instance.share(ShareParams(
        text: text,
        subject: subject,
        files: files.isNotEmpty ? files : null,
        sharePositionOrigin: origin,
      ));
      // `unavailable` (Linux / παλιά Windows) = σιωπή, όχι σφάλμα (D2).
      DebugConfig.nav('📤 Share result=${result.status.name}');
    } on UnimplementedError catch (e) {
      // Παλιά Windows: τα files δεν υποστηρίζονται → retry text-only.
      DebugConfig.warning('ShareService: files unsupported ($e)');
      if (files.isEmpty) rethrow;

      await SharePlus.instance.share(ShareParams(
        text: text,
        subject: subject,
        sharePositionOrigin: origin,
      ));
      if (context.mounted) {
        _showMessage(context, AppErrors.shareFilesUnsupported);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  /// iPad/macOS: το iOS plugin χρειάζεται **non-zero** origin, αλλιώς το
  /// popover αποτυγχάνει. Παίρνουμε το RenderBox της οθόνης (όχι του sheet).
  static Rect _originFor(BuildContext context) {
    if (context.mounted) {
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        return box.localToGlobal(Offset.zero) & box.size;
      }
      final size = MediaQuery.maybeSizeOf(context);
      if (size != null) {
        return Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 1,
          height: 1,
        );
      }
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}