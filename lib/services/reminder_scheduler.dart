// lib/services/reminder_scheduler.dart
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import 'notification_service.dart';
import 'reminder_bake_plan.dart';
import 'reminder_text.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../core/core.dart';
import 'package:isar/isar.dart';
import 'dart:async';

/// Έκβαση ενός OS-bake (skipped ≠ failed: τα skips δεν μετράνε ως αποτυχίες).
/// kept: incremental sync — το alarm υπάρχει ήδη στο OS, δεν ξαναψήθηκε.
enum ScheduleOutcome { baked, skipped, failed, kept }

class _BakeExecutionResult {
  const _BakeExecutionResult({
    required this.baked,
    required this.failed,
    required this.skipped,
    required this.cancelled,
    required this.cancelMs,
    required this.schedMs,
    required this.nativeMs,
  });

  final int baked;
  final int failed;
  final int skipped;
  final int cancelled;

  /// Φ0 (E45): χρόνοι του bake — `cancelMs` καλύπτει το loop των ακυρώσεων
  /// (κάθε `cancel` ξαναγράφει ΟΛΗ τη persisted λίστα του plugin),
  /// `schedMs` το loop των `zonedSchedule`, `nativeMs` μόνο το platform call
  /// (άρα `schedMs - nativeMs` ≈ Dart-side reads/text).
  final int cancelMs;
  final int schedMs;
  final int nativeMs;
}

class ReminderScheduler {
  ReminderScheduler._internal();
  static final ReminderScheduler instance = ReminderScheduler._internal();

  // M3 budget: περικοπή + day-granular resume re-bake.
  // Χάνεται σε restart (το cold start κάνει πάντα πλήρες bake και τα ξαναβγάζει).
  bool _osWindowTruncated = false;
  DateTime? _lastFullBakeDay; // date-only (startOfDay)
  bool _rebaking = false;

  /// True αν το τελευταίο bake κόπηκε στο OS-όριο (διαβάζεται από diagnostics).
  bool get isOsWindowTruncated => _osWindowTruncated;

  /// Φ0 (E45): σωρευτής χρόνου **μόνο** του platform call (`zonedSchedule`),
  /// ώστε να ξεχωρίζει το native κόστος από το Dart-side (reads/text/logs).
  /// Μηδενίζεται στο ξεκίνημα κάθε `_runBakePlan` — τα passes είναι σειριακά.
  int _accumNativeUs = 0;
  Timer? _refreshTimer;
  DateTime? _lastRefreshRun; // 🔍 DEBUG: για μέτρηση του κενού μεταξύ refresh

  /// B2/E33: maintenance gate για restore/wipe — όσο true, τα passes και
  /// των 3 ουρών (bake/refresh/purge) σκιπάρονται μέσω των queue gates.
  bool _maintenance = false;

  /// F6: υπήρχε εκκρεμές/σκιπαρισμένο debounce refresh στο pause —
  /// ξανα-οπλίζεται ΜΙΑ φορά στο abort (resume).
  bool _refreshWasPending = false;

  // P1#3 (S252): δίχτυο για το βαρύτερο postFrame βήμα (main:246). Ίδιο SPoT
  // instance-per-concern με το `_refreshQueue` (S246) — ΠΟΤΕ κοινή ουρά
  // (μάθημα S230→S232). Fail-open 60s + NEVER-THROW: ένα κόλλημα δεν παγώνει
  // το υπόλοιπο postFrame (habit repair/topUp, main:255-256).
  final SerialPassQueue _bakeQueue =
      SerialPassQueue(label: 'ReminderScheduler.bake');

  Future<void> scheduleAll({bool incremental = false}) =>
      _bakeQueue.run(() => _scheduleAllImpl(incremental: incremental));

  Future<void> _scheduleAllImpl({bool incremental = false}) async {
    try {
      DebugConfig.notif(
          'ReminderScheduler.scheduleAll: called, platform=$defaultTargetPlatform incremental=$incremental');
      // Μοναδική πηγή πλατφορμών: NotificationService.isSupportedPlatform.
      if (!NotificationService.isSupportedPlatform) {
        DebugConfig.notif(
            'ReminderScheduler.scheduleAll: platform not supported, skipping');
        return;
      }

      final settings = await SuperNoteHelper.instance.settings.get();
      DebugConfig.notif(
          'ReminderScheduler.scheduleAll: notificationsEnabled=${settings.notificationsEnabled}');
      // E15-F2: OFF = durable cancel (tray + AlarmManager alarms + boot cache).
      // Το cancelAll σβήνει και το cache του boot receiver -> reboot/update δεν
      // ανασταίνει alarms. Μένει μέσα στην _bakeQueue: ποτέ παράλληλο με bake.
      if (!settings.notificationsEnabled) {
        await NotificationService.instance.cancelAll();
        _osWindowTruncated = false;
        // B3: επιβεβαίωση ότι άδειασε όντως το OS (scheduled cache).
        final osLeft = (await NotificationService.instance
                .getPendingNotifications())
            .length;
        DebugConfig.notif(
            'ReminderScheduler.scheduleAll: OFF -> cancelAll done, os=$osLeft');
        if (osLeft > 0) {
          DebugConfig.warning(
              'scheduleAll: OFF but $osLeft OS alarms still pending - cancelAll did not clear all');
        }
        return;
      }

      final totalSw = Stopwatch()..start(); // PERF#9 (S224)

      // Incremental: current = ids που ήδη υπάρχουν στο OS. Άδειο (πραγματικά
      // ή λόγω σφάλματος του getPendingNotifications, που επιστρέφει []) →
      // πέφτουμε στο πλήρες flow.
      var effectiveIncremental = incremental;
      var osById = <int, OsReminderSnapshot>{};
      if (effectiveIncremental) {
        osById = await _readOsSnapshots();
        if (osById.isEmpty) {
          DebugConfig.notif(
              'ReminderScheduler.scheduleAll: INCREMENTAL → OS empty, full flow');
          effectiveIncremental = false;
        }
      }
      if (!effectiveIncremental) {
        await NotificationService.instance.cancelAll();
        DebugConfig.notif(
            'ReminderScheduler.scheduleAll: cancelAll done (PERF#9 ${totalSw.elapsedMilliseconds}ms)');
        osById = await _readOsSnapshots();
        if (osById.isNotEmpty) {
          DebugConfig.warning(
              'scheduleAll: cancelAll left ${osById.length} OS alarms — falling back to incremental reconciliation');
          effectiveIncremental = true;
        }
      }

      var pending = await SuperNoteHelper.instance.reminders.getPending();
      pending =
          pending.where((r) => r.rrule == null || r.rrule!.isEmpty).toList();
      DebugConfig.notif(
          'ReminderScheduler.scheduleAll: found ${pending.length} pending reminders (after filtering recurring roots)');

      final itemsById = await _buildItemsMap(pending);
      final plan = buildReminderBakePlan(
        rows: pending,
        items: itemsById,
        osById: osById,
        limit: NotificationService.osAlarmLimit,
        now: DateTime.now(),
        incremental: effectiveIncremental,
        habitOsWindow: true, // E45/A: OS κρατά 14ημ. για habits (DB 60)
        cancelableOsIds:
            effectiveIncremental ? osById.keys.toSet() : const <int>{},
      );

      // M1: 1 resolve για όλο το batch (αντί για 1/alarm) — singles αλλού per-call.
      final batchMode =
          await NotificationService.instance.resolveScheduleMode();
      final loopSw = Stopwatch()..start(); // PERF#9 (S224)
      final result = await _runBakePlan(
        plan,
        sound: settings.soundEnabled,
        vibration: settings.vibrationEnabled,
        mode: batchMode,
      );
      loopSw.stop(); // PERF#9 (S224)

      final osCount = // PERF#9 (S224)
          (await NotificationService.instance.getPendingNotifications()).length;
      final cut = plan.desiredCount -
          plan.keepIds.length -
          plan.schedule.length;
      _osWindowTruncated = plan.truncated;
      _lastFullBakeDay = DateTime.now().startOfDay;
      DebugConfig.notif(
          'PERF#9 scheduleAll: DONE db=${pending.length} desired=${plan.desiredCount} '
          'baked=${result.baked} kept=${plan.keepIds.length} failed=${result.failed} '
          'skipped=${plan.skippedCount + result.skipped} cancelled=${result.cancelled} '
          'deferred=${plan.deferredCount} beyond=${plan.beyondHorizonCount} '
          'cut=$cut truncated=${plan.truncated} os=$osCount '
          'loop=${loopSw.elapsedMilliseconds}ms total=${totalSw.elapsedMilliseconds}ms '
          // Φ3 (E45): ο παλιός `avg=` διαιρούσε με το σύνολο των DB rows
          // (`pending.length`), όχι με τα alarms που ψήθηκαν — παραπλανητικό.
          'avgSched=${result.baked == 0 ? 0 : (loopSw.elapsedMilliseconds / result.baked).toStringAsFixed(1)}ms/alarm '
          'dart=${result.schedMs - result.nativeMs}ms native=${result.nativeMs}ms '
          'cancel=${result.cancelMs}ms');
      if (plan.truncated) {
        DebugConfig.warning(
            'scheduleAll: BUDGET cut — desired=${plan.desiredCount} schedule=${plan.schedule.length} keep=${plan.keepIds.length} limit=${NotificationService.osAlarmLimit}');
      }
      DebugConfig.notif('ReminderScheduler.scheduleAll: DONE');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.scheduleAll', e, stack);
    }
  }

  Future<Map<int, OsReminderSnapshot>> _readOsSnapshots() async {
    final pending = await NotificationService.instance.getPendingNotifications();
    return {
      for (final p in pending)
        p.id: OsReminderSnapshot(
          id: p.id,
          title: p.title,
          body: p.body,
          payload: p.payload,
        ),
    };
  }

  Future<Map<int, Item?>> _buildItemsMap(Iterable<Reminder> rows) async {
    final out = <int, Item?>{};
    for (final r in rows) {
      if (out.containsKey(r.itemId)) continue;
      out[r.itemId] =
          await SuperNoteHelper.instance.items.getById(r.itemId);
    }
    return out;
  }

  Future<_BakeExecutionResult> _runBakePlan(
    ReminderBakePlan plan, {
    required bool sound,
    required bool vibration,
    required AndroidScheduleMode mode,
  }) async {
    _accumNativeUs = 0; // Φ0/E45: καθαρή μέτρηση για αυτό το bake
    final cancelSw = Stopwatch()..start();
    var cancelled = 0;
    for (final id in plan.cancelIds) {
      try {
        await NotificationService.instance.cancel(id);
        cancelled++;
      } catch (e, stack) {
        DebugConfig.error(
            'ReminderScheduler._runBakePlan cancel id=$id', e, stack);
      }
    }
    cancelSw.stop();
    final schedSw = Stopwatch()..start();
    var baked = 0;
    var failed = 0;
    var skipped = 0;
    for (final reminder in plan.schedule) {
      final outcome = await _scheduleOne(
        reminder,
        sound: sound,
        vibration: vibration,
        mode: mode,
      );
      if (outcome == ScheduleOutcome.baked) {
        baked++;
      } else if (outcome == ScheduleOutcome.failed) {
        failed++;
      } else {
        skipped++;
        // Αν το row έγινε orphan/archived/done ή χάθηκε μετά το planning,
        // καθάρισε τυχόν παλιό OS alarm του id. (Τα keeps δεν φτάνουν εδώ.)
        if (outcome == ScheduleOutcome.skipped) {
          await _cancelReminderIdsImpl([reminder.id]);
        }
      }
    }
    schedSw.stop();
    return _BakeExecutionResult(
      baked: baked,
      failed: failed,
      skipped: skipped,
      cancelled: cancelled,
      cancelMs: cancelSw.elapsedMilliseconds,
      schedMs: schedSw.elapsedMilliseconds,
      nativeMs: _accumNativeUs ~/ 1000,
    );
  }

  /// Resume re-bake ΜΟΝΟ αν κόπηκε budget ΚΑΙ άλλαξε η μέρα (≤1 βαρύ
  /// resume/μέρα). Τραβάει μακρινές rows στο OS καθώς περνά ο χρόνος.
  /// Incremental sync: κρατά ό,τι ήδη υπάρχει στο OS, ψήνει μόνο τα νέα
  /// (αντί για cancelAll + πλήρες ~20s bake). Το _rebaking σκεπάζει δεύτερο
  /// resume ενδιάμεσα.
  Future<void> rebakeIfTruncatedAndDayChanged() async {
    if (!_osWindowTruncated || _rebaking) return;
    final today = DateTime.now().startOfDay;
    if (_lastFullBakeDay == today) return;
    _rebaking = true;
    try {
      DebugConfig.nav(
          'rebakeIfTruncatedAndDayChanged: day rolled over — incremental sync');
      await scheduleAll(incremental: true);
    } finally {
      _rebaking = false;
    }
  }

  // ─────────────────────────────────────────────────────────
  // Debounced version for lifecycle events
  // ─────────────────────────────────────────────────────────

  Future<void> debouncedRefreshRecurringReminders(
      {Duration delay = const Duration(seconds: 2)}) async {
    DebugConfig.notif(
        'ReminderScheduler.debouncedRefreshRecurringReminders: called, delay=$delay');
    if (_maintenance) {
      // F6: όχι timer ενόσω τρέχει restore/wipe — rearm στο abort.
      _refreshWasPending = true;
      DebugConfig.notif(
          'ReminderScheduler.debouncedRefreshRecurringReminders: maintenance — deferred');
      return;
    }
    _refreshTimer?.cancel();
    _refreshTimer = Timer(delay, () async {
      _refreshTimer = null;
      try {
        DebugConfig.notif(
            'ReminderScheduler.debouncedRefreshRecurringReminders: executing actual refresh');
        await refreshRecurringReminders();
      } catch (e, stack) {
        DebugConfig.error('ReminderScheduler.debouncedRefreshRecurringReminders timer', e, stack);
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // Ανανέωση επαναλαμβανόμενων υπενθυμίσεων (batch logic)
  // ─────────────────────────────────────────────────────────

  // A6: σειριοποίηση — δύο ταυτόχρονες εκτελέσεις (startup/resume/
  // ReminderSection/archive) μπορούσαν να δημιουργήσουν διπλά παιδιά.
  // Hardening (καθρέφτης S244): timeout 60s/pass (fail-open — δεν ακυρώνει
  // Isar/OS work σε εξέλιξη) + μόνιμα queued/started/done logs.
  // Σύμβαση: NEVER-THROW (όλα logάρονται εδώ· η αλυσίδα μένει ζωντανή·
  // οι 9 καλούντες προχωρούν — verified ένας-ένας, κανένας δεν εξαρτάται
  // από throw).
  // S246: η ουρά εξήχθη στο SPoT `SerialPassQueue` (core/utils) — ίδια
  // logs/timeout/συμπεριφορά.
  final SerialPassQueue _refreshQueue =
      SerialPassQueue(label: 'ReminderScheduler.refresh');

  /// [bake] = false: μόνο δημιουργία/καθαρισμός rows, **χωρίς** OS bake.
  /// Το χρησιμοποιεί το startup, γιατί αμέσως μετά τρέχει `scheduleAll()`
  /// που ψήνει τα πάντα — αλλιώς ψήνουμε (π.χ. 31 distant alarms ≈2,4s) και
  /// τα σβήνει το `cancelAll` 0,9s αργότερα.
  Future<void> refreshRecurringReminders({bool bake = true}) =>
      _refreshQueue.run(() => _refreshRecurringRemindersImpl(bake: bake));

  Future<void> _refreshRecurringRemindersImpl({bool bake = true}) async {
    try {
      final now0 = DateTime.now();
      if (_lastRefreshRun != null) {
        final gap = now0.difference(_lastRefreshRun!);
        DebugConfig.notif(
          'ReminderScheduler.refreshRecurringReminders: started — '
              'GAP από προηγούμενο run: ${gap.inHours}h ${gap.inMinutes % 60}m '
              '(προηγούμενο: $_lastRefreshRun)',
        );
      } else {
        DebugConfig.notif(
            'ReminderScheduler.refreshRecurringReminders: started (πρώτη εκτέλεση)');
      }
      _lastRefreshRun = now0;
      final settings = await SuperNoteHelper.instance.settings.get();
      if (!settings.notificationsEnabled) {
        DebugConfig.notif(
            'refreshRecurringReminders: notifications disabled, skipping');
        return;
      }

      // Καθαρισμός fired παλιών one-shots (>7 ημερών) — το FLN δεν δίνει
      // fire-callback και το markSent δεν καλείται πουθενά, οπότε χωρίς
      // αυτό θα συσσωρεύονταν μέχρι το επόμενο cold-start init.
      final cleanedIds =
          await SuperNoteHelper.instance.reminders.cleanupOldPending();
      if (cleanedIds.isNotEmpty) {
        // DB-first cleanup επιστρέφει ids: καθάρισε και τα αντίστοιχα OS alarms
        // (αλλιώς μένουν ghosts στο AlarmManager/cache).
        await cancelReminderIds(cleanedIds);
        DebugConfig.notif(
            'refreshRecurringReminders: cleaned ${cleanedIds.length} old past reminders + OS cancel');
      }

      // ΜΟΝΟ ρίζες: έχουν rrule και parentReminderId == null
      final allRecurring = await SuperNoteHelper.instance.isar.reminders
          .filter()
          .rruleIsNotNull()
          .and()
          .not()
          .rruleEqualTo('')
          .parentReminderIdIsNull()
          .findAll();

      // Εξαίρεση: habits έχουν δικό τους scheduling (habit_service)
      DebugConfig.notif(
          'refreshRecurringReminders: all ${allRecurring.length} recurring roots:');
      final filtered = <Reminder>[];
      final itemByRootId = <int, Item?>{};
      for (final r in allRecurring) {
        final item = await SuperNoteHelper.instance.items.getById(r.itemId);
        itemByRootId[r.id] = item;
        DebugConfig.notif(
          '  root id=${r.id} itemId=${r.itemId} trigger=${r.triggerAt} rrule="${r.rrule}" type=${item?.type.name ?? 'null'} title="${item?.title ?? 'null'}"',
        );
        // E37: orphan root δεν αναγεννά παιδιά ούτε ψήνει OS alarms.
        if (item == null) {
          DebugConfig.warning(
              'refreshRecurringReminders: skipping orphan root id=${r.id} itemId=${r.itemId}');
          continue;
        }
        if (item.type == ItemType.habit) {
          DebugConfig.notif(
              'refreshRecurringReminders: skipping habit root id=${r.id}');
          continue;
        }
        // #2: Τα αρχειοθετημένα items δεν ξαναγεμίζουν recurring παιδιά.
        if (item.archived) {
          DebugConfig.notif(
              'refreshRecurringReminders: skipping archived root id=${r.id}');
          continue;
        }
        // Κάδος: συμμετρικά με archive — κρατημένες rows, καμία αναγέννηση.
        if (item.isDeleted) {
          DebugConfig.notif(
              'refreshRecurringReminders: skipping deleted root id=${r.id}');
          continue;
        }
        // A2: ούτε τα done/cancelled (το item είναι ήδη fetched — 0 έξτρα query).
        if (item.status == ItemStatus.done ||
            item.status == ItemStatus.cancelled) {
          DebugConfig.notif(
              'refreshRecurringReminders: skipping ${item.status.name} root id=${r.id}');
          continue;
        }
        if (r.status != ReminderStatus.pending) {
          DebugConfig.notif(
              'refreshRecurringReminders: skipping ${r.status.name} root id=${r.id}');
          continue;
        }
        filtered.add(r);
      }

      DebugConfig.notif(
          'Found ${allRecurring.length} recurring root reminders');
      final now = DateTime.now();
      int createdTotal = 0;
      // N2/E35: ένα μόνο batch στο τέλος (μία ανάγνωση OS cache + ένα plan),
      // αντί για scheduleReminders ανά root — αλλιώς 100 roots = 100 OS reads.
      final pendingToSchedule = <Reminder>[];

      for (final root in filtered) {
        final rrule = root.rrule!;
        if (rrule.isEmpty) continue;

        final recurrence = rruleToRecurrence(rrule);
        if (recurrence == null) {
          DebugConfig.notif(
              'Root ${root.id}: invalid rrule="$rrule", skipping');
          continue;
        }

        // ✅ batchSize ορίζεται ΕΔΩ ώστε να είναι ορατό και στο skip logic παρακάτω
        // A5: daily/custom 14 (με 5 το reminder σταματούσε μετά 5 μέρες χωρίς
        // άνοιγμα της εφαρμογής)· weekly/monthly/yearly μένουν 5.
        final batchSize = (recurrence.type == RecurrenceType.daily ||
                recurrence.type == RecurrenceType.custom)
            ? 14
            : 5;

        // 1. Έλεγξε αν ο root έχει ήδη παιδιά στο μέλλον (ενεργό batch)
        final rootItem = itemByRootId[root.id];
        final futureChildren = await SuperNoteHelper.instance.isar.reminders
            .filter()
            .parentReminderIdEqualTo(root.id)
            .triggerAtGreaterThan(now, include: true)
            .findAll();
        // Μόνο pending rows συμμετέχουν σε batch/OS repair.
        final futurePending = futureChildren
            .where((c) => c.status == ReminderStatus.pending)
            .toList();

        DebugConfig.notif(
          'Root ${root.id}: futureChildren count=${futureChildren.length} pending=${futurePending.length} after filtering parentReminderId=${root.id}',
        );
        for (final fc in futurePending) {
          DebugConfig.notif(
            '  child id=${fc.id} trigger=${fc.triggerAt} status=${fc.status.name}',
          );
        }

        if (futurePending.isNotEmpty) {
          // ✅ Έλεγχος αν τα παιδιά έχουν σωστή ώρα (ίδια με το root trigger).
          // Εξαιρούνται τα snoozed (snoozeUntil != null) — η μετατοπισμένη
          // ώρα τους είναι σκόπιμη και δεν πρέπει να διαγράφονται.
          final wrongTimeChildren = futurePending
              .where((child) =>
                  child.snoozeUntil == null &&
                  (child.triggerAt.hour != root.triggerAt.hour ||
                      child.triggerAt.minute != root.triggerAt.minute))
              .toList();

          // Υπάρχουν παιδιά με λάθος ώρα → DB delete πρώτα, OS cancel μετά.
          if (wrongTimeChildren.isNotEmpty) {
            final wrongIds = wrongTimeChildren.map((c) => c.id).toList();
            DebugConfig.notif(
              'Root ${root.id}: found ${wrongIds.length} children with wrong trigger time, cleaning up',
            );
            for (final wrongChild in wrongTimeChildren) {
              DebugConfig.notif(
                '  Deleting wrong child id=${wrongChild.id} trigger=${wrongChild.triggerAt} (expected hour=${root.triggerAt.hour}:${root.triggerAt.minute})',
              );
            }
            try {
              await SuperNoteHelper.instance.isar.writeTxn(() async {
                await SuperNoteHelper.instance.isar.reminders
                    .deleteAll(wrongIds);
              });
            } catch (e, stack) {
              DebugConfig.error(
                  'refreshRecurringReminders wrong-time DB delete root=${root.id}',
                  e,
                  stack);
            } finally {
              await cancelReminderIds(wrongIds);
            }
            futurePending.removeWhere((c) => wrongIds.contains(c.id));
          }

          // ✅ Skip μόνο αν έχουμε ΑΡΚΕΤΑ σωστά παιδιά (>= batchSize - 1)
          // Αν έχουμε λιγότερα → top-up batch.
          // Πριν το skip, κάνε batch repair των υπαρχόντων OS alarms.
          final correctChildren = futurePending
              .where((child) =>
                  child.triggerAt.hour == root.triggerAt.hour &&
                  child.triggerAt.minute == root.triggerAt.minute)
              .toList();

          if (correctChildren.length >= batchSize - 1) {
            pendingToSchedule.addAll(futurePending);
            DebugConfig.notif(
              'Root ${root.id}: has ${correctChildren.length} correct children (>= ${batchSize - 1}), skipping creation (queued for batch OS repair)',
            );
            continue;
          }

          DebugConfig.notif(
            'Root ${root.id}: only ${correctChildren.length} correct children (< ${batchSize - 1}), topping up batch',
          );
        }

        // 2. Νέο batch (ή top-up): A3/A4 — αλυσίδα από το DTSTART του root
        // (RRULE-σωστό): καμία εμφάνιση πριν το DTSTART και σωστό πλέγμα
        // interval>1 (daily/monthly/yearly). Βλ. planOccurrences.
        final List<DateTime> nextOccurrences =
            planOccurrences(recurrence, root.triggerAt, now, batchSize);

        if (nextOccurrences.isEmpty) {
          // Κενό = γνήσιο τέλος Ή υπέρβαση walk-cap (daily από 2000 ≈
          // 9700 βήματα > 6000 — εκτελεστικά επιβεβαιωμένο). Διαγραφή
          // ΜΟΝΟ στο γνήσιο τέλος (πρώτο βήμα νεκρό)· στο cap κρατάμε
          // το thread — σιωπηλή διαγραφή = απώλεια υπενθύμισης.
          final probe = recurrence.nextOccurrence(root.triggerAt,
              anchor: root.triggerAt);
          if (probe == null || !probe.isAfter(root.triggerAt)) {
            DebugConfig.notif(
                'Root ${root.id}: no future occurrences from rrule, deleting thread');
            await deleteReminderThread(root.id);
          } else {
            DebugConfig.warning(
                'Root ${root.id}: occurrence walk hit cap — keeping thread, no children created');
          }
          continue;
        }

        int createdForRoot = 0;

        for (final occ in nextOccurrences) {
          // Safety: αν για κάποιο λόγο έχει δημιουργηθεί ήδη child με αυτή την ώρα, μην το διπλο-δημιουργήσεις
          final existingChild = await SuperNoteHelper.instance.isar.reminders
              .filter()
              .parentReminderIdEqualTo(root.id)
              .triggerAtEqualTo(occ)
              .findFirst();

          if (existingChild != null) {
            DebugConfig.notif(
                'Root ${root.id}: child already exists at $occ, skipping');
            continue;
          }

          // E10: το παιδί παίρνει το ίδιο live/DB text με το root, ώστε
          // contact birthday να έχει σωστό title ΚΑΙ body από τη γέννησή του.
          final childText = resolveReminderNotificationText(root, rootItem);
          final child = Reminder()
            ..itemId = root.itemId
            ..triggerAt = occ
            ..rrule = null // τα παιδιά είναι one-shot
            ..title = childText.title
            ..body = childText.body
            ..status = ReminderStatus.pending
            ..parentReminderId = root.id
            ..createdAt = DateTime.now();

          await SuperNoteHelper.instance.isar.writeTxn(() async {
            await SuperNoteHelper.instance.isar.reminders.put(child);
          });

          createdForRoot++;
          createdTotal++;
          DebugConfig.notif(
              'Created child reminder ${child.id} for root ${root.id} at $occ');
        }

        // N2/E35: ένα batch scheduler για ΟΛΑ τα μελλοντικά pending παιδιά
        // (υπάρχοντα + νέα), με keep/replacement/budget — όχι 1 bake/child.
        final allFutureChildrenNow = await SuperNoteHelper.instance.isar.reminders
            .filter()
            .parentReminderIdEqualTo(root.id)
            .triggerAtGreaterThan(now, include: true)
            .findAll();
        pendingToSchedule.addAll(allFutureChildrenNow
            .where((c) => c.status == ReminderStatus.pending));
        if (allFutureChildrenNow.isNotEmpty) {
          final maxTrigger = allFutureChildrenNow
              .map((c) => c.triggerAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          final runway = maxTrigger.difference(now);
          DebugConfig.notif(
            'Root ${root.id}: 🔋 RUNWAY μέχρι $maxTrigger '
                '(${runway.inDays}d ${runway.inHours % 24}h) — '
                'αν δεν ανοίξει το app μέχρι τότε, οι υπενθυμίσεις σταματάνε',
          );
        } else {
          DebugConfig.warning(
              'Root ${root.id}: ⚠️ ΚΑΝΕΝΑ μελλοντικό παιδί μετά το batch — runway = 0!');
        }

        DebugConfig.notif(
            'Root ${root.id}: created $createdForRoot new children in this batch');
      }

      if (bake && pendingToSchedule.isNotEmpty) {
        await scheduleReminders(pendingToSchedule);
      }
      DebugConfig.notif(
          'refreshRecurringReminders: created $createdTotal new child reminders total '
          '(scheduled batch=${pendingToSchedule.length}'
          '${bake ? '' : ', bake=off → scheduleAll'} )');
    } catch (e, stack) {
      DebugConfig.error(
          'ReminderScheduler.refreshRecurringReminders', e, stack);
    }
  }

  /// Pure (για unit test): οι επόμενες [count] εμφανίσεις ΜΕΤΑ το [now],
  /// με αλυσίδα από το [dtstart] (root.triggerAt). Το DTSTART είναι η πρώτη
  /// εμφάνιση· καμία εμφάνιση πριν από αυτό, και το πλέγμα interval>1
  /// μετριέται πάντα από το DTSTART (όχι από «σήμερα»).
  static List<DateTime> planOccurrences(
      Recurrence recurrence, DateTime dtstart, DateTime now, int count) {
    const maxWalk = 6000; // daily ~16 χρόνια ιστορικού — ασφάλεια loop
    final out = <DateTime>[];
    DateTime cursor = dtstart;
    int guard = 0;
    while (!cursor.isAfter(now)) {
      final n = recurrence.nextOccurrence(cursor, anchor: dtstart);
      if (n == null || !n.isAfter(cursor) || ++guard > maxWalk) return out;
      cursor = n;
    }
    out.add(cursor);
    while (out.length < count) {
      final n = recurrence.nextOccurrence(out.last, anchor: dtstart);
      if (n == null || !n.isAfter(out.last)) break;
      out.add(n);
    }
    return out;
  }

  // ─────────────────────────────────────────────────────────
  // Cascade διαγραφή νήματος (ρίζα + όλα τα παιδιά)
  // ─────────────────────────────────────────────────────────

  Future<void> deleteReminderThread(int reminderId) =>
      _bakeQueue.run(() => _deleteReminderThreadImpl(reminderId));

  Future<void> _deleteReminderThreadImpl(int reminderId) async {
    try {
      DebugConfig.notif('ReminderScheduler.deleteReminderThread: id=$reminderId');
      final reminder =
          await SuperNoteHelper.instance.isar.reminders.get(reminderId);
      // Unconditional wipe (N4): ακόμη κι αν η row λείπει, καθάρισε το OS id.
      final rootId = reminder?.parentReminderId ?? reminder?.id ?? reminderId;

      final children = await SuperNoteHelper.instance.isar.reminders
          .filter()
          .parentReminderIdEqualTo(rootId)
          .findAll();

      final allIds = <int>{
        reminderId,
        rootId,
        ...children.map((c) => c.id),
      }.toList();

      // Delete order: DB πρώτα, OS cancel μετά — ακόμη κι αν το DB delete
      // αποτύχει, το finally καθαρίζει τα alarms (κανένα ghost).
      try {
        await SuperNoteHelper.instance.isar.writeTxn(() async {
          await SuperNoteHelper.instance.isar.reminders.deleteAll(allIds);
        });
      } catch (e, stack) {
        DebugConfig.error(
            'ReminderScheduler.deleteReminderThread DB id=$reminderId', e, stack);
      } finally {
        for (final id in allIds) {
          try {
            await NotificationService.instance.cancel(id);
          } catch (e, stack) {
            DebugConfig.error(
                'ReminderScheduler.deleteReminderThread cancel id=$id', e, stack);
          }
        }
      }

      DebugConfig.notif('deleteReminderThread: deleted thread with ids $allIds');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.deleteReminderThread', e, stack);
    }
  }

  Future<void> deleteAllRemindersForItem(int itemId) =>
      _bakeQueue.run(() => _deleteAllRemindersImpl([itemId]));

  /// E05 (F13b): batch εκδοχή — **1** OS snapshot (`pendingNotificationRequests`)
  /// για όλα τα items + 1 query rows + 1 writeTxn (αντί N× platform call).
  /// Ίδιο τελικό state με N× single.
  Future<void> deleteAllRemindersForItems(List<int> itemIds) {
    final ids = itemIds.toSet().toList();
    if (ids.isEmpty) return Future<void>.value();
    return _bakeQueue.run(() => _deleteAllRemindersImpl(ids));
  }

  Future<void> _deleteAllRemindersImpl(List<int> itemIds) async {
    final one = itemIds.length == 1;
    final label =
        one ? 'deleteAllRemindersForItem' : 'deleteAllRemindersForItems';
    final suffix = one ? 'itemId=${itemIds.first}' : 'n=${itemIds.length}';
    try {
      DebugConfig.notif('ReminderScheduler.$label: $suffix');
      final payloads = {for (final id in itemIds) id.toString()};
      final all = await SuperNoteHelper.instance.isar.reminders
          .filter()
          .anyOf(itemIds, (q, id) => q.itemIdEqualTo(id))
          .findAll();
      // H4α: ένα batch αντί για thread-delete ανά row. Το OS scan καλύπτει
      // και ghosts που δεν έχουν πλέον DB row.
      // S283: DB ids → μόνο όσα μπορεί να είναι στο OS (μέλλον ∧ εντός
      // ορίζοντα ∧ όχι habit-deferred), ώστε να μη γίνονται 60 platform calls
      // για 13 alarms. Το payload-union παρακάτω μένει ως ghost protection.
      final ids = <int>{...osSchedulableIds(rows: all, now: DateTime.now())};
      final os = await _readOsSnapshots();
      ids.addAll(os.values
          .where((o) => payloads.contains(o.payload))
          .map((o) => o.id));

      try {
        // Guard στο `all` (όχι στο `ids`): ΠΟΤΕ deleteAll([]) — βλ. hardDeleteMany.
        if (all.isNotEmpty) {
          await SuperNoteHelper.instance.isar.writeTxn(() async {
            await SuperNoteHelper.instance.isar.reminders
                .deleteAll(all.map((r) => r.id).toList());
          });
        }
      } catch (e, stack) {
        DebugConfig.error('ReminderScheduler.$label DB $suffix', e, stack);
      } finally {
        await _cancelReminderIdsImpl(ids);
      }
      DebugConfig.notif(
          '$label: deleted ${all.length} rows, cancelled ${ids.length} OS ids $suffix');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.$label', e, stack);
    }
  }

  /// One-shot purge υπενθυμίσεων εγγραφών συλλογών (feature νεκρό —
  /// η καμπάνα αφαιρέθηκε από το entry detail). Σαρώνει ΟΛΑ τα rows
  /// (χωρίς παράθυρο/status) και σβήνει όσα δείχνουν σε knowledge
  /// item ή σε ανύπαρκτο item (orphans). Idempotent.
  ///
  /// P1#3 (S252): δίχτυο για το postFrame purge (main:239) — ίδιο SPoT
  /// instance-per-concern. Fail-open 60s + NEVER-THROW (το impl κρατά το
  /// δικό του try/catch + `DebugConfig.error`).
  final SerialPassQueue _purgeQueue =
      SerialPassQueue(label: 'ReminderScheduler.purge');

  Future<void> purgeKnowledgeReminders() =>
      _purgeQueue.run(_purgeKnowledgeRemindersImpl);

  Future<void> _purgeKnowledgeRemindersImpl() async {
    try {
      final all = await SuperNoteHelper.instance.isar.reminders
          .where()
          .findAll();
      final doneRoots = <int>{};
      var purged = 0;
      for (final r in all) {
        final item = await SuperNoteHelper.instance.isar.items.get(r.itemId);
        if (item != null && item.type != ItemType.knowledge) continue;
        final rootId = r.parentReminderId ?? r.id;
        if (!doneRoots.add(rootId)) continue;
        await deleteReminderThread(rootId);
        purged++;
      }
      DebugConfig.notif(
          'purgeKnowledgeReminders: scanned=${all.length} purged=$purged');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.purgeKnowledgeReminders', e, stack);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Maintenance gate (B2/E33) — restore/wipe orchestration
  // ─────────────────────────────────────────────────────────

  /// Κλείνει τα gates και των 3 ουρών ΠΡΙΝ το drain (E33).
  /// Ακυρώνει το εκκρεμές debounce refresh· rearm ΜΟΝΟ στο abort (F6).
  void pauseForMaintenance() {
    if (_maintenance) return;
    _maintenance = true;
    final timer = _refreshTimer;
    _refreshTimer = null;
    if (timer != null) {
      timer.cancel();
      _refreshWasPending = true;
    }
    _bakeQueue.pauseForMaintenance();
    _refreshQueue.pauseForMaintenance();
    _purgeQueue.pauseForMaintenance();
    DebugConfig.notif('ReminderScheduler.maintenance: paused');
  }

  /// Περιμένει τα πραγματικά in-flight passes και των 3 ουρών (παράλληλα).
  /// false = δεν καθάρισαν εντός [maxWait] → ο caller κάνει abort ΧΩΡΙΣ close.
  Future<bool> drainForMaintenance(Duration maxWait) async {
    final results = await Future.wait([
      _bakeQueue.waitForIdle(maxWait),
      _refreshQueue.waitForIdle(maxWait),
      _purgeQueue.waitForIdle(maxWait),
    ]);
    final ok = results.every((idle) => idle);
    if (!ok) {
      DebugConfig.warning(
          'ReminderScheduler.maintenance: drain TIMEOUT '
              '(bake=${_bakeQueue.inFlightCount} '
              'refresh=${_refreshQueue.inFlightCount} '
              'purge=${_purgeQueue.inFlightCount})');
    }
    return ok;
  }

  /// Ανοίγει τα gates. Στο abort ([rearmRefresh] true) ξανα-οπλίζει ΜΙΑ
  /// φορά το debounce refresh αν είχε ακυρωθεί/αναβληθεί λόγω pause (F6).
  void resumeAfterMaintenance({bool rearmRefresh = true}) {
    if (!_maintenance) return;
    _maintenance = false;
    _bakeQueue.resumeAfterMaintenance();
    _refreshQueue.resumeAfterMaintenance();
    _purgeQueue.resumeAfterMaintenance();
    DebugConfig.notif('ReminderScheduler.maintenance: resumed');
    if (_refreshWasPending) {
      _refreshWasPending = false;
      if (rearmRefresh) {
        unawaited(debouncedRefreshRecurringReminders());
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // Υπάρχουσες μέθοδοι (όπως τις είχες)
  // ─────────────────────────────────────────────────────────

  Future<void> scheduleReminder(Reminder reminder) =>
      _bakeQueue.run(() => _scheduleReminderImpl(reminder));

  /// Batch scheduling για refresh/top-up/repair: keep υπάρχοντα σωστά alarms,
  /// αντικατέστησε μόνο stale text, πρόσθεσε νέα ΜΟΝΟ στα ελεύθερα slots.
  Future<void> scheduleReminders(Iterable<Reminder> reminders) =>
      _bakeQueue.run(() => _scheduleRemindersImpl(reminders));

  /// Snooze/trigger change: cancel + fresh schedule στο ΙΔΙΟ pass της
  /// _bakeQueue, ώστε να μη μπει άλλο bake ανάμεσα.
  Future<void> rescheduleReminder(Reminder reminder) =>
      _bakeQueue.run(() => _rescheduleReminderImpl(reminder));

  Future<void> _rescheduleReminderImpl(Reminder reminder) async {
    await _cancelReminderIdsImpl([reminder.id]);
    await _scheduleReminderImpl(reminder);
  }

  Future<void> _scheduleReminderImpl(Reminder reminder) async {
    try {
      if (!NotificationService.isSupportedPlatform) return;
      DebugConfig.notif(
          'ReminderScheduler.scheduleReminder: id=${reminder.id}, trigger=${reminder.triggerAt}, status=${reminder.status.name}');
      final settings = await SuperNoteHelper.instance.settings.get();
      if (!settings.notificationsEnabled) return;
      final fresh =
          await SuperNoteHelper.instance.reminders.getById(reminder.id);
      if (fresh == null || fresh.status != ReminderStatus.pending) {
        DebugConfig.notif('scheduleReminder: fresh row missing/non-pending');
        return;
      }
      final os = await _readOsSnapshots();
      if (!os.containsKey(fresh.id) &&
          os.length >= NotificationService.osAlarmLimit) {
        _osWindowTruncated = true;
        DebugConfig.warning(
            'scheduleReminder: OS budget full (${os.length}/${NotificationService.osAlarmLimit}) — keeping existing alarms, id=${fresh.id}');
        return;
      }
      final outcome = await _scheduleOne(
        fresh,
        sound: settings.soundEnabled,
        vibration: settings.vibrationEnabled,
      );
      if (outcome == ScheduleOutcome.skipped) {
        // Orphan/archived/done/past row: μην αφήσεις παλιό alarm στο OS.
        await _cancelReminderIdsImpl([fresh.id]);
      }
      DebugConfig.notif(
          'scheduleReminder: id=${fresh.id} outcome=${outcome.name}');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.scheduleReminder', e, stack);
    }
  }

  Future<void> _scheduleRemindersImpl(Iterable<Reminder> reminders) async {
    try {
      if (!NotificationService.isSupportedPlatform) return;
      final settings = await SuperNoteHelper.instance.settings.get();
      if (!settings.notificationsEnabled) return;
      final rows = reminders.toList();
      if (rows.isEmpty) return;

      final readSw = Stopwatch()..start(); // Φ0/E45
      final os = await _readOsSnapshots();
      final itemsById = await _buildItemsMap(rows);
      readSw.stop();
      final planSw = Stopwatch()..start(); // Φ0/E45
      final plan = buildReminderBakePlan(
        rows: rows,
        items: itemsById,
        osById: os,
        limit: NotificationService.osAlarmLimit,
        now: DateTime.now(),
        incremental: true,
        habitOsWindow: true, // E45/A
        // Καμία stale ακύρωση εδώ: το batch δεν είναι υπεύθυνο για ghosts
        // άλλων rows· το scheduleAll/rescheduleForItem το κάνει scoped.
        cancelableOsIds: const <int>{},
      );
      planSw.stop();
      final modeSw = Stopwatch()..start(); // Φ0/E45
      final mode = await NotificationService.instance.resolveScheduleMode();
      modeSw.stop();
      final result = await _runBakePlan(
        plan,
        sound: settings.soundEnabled,
        vibration: settings.vibrationEnabled,
        mode: mode,
      );
      if (plan.truncated) _osWindowTruncated = true;
      DebugConfig.notif(
          'scheduleReminders: rows=${rows.length} desired=${plan.desiredCount} '
          'baked=${result.baked} kept=${plan.keepIds.length} failed=${result.failed} '
          'skipped=${plan.skippedCount + result.skipped} truncated=${plan.truncated}');
      // Φ0/E45: διαχωρισμός read/plan/mode/cancel/sched/native — η γραμμή
      // `scheduleReminders:` μένει byte-identical για τα υπάρχοντα greps.
      DebugConfig.notif(
          'PERF#9b scheduleReminders: rows=${rows.length} os=${os.length} '
          'readMs=${readSw.elapsedMilliseconds} planMs=${planSw.elapsedMilliseconds} '
          'modeMs=${modeSw.elapsedMilliseconds} cancelMs=${result.cancelMs} '
          'schedMs=${result.schedMs} nativeMs=${result.nativeMs} '
          'dartMs=${result.schedMs - result.nativeMs} baked=${result.baked} '
          'deferred=${plan.deferredCount}');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.scheduleReminders', e, stack);
    }
  }

  /// Ξαναψήνει τα OS alarms ενός item με ζωντανό τίτλο (μετά από μετονομασία).
  /// Μόνο pending one-shots/παιδιά (όχι recurring roots — όπως το scheduleAll)·
  /// τα guards του _scheduleOne (past/archived/done) ισχύουν από κάτω.
  ///
  /// E17: ίδιο `_bakeQueue` με `scheduleAll` — ποτέ παράλληλο bake
  /// στο OS cache· fail-open 60s + NEVER-THROW (ο καλών δεν παγώνει).
  Future<void> rescheduleForItem(int itemId) =>
      _bakeQueue.run(() => _rescheduleForItemImpl(itemId));

  Future<void> _rescheduleForItemImpl(int itemId) async {
    try {
      final item = await SuperNoteHelper.instance.items.getById(itemId);
      final reminders =
          await SuperNoteHelper.instance.reminders.getForItem(itemId);

      // E10 sync: γράψε πρώτα το νέο live text στη DB (root + children), ώστε
      // η αποθηκευμένη κατάσταση να συμφωνεί με αυτό που θα ψηθεί.
      if (item != null) {
        final changed = <Reminder>[];
        final now = DateTime.now();
        for (final r in reminders) {
          final text = syncableReminderNotificationText(r, item);
          if (text != null) {
            r.title = text.title;
            r.body = text.body;
            r.updatedAt = now;
            changed.add(r);
          }
        }
        if (changed.isNotEmpty) {
          await SuperNoteHelper.instance.isar.writeTxn(() async {
            await SuperNoteHelper.instance.isar.reminders.putAll(changed);
          });
        }
      }

      if (item == null) {
        DebugConfig.warning(
            'rescheduleForItem: item=$itemId missing — cancelling ghost alarms');
        await _cancelAllForItemImpl(itemId);
        return;
      }
      if (!NotificationService.isSupportedPlatform) return;
      final settings = await SuperNoteHelper.instance.settings.get();
      if (!settings.notificationsEnabled) return;

      final os = await _readOsSnapshots();
      final reminderIds = reminders.map((r) => r.id).toSet();
      final cancelable = os.values
          .where((o) =>
              o.payload == itemId.toString() || reminderIds.contains(o.id))
          .map((o) => o.id)
          .toSet();
      final plan = buildReminderBakePlan(
        rows: reminders,
        items: {itemId: item},
        osById: os,
        limit: NotificationService.osAlarmLimit,
        now: DateTime.now(),
        incremental: true,
        habitOsWindow: true, // E45/A
        cancelableOsIds: cancelable,
        forceSchedule: true,
      );
      final mode = await NotificationService.instance.resolveScheduleMode();
      final result = await _runBakePlan(
        plan,
        sound: settings.soundEnabled,
        vibration: settings.vibrationEnabled,
        mode: mode,
      );
      if (plan.truncated) _osWindowTruncated = true;
      DebugConfig.notif(
          'rescheduleForItem: itemId=$itemId rebaked=${result.baked} '
          'kept=${plan.keepIds.length} failed=${result.failed} '
          'skipped=${plan.skippedCount + result.skipped} '
          'cancelled=${result.cancelled} truncated=${plan.truncated}');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.rescheduleForItem', e, stack);
    }
  }

  Future<void> cancelReminder(int reminderId) =>
      _bakeQueue.run(() => _cancelReminderIdsImpl([reminderId]));

  Future<void> cancelReminderIds(Iterable<int> ids) =>
      _bakeQueue.run(() => _cancelReminderIdsImpl(ids));

  Future<void> _cancelReminderIdsImpl(Iterable<int> ids) async {
    for (final id in ids.toSet()) {
      try {
        DebugConfig.notif('ReminderScheduler.cancelReminder: id=$id');
        await NotificationService.instance.cancel(id);
      } catch (e, stack) {
        DebugConfig.error('ReminderScheduler.cancelReminder id=$id', e, stack);
      }
    }
  }

  Future<void> cancelAllForItem(int itemId) =>
      _bakeQueue.run(() => _cancelAllForItemImpl(itemId));

  Future<void> _cancelAllForItemImpl(int itemId) async {
    try {
      DebugConfig.notif('ReminderScheduler.cancelAllForItem: itemId=$itemId');
      final reminders =
          await SuperNoteHelper.instance.reminders.getForItem(itemId);
      // S283: cancel ΜΟΝΟ όσων μπορεί να είναι στο OS (μέλλον ∧ εντός
      // ορίζοντα ∧ όχι habit-deferred) — πριν γίνονταν 120 platform calls για
      // 27 alarms (~2,4s). Τα deferred/beyond rows δεν μπήκαν ποτέ στο OS.
      final ids = <int>{
        ...osSchedulableIds(rows: reminders, now: DateTime.now())
      };
      // Unconditional wipe: ακόμη κι αν λείπουν rows, σάρωσε τα OS ghosts
      // που δηλώνουν αυτό το item στο payload.
      final os = await _readOsSnapshots();
      ids.addAll(os.values
          .where((o) => o.payload == itemId.toString())
          .map((o) => o.id));
      await _cancelReminderIdsImpl(ids);
      DebugConfig.notif(
          'cancelAllForItem: itemId=$itemId cancelled=${ids.length}');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.cancelAllForItem', e, stack);
    }
  }

  /// Per-row delete (π.χ. παρελθούσες υπενθυμίσεις): DB πρώτα, μετά cancel.
  /// Δεν αγγίζει root/thread — αυτό είναι ευθύνη του deleteReminderThread.
  Future<void> deleteSingleReminder(int reminderId) =>
      _bakeQueue.run(() => _deleteSingleReminderImpl(reminderId));

  Future<void> _deleteSingleReminderImpl(int reminderId) async {
    try {
      try {
        await SuperNoteHelper.instance.isar.writeTxn(() async {
          await SuperNoteHelper.instance.isar.reminders.delete(reminderId);
        });
      } catch (e, stack) {
        DebugConfig.error(
            'ReminderScheduler.deleteSingleReminder DB id=$reminderId',
            e,
            stack);
      } finally {
        await _cancelReminderIdsImpl([reminderId]);
      }
      DebugConfig.notif(
          'deleteSingleReminder: deleted+cancelled id=$reminderId');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.deleteSingleReminder', e, stack);
    }
  }

  Future<ScheduleOutcome> _scheduleOne(
    Reminder reminder, {
    bool sound = true,
    bool vibration = true,
    AndroidScheduleMode? mode, // batch-override· null = resolve per-call (ως πριν)
  }) async {
    try {
      // E36: πάντα fresh DB row — το batch snapshot μπορεί να είναι stale μετά
      // από snooze/delete που περίμενε στην ουρά.
      final fresh =
          await SuperNoteHelper.instance.reminders.getById(reminder.id);
      if (fresh == null) {
        DebugConfig.notif(
            'ReminderScheduler._scheduleOne: row ${reminder.id} missing, SKIP');
        return ScheduleOutcome.skipped;
      }
      if (fresh.status != ReminderStatus.pending) {
        DebugConfig.notif(
            'ReminderScheduler._scheduleOne: status=${fresh.status.name}, SKIP id=${fresh.id}');
        return ScheduleOutcome.skipped;
      }
      if (fresh.triggerAt.isBefore(DateTime.now())) {
        DebugConfig.notif(
            'ReminderScheduler._scheduleOne: trigger in past, SKIP id=${fresh.id}');
        return ScheduleOutcome.skipped;
      }

      final item =
          await SuperNoteHelper.instance.items.getById(fresh.itemId);
      // E37 orphan guard: χωρίς item δεν υπάρχει έγκυρος προορισμός.
      if (item == null) {
        DebugConfig.warning(
            'ReminderScheduler._scheduleOne: ORPHAN, SKIP id=${fresh.id} itemId=${fresh.itemId}');
        return ScheduleOutcome.skipped;
      }
      if (item.archived) {
        DebugConfig.notif(
            'ReminderScheduler._scheduleOne: ARCHIVED, SKIP id=${fresh.id} itemId=${fresh.itemId}');
        return ScheduleOutcome.skipped;
      }
      // Κάδος: συμμετρικά με archive — οι rows κρατιούνται για το restore,
      // το OS μένει σιωπηλό (χωρίς αυτό το scheduleAll/reboot θα τα ξυπνούσε).
      if (item.isDeleted) {
        DebugConfig.notif(
            'ReminderScheduler._scheduleOne: DELETED, SKIP id=${fresh.id} itemId=${fresh.itemId}');
        return ScheduleOutcome.skipped;
      }
      // A2: ολοκληρωμένο/ακυρωμένο δεν χτυπά.
      final st = item.status;
      if (st == ItemStatus.done || st == ItemStatus.cancelled) {
        DebugConfig.notif(
            'ReminderScheduler._scheduleOne: ${st.name}, SKIP id=${fresh.id} itemId=${fresh.itemId}');
        return ScheduleOutcome.skipped;
      }

      final text = resolveReminderNotificationText(fresh, item);
      DebugConfig.notif(
          '_scheduleOne: itemId=${fresh.itemId} archived=${item.archived} title=${AppStringUtils.redact(item.title)}');

      // E15-F2 (C): το mode λύνεται ΠΡΙΝ το fresh enabled read, ώστε μετά το
      // read να μην υπάρχει await μέχρι το platform call. Έτσι ένα OFF
      // (cancelAll) δεν μπορεί να μπει ανάμεσα και να αφήσει ghost alarm.
      final resolvedMode =
          mode ?? await NotificationService.instance.resolveScheduleMode();
      final enabledNow = (await SuperNoteHelper.instance.settings.get())
          .notificationsEnabled;
      if (!enabledNow) {
        DebugConfig.notif(
            'ReminderScheduler._scheduleOne: OFF, SKIP id=${fresh.id}');
        return ScheduleOutcome.skipped;
      }
      try {
        final nativeSw = Stopwatch()..start(); // Φ0/E45: μόνο το platform call
        final ok = await NotificationService.instance.schedule(
          id: fresh.id,
          title: text.title,
          body: text.body,
          scheduledAt: fresh.triggerAt,
          payload: fresh.itemId.toString(),
          sound: sound,
          vibration: vibration,
          mode: resolvedMode,
        );
        nativeSw.stop();
        _accumNativeUs += nativeSw.elapsedMicroseconds;
        if (!ok) {
          DebugConfig.warning(
              'ReminderScheduler._scheduleOne: FAILED id=${fresh.id} (OS rejected — rows kept)');
          return ScheduleOutcome.failed;
        }
        DebugConfig.notif(
            'ReminderScheduler._scheduleOne: ✅ SUCCESS id=${fresh.id}');
        return ScheduleOutcome.baked;
      } catch (e, stack) {
        DebugConfig.error(
            'ReminderScheduler._scheduleOne: ❌ EXCEPTION id=${fresh.id}',
            e,
            stack);
        return ScheduleOutcome.failed;
      }
    } catch (e, stack) {
      DebugConfig.error(
          'ReminderScheduler._scheduleOne: ❌ OUTER id=${reminder.id}',
          e,
          stack);
      return ScheduleOutcome.failed;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 🔍 DEBUG-ONLY: instant snapshot ΟΛΩΝ των recurring reminders.
  // Δείχνει ΑΜΕΣΑ αν κάποιο root έχει ήδη "στερέψει" (0 μελλοντικά
  // παιδιά) — χρησιμοποιεί δεδομένα ΗΔΗ αποθηκευμένα στη DB, δεν
  // χρειάζεται να περιμένουμε μέρες.
  // ─────────────────────────────────────────────────────────

  Future<void> debugDumpAllRecurringState() async {
    try {
      final now = DateTime.now();
      DebugConfig.notif(
          '══════════ debugDumpAllRecurringState: START ($now) ══════════');

      final allRoots = await SuperNoteHelper.instance.isar.reminders
          .filter()
          .rruleIsNotNull()
          .and()
          .not()
          .rruleEqualTo('')
          .parentReminderIdIsNull()
          .findAll();

      DebugConfig.notif(
          'debugDump: βρέθηκαν ${allRoots.length} recurring roots συνολικά');

      for (final root in allRoots) {
        final item = await SuperNoteHelper.instance.items.getById(root.itemId);
        final allChildren = await SuperNoteHelper.instance.isar.reminders
            .filter()
            .parentReminderIdEqualTo(root.id)
            .sortByTriggerAt()
            .findAll();

        final futureChildren =
        allChildren.where((c) => c.triggerAt.isAfter(now)).toList();
        final pastChildren =
        allChildren.where((c) => !c.triggerAt.isAfter(now)).toList();

        DebugConfig.notif(
          '── Root ${root.id} | item="${item?.title ?? '?'}" (${item?.type.name ?? '?'}) '
              '| rrule="${root.rrule}" | root.triggerAt=${root.triggerAt} | status=${root.status.name}',
        );
        DebugConfig.notif(
          '   Σύνολο παιδιών: ${allChildren.length} '
              '(μελλοντικά: ${futureChildren.length}, περασμένα: ${pastChildren.length})',
        );

        if (futureChildren.isEmpty) {
          DebugConfig.warning(
            '   🔴 STARVED — ΚΑΝΕΝΑ μελλοντικό παιδί! Οι υπενθυμίσεις για αυτό ΕΧΟΥΝ ΗΔΗ σταματήσει.',
          );
          if (pastChildren.isNotEmpty) {
            final lastFired = pastChildren.last;
            final since = now.difference(lastFired.triggerAt);
            DebugConfig.warning(
              '   Τελευταίο παιδί ήταν στις ${lastFired.triggerAt} '
                  '(πριν ${since.inDays}d ${since.inHours % 24}h) — από τότε ΔΕΝ δημιουργήθηκε νέο.',
            );
          }
        } else {
          final maxTrigger = futureChildren
              .map((c) => c.triggerAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          final runway = maxTrigger.difference(now);
          DebugConfig.notif(
            '   🟢 OK — runway μέχρι $maxTrigger (${runway.inDays}d ${runway.inHours % 24}h)',
          );
        }

        final createdTimestamps =
        (allChildren.map((c) => c.createdAt).toSet().toList())..sort();
        DebugConfig.notif('   Batch creation timestamps: $createdTimestamps');
      }
      DebugConfig.notif(
          '══════════ debugDumpAllRecurringState: END ══════════');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.debugDumpAllRecurringState', e, stack);
    }
  }
}
