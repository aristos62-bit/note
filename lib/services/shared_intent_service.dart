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
//
// S-13: η καθαρή λογική (ταξινόμηση/όρια/clamp) ζει στο
// `share/inbound_share.dart` — εδώ μένει orchestration, rollback και
// καθαρισμός του cache αντιγράφου του plugin.
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/core.dart';
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import 'attachment_service.dart';
import 'share/inbound_share.dart';

/// Προορισμός κοινοποίησης (επιλογή χρήστη στο sheet).
enum SharedTarget { note, event }

/// Αποτέλεσμα αποθήκευσης — για SnackBar + navigation.
class SharedSaveResult {
  final Item? item;
  final SharedTarget target;
  final int attachments;

  /// Πόσα αρχεία παραλείφθηκαν λόγω ορίων (πλήθος/μέγεθος/σύνολο). S-13.
  final int skippedOversize;

  /// S-13: το κείμενο περικόπηκε στο `ShareLimits.maxTextChars`.
  final bool textTruncated;

  /// S-321: το native δεν μπόρεσε να διαβάσει τόσα αρχεία (content:// χωρίς
  /// άδεια, κατεστραμμένο stream).
  final int unreadable;

  final String? error;

  const SharedSaveResult({
    this.item,
    required this.target,
    this.attachments = 0,
    this.skippedOversize = 0,
    this.textTruncated = false,
    this.unreadable = 0,
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
      final initial = await ReceiveSharingIntent.instance
          .getInitialMedia()
          .timeout(const Duration(seconds: 5));
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
  ///
  /// S-13: η **πραγματική** ταξινόμηση γίνεται στο `InboundShare.classify`
  /// (ελέγχει αν το `path` είναι υπαρκτό αρχείο — βλ. S-13b).
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
      return 'Κοινοποίηση ${AppDateUtils.formatNumeric(now)}';
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

  /// system "Γενικά" → πρώτο root → null.
  ///
  /// S272 (E38): δεν λαμβάνεται πλέον υπόψη `preferredFolderId` — η εφαρμογή
  /// ξεκινά σε «Όλοι». Ο φάκελος δίνεται πλέον ρητά από το UI (`preferred`,
  /// μέσω `resolveFolderForNewItem`)· το fallback μένει για ασφάλεια.
  Future<int?> _resolveFolder(SuperNoteHelper helper, int wsId,
      {int? preferred}) async {
    if (preferred != null) return preferred;
    try {
      final folders = await helper.folders.getByWorkspace(wsId);
      if (folders.isEmpty) return null;
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
  // S-13c — καθαρισμός του cache αντιγράφου του plugin
  // ─────────────────────────────────────────────────────────

  /// Το `receive_sharing_intent` **αντιγράφει** κάθε κοινόχρηστο αρχείο στο
  /// `cacheDir` πριν το δώσει στο Dart. Χωρίς καθαρισμό κάθε share αφήνει
  /// μόνιμο αντίγραφο (το `sweepStaleArtifacts` αγγίζει μόνο `_backup_*`).
  ///
  /// ΑΣΦΑΛΕΙΑ: διαγράφουμε **μόνο** ό,τι βρίσκεται μέσα στο temp root. Το
  /// `path` μπορεί να είναι η αρχική διαδρομή του χρήστη (ExternalStorage
  /// provider) — ένα τέτοιο αρχείο **δεν** πρέπει να σβηστεί ποτέ.
  Future<void> _cleanupIntentCache(List<String> paths) async {
    if (paths.isEmpty) return;
    Directory tempRoot;
    try {
      tempRoot = await getTemporaryDirectory();
    } catch (e) {
      DebugConfig.warning(
          'SharedIntent cache cleanup: temp dir unavailable (${e.runtimeType})');
      return;
    }
    final root = p.normalize(tempRoot.path);
    var removed = 0;
    for (final raw in paths) {
      try {
        final path = p.normalize(raw);
        if (!p.isWithin(root, path)) continue;
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          removed++;
        }
        await _pruneIntakeDir(root, file.parent);
      } catch (e) {
        DebugConfig.warning(
            'SharedIntent cache cleanup failed (${e.runtimeType})');
      }
    }
    DebugConfig.db('SharedIntent cache cleaned n=$removed/${paths.length}');
  }

  /// S-321: ο fork αντιγράφει σε `cacheDir/intake_<ts>_<n>/` — όταν το τελευταίο
  /// αρχείο του φακέλου σβηστεί, σβήνεται και ο (άδειος) φάκελος. Μόνο εντός
  /// temp root και μόνο με το γνωστό πρόθεμα (ποτέ ξένος φάκελος).
  Future<void> _pruneIntakeDir(String root, Directory dir) async {
    try {
      if (!p.basename(dir.path).startsWith(InboundShare.intakeDirPrefix)) return;
      if (!p.isWithin(root, dir.path)) return;
      if (!await dir.exists()) return;
      if (await dir.list().isEmpty) await dir.delete();
    } catch (e) {
      DebugConfig.warning(
          'SharedIntent prune intake dir failed (${e.runtimeType})');
    }
  }

  // ─────────────────────────────────────────────────────────
  // SAVE — κοινά βήματα
  // ─────────────────────────────────────────────────────────

  /// Αντιγράφει τα αποδεκτά αρχεία ως συνημμένα. Επιστρέφει τις γραμμές 📎.
  Future<({List<String> lines, int saved})> _saveAttachments({
    required int itemId,
    required List<InboundFile> accepted,
  }) async {
    final lines = <String>[];
    var saved = 0;
    for (final f in accepted) {
      try {
        final att = await AttachmentService.instance.saveFile(
          itemId: itemId,
          sourcePath: f.path,
        );
        saved++;
        lines.add('📎 ${att.fileName} (${att.readableSize})');
        final disp = p.basename(f.path);
        if (disp != att.fileName) {
          DebugConfig.db(
              'SharedIntent sanitize: ${AppStringUtils.redact(disp, label: 'file')} → ${AppStringUtils.redact(att.fileName, label: 'file')}');
        }
      } catch (e, stack) {
        DebugConfig.error(
            'SharedIntent saveFile ${AppStringUtils.redact(f.path, label: 'path')}',
            e,
            stack);
      }
    }
    return (lines: lines, saved: saved);
  }

  /// Ταξινόμηση + clamp + πλάνο ορίων, με **ένα** μέτρημα ανά αρχείο.
  Future<
      ({
        String text,
        bool truncated,
        int maxMB,
        InboundPlan plan,
        List<String> sources,
        int unreadable,
        int nativeTooLarge,
      })> _prepare(
    List<SharedMediaFile> files,
    int perFileBytes,
    int maxMB,
  ) async {
    final content = await InboundShare.classify(files);
    final clamped = InboundShare.clampText(content.text);
    final plan = await InboundShare.planFor(
      content.filePaths,
      perFileBytes: perFileBytes,
    );
    DebugConfig.db(
        'SharedIntent plan: files=${content.filePaths.length} '
        'accepted=${plan.accepted.length} skipped=${plan.skippedCount} '
        'unreadable=${content.unreadable} nativeTooLarge=${content.nativeTooLarge} '
        'textLen=${clamped.text.length} truncated=${clamped.truncated} '
        'perFile=$perFileBytes');
    return (
      text: clamped.text,
      truncated: clamped.truncated,
      maxMB: maxMB,
      plan: plan,
      sources: content.filePaths,
      unreadable: content.unreadable,
      nativeTooLarge: content.nativeTooLarge,
    );
  }

  /// Μήνυμα όταν δεν μένει τίποτα αποθηκεύσιμο.
  ///
  /// S-321: προτεραιότητα = όρια (Dart ή native ceiling) → αδυναμία ανάγνωσης
  /// → κενή κοινοποίηση.
  String _emptyMessage(
    InboundPlan plan,
    int maxMB, {
    required int nativeTooLarge,
    required int unreadable,
  }) {
    if (plan.hasLimitSkips || nativeTooLarge > 0) {
      return AppErrors.attachTooLarge(maxMB);
    }
    if (unreadable > 0) return AppErrors.shareIntakeUnreadable(unreadable);
    return 'Κενή κοινοποίηση';
  }

  // ─────────────────────────────────────────────────────────
  // SAVE — Σημείωση
  // ─────────────────────────────────────────────────────────

  Future<SharedSaveResult> saveAsNote({
    required List<SharedMediaFile> files,
    int? folderId,
    void Function()? onSaved,
  }) async {
    Item? created;
    try {
      if (!SuperNoteHelper.isInitialized) {
        return const SharedSaveResult(
            target: SharedTarget.note, error: 'Η βάση δεν είναι έτοιμη');
      }
      final helper = SuperNoteHelper.instance;
      final settings = await helper.settings.get();
      final prep = await _prepare(
        files,
        settings.attachmentMaxBytes,
        settings.effectiveMaxAttachmentMB,
      );

      // Τίποτα αποθηκεύσιμο (όλα oversize/άκυρα) → κανένα item, καθαρό cache.
      if (prep.text.isEmpty && prep.plan.accepted.isEmpty) {
        await _cleanupIntentCache(prep.sources);
        return SharedSaveResult(
          target: SharedTarget.note,
          skippedOversize: prep.plan.limitSkippedCount + prep.nativeTooLarge,
          textTruncated: prep.truncated,
          unreadable: prep.unreadable,
          error: _emptyMessage(
            prep.plan,
            prep.maxMB,
            nativeTooLarge: prep.nativeTooLarge,
            unreadable: prep.unreadable,
          ),
        );
      }

      final wsId = await _resolveWorkspace(helper);
      if (wsId == null) {
        return const SharedSaveResult(
            target: SharedTarget.note, error: 'Δεν βρέθηκε workspace');
      }
      final resolvedFolderId =
          await _resolveFolder(helper, wsId, preferred: folderId);
      final title = shareTitle(
        text: prep.text,
        filePaths: prep.plan.accepted.map((f) => f.path).toList(),
      );

      created = await helper.items.create(
        type: ItemType.note,
        workspaceId: wsId,
        title: title,
        folderId: resolvedFolderId,
      );

      // Αρχεία → attachments/ (copy, sanitize, dedup — από το service).
      final res = await _saveAttachments(
        itemId: created.id,
        accepted: prep.plan.accepted,
      );

      final bodyParts = <String>[];
      if (prep.text.isNotEmpty) bodyParts.add(prep.text);
      if (res.lines.isNotEmpty) bodyParts.add(res.lines.join('\n'));
      if (bodyParts.isEmpty) {
        // Π.χ. όλα τα αρχεία απέτυχαν στην αντιγραφή — μη μένει κενό item.
        await helper.items.hardDelete(created.id);
        created = null;
        await _cleanupIntentCache(prep.sources);
        return SharedSaveResult(
          target: SharedTarget.note,
          skippedOversize: prep.plan.limitSkippedCount + prep.nativeTooLarge,
          textTruncated: prep.truncated,
          unreadable: prep.unreadable,
          error: AppErrors.attachSaveFailed,
        );
      }

      // ΜΟΝΟ text blocks — τα image/file/link δεν προβάλλονται στις σημειώσεις.
      await helper.blocks.create(
        itemId: created.id,
        type: BlockType.text,
        text: bodyParts.join('\n\n'),
      );

      await _cleanupIntentCache(prep.sources);

      onSaved?.call();
      DebugConfig.db(
          'SharedIntent saved note id=${created.id} blocks=1 '
          'attachments=${res.saved} skipped=${prep.plan.skippedCount}');
      return SharedSaveResult(
          item: created,
          target: SharedTarget.note,
          attachments: res.saved,
          skippedOversize: prep.plan.limitSkippedCount + prep.nativeTooLarge,
          textTruncated: prep.truncated,
          unreadable: prep.unreadable);
    } catch (e, stack) {
      DebugConfig.error('SharedIntent saveAsNote', e, stack);
      final item = created;
      if (item != null) {
        try {
          await SuperNoteHelper.instance.items.hardDelete(item.id);
        } catch (err, st) {
          DebugConfig.error('SharedIntent rollback note', err, st);
        }
      }
      return const SharedSaveResult(
          target: SharedTarget.note, error: AppErrors.attachSaveFailed);
    }
  }

  // ─────────────────────────────────────────────────────────
  // SAVE — Συμβάν (ημερολόγιο, ΟΧΙ υπενθύμιση)
  // ─────────────────────────────────────────────────────────

  Future<SharedSaveResult> saveAsEvent({
    required List<SharedMediaFile> files,
    int? folderId,
    required DateTime start,
    void Function()? onSaved,
  }) async {
    Item? created;
    try {
      if (!SuperNoteHelper.isInitialized) {
        return const SharedSaveResult(
            target: SharedTarget.event, error: 'Η βάση δεν είναι έτοιμη');
      }
      final helper = SuperNoteHelper.instance;
      final settings = await helper.settings.get();
      final prep = await _prepare(
        files,
        settings.attachmentMaxBytes,
        settings.effectiveMaxAttachmentMB,
      );

      // S-13 (Δ5): ενιαία πολιτική με τη σημείωση — ποτέ κενό συμβάν.
      if (prep.text.isEmpty && prep.plan.accepted.isEmpty) {
        await _cleanupIntentCache(prep.sources);
        return SharedSaveResult(
          target: SharedTarget.event,
          skippedOversize: prep.plan.limitSkippedCount + prep.nativeTooLarge,
          textTruncated: prep.truncated,
          unreadable: prep.unreadable,
          error: _emptyMessage(
            prep.plan,
            prep.maxMB,
            nativeTooLarge: prep.nativeTooLarge,
            unreadable: prep.unreadable,
          ),
        );
      }

      final wsId = await _resolveWorkspace(helper);
      if (wsId == null) {
        return const SharedSaveResult(
            target: SharedTarget.event, error: 'Δεν βρέθηκε workspace');
      }
      final resolvedFolderId =
          await _resolveFolder(helper, wsId, preferred: folderId);
      final title = shareTitle(
        text: prep.text,
        filePaths: prep.plan.accepted.map((f) => f.path).toList(),
      );

      final norm =
          DateTime(start.year, start.month, start.day, start.hour, start.minute);
      final end = norm.add(const Duration(hours: 1));

      created = await helper.items.create(
        type: ItemType.event,
        workspaceId: wsId,
        title: title,
        folderId: resolvedFolderId,
      );
      await helper.properties.setDate(created.id, 'start_time', norm);
      await helper.properties.setDate(created.id, 'end_time', end);
      await helper.properties.set(
          itemId: created.id, key: 'all_day', value: 'false');

      final res = await _saveAttachments(
        itemId: created.id,
        accepted: prep.plan.accepted,
      );

      final notesParts = <String>[];
      if (prep.text.isNotEmpty) notesParts.add(prep.text);
      if (res.lines.isNotEmpty) notesParts.add(res.lines.join('\n'));
      if (notesParts.isEmpty) {
        await helper.items.hardDelete(created.id);
        created = null;
        await _cleanupIntentCache(prep.sources);
        return SharedSaveResult(
          target: SharedTarget.event,
          skippedOversize: prep.plan.limitSkippedCount + prep.nativeTooLarge,
          textTruncated: prep.truncated,
          unreadable: prep.unreadable,
          error: AppErrors.attachSaveFailed,
        );
      }
      await helper.properties.set(
        itemId: created.id,
        key: 'notes',
        value: notesParts.join('\n\n'),
      );

      await _cleanupIntentCache(prep.sources);

      onSaved?.call();
      DebugConfig.db(
          'SharedIntent saved event id=${created.id} start=$norm '
          'attachments=${res.saved} skipped=${prep.plan.skippedCount}');
      DebugConfig.nav('SharedIntent → /calendar/${created.id}');
      return SharedSaveResult(
          item: created,
          target: SharedTarget.event,
          attachments: res.saved,
          skippedOversize: prep.plan.limitSkippedCount + prep.nativeTooLarge,
          textTruncated: prep.truncated,
          unreadable: prep.unreadable);
    } catch (e, stack) {
      DebugConfig.error('SharedIntent saveAsEvent', e, stack);
      final item = created;
      if (item != null) {
        try {
          await SuperNoteHelper.instance.items.hardDelete(item.id);
        } catch (err, st) {
          DebugConfig.error('SharedIntent rollback event', err, st);
        }
      }
      return const SharedSaveResult(
          target: SharedTarget.event, error: AppErrors.attachSaveFailed);
    }
  }
}
