// lib/features/settings/settings_backup_passphrase_gate.dart
//
// S-02 (D8): μία προτροπή κωδικού ανά εκκίνηση όταν το αυτόματο αντίγραφο
// είναι ενεργό. Χωρίς αυτό το auto-backup θα έτρεχε πρακτικά ποτέ (D2=i:
// ο κωδικός δεν αποθηκεύεται). Αν ο χρήστης ακυρώσει, το auto-backup
// σκιπάρεται ΜΟΝΟ για αυτή τη συνεδρία — καμία μόνιμη υποβάθμιση.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import 'settings_backup_passphrase.dart';

class BackupPassphraseGate extends ConsumerStatefulWidget {
  const BackupPassphraseGate({super.key});

  @override
  ConsumerState<BackupPassphraseGate> createState() =>
      _BackupPassphraseGateState();
}

class _BackupPassphraseGateState extends ConsumerState<BackupPassphraseGate> {
  bool _scheduled = false;
  bool _dialogOpen = false;
  bool _sessionDismissed = false;

  @override
  Widget build(BuildContext context) {
    final blocked = ref.watch(appContentBlockedProvider);
    final settings = ref.watch(settingsStreamProvider).valueOrNull;
    final autoBackup = settings?.autoBackupEnabled ?? false;

    final needsPrompt = autoBackup &&
        !blocked &&
        !_sessionDismissed &&
        !_scheduled &&
        !BackupPassphraseCache.instance.hasPassphrase;

    if (needsPrompt) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
    }
    return const SizedBox.shrink();
  }

  Future<void> _prompt() async {
    if (!mounted || _dialogOpen) return;
    _dialogOpen = true;
    try {
      final value = await ensureBackupPassphrase(
        context,
        requireConfirmation: true,
      );
      if (value == null) {
        _sessionDismissed = true;
        DebugConfig.db(
            'BackupPassphraseGate: dismissed — auto-backup skipped this session');
      } else {
        DebugConfig.db('BackupPassphraseGate: session key set');
      }
    } catch (e, stack) {
      DebugConfig.error('BackupPassphraseGate', e, stack);
      _sessionDismissed = true;
    } finally {
      _dialogOpen = false;
    }
  }
}
