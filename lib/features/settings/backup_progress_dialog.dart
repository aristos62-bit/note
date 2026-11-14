// lib/features/settings/backup_progress_dialog.dart
//
// S-307 (Δ4): διάλογος προόδου για export/restore — μοτίβο
// `SettingsImportProgressDialog` (SafeDialogBody, LinearProgressIndicator,
// pop μία φορά, χωρίς pop μέσα στο build).
//
// Ο χρήστης βλέπει φάση + ποσοστό + «x / y MB» και μπορεί να ακυρώσει· η
// ακύρωση περνά στο service (BackupCancelledException) και καθαρίζει
// partial/temp artifacts.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/backup/backup_progress.dart';
import '../../services/services.dart';
import '../../shared/widgets/widgets.dart';

/// Μοιράζεται ανάμεσα στο dialog και στο task (πρόοδος + ακύρωση).
class BackupProgressController {
  final ValueNotifier<BackupProgress?> _notifier =
      ValueNotifier<BackupProgress?>(null);
  bool _cancelled = false;

  ValueListenable<BackupProgress?> get listenable => _notifier;

  /// true μόλις ο χρήστης πατήσει «Ακύρωση» — τα στάδια το ελέγχουν.
  bool get isCancelled => _cancelled;

  void report(BackupProgress progress) {
    _notifier.value = progress;
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    DebugConfig.db('BackupProgressDialog: cancel requested');
  }

  void dispose() => _notifier.dispose();
}

/// Δείχνει τον διάλογο προόδου και τρέχει [task].
///
/// Επιστρέφει το αποτέλεσμα του [task] ή null αν το task αποτύχει/ακυρωθεί
/// χωρίς αποτέλεσμα.
Future<T?> showBackupProgressDialog<T>({
  required BuildContext context,
  required String title,
  required Future<T> Function(BackupProgressController controller) task,
  bool cancellable = true,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => _BackupProgressDialog<T>(
      title: title,
      task: task,
      cancellable: cancellable,
    ),
  );
}

class _BackupProgressDialog<T> extends StatefulWidget {
  final String title;
  final Future<T> Function(BackupProgressController controller) task;
  final bool cancellable;

  const _BackupProgressDialog({
    required this.title,
    required this.task,
    required this.cancellable,
  });

  @override
  State<_BackupProgressDialog<T>> createState() =>
      _BackupProgressDialogState<T>();
}

class _BackupProgressDialogState<T> extends State<_BackupProgressDialog<T>> {
  final BackupProgressController _controller = BackupProgressController();
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// S256/F9 pattern: κλείνει το dialog ΜΙΑ φορά, ποτέ μέσα στο build.
  void _popOnce(T? result) {
    if (_popped) return;
    _popped = true;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  Future<void> _run() async {
    T? result;
    try {
      result = await widget.task(_controller);
    } catch (e, s) {
      DebugConfig.error('BackupProgressDialog.task', e, s);
      result = null;
    }
    if (!mounted) return;
    _popOnce(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: SafeDialogBody(
          child: ValueListenableBuilder<BackupProgress?>(
            valueListenable: _controller.listenable,
            builder: (context, progress, _) {
              final hasTotal = progress != null && progress.total > 0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: context.titleSm),
                  const SizedBox(height: Spacing.md),
                  LinearProgressIndicator(
                    value: progress?.fraction,
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    progress?.phase.label ?? 'Προετοιμασία...',
                    style: context.bodySm,
                  ),
                  if (hasTotal) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      '${ShareFormatters.humanSize(progress.done)} / '
                      '${ShareFormatters.humanSize(progress.total)}',
                      style: context.labelSm.withColor(context.cText2),
                    ),
                  ],
                  if (widget.cancellable) ...[
                    const SizedBox(height: Spacing.md),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _controller.isCancelled
                            ? null
                            : _controller.cancel,
                        child: const Text('Ακύρωση'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
