// lib/services/reminder_scheduler.dart
import '../helpers/super_note_helper.dart';
import '../models/models.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';
import '../core/core.dart';
import 'package:isar/isar.dart';
import 'dart:async';

class ReminderScheduler {
  ReminderScheduler._internal();
  static final ReminderScheduler instance = ReminderScheduler._internal();
  Timer? _refreshTimer;
  DateTime? _lastRefreshRun; // 🔍 DEBUG: για μέτρηση του κενού μεταξύ refresh

  Future<void> scheduleAll() async {
    try {
      DebugConfig.notif(
          'ReminderScheduler.scheduleAll: called, platform=$defaultTargetPlatform');
      if (![
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ].contains(defaultTargetPlatform)) {
        DebugConfig.notif(
            'ReminderScheduler.scheduleAll: platform not supported, skipping');
        return;
      }

      final settings = await SuperNoteHelper.instance.settings.get();
      DebugConfig.notif(
          'ReminderScheduler.scheduleAll: notificationsEnabled=${settings.notificationsEnabled}');
      if (!settings.notificationsEnabled) return;

      await NotificationService.instance.cancelAll();
      DebugConfig.notif('ReminderScheduler.scheduleAll: cancelAll done');

      var pending = await SuperNoteHelper.instance.reminders.getPending();
      pending =
          pending.where((r) => r.rrule == null || r.rrule!.isEmpty).toList();
      DebugConfig.notif(
          'ReminderScheduler.scheduleAll: found ${pending.length} pending reminders (after filtering recurring roots)');
      for (final r in pending) {
        DebugConfig.notif(
            '  pending: id=${r.id} trigger=${r.triggerAt} status=${r.status.name} itemId=${r.itemId}');
      }

      for (final reminder in pending) {
        final scheduledItem =
            await SuperNoteHelper.instance.items.getById(reminder.itemId);
        DebugConfig.notif(
            '  scheduleAll: scheduling id=${reminder.id} itemId=${reminder.itemId} archived=${scheduledItem?.archived}');
        await _scheduleOne(
          reminder,
          sound: settings.soundEnabled,
          vibration: settings.vibrationEnabled,
        );
      }
      DebugConfig.notif('ReminderScheduler.scheduleAll: DONE');
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.scheduleAll', e, stack);
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

  Future<void> refreshRecurringReminders() async {
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
        const batchSize = 5;

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

        // 2. Δημιούργησε νέο batch (ή top-up αν έχουν απομείνει λίγα παιδιά)
        final List<DateTime> nextOccurrences = [];

        // ✅ Χρησιμοποιούμε την ώρα του root trigger αντί για now
        // ώστε τα παιδιά να έχουν πάντα τη σωστή ώρα (π.χ. 20:30)
        final rootHour = root.triggerAt.hour;
        final rootMinute = root.triggerAt.minute;
        final rootSecond = root.triggerAt.second;

        final todayAtTriggerTime = DateTime(
          now.year,
          now.month,
          now.day,
          rootHour,
          rootMinute,
          rootSecond,
        );

        // Αν η σημερινή ώρα trigger δεν έχει παρέλθει ΚΑΙ είναι έγκυρη ημέρα
        // βάσει recurrence, συμπεριλαμβάνουμε το σήμερα
        // (το nextOccurrence επιστρέφει ΠΑΝΤΑ επόμενη περίοδο, ποτέ ίδια)
        if (todayAtTriggerTime.isAfter(now) && _isTodayValidRecurrence(recurrence, now, root)) {
          nextOccurrences.add(todayAtTriggerTime);
        }

        // ✅ Ξεκινάμε πάντα από todayAtTriggerTime (με τη σωστή ώρα του root)
        // Έτσι το nextOccurrence() παράγει παιδιά με τη σωστή ώρα
        // Αν η λίστα έχει ήδη entries, ξεκινάμε από το τελευταίο +1sec
        DateTime current = nextOccurrences.isNotEmpty
            ? nextOccurrences.last
            : todayAtTriggerTime;
        while (nextOccurrences.length < batchSize) {
          // Anchor = DTSTART του root (RRULE-σωστό)· monthly/yearly anchors
          // είναι απόλυτα (μήνες/έτη) χωρίς epoch-αντίστοιχο → μηδέν απόκλιση.
          // Για weekly-habits ισχύει το epochMonday (βλ. Recurrence) — σκόπιμα.
          final next = recurrence.nextOccurrence(current, anchor: root.triggerAt);
          if (next == null) break;
          nextOccurrences.add(next);
          // current = next.add(const Duration(seconds: 1));
          current = next;
        }

        if (nextOccurrences.isEmpty) {
          DebugConfig.notif(
              'Root ${root.id}: no future occurrences from rrule, deleting thread');
          await deleteReminderThread(root.id);
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

  /// Ελέγχει αν το σήμερα είναι έγκυρη ημέρα βάσει recurrence
  bool _isTodayValidRecurrence(Recurrence recurrence, DateTime now, Reminder root) {
    switch (recurrence.type) {
      case RecurrenceType.daily:
      case RecurrenceType.custom:
      // ✅ Αν interval > 1 (π.χ. κάθε 3 μέρες), ελέγχουμε αν σήμερα
      // είναι έγκυρη μέρα βάσει της αρχικής ημερομηνίας του root
        if (recurrence.interval == 1) return true;
        final diffDays = DateTime(now.year, now.month, now.day)
            .difference(DateTime(
          root.triggerAt.year,
          root.triggerAt.month,
          root.triggerAt.day,
        ))
            .inDays;
        return diffDays >= 0 && diffDays % recurrence.interval == 0;
      case RecurrenceType.weekly:
        if (recurrence.days != null && recurrence.days!.isNotEmpty) {
          return Recurrence.isValidWeeklyDay(
              now, recurrence.days!, recurrence.interval, root.triggerAt);
        }
        final diff = DateTime(now.year, now.month, now.day)
            .difference(DateTime(
              root.triggerAt.year, root.triggerAt.month, root.triggerAt.day))
            .inDays;
        return diff >= 0 && diff % (7 * recurrence.interval) == 0;
      case RecurrenceType.monthly:
        if (recurrence.days != null && recurrence.days!.isNotEmpty) {
          if (!recurrence.days!.contains(now.day)) return false;
          if (recurrence.interval <= 1) return true;
          final totalMonths = now.year * 12 + now.month - 1;
          final rootMonths = root.triggerAt.year * 12 + root.triggerAt.month - 1;
          return totalMonths >= rootMonths &&
              (totalMonths - rootMonths) % recurrence.interval == 0;
        }
        final totalMonths = now.year * 12 + now.month - 1;
        final rootMonths = root.triggerAt.year * 12 + root.triggerAt.month - 1;
        return now.day == root.triggerAt.day &&
            totalMonths >= rootMonths &&
            (totalMonths - rootMonths) % recurrence.interval == 0;
      case RecurrenceType.yearly:
        if (recurrence.days != null && recurrence.days!.length == 2) {
          if (recurrence.days![0] != now.month ||
              recurrence.days![1] != now.day) {
            return false;
          }
          if (recurrence.interval <= 1) return true;
          return now.year >= root.triggerAt.year &&
              (now.year - root.triggerAt.year) % recurrence.interval == 0;
        }
        return now.month == root.triggerAt.month &&
            now.day == root.triggerAt.day &&
            now.year >= root.triggerAt.year &&
            (now.year - root.triggerAt.year) % recurrence.interval == 0;
    }
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
      for (final r in all) {
        await deleteReminderThread(r.id);
      }
    } catch (e, stack) {
      DebugConfig.error('ReminderScheduler.deleteAllRemindersForItem', e, stack);
    }
  }

  /// One-shot purge υπενθυμίσεων εγγραφών συλλογών (feature νεκρό —
  /// η καμπάνα αφαιρέθηκε από το entry detail). Σαρώνει ΟΛΑ τα rows
  /// (χωρίς παράθυρο/status) και σβήνει όσα δείχνουν σε knowledge
  /// item ή σε ανύπαρκτο item (orphans). Idempotent.
  Future<void> purgeKnowledgeReminders() async {
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

  Future<void> _scheduleOne(
    Reminder reminder, {
    bool sound = true,
    bool vibration = true,
  }) async {
    final now = DateTime.now();
    if (reminder.triggerAt.isBefore(now)) {
      DebugConfig.notif(
          'ReminderScheduler._scheduleOne: SKIP - trigger in past');
      return;
    }

    String title = reminder.title ?? 'SuperNote';
    String body = reminder.body ?? 'Έχεις μια υπενθύμιση';

    if (reminder.title == null) {
      final item =
          await SuperNoteHelper.instance.items.getById(reminder.itemId);
      if (item != null) {
        title = item.icon != null
            ? '${item.icon} ${item.title ?? 'Χωρίς τίτλο'}'
            : item.title ?? 'Χωρίς τίτλο';
      }
    }
    final item = await SuperNoteHelper.instance.items.getById(reminder.itemId);
    DebugConfig.notif(
        '_scheduleOne: itemId=${reminder.itemId} archived=${item?.archived} title=${AppStringUtils.redact(item?.title)}');
    // #2: Τα αρχειοθετημένα items ΔΕΝ προγραμματίζουν OS reminders (archive = σίγαση).
    if (item?.archived == true) {
      DebugConfig.notif(
          'ReminderScheduler._scheduleOne: ARCHIVED, SKIP id=${reminder.id} itemId=${reminder.itemId}');
      return;
    }
    try {
      await NotificationService.instance.schedule(
        id: reminder.id,
        title: title,
        body: body,
        scheduledAt: reminder.triggerAt,
        payload: reminder.itemId.toString(),
        sound: sound,
        vibration: vibration,
      );
      DebugConfig.notif(
          'ReminderScheduler._scheduleOne: ✅ SUCCESS id=${reminder.id}');
    } catch (e, stack) {
      DebugConfig.error(
          'ReminderScheduler._scheduleOne: ❌ EXCEPTION id=${reminder.id}',
          e,
          stack);
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
