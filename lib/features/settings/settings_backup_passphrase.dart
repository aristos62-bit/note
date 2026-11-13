// lib/features/settings/settings_backup_passphrase.dart
//
// S-02 (D2=i, D8): dialog προτροπής κωδικού για το κρυπτογραφημένο
// αντίγραφο. Ο κωδικός κρατιέται ΜΟΝΟ στη μνήμη της συνεδρίας
// (BackupPassphraseCache) — ποτέ σε DB/αρχείο/Keystore.
import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/services.dart';

/// Ελάχιστο μήκος κωδικού αντιγράφου.
const int minBackupPassphraseLength = 8;

/// Διάλογος εισαγωγής κωδικού. Επιστρέφει null σε ακύρωση.
///
/// Σκόπιμα χωρίς dispose των controllers: πεθαίνουν μαζί με το subtree (GC) —
/// το πρόωρο dispose έσκασε σε S120 (use-after-dispose στο pop animation).
Future<String?> showBackupPassphraseDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool requireConfirmation = false,
  String? initial,
}) {
  final controller = TextEditingController(text: initial ?? '');
  final confirmController = TextEditingController();
  var obscure = true;
  var error = '';

  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        String? validate() {
          final value = controller.text.trim();
          if (value.length < minBackupPassphraseLength) {
            return AppErrors.backupPassphraseTooShort;
          }
          if (requireConfirmation &&
              confirmController.text.trim() != value) {
            return AppErrors.backupPassphraseMismatch;
          }
          return null;
        }

        void submit() {
          final problem = validate();
          if (problem != null) {
            setState(() => error = problem);
            return;
          }
          Navigator.pop(ctx, controller.text.trim());
        }

        return AlertDialog(
          scrollable: true,
          title: Row(
            children: [
              const Icon(Icons.key_rounded, size: 20),
              const SizedBox(width: Spacing.sm),
              Expanded(child: Text(title)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: Spacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: obscure,
                textInputAction: requireConfirmation
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  labelText: 'Κωδικός',
                  errorText: error.isEmpty ? null : error,
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Εμφάνιση' : 'Απόκρυψη',
                    icon: Icon(obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
              if (requireConfirmation) ...[
                const SizedBox(height: Spacing.sm),
                TextField(
                  controller: confirmController,
                  obscureText: obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                    labelText: 'Επιβεβαίωση κωδικού',
                  ),
                ),
              ],
              const SizedBox(height: Spacing.md),
              Text(
                AppErrors.backupPassphraseHint,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ακύρωση'),
            ),
            FilledButton(
              onPressed: submit,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
}

/// Επιστρέφει τον κωδικό της συνεδρίας. Αν δεν υπάρχει, ζητά νέο.
///
/// [requireConfirmation] true → διπλό πεδίο (νέος κωδικός).
Future<String?> ensureBackupPassphrase(
  BuildContext context, {
  bool requireConfirmation = false,
}) async {
  final cached = BackupPassphraseCache.instance.passphrase;
  if (cached != null && cached.isNotEmpty && !requireConfirmation) {
    return cached;
  }
  if (!context.mounted) return null;
  final value = await showBackupPassphraseDialog(
    context,
    title: 'Κωδικός αντιγράφου',
    message: 'Το αντίγραφο κρυπτογραφείται με AES-256.\n'
        'Θα χρειαστείτε τον ίδιο κωδικό για την επαναφορά.',
    confirmLabel: 'Συνέχεια',
    requireConfirmation: requireConfirmation,
    initial: cached,
  );
  if (value != null) {
    BackupPassphraseCache.instance.setPassphrase(value);
  }
  return value;
}
