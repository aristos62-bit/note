// lib/shared/mixins/detail_screen_mixin.dart
//
// Central mixin for all detail screens providing:
// - _isSaving gate to prevent double-saves
// - dispose() safety net for empty-new-item deletion
// - mounted checks after every async gap
// - Unified error/success SnackBars
// - DebugConfig logging on every operation
//
// Χρήση:
//   class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen>
//       with DetailScreenMixin<NoteDetailScreen> {
//
//     @override
//     TextEditingController get titleCtrl => _titleCtrl;
//
//     @override
//     void initState() {
//       super.initState();
//       initScreen(itemId: widget.itemId, isNew: widget.isNew);
//     }
//
//     @override
//     void dispose() {
//       disposeScreen();
//       _titleCtrl.dispose();
//       super.dispose();
//     }
//   }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../helpers/super_note_helper.dart';
import '../widgets/widgets.dart';

mixin DetailScreenMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _isSaving = false;
  bool _disposeGuard = false;
  int? _itemId;
  bool _isNew = false;

  /// Πρέπει να παρέχεται από κάθε screen
  TextEditingController get titleCtrl;

  /// Κάλεσε στο initState() του screen (μετά το super.initState())
  void initScreen({required int itemId, required bool isNew}) {
    _itemId = itemId;
    _isNew = isNew;
    DebugConfig.nav('$runtimeType init id=$itemId isNew=$isNew');
  }

  /// Κάλεσε στο dispose() του screen (πριν το super.dispose())
  void disposeScreen() {
    if (_disposeGuard) return;
    _disposeGuard = true;
    DebugConfig.nav('$runtimeType dispose id=$_itemId');
    if (_isNew && _itemId != null && titleCtrl.text.trim().isEmpty) {
      DebugConfig.db('$runtimeType softDelete empty new item id=$_itemId');
      SuperNoteHelper.instance.items.softDelete(_itemId!);
    }
  }

  /// Safe save: empty title check + _isSaving gate + mounted + try-catch
  /// Επιστρέφει true αν το save ολοκληρώθηκε επιτυχώς.
  Future<bool> executeSave(Future<void> Function() saveFn) async {
    if (_isSaving) return false;
    if (titleCtrl.text.trim().isEmpty) {
      showSnackBar('Παρακαλώ προσθέστε τίτλο');
      return false;
    }
    _isSaving = true;
    try {
      await saveFn();
      if (!mounted) return false;
      DebugConfig.db('$runtimeType saved id=$_itemId');
      return true;
    } catch (e, stack) {
      DebugConfig.error('$runtimeType save failed', e, stack);
      if (mounted) {
        showSnackBar('Σφάλμα κατά την αποθήκευση');
      }
      return false;
    } finally {
      _isSaving = false;
    }
  }

  /// Save-or-delete για back button:
  /// - empty + isNew → delete (ή custom deleteFn)
  /// - empty + existing → return (κανένα save)
  /// - has title → saveFn
  Future<void> executeSaveOrDelete({
    required Future<void> Function() saveFn,
    Future<void> Function()? deleteFn,
  }) async {
    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      if (_isNew) {
        DebugConfig.db('$runtimeType delete empty new item id=$_itemId');
        try {
          if (deleteFn != null) {
            await deleteFn();
          } else {
            await SuperNoteHelper.instance.items.softDelete(_itemId!);
          }
        } catch (e, stack) {
          DebugConfig.error('$runtimeType executeSaveOrDelete delete', e, stack);
        }
      }
      return;
    }
    await saveFn();
  }

  /// Navigator.pop με mounted check
  void safePop() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Εμφάνιση SnackBar με mounted check
  void showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Εμφάνιση ConfirmDialog με mounted check
  Future<bool> showConfirm(String title, {String? subtitle}) async {
    if (!mounted) return false;
    final result = await ConfirmDialog.show(
      context,
      title: title,
      subtitle: subtitle,
    );
    return result;
  }
}
