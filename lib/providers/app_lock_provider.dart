// lib/providers/app_lock_provider.dart
//
// S-17: fail-closed lock gate.
//
// Το gate είναι η **μοναδική** πηγή αλήθειας για το αν το περιεχόμενο της
// εφαρμογής επιτρέπεται να φανεί. Κανόνες:
//   • Μόνο κλειδώνει σε κάθε άγνωστη/αποτυχημένη κατάσταση.
//   • Ξεκλειδώνει **μόνο** όταν τα settings επιβεβαιωμένα λένε disabled
//     (reconciliation — αλλιώς ένα transient DB error θα άφηνε μόνιμο deadlock).
//   • `enabled` είναι μόνο cached ένδειξη (για το resume-obscuring) — όχι
//     άδεια για unlock.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/debug_config.dart';
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import '../services/app_lock_service.dart';
import '../services/security_service.dart';
import 'settings_provider.dart';

final appLockStateProvider = StateProvider<bool>((ref) {
  return AppLockService.instance.isLocked;
});

// ─────────────────────────────────────────────────────────────────
// S-03 — persisted lockout store (ενιαία πύλη επαλήθευσης PIN)
// ─────────────────────────────────────────────────────────────────

enum PinCheckStatus { ok, wrong, lockedOut, unavailable }

class PinCheckResult {
  const PinCheckResult(
    this.status, {
    this.remainingSeconds = 0,
    this.verifiedHash,
  });

  final PinCheckStatus status;

  /// Για `wrong`/`lockedOut`: υπόλοιπο lockout (0 = κανένα).
  final int remainingSeconds;

  /// Το hash στο οποίο επαληθεύτηκε το PIN (για ασφαλές hash-upgrade).
  final String? verifiedHash;
}

class LockoutSnapshot {
  const LockoutSnapshot({
    required this.failedAttempts,
    required this.remainingSeconds,
    required this.pinLength,
    required this.pinLengthTrusted,
  });

  final int failedAttempts;
  final int remainingSeconds;
  final int pinLength;
  final bool pinLengthTrusted;

  bool get isLockedOut => remainingSeconds > 0;
}

/// Διαβάζει με `lockGateSettingsReaderProvider` (fail-closed) και γράφει με
/// `appLockSettingsWriterProvider` (committed snapshot ή null).
class AppLockAttemptsStore {
  AppLockAttemptsStore(this._ref);

  final Ref _ref;

  Future<AppSettings?> _read() async {
    try {
      return await _ref.read(lockGateSettingsReaderProvider)();
    } catch (e, s) {
      DebugConfig.error('AppLockAttemptsStore.read', e, s);
      return null;
    }
  }

  Future<AppSettings?> _write(void Function(AppSettings) updater) async {
    try {
      return await _ref.read(appLockSettingsWriterProvider)(updater);
    } catch (e, s) {
      DebugConfig.error('AppLockAttemptsStore.write', e, s);
      return null;
    }
  }

  /// `null` = άγνωστη/αναγνώσιμη κατάσταση (fail-closed από τον caller).
  Future<LockoutSnapshot?> snapshot({AppSettings? settings}) async {
    final s = settings ?? await _read();
    if (s == null) return null;

    final mono = await SecurityService.elapsedRealtimeMs();
    final remaining = AppLockService.remainingLockoutSeconds(
      failedAttempts: s.appLockFailedAttempts,
      lockoutUntilEpochMs: s.appLockLockoutUntilEpochMs,
      lockoutDurationSeconds: s.appLockLockoutDurationSeconds,
      lockoutMonoMs: s.appLockLockoutMonoMs,
      lastSeenWallMs: s.appLockLastSeenWallMs,
      nowMonoMs: mono,
    );
    final rawLen = s.appLockPinLength;
    final trusted = rawLen >= 4 && rawLen <= 6;

    return LockoutSnapshot(
      failedAttempts: AppLockService.sanitizeAttempts(s.appLockFailedAttempts),
      remainingSeconds: remaining,
      pinLength: trusted ? rawLen : 6,
      pinLengthTrusted: trusted,
    );
  }

  /// Έλεγχος lockout → verify → καταγραφή αποτυχίας.
  ///
  /// Σε επιτυχία **δεν** κάνει reset/hash-upgrade (βλ. `finishSuccess`), ώστε
  /// ο caller να ξεκλειδώσει αμέσως χωρίς να περιμένει write.
  Future<PinCheckResult> verify(String pin) async {
    final s = await _read();
    if (s == null || s.appLockPinHash == null) {
      return const PinCheckResult(PinCheckStatus.unavailable);
    }

    final mono = await SecurityService.elapsedRealtimeMs();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final remaining = AppLockService.remainingLockoutSeconds(
      failedAttempts: s.appLockFailedAttempts,
      lockoutUntilEpochMs: s.appLockLockoutUntilEpochMs,
      lockoutDurationSeconds: s.appLockLockoutDurationSeconds,
      lockoutMonoMs: s.appLockLockoutMonoMs,
      lastSeenWallMs: s.appLockLastSeenWallMs,
      nowMonoMs: mono,
      nowEpochMs: nowMs,
    );
    if (remaining > 0) {
      return PinCheckResult(
        PinCheckStatus.lockedOut,
        remainingSeconds: remaining,
      );
    }

    final hash = s.appLockPinHash!;
    if (!AppLockService.instance.verifyPin(pin, hash)) {
      final secs = await _recordFailure(nowMs: nowMs, nowMonoMs: mono);
      return PinCheckResult(
        PinCheckStatus.wrong,
        remainingSeconds: secs,
      );
    }

    DebugConfig.notif('AppLock: PIN verified (lockout store)');
    return PinCheckResult(PinCheckStatus.ok, verifiedHash: hash);
  }

  Future<int> _recordFailure({
    required int nowMs,
    required int? nowMonoMs,
  }) async {
    var lockoutSeconds = 0;
    final updated = await _write((s) {
      final attempts =
          AppLockService.sanitizeAttempts(s.appLockFailedAttempts) + 1;
      s.appLockFailedAttempts = attempts;
      s.appLockLastSeenWallMs = nowMs;
      lockoutSeconds = AppLockService.nextLockoutSeconds(attempts);
      if (lockoutSeconds > 0) {
        s.appLockLockoutDurationSeconds = lockoutSeconds;
        s.appLockLockoutUntilEpochMs = nowMs + lockoutSeconds * 1000;
        s.appLockLockoutMonoMs =
            (nowMonoMs != null && nowMonoMs >= 0) ? nowMonoMs : 0;
      } else {
        s.appLockLockoutDurationSeconds = 0;
        s.appLockLockoutUntilEpochMs = 0;
        s.appLockLockoutMonoMs = 0;
      }
    });

    if (updated == null) {
      DebugConfig.error('AppLock: lockout counter write failed (best effort)');
    } else if (lockoutSeconds > 0) {
      DebugConfig.notif('AppLock: lockout ${lockoutSeconds}s after failure');
    } else {
      DebugConfig.notif('AppLock: failed attempt recorded');
    }
    return lockoutSeconds;
  }

  /// Μετά επιτυχία: reset μετρητών (μόνο αν χρειάζεται) + hash-upgrade.
  /// Best-effort — αποτυχία write δεν ακυρώνει το ξεκλείδωμα.
  Future<void> finishSuccess({String? pin, String? verifiedHash}) async {
    final s = await _read();
    if (s == null) return;

    final needsReset = s.appLockFailedAttempts != 0 ||
        s.appLockLockoutUntilEpochMs != 0 ||
        s.appLockLockoutDurationSeconds != 0 ||
        s.appLockLockoutMonoMs != 0;

    String? newHash;
    if (pin != null &&
        verifiedHash != null &&
        s.appLockPinHash == verifiedHash &&
        AppLockService.shouldUpgradeHash(verifiedHash)) {
      newHash = AppLockService.instance.hashPin(pin);
    }

    if (!needsReset && newHash == null) return;

    final updated = await _write((x) {
      if (needsReset) {
        x.appLockFailedAttempts = 0;
        x.appLockLockoutUntilEpochMs = 0;
        x.appLockLockoutDurationSeconds = 0;
        x.appLockLockoutMonoMs = 0;
      }
      if (newHash != null && x.appLockPinHash == verifiedHash) {
        x.appLockPinHash = newHash;
      }
    });

    if (updated == null) {
      DebugConfig.error('AppLock: post-success write failed (best effort)');
    } else {
      if (needsReset) DebugConfig.notif('AppLock: lockout counter reset');
      if (newHash != null) {
        DebugConfig.notif('AppLock: hash upgraded to v1 (store)');
      }
    }
  }
}

final appLockAttemptsStoreProvider =
    Provider<AppLockAttemptsStore>((ref) => AppLockAttemptsStore(ref));

// ─────────────────────────────────────────────────────────────────
// S-17 — Lock gate state
// ─────────────────────────────────────────────────────────────────

enum LockGateStatus { resolving, ready, failed }

enum LockGateFailure { readFailed, missingPinConfig }

/// Timeouts του gate (injectable για tests).
class LockGateTimeouts {
  const LockGateTimeouts({
    this.cold = const Duration(seconds: 5),
    this.resume = const Duration(seconds: 2),
    this.retry = const Duration(seconds: 5),
  });

  final Duration cold;
  final Duration resume;
  final Duration retry;
}

typedef LockGateSettingsReader = Future<AppSettings?> Function();

/// Test seam: διαβάζει **ακατέργαστα** (`getOrNull`) ώστε null/σφάλμα DB
/// να σημαίνει fail-closed — όχι σιωπηλό default `AppSettings()`.
final lockGateSettingsReaderProvider = Provider<LockGateSettingsReader>((ref) {
  return () => SuperNoteHelper.instance.settings.getOrNull();
});

final lockGateTimeoutsProvider = Provider<LockGateTimeouts>((ref) {
  return const LockGateTimeouts();
});

class LockGateState {
  const LockGateState({
    required this.status,
    this.failure,
    this.enabled,
    this.settings,
  });

  const LockGateState.resolving()
      : status = LockGateStatus.resolving,
        failure = null,
        enabled = null,
        settings = null;

  final LockGateStatus status;
  final LockGateFailure? failure;

  /// Τελευταία γνωστή τιμή `appLockEnabled`· `null` = άγνωστο.
  /// Χρησιμοποιείται **μόνο** για το resume-obscuring (Q5).
  final bool? enabled;

  /// Snapshot της τελευταίας επιτυχημένης ανάγνωσης.
  final AppSettings? settings;

  bool get blocked => status != LockGateStatus.ready;

  LockGateState copyWith({
    LockGateStatus? status,
    LockGateFailure? failure,
    bool? enabled,
    AppSettings? settings,
    bool clearFailure = false,
  }) {
    return LockGateState(
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
      enabled: enabled ?? this.enabled,
      settings: settings ?? this.settings,
    );
  }
}

class LockGateController extends Notifier<LockGateState> {
  /// Ακυρώνει in-flight resolves όταν αλλάζει το lifecycle (pause/detach).
  int _generation = 0;

  @override
  LockGateState build() => const LockGateState.resolving();

  LockGateTimeouts get _timeouts => ref.read(lockGateTimeoutsProvider);

  /// Cold start / pre-runApp.
  Future<void> resolveCold() => _resolve(_timeouts.cold);

  /// Χειροκίνητο retry από το failure UI.
  Future<void> retry() => _resolve(_timeouts.retry);

  /// Resume: Q8 — χωρίς `pausedAt`/`elapsedSeconds` δεν υπάρχει λόγος
  /// επανανάγνωσης/lock. S-03: `elapsedSeconds` = monotonic (προτιμάται).
  Future<void> resolveResume(DateTime? pausedAt, {int? elapsedSeconds}) async {
    if (pausedAt == null && elapsedSeconds == null) return;
    await _resolve(
      _timeouts.resume,
      pausedAt: pausedAt,
      elapsedSeconds: elapsedSeconds,
    );
  }

  /// Μετά το inline setup του PIN (Q6/4b): επανανάγνωση + lock.
  Future<void> resolveAfterSetup() => _resolve(_timeouts.retry);

  /// S-24: εφαρμόζει ένα **committed** settings snapshot (αποτέλεσμα
  /// επιτυχημένου write του lock toggle) χωρίς δεύτερη ανάγνωση DB.
  /// Το generation bump ακυρώνει τυχόν in-flight resolve, ώστε ένα παλιό
  /// snapshot να μην υπερισχύσει της νέας κατάστασης.
  Future<void> applySettings(AppSettings settings) async {
    _generation++;
    final wasLocked = ref.read(appLockStateProvider);
    await _apply(settings, pausedAt: null, wasLocked: wasLocked);
  }

  /// Καλείται στο pause/detached πριν αλλάξει το lifecycle state.
  void markPaused() {
    _generation++;
  }

  /// S164 safety-net χωρίς δεύτερη ανάγνωση DB.
  /// Policy S165: FLAG_SECURE ON όσο το app-lock είναι enabled.
  void reassertSecure() {
    final secure = state.status == LockGateStatus.ready
        ? state.enabled == true
        : true;
    unawaited(SecurityService.setSecure(secure));
  }

  Future<void> _resolve(
    Duration timeout, {
    DateTime? pausedAt,
    int? elapsedSeconds,
  }) async {
    final generation = ++_generation;
    final wasLocked = ref.read(appLockStateProvider);

    // Q5: όσο το app-lock είναι (ή ήταν) ενεργό, obscure αμέσως. Αν είναι
    // γνωστά disabled, μην καλύπτεις τη οθόνη σε κάθε resume.
    final obscure =
        state.status == LockGateStatus.failed || state.enabled != false;
    if (obscure) {
      _publish(state.copyWith(
        status: LockGateStatus.resolving,
        clearFailure: true,
      ));
    }

    try {
      final settings =
          await ref.read(lockGateSettingsReaderProvider)().timeout(timeout);
      if (generation != _generation) return;
      await _apply(
        settings,
        pausedAt: pausedAt,
        elapsedSeconds: elapsedSeconds,
        wasLocked: wasLocked,
      );
    } catch (e, stack) {
      if (generation != _generation) return;
      DebugConfig.error('LockGate resolve', e, stack);
      await _fail(LockGateFailure.readFailed);
    }
  }

  Future<void> _apply(
    AppSettings? settings, {
    DateTime? pausedAt,
    int? elapsedSeconds,
    required bool wasLocked,
  }) async {
    if (settings == null) {
      await _fail(LockGateFailure.missingPinConfig);
      return;
    }

    if (!settings.appLockEnabled) {
      // Επιβεβαιωμένα disabled: καθάρισε τυχόν lock από προηγούμενο failure
      // (reconciliation). Σε unknown/failed ΔΕΝ φτάνουμε εδώ.
      _unlockNow();
      _publish(LockGateState(
        status: LockGateStatus.ready,
        enabled: false,
        settings: settings,
      ));
      await SecurityService.setSecure(false);
      return;
    }

    // enabled αλλά χωρίς PIN → αδύνατο να ξεκλειδώσει: fail-closed + setup UI.
    if (settings.appLockPinHash == null) {
      await _fail(LockGateFailure.missingPinConfig);
      return;
    }

    // Cold/retry → πάντα lock. Resume → μόνο αν πέρασε το timeout (L1/S-03).
    var shouldLock = (pausedAt == null && elapsedSeconds == null) ||
        AppLockService.shouldLockOnResume(
          pausedAt,
          DateTime.now(),
          settings.appLockTimeoutSeconds,
          elapsedSeconds: elapsedSeconds,
        );
    // Ο χρήστης μπορεί να ξεκλείδωσε (PIN/biometric) όσο διαρκούσε το resolve·
    // μην του ξανακλειδώσεις την εφαρμογή που μόλις άνοιξε νόμιμα.
    if (pausedAt != null &&
        shouldLock &&
        wasLocked &&
        !ref.read(appLockStateProvider)) {
      shouldLock = false;
    }
    if (shouldLock) {
      _lockNow();
    }

    _publish(LockGateState(
      status: LockGateStatus.ready,
      enabled: true,
      settings: settings,
    ));
    await SecurityService.setSecure(true);
  }

  Future<void> _fail(LockGateFailure failure) async {
    _lockNow();
    _publish(state.copyWith(
      status: LockGateStatus.failed,
      failure: failure,
    ));
    await SecurityService.setSecure(true);
  }

  void _lockNow() {
    AppLockService.instance.lock();
    try {
      ref.read(appLockStateProvider.notifier).state = true;
    } catch (e) {
      DebugConfig.notif('LockGate: appLockState update after dispose ignored');
    }
  }

  void _unlockNow() {
    AppLockService.instance.unlock();
    try {
      ref.read(appLockStateProvider.notifier).state = false;
    } catch (e) {
      DebugConfig.notif('LockGate: appLockState update after dispose ignored');
    }
  }

  /// Το `state` μπορεί να αγγιχτεί μετά από dispose του container (π.χ.
  /// in-flight resume όταν η εφαρμογή πάει detached). Τα generation guards
  /// το καλύπτουν· αυτό είναι το τελευταίο δίχτυ ασφαλείας.
  void _publish(LockGateState next) {
    try {
      state = next;
    } catch (e) {
      DebugConfig.notif('LockGate: state update after dispose ignored');
    }
  }
}

final lockGateProvider =
    NotifierProvider<LockGateController, LockGateState>(LockGateController.new);

/// true όταν το περιεχόμενο πρέπει να είναι καλυμμένο (gate ή PIN lock).
/// Το χρησιμοποιεί το back-block (`didPopRoute`).
final appContentBlockedProvider = Provider<bool>((ref) {
  final gate = ref.watch(lockGateProvider);
  final locked = ref.watch(appLockStateProvider);
  return gate.status != LockGateStatus.ready || locked;
});
