// lib/core/utils/serial_pass_queue.dart
//
// SPoT σειριοποίησης ασύγχρονων «passes» (S246).
// Ενοποιεί 2 ουρές: HabitService (A6: habit row-mutations — habit_service.dart:641-672)
// + ReminderScheduler (A6: refresh — reminder_scheduler.dart:223-248).
// ΚΑΘΕ instance έχει ΔΙΚΗ της chain/ids — «shared» = κοινή υλοποίηση,
// ΠΟΤΕ κοινή ουρά μεταξύ services (S230→S232).
// Pure Dart — χωρίς Riverpod/DB· unit-testable χωρίς Isar (σύμβαση S193/S194).
// Μηχανική: future-chain (ίδια με τις υπάρχουσες ουρές S212/S244/S245) — κανένα νέο primitive/package.
import 'dart:async';
import 'debug_config.dart';

/// Σειριακή ουρά passes πάνω σε μία future-chain, με fail-open timeout
/// και σύμβαση NEVER-THROW.
///
/// Σύμβαση:
/// - Σειρά: κάθε pass περιμένει το προηγούμενο (σειρά κλήσης [run]).
/// - Fail-open [timeout] (default 60s — το κοινό πρότυπο των hardenings):
///   στη λήξη το επόμενο pass προχωρά — δεν ακυρώνεται Isar/OS δουλειά
///   που βρίσκεται ήδη σε εξέλιξη.
/// - NEVER-THROW: το [run] δεν πετάει ποτέ· κάθε σφάλμα (και timeout)
///   logάρεται ως `'$label FAILED id=N'` (μόνο label+id — χωρίς PII, R4).
/// - Μην καλείς [run] από pass της ίδιας ουράς (θα περίμενε τον εαυτό του)·
///   το [onTimeout] πρέπει να μην πετάει.
class SerialPassQueue {
  SerialPassQueue({
    required this.label,
    this.timeout = const Duration(seconds: 60),
    this.onTimeout,
  });

  /// Πρόθεμα στα logs — π.χ. `HabitService.pass` / `ReminderScheduler.refresh`.
  final String label;

  /// Όριο ανά pass (fail-open)· default 60s (πρότυπο των hardenings).
  final Duration timeout;

  /// Προαιρετικό callback στη λήξη (π.χ. reset guard για retry στο επόμενο pass).
  final void Function()? onTimeout;

  int _seq = 0;
  Future<void> _chain = Future<void>.value();

  /// Προσθέτει pass στην ουρά· ολοκληρώνεται πάντα κανονικά (ποτέ throw).
  Future<void> run(Future<void> Function() task) {
    final passId = ++_seq;
    DebugConfig.notif('$label queued id=$passId');
    final next = _chain.then((_) async {
      DebugConfig.notif('$label started id=$passId');
      try {
        await task().timeout(timeout);
        DebugConfig.notif('$label done id=$passId');
      } catch (e, stack) {
        if (e is TimeoutException) onTimeout?.call();
        DebugConfig.error('$label FAILED id=$passId', e, stack);
      }
    });
    _chain = next.catchError((_) {});
    return next;
  }
}
