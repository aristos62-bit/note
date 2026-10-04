// lib/services/shared_intent_service.dart
//
// Λήψη shared content από άλλες εφαρμογές (Android share intent → SuperNote).
// Singleton (όπως τα υπόλοιπα services). ΔΕΝ κάνει import providers
// (κύκλος imports) — η ανανέωση UI γίνεται μέσω `onSaved` callback.
//
// ΧΡΗΣΗ (main.dart, postFrame):
//   await SharedIntentService.instance.init();
//   // + SharedIntentListener στο SuperNoteApp Stack για το dialog
//
// ΔΙΑΧΩΡΙΣΜΟΣ: αποθηκεύει Items (note/event) — ΠΟΤΕ Reminder rows.
// Οι ειδοποιήσεις μπαίνουν μόνο από την καμπάνα (ReminderSection).
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/core.dart';
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import 'attachment_service.dart';

/// Προορισμός κοινοποίησης (επιλογή χρήστη στο sheet).
enum SharedTarget { note, event }

/// Αποτέλεσμα αποθήκευσης — για SnackBar + navigation.
class SharedSaveResult {
  final Item? item;
  final SharedTarget target;
  final int attachments;
  final int skippedOversize;
  final String? error;

  const SharedSaveResult({
    this.item,
    required this.target,
    this.attachments = 0,
    this.skippedOversize = 0,
    this.error,
  });

  bool get ok => item != null && error == null;
}

class SharedIntentService {
  SharedIntentService._();
  static final SharedIntentService instance = SharedIntentService._();

  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _inited = false;
  final StreamController<List<SharedMediaFile>> _incoming =
      StreamController<List<SharedMediaFile>>.broadcast();

  /// Warm + cold shares (μετά το init). Το UI (listener) δείχνει το sheet.
  Stream<List<SharedMediaFile>> get incoming => _incoming.stream;

  String? _lastKey;
  DateTime? _lastTime;

  // ─────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      final initial =
          await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) {
        DebugConfig.notif('SharedIntent cold-start n=${initial.length}');
        _emit(initial);
        await ReceiveSharingIntent.instance.reset();
      }
    } catch (e, stack) {
      DebugConfig.error('SharedIntent getInitialMedia', e, stack);
    }
    try {
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (files) {
          if (files.isEmpty) return;
          DebugConfig.notif('SharedIntent warm n=${files.length}');
          _emit(files);
        },
        onError: (Object e, StackTrace s) {
          DebugConfig.error('SharedIntent stream', e, s);
        },
      );
      DebugConfig.startup('SharedIntent init');
    } catch (e, stack) {
      DebugConfig.error('SharedIntent listen', e, stack);
    }
  }

  void dispose() {
    try {
      _sub?.cancel();
      _sub = null;
      _incoming.close();
    } catch (e, stack) {
      DebugConfig.error('SharedIntent dispose', e, stack);
    }
  }

  void _emit(List<SharedMediaFile> files) {
    if (_incoming.isClosed) return;
    if (isDuplicate(files)) {
      DebugConfig.warning('SharedIntent duplicate share skipped');
      return;
    }
    _incoming.add(files);
  }

  // ─────────────────────────────────────────────────────────
  // PURE HELPERS (static — testable χωρίς plugin/DB)
  // ─────────────────────────────────────────────────────────

  /// Αρχεία προς αποθήκευση (τα text/url/message γίνονται κείμενο).
  static bool isFileType(SharedMediaFile f) =>
      f.type == SharedMediaType.image ||
      f.type == SharedMediaType.video ||
      f.type == SharedMediaType.file;

  /// Συνδυασμένο κείμενο: text + url paths + iOS message.
  static String combineText(List<SharedMediaFile> files) {
    final parts = <String>[];
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        final t = f.path.trim();
        if (t.isNotEmpty) parts.add(t);
      }
      final msg = f.message?.trim() ?? '';
      if (msg.isNotEmpty && !parts.contains(msg)) parts.add(msg);
    }
    return parts.join('\n').trim();
  }

  /// Τίτλος: 1η μη-κενή γραμμή (truncate 80), fallback με ημερομηνία.
  /// Πάντα μη-κενός (DetailScreenMixin σβήνει κενά νέα).
  /// Το fallback δεν χρησιμοποιεί intl (test-safe χωρίς locale init).
  static String buildTitle(String text) {
    final first = text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (first.isEmpty) {
      final now = DateTime.now();
      return 'Κοινοποίηση ${now.day}/${now.month}/${now.year}';
    }
    return AppStringUtils.truncate(first, 80);
  }

  /// Έξυπνος τίτλος κοινοποίησης:
  /// - link-only → `🔗 host` (π.χ. `🔗 en.wikipedia.org`)
  /// - file-only → όνομα 1ου αρχείου (+πλήθος)
  /// - αλλιώς → 1η γραμμή κειμένου. Πάντα μη-κενός, offline.
  static String shareTitle(
      {required String text, required List<String> filePaths}) {
    final t = text.trim();
    if (t.isNotEmpty) {
      final lines = t
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length == 1 && AppStringUtils.isUrl(lines.first)) {
        final host = Uri.tryParse(lines.first)?.host ?? '';
        if (host.isNotEmpty) {
          return AppStringUtils.truncate('🔗 $host', 80);
        }
      }
      return buildTitle(t);
    }
    if (filePaths.isNotEmpty) {
      final first = AppStringUtils.truncate(
          AppStringUtils.sanitizeFileName(p.basename(filePaths.first)), 60);
      if (filePaths.length > 1) return '$first +${filePaths.length - 1}';
      return first;
    }
    return buildTitle('');
  }
  /// Dedup: ίδιο περιεχόμενο μέσα σε 2s (διπλό tap / διπλό intent).
  bool isDuplicate(List<SharedMediaFile> files) {
    final key = files.map((f) => '${f.type.value}:${f.path}').join('|');
    final now = DateTime.now();
    if (_lastKey == key &&
        _lastTime != null &&
        now.difference(_lastTime!).inSeconds < 2) {
      return true;
    }
    _lastKey = key;
    _lastTime = now;
    return false;
  }

  static String readableSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  // ─────────────────────────────────────────────────────────
  // RESOLVE (workspace/folder/limits — χωρίς providers)
  // ─────────────────────────────────────────────────────────

  Future<int?> _resolveWorkspace(SuperNoteHelper helper) async {
    try {
      final settings = await helper.settings.get();
      if (settings.defaultWorkspaceId != null) {
        return settings.defaultWorkspaceId;
      }
      return (await helper.workspaces.getDefault())?.id;
    } catch (e, stack) {
      DebugConfig.error('SharedIntent resolveWorkspace', e, stack);
      return null;
    }
  }

  /// preferredFolderId → system "Γενικά" → πρώτο root → null.
  /// (ίδια λογική με FolderAutoSelectMixin — headless).
  Future<int?> _resolveFolder(SuperNoteHelper helper, int wsId) async {
    try {
      final settings = await helper.settings.get();
      final folders = await helper.folders.getByWorkspace(wsId);
      if (folders.isEmpty) return null;
      final preferred = settings.preferredFolderId;
      if (preferred != null && folders.any((f) => f.id == preferred)) {
        return preferred;
      }
      for (final f in folders) {
        if (f.isSystem) return f.id;
      }
      return folders.first.id;
    } catch (e, stack) {
      DebugConfig.error('SharedIntent resolveFolder', e, stack);
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // SAVE — Σημείωση
  // ─────────────────────────────────────────────────────────

  Future<SharedSaveResult> saveAsNote({
    required List<SharedMediaFile> files,
    void Function()? onSaved,
  }) async {
    try {
      if (!SuperNoteHelper.isInitialized) {
        return const SharedSaveResult(
            target: SharedTarget.note, error: 'Η βάση δεν είναι έτοιμη');
      }
      final helper = SuperNoteHelper.instance;
      final text = combineText(files);
      final media = files.where(isFileType).toList();

      final wsId = await _resolveWorkspace(helper);
      if (wsId == null) {
        return const SharedSaveResult(
            target: SharedTarget.note, error: 'Δεν βρέθηκε workspace');
      }
      final folderId = await _resolveFolder(helper, wsId);
      final title =
          shareTitle(text: text, filePaths: media.map((f) => f.path).toList());

      final settings = await helper.settings.get();
      final maxBytes = settings.maxAttachmentSizeMB <= 0
          ? null
          : settings.maxAttachmentSizeMB * 1024 * 1024;

      final item = await helper.items.create(
        type: ItemType.note,
        workspaceId: wsId,
        title: title,
        folderId: folderId,
      );

      // Αρχεία → attachments/ (copy, sanitize, dedup — από το service).
      final attachLines = <String>[];
      var saved = 0;
      var skipped = 0;
      for (final f in media) {
        try {
          final src = File(f.path);
          if (!await src.exists()) continue;
          final size = await src.length();
          if (maxBytes != null && size > maxBytes) {
            skipped++;
            DebugConfig.warning(
                'SharedIntent oversize ${f.path} ($size > $maxBytes bytes)');
            continue;
          }
          final att = await AttachmentService.instance.saveFile(
            itemId: item.id,
            sourcePath: f.path,
          );
          saved++;
          attachLines.add(
              '📎 ${att.fileName} (${readableSize(att.fileSize)})');
        } catch (e, stack) {
          DebugConfig.error('SharedIntent saveFile ${f.path}', e, stack);
        }
      }

      final bodyParts = <String>[];
      if (text.isNotEmpty) bodyParts.add(text);
      if (attachLines.isNotEmpty) bodyParts.add(attachLines.join('\n'));
      if (bodyParts.isEmpty) {
        // Τίποτα αποθηκεύσιμο (π.χ. όλα oversize) — καθάρισε το κενό item.
        await helper.items.softDelete(item.id);
        if (skipped > 0) {
          return SharedSaveResult(
              target: SharedTarget.note,
              skippedOversize: skipped,
              error:
                  'Το αρχείο υπερβαίνει το όριο των ${settings.maxAttachmentSizeMB}MB');
        }
        return const SharedSaveResult(
            target: SharedTarget.note, error: 'Κενή κοινοποίηση');
      }

      // ΜΟΝΟ text blocks — τα image/file/link δεν προβάλλονται στις σημειώσεις.
      await helper.blocks.create(
        itemId: item.id,
        type: BlockType.text,
        text: bodyParts.join('\n\n'),
      );

      onSaved?.call();
      DebugConfig.db(
          'SharedIntent saved note id=${item.id} blocks=1 attachments=$saved skipped=$skipped');
      return SharedSaveResult(
          item: item,
          target: SharedTarget.note,
          attachments: saved,
          skippedOversize: skipped);
    } catch (e, stack) {
      DebugConfig.error('SharedIntent saveAsNote', e, stack);
      return SharedSaveResult(
          target: SharedTarget.note, error: 'Αποτυχία αποθήκευσης: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // SAVE — Συμβάν (ημερολόγιο, ΟΧΙ υπενθύμιση)
  // ─────────────────────────────────────────────────────────

  Future<SharedSaveResult> saveAsEvent({
    required List<SharedMediaFile> files,
    required DateTime start,
    void Function()? onSaved,
  }) async {
    try {
      if (!SuperNoteHelper.isInitialized) {
        return const SharedSaveResult(
            target: SharedTarget.event, error: 'Η βάση δεν είναι έτοιμη');
      }
      final helper = SuperNoteHelper.instance;
      final text = combineText(files);
      final media = files.where(isFileType).toList();

      final wsId = await _resolveWorkspace(helper);
      if (wsId == null) {
        return const SharedSaveResult(
            target: SharedTarget.event, error: 'Δεν βρέθηκε workspace');
      }
      final folderId = await _resolveFolder(helper, wsId);
      final title =
          shareTitle(text: text, filePaths: media.map((f) => f.path).toList());

      final settings = await helper.settings.get();
      final maxBytes = settings.maxAttachmentSizeMB <= 0
          ? null
          : settings.maxAttachmentSizeMB * 1024 * 1024;

      final norm =
          DateTime(start.year, start.month, start.day, start.hour, start.minute);
      final end = norm.add(const Duration(hours: 1));

      final item = await helper.items.create(
        type: ItemType.event,
        workspaceId: wsId,
        title: title,
        folderId: folderId,
      );
      await helper.properties.setDate(item.id, 'start_time', norm);
      await helper.properties.setDate(item.id, 'end_time', end);
      await helper.properties.set(
          itemId: item.id, key: 'all_day', value: 'false');

      final attachLines = <String>[];
      var saved = 0;
      var skipped = 0;
      for (final f in media) {
        try {
          final src = File(f.path);
          if (!await src.exists()) continue;
          final size = await src.length();
          if (maxBytes != null && size > maxBytes) {
            skipped++;
            DebugConfig.warning(
                'SharedIntent oversize ${f.path} ($size > $maxBytes bytes)');
            continue;
          }
          final att = await AttachmentService.instance.saveFile(
            itemId: item.id,
            sourcePath: f.path,
          );
          saved++;
          attachLines.add(
              '📎 ${att.fileName} (${readableSize(att.fileSize)})');
          final disp = p.basename(f.path);
          if (disp != att.fileName) {
            DebugConfig.db('SharedIntent sanitize: "$disp" → "${att.fileName}"');
          }
        } catch (e, stack) {
          DebugConfig.error('SharedIntent saveFile ${f.path}', e, stack);
        }
      }

      final notesParts = <String>[];
      if (text.isNotEmpty) notesParts.add(text);
      if (attachLines.isNotEmpty) notesParts.add(attachLines.join('\n'));
      if (notesParts.isNotEmpty) {
        await helper.properties.set(
          itemId: item.id,
          key: 'notes',
          value: notesParts.join('\n\n'),
        );
      }

      onSaved?.call();
      DebugConfig.db(
          'SharedIntent saved event id=${item.id} start=$norm attachments=$saved skipped=$skipped');
      DebugConfig.nav('SharedIntent → /calendar/${item.id}');
      return SharedSaveResult(
          item: item,
          target: SharedTarget.event,
          attachments: saved,
          skippedOversize: skipped);
    } catch (e, stack) {
      DebugConfig.error('SharedIntent saveAsEvent', e, stack);
      return SharedSaveResult(
          target: SharedTarget.event, error: 'Αποτυχία αποθήκευσης: $e');
    }
  }
}
