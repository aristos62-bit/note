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

  /// Πραγματικά ενεργά passes — από την έναρξη του task μέχρι την
  /// πραγματική του ολοκλήρωση (ΟΧΙ μέχρι το fail-open [timeout]).
  /// Είναι η βάση του drain πριν από close της DB (E33).
  int _inFlight = 0;

  /// Maintenance gate (E33): όσο είναι true, νέα passes σκιπάρονται
  /// (δεν μπαίνουν στην ουρά) και όσα ήδη περιμένουν σκιπάρονται
  /// κατά την εκτέλεση — έτσι κανένα νέο write δεν ξεκινά πριν το close.
  bool _maintenance = false;

  /// Αριθμός passes που εκτελούνται αυτή τη στιγμή (πραγματικό in-flight).
  int get inFlightCount => _inFlight;

  /// true όταν δεν εκτελείται κανένα pass.
  bool get isIdle => _inFlight == 0;

  /// true όσο είναι ενεργό το maintenance gate.
  bool get isPaused => _maintenance;

  /// Κλείνει το gate — καλείται ΠΡΙΝ το drain (restore/wipe, E33).
  void pauseForMaintenance() {
    if (_maintenance) return;
    _maintenance = true;
    DebugConfig.notif('$label maintenance: paused');
  }

  /// Ανοίγει ξανά το gate — μόνο σε abort ΠΡΙΝ το close της DB.
  void resumeAfterMaintenance() {
    if (!_maintenance) return;
    _maintenance = false;
    DebugConfig.notif('$label maintenance: resumed');
  }

  /// Περιμένει μέχρι να μηδενιστεί το πραγματικό in-flight.
  /// Επιστρέφει false αν περάσει το [maxWait] — ο caller κάνει abort
  /// (ΠΟΤΕ close της DB όσο υπάρχει ενεργό pass).
  Future<bool> waitForIdle(Duration maxWait) async {
    if (_inFlight == 0) return true;
    final sw = Stopwatch()..start();
    while (_inFlight > 0) {
      final remaining = maxWait - sw.elapsed;
      if (remaining <= Duration.zero) return false;
      await Future<void>.delayed(
        remaining < const Duration(milliseconds: 50)
            ? remaining
            : const Duration(milliseconds: 50),
      );
    }
    return true;
  }

  /// Προσθέτει pass στην ουρά· ολοκληρώνεται πάντα κανονικά (ποτέ throw).
  Future<void> run(Future<void> Function() task) {
    // Gate 1 (enqueue): μετά το pause δεν μπαίνει νέο pass στην ουρά.
    if (_maintenance) {
      DebugConfig.notif('$label skipped (maintenance)');
      return Future<void>.value();
    }
    final passId = ++_seq;
    DebugConfig.notif('$label queued id=$passId');
    final next = _chain.then((_) async {
      // Gate 2 (execution): pass που μπήκε πριν το pause αλλά εκτελείται
      // μετά — σκιπάρεται χωρίς να αγγίξει Isar/OS (E33).
      if (_maintenance) {
        DebugConfig.notif('$label skipped id=$passId (maintenance)');
        return;
      }
      DebugConfig.notif('$label started id=$passId');
      _inFlight++;
      final taskFuture = Future<void>.sync(task);
      // F2: decrement στο ΠΡΑΓΜΑΤΙΚΟ τέλος (value ή error) — χωρίς
      // unhandled async error (όχι whenComplete + unawaited).
      unawaited(taskFuture.then<void>(
            (_) {
          _inFlight--;
        },
        onError: (Object _, StackTrace __) {
          _inFlight--;
        },
      ));
      try {
        await taskFuture.timeout(timeout);
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
