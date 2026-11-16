// lib/shared/widgets/shared_intent_sheet.dart
//
// Dialog ροής κοινοποίησης: επιλογή Σημείωση/Συμβάν (+ ημερομηνία) + φάκελος
// + αποθήκευση μέσω SharedIntentService. Warm + cold shares → sheet,
// κλειδωμένο → ουρά μέχρι unlock.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/share/inbound_share.dart';
import '../../services/share/share_models.dart';
import '../../services/shared_intent_service.dart';
import 'folder_picker_dialog.dart';
import 'item_type_icon.dart';
import 'safe_sheet.dart';

// ─────────────────────────────────────────────────────────────
// LISTENER — mount στο SuperNoteApp Stack (χωρίς UI)
// ─────────────────────────────────────────────────────────────

class SharedIntentListener extends ConsumerStatefulWidget {
  const SharedIntentListener({super.key});

  @override
  ConsumerState<SharedIntentListener> createState() =>
      _SharedIntentListenerState();
}

class _SharedIntentListenerState extends ConsumerState<SharedIntentListener> {
  StreamSubscription<List<SharedMediaFile>>? _sub;
  List<SharedMediaFile>? _queued;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _sub = SharedIntentService.instance.incoming.listen(_onIncoming);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get _locked {
    final settings = ref.read(settingsNotifierProvider).valueOrNull;
    return (settings?.appLockEnabled ?? false) &&
        ref.read(appLockStateProvider);
  }

  void _onIncoming(List<SharedMediaFile> files) {
    if (!mounted || files.isEmpty) return;
    if (_locked) {
      DebugConfig.notif('SharedIntent queued until unlock n=${files.length}');
      _queued = files;
      return;
    }
    _showSheet(files);
  }

  Future<void> _showSheet(List<SharedMediaFile> files) async {
    if (!mounted || _sheetOpen) return;
    _sheetOpen = true;
    try {
      await showSafeSheet<void>(
        context,
        scrollControlled: true,
        // Αδιαφανές φόντο: να μην φαίνεται το layer από πίσω.
        barrierColor: Colors.black.withValues(alpha: 0.75),
        child: _ShareSheet(files: files),
      );
    } catch (e, stack) {
      DebugConfig.error('SharedIntent sheet', e, stack);
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(appLockStateProvider, (_, locked) {
      if (locked == false && _queued != null && mounted && !_sheetOpen) {
        final q = _queued;
        _queued = null;
        DebugConfig.notif('SharedIntent dequeued after unlock');
        _showSheet(q!);
      }
    });
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────
// SHEET — επιλογή προορισμού + ημερομηνία + αποθήκευση
// ─────────────────────────────────────────────────────────────

class _ShareSheet extends ConsumerStatefulWidget {
  final List<SharedMediaFile> files;
  const _ShareSheet({required this.files});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  ItemType _target = ItemType.note;
  late DateTime _eventStart;
  bool _saving = false;

  /// S-13: υπολογίζεται **μία φορά** στο initState (async classify) — πριν
  /// καλούνταν το `combineText` σε κάθε build (split ολόκληρου του κειμένου).
  String _excerpt = '';

  /// S-13 (device test #3): μήνυμα αποτυχίας **μέσα** στο sheet. Ένα SnackBar
  /// από το `ScaffoldMessenger` ζωγραφίζεται πίσω από το modal sheet — ο
  /// χρήστης δεν έβλεπε τίποτα και το sheet φαινόταν «παγωμένο».
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _eventStart = DateTime(now.year, now.month, now.day, 9, 0);
    _loadExcerpt();
  }

  Future<void> _loadExcerpt() async {
    final content = await InboundShare.classify(widget.files);
    final nFiles = content.filePaths.length;
    String excerpt = '';
    if (content.text.isNotEmpty) {
      excerpt = AppStringUtils.truncate(content.text, 200);
    } else if (nFiles > 0) {
      excerpt = nFiles == 1 ? '1 αρχείο' : '$nFiles αρχεία';
    }
    if (mounted && excerpt.isNotEmpty) {
      setState(() => _excerpt = excerpt);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showReminderPicker(
      context: context,
      initialDateTime: _eventStart,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + AppDateUtils.pickerLastYears),
    );
    if (picked != null && mounted) {
      setState(() => _eventStart = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // E38: ίδιος κανόνας με τις 7 λίστες + Ημερολόγιο. Μέσα στο try ώστε
      // το finally να καθαρίζει πάντα το _saving (ακύρωση → sheet μένει).
      final folderId = await resolveFolderForNewItem(context, ref);
      if (folderId == null || !mounted) return;

      final svc = SharedIntentService.instance;
      final SharedSaveResult res;
      if (_target == ItemType.event) {
        res = await svc.saveAsEvent(
          files: widget.files,
          folderId: folderId,
          start: _eventStart,
          onSaved: () => ref.invalidate(itemNotifierProvider),
        );
      } else {
        res = await svc.saveAsNote(
          files: widget.files,
          folderId: folderId,
          onSaved: () => ref.invalidate(itemNotifierProvider),
        );
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (!res.ok || res.item == null) {
        // S-13: inline — SnackBar πίσω από το sheet δεν φαίνεται (device #3).
        setState(() => _error = res.error ?? AppErrors.attachSaveFailed);
        return;
      }
      final route = _target == ItemType.event
          ? AppRoutes.event(res.item!.id)
          : AppRoutes.note(res.item!.id);

      // S-314: τα terminal μηνύματα περιμένουν ξεκλείδωμα. Το wait ΠΡΕΠΕΙ να
      // γίνει πριν το `pop` — μετά, το `ref` του sheet είναι άκυρο.
      final notes = <String>[];
      if (res.textTruncated) {
        notes.add(AppErrors.shareTextTruncated(ShareLimits.maxTextChars));
      }
      if (res.skippedOversize > 0) {
        notes.add(AppErrors.oversizeSkipped(res.skippedOversize));
      }
      var unlocked = true;
      if (notes.isNotEmpty) {
        unlocked = await waitUntilContentUnblocked(ref);
      }
      if (!mounted) return;

      DebugConfig.nav('SharedIntent saved → $route');
      final nav = Navigator.of(context);
      final router = ref.read(appRouterProvider);
      nav.pop();
      router.go(route);
      if (notes.isNotEmpty && unlocked) {
        messenger.showSnackBar(SnackBar(content: Text(notes.join('\n'))));
      }
    } catch (e, stack) {
      DebugConfig.error('SharedIntent _save', e, stack);
      if (mounted) {
        setState(() => _error = AppErrors.attachSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeSheet(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Κοινοποίηση από άλλη εφαρμογή',
                style: context.titleSm, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_excerpt.isNotEmpty) ...[
              const SizedBox(height: Spacing.xs),
              Text(_excerpt,
                  style: context.bodySm.withColor(context.cText2),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
            if (_error != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(_error!,
                  style: context.bodySm.withColor(context.cError),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: Spacing.md),
            ItemTypePicker(
              selected: _target,
              types: const [ItemType.note, ItemType.event],
              onSelected: (t) => setState(() => _target = t),
            ),
            if (_target == ItemType.event) ...[
              const SizedBox(height: Spacing.sm),
              GestureDetector(
                onTap: _pickDate,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: context.cText2),
                    const SizedBox(width: Spacing.sm),
                    Text(AppDateUtils.formatDateTime(_eventStart),
                        style: context.bodyMd),
                    const Spacer(),
                    Icon(Icons.edit_rounded,
                        size: 14, color: context.cText2),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Άκυρο'),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Αποθήκευση'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
          ],
        ),
        ),
      );
  }
}
