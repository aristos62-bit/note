// lib/services/reminder_scheduler.dart
import '../helpers/super_note_helper.dart';
import '../helpers/item_color_helper.dart';
import '../models/models.dart';
import 'notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../core/core.dart';
import 'package:isar/isar.dart';
import 'dart:async';

/// Έκβαση ενός OS-bake (skipped ≠ failed: τα skips δεν μετράνε ως αποτυχίες).
/// kept: incremental sync — το alarm υπάρχει ήδη στο OS, δεν ξαναψήθηκε.
enum ScheduleOutcome { baked, skipped, failed, kept }

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
  Timer? _refreshTimer;
  DateTime? _lastRefreshRun; // 🔍 DEBUG: για μέτρηση του κενού μεταξύ refresh

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
      // πέφτουμε στο πλήρες flow. Το stale κρατά ό,τι δεν επιβεβαιώθηκε.
      Set<int>? keepIds;
      Set<int>? stale;
      if (incremental) {
        final current = (await NotificationService.instance
                .getPendingNotifications())
            .map((p) => p.id)
            .toSet();
        if (current.isEmpty) {
          DebugConfig.notif(
              'ReminderScheduler.scheduleAll: INCREMENTAL → OS empty, full flow');
        } else {
          keepIds = current;
          stale = Set<int>.of(current);
        }
      }
      if (keepIds == null) {
        await NotificationService.instance.cancelAll();
        DebugConfig.notif(
            'ReminderScheduler.scheduleAll: cancelAll done (PERF#9 ${totalSw.elapsedMilliseconds}ms)');
      }

      var pending = await SuperNoteHelper.instance.reminders.getPending();
      pending =
          pending.where((r) => r.rrule == null || r.rrule!.isEmpty).toList();
      DebugConfig.notif(
          'ReminderScheduler.scheduleAll: found ${pending.length} pending reminders (after filtering recurring roots)');
      for (final r in pending) {
        DebugConfig.notif(
            '  pending: id=${r.id} trigger=${r.triggerAt} status=${r.status.name} itemId=${r.itemId}');
      }

      // Incremental: ghosts (στο OS αλλά όχι στο DB-pending) φεύγουν ΠΡΙΝ τα
      // bakes, για να ελευθερωθούν slots (όριο AlarmManager 500).
      var cancelled = 0;
      if (stale != null) {
        final pendingIds = pending.map((r) => r.id).toSet();
        for (final id in stale.where((id) => !pendingIds.contains(id)).toList()) {
          await NotificationService.instance.cancel(id);
          stale.remove(id);
          cancelled++;
        }
      }

      final loopSw = Stopwatch()..start(); // PERF#9 (S224)
      var done = 0; // PERF#9 (S224)
      var baked = 0;
      var kept = 0;
      var failed = 0;
      var skipped = 0;
      var truncated = false;
      var chunkStartMs = 0; // PERF#9 (S224)
      // M1: 1 resolve για όλο το batch (αντί για 1/alarm) — singles αλλού per-call.
      final batchMode =
          await NotificationService.instance.resolveScheduleMode();
      // M3 budget: oldest-first (το getPending είναι sortByTriggerAt) + stop
      // στο λειτουργικό όριο — deterministic αντί για σιωπηλή απώλεια iOS.
      // Χωρίς παράθυρο ημερών: καθαρό count-cap κατά triggerAt σειρά.
      // Στο όριο μετράνε baked + kept (και τα δύο καταλαμβάνουν OS slot).
      final limit = NotificationService.osAlarmLimit;
      for (final reminder in pending) {
        if (baked + kept >= limit) {
          truncated = true;
          DebugConfig.warning(
              'scheduleAll: BUDGET cut at ${baked + kept}/$limit of ${pending.length} — oldest-first kept');
          break;
        }
        // E15-F2 (C3): φραγή — αν οι ειδοποιήσεις έκλεισαν στη μέση του loop,
        // σταμάτα αμέσως (το _scheduleOne έχει δικό του guard, αλλά έτσι
        // γλιτώνουμε έως 450 περιττά reads/κλήσεις).
        if (done > 0 && done % 20 == 0) {
          final stillEnabled = (await SuperNoteHelper.instance.settings.get())
              .notificationsEnabled;
          if (!stillEnabled) {
            DebugConfig.warning(
                'scheduleAll: OFF mid-loop at $done/${pending.length} - aborting bake');
            break;
          }
        }
        final scheduledItem =
            await SuperNoteHelper.instance.items.getById(reminder.itemId);
        DebugConfig.notif(
            '  scheduleAll: scheduling id=${reminder.id} itemId=${reminder.itemId} archived=${scheduledItem?.archived}');
        final outcome = await _scheduleOne(
          reminder,
          sound: settings.soundEnabled,
          vibration: settings.vibrationEnabled,
          mode: batchMode,
          keepIds: keepIds,
        );
        if (outcome == ScheduleOutcome.baked) {
          baked++;
          stale?.remove(reminder.id);
        } else if (outcome == ScheduleOutcome.kept) {
          kept++;
          stale?.remove(reminder.id);
        } else if (outcome == ScheduleOutcome.failed) {
          failed++;
        } else {
          skipped++;
          // Skipped αλλά υπάρχει στο OS (archived/done/past ενώ ψήθηκε παλιά) → cancel.
          if (stale != null && stale.remove(reminder.id)) {
            await NotificationService.instance.cancel(reminder.id);
            cancelled++;
          }
        }
        done++; // PERF#9 (S224)
        if (done % 50 == 0) {
          // PERF#9 (S224): αν ο χρόνος ανά 50άδα μεγαλώνει → O(n²) στο plugin
          final nowMs = loopSw.elapsedMilliseconds;
          DebugConfig.notif(
              'PERF#9 scheduleAll: $done/${pending.length} — τελευταία 50 σε ${nowMs - chunkStartMs}ms');
          chunkStartMs = nowMs;
        }
      }
      loopSw.stop(); // PERF#9 (S224)
      // Incremental: ό,τι έμεινε στο stale (πέρα από το budget cut, ή failed)
      // δεν ανήκει στο desired σύνολο → cancel.
      if (stale != null) {
        for (final id in stale.toList()) {
          await NotificationService.instance.cancel(id);
          cancelled++;
        }
        DebugConfig.notif(
            'PERF#9 scheduleAll: INCREMENTAL cancel=$cancelled bake=$baked keep=$kept');
      }
      final osCount = // PERF#9 (S224)
          (await NotificationService.instance.getPendingNotifications()).length;
      final cut = pending.length - done;
      _osWindowTruncated = truncated;
      _lastFullBakeDay = DateTime.now().startOfDay;
      DebugConfig.notif(
          'PERF#9 scheduleAll: DONE db=${pending.length} baked=$baked kept=$kept failed=$failed skipped=$skipped cut=$cut truncated=$truncated os=$osCount '
          'loop=${loopSw.elapsedMilliseconds}ms total=${totalSw.elapsedMilliseconds}ms '
          'avg=${pending.isEmpty ? 0 : (loopSw.elapsedMilliseconds / pending.length).toStringAsFixed(1)}ms/alarm');
      DebugConfig.notif('ReminderScheduler.scheduleAll: DONE');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.scheduleAll', e, stack);
    }
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
    _refreshTimer?.cancel();
    _refreshTimer = Timer(delay, () async {
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

  Future<void> refreshRecurringReminders() =>
      _refreshQueue.run(_refreshRecurringRemindersImpl);

  Future<void> _refreshRecurringRemindersImpl() async {
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
      final cleaned =
          await SuperNoteHelper.instance.reminders.cleanupOldPending();
      if (cleaned > 0) {
        DebugConfig.notif(
            'refreshRecurringReminders: cleaned $cleaned old past reminders');
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
      for (final r in allRecurring) {
        final item = await SuperNoteHelper.instance.items.getById(r.itemId);
        DebugConfig.notif(
          '  root id=${r.id} itemId=${r.itemId} trigger=${r.triggerAt} rrule="${r.rrule}" type=${item?.type.name ?? 'null'} title="${item?.title ?? 'null'}"',
        );
        if (item != null && item.type == ItemType.habit) {
          DebugConfig.notif(
              'refreshRecurringReminders: skipping habit root id=${r.id}');
          continue;
        }
        // #2: Τα αρχειοθετημένα items δεν ξαναγεμίζουν recurring παιδιά.
        if (item != null && item.archived) {
          DebugConfig.notif(
              'refreshRecurringReminders: skipping archived root id=${r.id}');
          continue;
        }
        // Κάδος: συμμετρικά με archive — κρατημένες rows, καμία αναγέννηση.
        if (item != null && item.isDeleted) {
          DebugConfig.notif(
              'refreshRecurringReminders: skipping deleted root id=${r.id}');
          continue;
        }
        // A2: ούτε τα done/cancelled (το item είναι ήδη fetched — 0 έξτρα query).
        if (item != null &&
            (item.status == ItemStatus.done ||
                item.status == ItemStatus.cancelled)) {
          DebugConfig.notif(
              'refreshRecurringReminders: skipping ${item.status.name} root id=${r.id}');
          continue;
        }
        filtered.add(r);
      }

      DebugConfig.notif(
          'Found ${allRecurring.length} recurring root reminders');
      final now = DateTime.now();
      int createdTotal = 0;

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
        final futureChildren = await SuperNoteHelper.instance.isar.reminders
            .filter()
            .parentReminderIdEqualTo(root.id)
            .triggerAtGreaterThan(now, include: true)
            .findAll();

        DebugConfig.notif(
          'Root ${root.id}: futureChildren count=${futureChildren.length} after filtering parentReminderId=${root.id}',
        );
        for (final fc in futureChildren) {
          DebugConfig.notif(
            '  child id=${fc.id} trigger=${fc.triggerAt} status=${fc.status.name}',
          );
        }

        if (futureChildren.isNotEmpty) {
          // ✅ Έλεγχος αν τα παιδιά έχουν σωστή ώρα (ίδια με το root trigger).
          // Εξαιρούνται τα snoozed (snoozeUntil != null) — η μετατοπισμένη
          // ώρα τους είναι σκόπιμη και δεν πρέπει να διαγράφονται.
          final wrongTimeChildren = futureChildren
              .where((child) =>
                  child.snoozeUntil == null &&
                  (child.triggerAt.hour != root.triggerAt.hour ||
                      child.triggerAt.minute != root.triggerAt.minute))
              .toList();

          // Υπάρχουν παιδιά με λάθος ώρα → διέγραψε τα
          if (wrongTimeChildren.isNotEmpty) {
            DebugConfig.notif(
              'Root ${root.id}: found ${wrongTimeChildren.length} children with wrong trigger time, cleaning up',
            );
            for (final wrongChild in wrongTimeChildren) {
              DebugConfig.notif(
                '  Deleting wrong child id=${wrongChild.id} trigger=${wrongChild.triggerAt} (expected hour=${root.triggerAt.hour}:${root.triggerAt.minute})',
              );
              await NotificationService.instance.cancel(wrongChild.id);
              await SuperNoteHelper.instance.isar.writeTxn(() async {
                await SuperNoteHelper.instance.isar.reminders
                    .delete(wrongChild.id);
              });
            }
          }

          // ✅ Skip μόνο αν έχουμε ΑΡΚΕΤΑ σωστά παιδιά (>= batchSize - 1)
          // Αν έχουμε λιγότερα → top-up batch
          final correctChildren = futureChildren
              .where((child) =>
          child.triggerAt.hour == root.triggerAt.hour &&
              child.triggerAt.minute == root.triggerAt.minute)
              .toList();

          if (correctChildren.length >= batchSize - 1) {
            DebugConfig.notif(
              'Root ${root.id}: has ${correctChildren.length} correct children (>= ${batchSize - 1}), skipping',
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

          final child = Reminder()
            ..itemId = root.itemId
            ..triggerAt = occ
            ..rrule = null // τα παιδιά είναι one-shot
            ..title = root.title
            ..body = root.body
            ..status = ReminderStatus.pending
            ..parentReminderId = root.id
            ..createdAt = DateTime.now();

          await SuperNoteHelper.instance.isar.writeTxn(() async {
            await SuperNoteHelper.instance.isar.reminders.put(child);
          });

          await scheduleReminder(child);
          createdForRoot++;
          createdTotal++;
          DebugConfig.notif(
              'Created child reminder ${child.id} for root ${root.id} at $occ');
        }

        // 🔍 DEBUG: runway — πότε εξαντλείται το τρέχον batch παιδιών
        final allFutureChildrenNow = await SuperNoteHelper.instance.isar.reminders
            .filter()
            .parentReminderIdEqualTo(root.id)
            .triggerAtGreaterThan(now, include: true)
            .findAll();
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

      DebugConfig.notif(
          'refreshRecurringReminders: created $createdTotal new child reminders total');
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

  Future<void> deleteReminderThread(int reminderId) async {
    try {
      DebugConfig.notif('ReminderScheduler.deleteReminderThread: id=$reminderId');
      final reminder =
      await SuperNoteHelper.instance.isar.reminders.get(reminderId);
      if (reminder == null) return;
      final rootId = reminder.parentReminderId ?? reminder.id;

      final children = await SuperNoteHelper.instance.isar.reminders
          .filter()
          .parentReminderIdEqualTo(rootId)
          .findAll();

      final allIds = [rootId, ...children.map((c) => c.id)];

      for (final id in allIds) {
        await NotificationService.instance.cancel(id);
      }

      await SuperNoteHelper.instance.isar.writeTxn(() async {
        await SuperNoteHelper.instance.isar.reminders.deleteAll(allIds);
      });

      DebugConfig.notif('deleteReminderThread: deleted thread with ids $allIds');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.deleteReminderThread', e, stack);
    }
  }

  Future<void> deleteAllRemindersForItem(int itemId) async {
    try {
      DebugConfig.notif(
          'ReminderScheduler.deleteAllRemindersForItem: itemId=$itemId');
      final all = await SuperNoteHelper.instance.isar.reminders
          .filter()
          .itemIdEqualTo(itemId)
          .findAll();
      if (all.isEmpty) return;
      // H4α: ένα batch αντί για thread-delete ανά row (μια συνήθεια έχει
      // ~180 rows → 180 queries/transactions). Τα παιδιά έχουν ίδιο itemId.
      final ids = [for (final r in all) r.id];
      for (final id in ids) {
        await NotificationService.instance.cancel(id);
      }
      await SuperNoteHelper.instance.isar.writeTxn(() async {
        await SuperNoteHelper.instance.isar.reminders.deleteAll(ids);
      });
      DebugConfig.notif(
          'deleteAllRemindersForItem: deleted ${ids.length} rows itemId=$itemId');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.deleteAllRemindersForItem', e, stack);
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
  // Υπάρχουσες μέθοδοι (όπως τις είχες)
  // ─────────────────────────────────────────────────────────

  Future<void> scheduleReminder(Reminder reminder) async {
    try {
      DebugConfig.notif(
          'ReminderScheduler.scheduleReminder: id=${reminder.id}, trigger=${reminder.triggerAt}, status=${reminder.status.name}');
      final settings = await SuperNoteHelper.instance.settings.get();
      if (!settings.notificationsEnabled) return;
      if (reminder.triggerAt.isBefore(DateTime.now())) {
        DebugConfig.notif('scheduleReminder: trigger in past, skipping');
        return;
      }
      if (reminder.status != ReminderStatus.pending) {
        DebugConfig.notif(
            'scheduleReminder: status is ${reminder.status.name}, skipping');
        return;
      }
      await _scheduleOne(
        reminder,
        sound: settings.soundEnabled,
        vibration: settings.vibrationEnabled,
      );
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.scheduleReminder', e, stack);
    }
  }

  /// Ξαναψήνει τα OS alarms ενός item με ζωντανό τίτλο (μετά από μετονομασία).
  /// Μόνο pending one-shots/παιδιά (όχι recurring roots — όπως το scheduleAll)·
  /// τα guards του _scheduleOne (past/archived/done) ισχύουν από κάτω.
  Future<void> rescheduleForItem(int itemId) async {
    try {
      if (!NotificationService.isSupportedPlatform) return;
      final settings = await SuperNoteHelper.instance.settings.get();
      if (!settings.notificationsEnabled) return;
      final reminders =
          await SuperNoteHelper.instance.reminders.getForItem(itemId);
      var rebaked = 0;
      var failed = 0;
      var skipped = 0;
      for (final r in reminders) {
        if (r.status != ReminderStatus.pending) continue;
        if (r.rrule != null && r.rrule!.isNotEmpty) continue;
        final outcome = await _scheduleOne(
          r,
          sound: settings.soundEnabled,
          vibration: settings.vibrationEnabled,
        );
        if (outcome == ScheduleOutcome.baked) {
          rebaked++;
        } else if (outcome == ScheduleOutcome.failed) {
          failed++;
        } else {
          skipped++;
        }
      }
      DebugConfig.notif(
          'rescheduleForItem: itemId=$itemId rebaked=$rebaked failed=$failed skipped=$skipped');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.rescheduleForItem', e, stack);
    }
  }

  Future<void> cancelReminder(int reminderId) async {
    try {
      DebugConfig.notif('ReminderScheduler.cancelReminder: id=$reminderId');
      await NotificationService.instance.cancel(reminderId);
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.cancelReminder', e, stack);
    }
  }

  Future<void> cancelAllForItem(int itemId) async {
    try {
      DebugConfig.notif('ReminderScheduler.cancelAllForItem: itemId=$itemId');
      final reminders =
      await SuperNoteHelper.instance.reminders.getForItem(itemId);
      for (final r in reminders) {
        await NotificationService.instance.cancel(r.id);
      }
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.cancelAllForItem', e, stack);
    }
  }

  Future<ScheduleOutcome> _scheduleOne(
    Reminder reminder, {
    bool sound = true,
    bool vibration = true,
    AndroidScheduleMode? mode, // batch-override· null = resolve per-call (ως πριν)
    Set<int>? keepIds, // incremental sync: ids ήδη στο OS → kept, χωρίς bake
  }) async {
    final now = DateTime.now();
    if (reminder.triggerAt.isBefore(now)) {
      DebugConfig.notif(
          'ReminderScheduler._scheduleOne: SKIP - trigger in past');
      return ScheduleOutcome.skipped;
    }

    final item =
        await SuperNoteHelper.instance.items.getById(reminder.itemId);
    String title = reminder.title ?? 'SuperNote';
    String body = reminder.body ?? 'Έχεις μια υπενθύμιση';

    if (reminder.title == null && item != null) {
      title = item.icon != null
          ? '${item.icon} ${item.title ?? 'Χωρίς τίτλο'}'
          : item.title ?? 'Χωρίς τίτλο';
    } else if ((reminder.title == 'Υπενθύμιση' ||
            ItemColorHelper.isBirthdayEvent(item)) &&
        item?.title?.isNotEmpty == true) {
      // Generic bell + γενέθλια (S156 SPoT predicate, όπως το resync) →
      // ζωντανός τίτλος: το resync σώζει body=όνομα, το schedule το
      // ξαναδιαβάζει (ίδια σύμβαση)· habits (δικοί τους τίτλοι) snapshot.
      body = item!.title!;
      DebugConfig.notif('ReminderScheduler._scheduleOne: live-body used');
    }
    DebugConfig.notif(
        '_scheduleOne: itemId=${reminder.itemId} archived=${item?.archived} title=${AppStringUtils.redact(item?.title)}');
    // #2: Τα αρχειοθετημένα items ΔΕΝ προγραμματίζουν OS reminders (archive = σίγαση).
    if (item?.archived == true) {
      DebugConfig.notif(
          'ReminderScheduler._scheduleOne: ARCHIVED, SKIP id=${reminder.id} itemId=${reminder.itemId}');
      return ScheduleOutcome.skipped;
    }
    // Κάδος: συμμετρικά με archive — οι rows κρατιούνται για το restore,
    // το OS μένει σιωπηλό (χωρίς αυτό το scheduleAll/reboot θα τα ξυπνούσε).
    if (item?.isDeleted == true) {
      DebugConfig.notif(
          'ReminderScheduler._scheduleOne: DELETED, SKIP id=${reminder.id} itemId=${reminder.itemId}');
      return ScheduleOutcome.skipped;
    }
    // A2: ολοκληρωμένο/ακυρωμένο δεν χτυπά (ίδια σημασιολογία με archive·
    // το item είναι ήδη fetched για το live-body — 0 έξτρα query).
    final st = item?.status;
    if (st == ItemStatus.done || st == ItemStatus.cancelled) {
      DebugConfig.notif(
          'ReminderScheduler._scheduleOne: ${st?.name}, SKIP id=${reminder.id} itemId=${reminder.itemId}');
      return ScheduleOutcome.skipped;
    }
    // Incremental sync: τα guards πέρασαν, το alarm υπάρχει ήδη στο OS → keep.
    if (keepIds != null && keepIds.contains(reminder.id)) {
      DebugConfig.notif(
          'ReminderScheduler._scheduleOne: KEPT id=${reminder.id} (already in OS)');
      return ScheduleOutcome.kept;
    }
    // E15-F2 (C): το mode λύνεται ΠΡΙΝ το fresh enabled read, ώστε μετά το
    // read να μην υπάρχει await μέχρι το platform call. Έτσι ένα OFF
    // (cancelAll) δεν μπορεί να μπει ανάμεσα και να αφήσει ghost alarm.
    final resolvedMode =
        mode ?? await NotificationService.instance.resolveScheduleMode();
    // Fresh guard: το settings του batch είναι snapshot πριν το loop· αν ο
    // χρήστης κλείσει τις ειδοποιήσεις στη μέση, σταματάμε αμέσως.
    final enabledNow = (await SuperNoteHelper.instance.settings.get())
        .notificationsEnabled;
    if (!enabledNow) {
      DebugConfig.notif(
          'ReminderScheduler._scheduleOne: OFF, SKIP id=${reminder.id}');
      return ScheduleOutcome.skipped;
    }
    try {
      final ok = await NotificationService.instance.schedule(
        id: reminder.id,
        title: title,
        body: body,
        scheduledAt: reminder.triggerAt,
        payload: reminder.itemId.toString(),
        sound: sound,
        vibration: vibration,
        mode: resolvedMode,
      );
      if (!ok) {
        DebugConfig.warning(
            'ReminderScheduler._scheduleOne: FAILED id=${reminder.id} (OS rejected — rows kept)');
        return ScheduleOutcome.failed;
      }
      DebugConfig.notif(
          'ReminderScheduler._scheduleOne: ✅ SUCCESS id=${reminder.id}');
      return ScheduleOutcome.baked;
    } catch (e, stack) {
      DebugConfig.error(
          'ReminderScheduler._scheduleOne: ❌ EXCEPTION id=${reminder.id}',
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
