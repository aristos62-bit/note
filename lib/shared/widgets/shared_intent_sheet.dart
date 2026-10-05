// lib/shared/widgets/shared_intent_sheet.dart
//
// Dialog ροής κοινοποίησης: επιλογή Σημείωση/Συμβάν (+ ημερομηνία)
// + αποθήκευση μέσω SharedIntentService. Warm shares → sheet,
// κλειδωμένο → ουρά μέχρι unlock, cold → auto-draft (χωρίς context).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/shared_intent_service.dart';
import 'item_type_icon.dart';
import 'sheet_handle.dart';

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
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        // Αδιαφανές φόντο: να μην φαίνεται το layer από πίσω.
        barrierColor: Colors.black.withValues(alpha: 0.75),
        backgroundColor: ColorsUI.getSurface(context.brightness),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.bottomSheet),
            topRight: Radius.circular(AppRadius.bottomSheet),
          ),
        ),
        builder: (_) => _ShareSheet(files: files),
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _eventStart = DateTime(now.year, now.month, now.day, 9, 0);
  }

  String get _excerpt {
    final text = SharedIntentService.combineText(widget.files);
    final nFiles =
        widget.files.where(SharedIntentService.isFileType).length;
    if (text.isNotEmpty) return AppStringUtils.truncate(text, 200);
    if (nFiles > 0) {
      return nFiles == 1 ? '1 αρχείο' : '$nFiles αρχεία';
    }
    return '';
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
    setState(() => _saving = true);
    try {
      final svc = SharedIntentService.instance;
      final SharedSaveResult res;
      if (_target == ItemType.event) {
        res = await svc.saveAsEvent(
          files: widget.files,
          start: _eventStart,
          onSaved: () => ref.invalidate(itemNotifierProvider),
        );
      } else {
        res = await svc.saveAsNote(
          files: widget.files,
          onSaved: () => ref.invalidate(itemNotifierProvider),
        );
      }
      if (!mounted) return;
      if (!res.ok || res.item == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error ?? AppErrors.attachSaveFailed)),
        );
        return;
      }
      final route = _target == ItemType.event
          ? AppRoutes.event(res.item!.id)
          : AppRoutes.note(res.item!.id);
      DebugConfig.nav('SharedIntent saved → $route');
      if (context.mounted) Navigator.of(context).pop();
      ref.read(appRouterProvider).go(route);
      if (res.skippedOversize > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppErrors.oversizeSkipped(res.skippedOversize))),
        );
      }
    } catch (e, stack) {
      DebugConfig.error('SharedIntent _save', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppErrors.attachSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Spacing.lg,
          right: Spacing.lg,
          top: Spacing.md,
          bottom:
              MediaQuery.of(context).viewInsets.bottom + Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SheetHandle(),
            ),
            const SizedBox(height: Spacing.md),
            Text('Κοινοποίηση από άλλη εφαρμογή',
                style: context.titleMd),
            if (_excerpt.isNotEmpty) ...[
              const SizedBox(height: Spacing.xs),
              Text(_excerpt,
                  style: context.bodySm.withColor(context.cText2),
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
          ],
        ),
      ),
    );
  }
}
