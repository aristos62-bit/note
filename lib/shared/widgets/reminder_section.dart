// lib/shared/widgets/reminder_section.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../services/reminder_scheduler.dart';
import '../../services/notification_service.dart';
import 'reminder_recurrence_picker.dart';

// ---------------------------------------------------------------------
// Main Widget
// ---------------------------------------------------------------------

class ReminderSection extends ConsumerStatefulWidget {
  final int itemId;
  final String itemTitle;
  final DateTime? defaultStartTime;

  const ReminderSection({
    super.key,
    required this.itemId,
    required this.itemTitle,
    this.defaultStartTime,
  });

  @override
  ConsumerState<ReminderSection> createState() => _ReminderSectionState();
}

class _ReminderSectionState extends ConsumerState<ReminderSection> {
  bool _enabled = false;
  DateTime? _triggerDateTime;
  Recurrence? _recurrence;
  bool _isLoading = true;
  int? _reminderId;

  /// Υπάρχει ώρα που μπορεί πραγματικά να χτυπήσει: μελλοντική ώρα, ή
  /// επαναλαμβανόμενη (το DTSTART μπορεί να είναι στο παρελθόν).
  bool get _hasUsableTrigger {
    final t = _triggerDateTime;
    if (t == null) return false;
    return _recurrence != null || !t.isBefore(DateTime.now());
  }

  /// SnackBar με mounted check (mirror DetailScreenMixin.showSnackBar —
  /// το mixin δεν εφαρμόζεται εδώ, απαιτεί titleCtrl).
  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    DebugConfig.notif('ReminderSection._loadData: itemId=${widget.itemId}');
    setState(() => _isLoading = true);
    try {
      final reminders = await ref.read(itemRemindersProvider(widget.itemId).future);
      DebugConfig.notif('ReminderSection._loadData: found ${reminders.length} reminders for item ${widget.itemId}');
      final roots = reminders.where((r) => r.rrule != null && r.parentReminderId == null).toList();
      final children = reminders.where((r) => r.rrule == null && r.parentReminderId != null).toList();
      DebugConfig.notif('  breakdown: ${roots.length} roots, ${children.length} children');
      for (final r in reminders) {
        DebugConfig.notif('  reminder id=${r.id} status=${r.status.name} trigger=${r.triggerAt} rrule=${r.rrule} parentId=${r.parentReminderId}');
      }
      if (reminders.isNotEmpty) {
        // ✅ Φορτώνουμε πάντα το ROOT reminder (parentReminderId == null)
        // Αν δεν υπάρχει root (π.χ. μόνο παιδιά), παίρνουμε το first ως fallback
        final root = reminders.firstWhere(
              (r) => r.parentReminderId == null,
          orElse: () => reminders.first,
        );
        if (roots.length > 1) {
          DebugConfig.warning('ReminderSection._loadData: ⚠️ MULTIPLE ROOTS ($roots) for item=${widget.itemId}! Selected root id=${root.id}');
        }
        _reminderId = root.id;
        _triggerDateTime = root.triggerAt;
        _enabled = true;
        _recurrence = rruleToRecurrence(root.rrule);
        DebugConfig.notif('ReminderSection._loadData: loaded root reminder id=${root.id} parentId=${root.parentReminderId} enabled=true');
      } else {
        _reminderId = null;
        _triggerDateTime = null;
        _enabled = false;
        _recurrence = null;
        DebugConfig.notif('ReminderSection._loadData: no reminders found, enabled=false');
      }
    } catch (e) {
      DebugConfig.error('ReminderSection._loadData', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveReminder() async {
    DebugConfig.notif('ReminderSection._saveReminder: enabled=$_enabled, trigger=$_triggerDateTime, reminderId=$_reminderId, itemId=${widget.itemId}');
    try {
      if (!_enabled || _triggerDateTime == null) {
        DebugConfig.notif('ReminderSection._saveReminder: disabled or no trigger → deleting if exists');
        if (_reminderId != null) {
          DebugConfig.notif('ReminderSection._saveReminder: deleting ALL reminders for itemId=${widget.itemId}');
          await ReminderScheduler.instance.deleteAllRemindersForItem(widget.itemId);
          _reminderId = null;
          ref.invalidate(itemRemindersProvider(widget.itemId));
          ref.invalidate(reminderNotifierProvider(widget.itemId));
          ref.invalidate(pendingRemindersProvider);
          DebugConfig.notif('ReminderSection._saveReminder: all reminders deleted');
        }
        return;
      }

      // Windows: rows saved, no OS alarm (hint shown in UI).
      if (!NotificationService.isSupportedPlatform) {
        DebugConfig.warning('ReminderSection._saveReminder: unsupported platform — rows saved, no OS alarm');
      }

      if (_recurrence?.type == RecurrenceType.yearly && _triggerDateTime != null) {
        final cur = _recurrence!;
        final iv = cur.interval < 1 ? 1 : cur.interval;
        _recurrence = Recurrence(type: RecurrenceType.yearly, interval: iv, days: [_triggerDateTime!.month, _triggerDateTime!.day]);
        DebugConfig.notif('ReminderSection._saveReminder: yearly keep interval=$iv');
      }
      final rrule = recurrenceToRRULE(_recurrence);
      const title = 'Υπενθύμιση';
      final body = widget.itemTitle;
      DebugConfig.notif('ReminderSection._saveReminder: rrule=$rrule, title=$title, body=$body');

      if (_reminderId != null) {
        DebugConfig.notif('ReminderSection._saveReminder: UPDATING (reminderId=$_reminderId) → rrule=${rrule ?? 'null'}');

        if (rrule != null) {
          // ── Recurring update: διαγραφή παλιού thread + νέο root ──
          DebugConfig.notif('ReminderSection._saveReminder: recurring update, deleting old thread id=$_reminderId');
          await ReminderScheduler.instance.deleteReminderThread(_reminderId!);
          final root = await ref.read(reminderNotifierProvider(widget.itemId).notifier).create(
            triggerAt: _triggerDateTime!,
            rrule: rrule,
            title: title,
            body: body,
          );
          if (root == null) {
            DebugConfig.error('ReminderSection._saveReminder recurring create failed');
            return;
          }
          _reminderId = root.id;
          DebugConfig.notif('ReminderSection._saveReminder: created new root id=${root.id}, trigger=${root.triggerAt}');
          // Μην προγραμματίζεις το root — τα παιδιά από refreshRecurringReminders το αντικαθιστούν
          await ReminderScheduler.instance.refreshRecurringReminders();
          DebugConfig.notif('ReminderSection._saveReminder: recurring update DONE');

        } else {
          // ── One-shot update: διαγραφή παλιού thread (root + τυχόν παιδιά)
          //    και δημιουργία νέου one-shot reminder ──
          DebugConfig.notif('ReminderSection._saveReminder: one-shot update, deleting old thread id=$_reminderId');
          await ReminderScheduler.instance.deleteReminderThread(_reminderId!);

          final newReminder = await ref.read(reminderNotifierProvider(widget.itemId).notifier).create(
            triggerAt: _triggerDateTime!,
            rrule: null,
            title: title,
            body: body,
          );
          if (newReminder == null) {
            DebugConfig.error('ReminderSection._saveReminder one-shot create failed');
            return;
          }
          _reminderId = newReminder.id;
          DebugConfig.notif('ReminderSection._saveReminder: created one-shot id=${newReminder.id}, trigger=${newReminder.triggerAt}');
          await ReminderScheduler.instance.scheduleReminder(newReminder);
          DebugConfig.notif('ReminderSection._saveReminder: one-shot update DONE');
        }

      } else {
        // ── Νέο reminder (δεν υπήρχε προηγουμένως) ──
        DebugConfig.notif('ReminderSection._saveReminder: CREATING NEW reminder for itemId=${widget.itemId}');
        final newReminder = await ref.read(reminderNotifierProvider(widget.itemId).notifier).create(
          triggerAt: _triggerDateTime!,
          rrule: rrule,
          title: title,
          body: body,
        );
        if (newReminder == null) {
          DebugConfig.error('ReminderSection._saveReminder create failed');
          return;
        }
        _reminderId = newReminder.id;
        DebugConfig.notif('ReminderSection._saveReminder: created reminder id=${newReminder.id}, trigger=${newReminder.triggerAt}, status=${newReminder.status.name}');
        if (rrule != null) {
          await ReminderScheduler.instance.refreshRecurringReminders();
        } else {
          await ReminderScheduler.instance.scheduleReminder(newReminder);
        }
      }
      if (mounted && NotificationService.isSupportedPlatform) {
        try {
          final settings = await ref.read(dbProvider).settings.get();
          if (!settings.notificationsEnabled && mounted) {
            _snack(AppErrors.reminderSavedNoAlarm);
          }
        } catch (e) {
          DebugConfig.error('ReminderSection settings-check', e);
        }
      }
      DebugConfig.notif('ReminderSection._saveReminder: DONE');
    } catch (e) {
      DebugConfig.error('ReminderSection._saveReminder', e);
    }
  }

  /// Ακύρωση picker χωρίς χρήσιμη ώρα και χωρίς τίποτα στη βάση → το switch
  /// επιστρέφει σε OFF (αλλιώς δείχνει ενεργή υπενθύμιση που δεν αποθηκεύτηκε).
  void _revertSwitchIfNoTrigger() {
    if (!mounted) return;
    if (_reminderId == null && !_hasUsableTrigger) {
      DebugConfig.notif(
          'ReminderSection: picker cancelled, no usable trigger → switch OFF');
      setState(() => _enabled = false);
    }
  }

  Future<void> _pickDateTime() async {
    DebugConfig.notif('ReminderSection._pickDateTime: called');
    final now = DateTime.now();
    final initial = _triggerDateTime ?? widget.defaultStartTime ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      locale: const Locale('el', 'GR'),
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + AppDateUtils.pickerLastYears),
      helpText: 'Ημερομηνία υπενθύμισης',
    );
    if (!mounted) return;
    if (date == null) {
      DebugConfig.notif('ReminderSection._pickDateTime: date picker cancelled');
      _revertSwitchIfNoTrigger();
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Ώρα υπενθύμισης',
    );
    if (!mounted) return;
    if (time == null) {
      DebugConfig.notif('ReminderSection._pickDateTime: time picker cancelled');
      _revertSwitchIfNoTrigger();
      return;
    }
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    DebugConfig.notif('ReminderSection._pickDateTime: selected dt=$dt');
    if (_recurrence == null && dt.isBefore(DateTime.now())) {
      DebugConfig.notif('ReminderSection._pickDateTime: past one-shot, blocked');
      _snack(AppErrors.reminderInPast);
      _revertSwitchIfNoTrigger();
      return;
    }
    setState(() => _triggerDateTime = dt);
    await _saveReminder();
  }

  Future<void> _editRecurrence() async {
    final initialTrigger = _triggerDateTime ?? widget.defaultStartTime ?? DateTime.now();
    final result = await showRecurrencePicker(
      context: context,
      initialRecurrence: _recurrence,
      initialTrigger: initialTrigger,
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => _recurrence = result);
      await _saveReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(Spacing.sm),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_outlined, size: 18, color: context.cText2),
            const SizedBox(width: Spacing.sm),
            Text('Υπενθύμιση', style: context.bodyMd),
            const Spacer(),
            Switch(
              value: _enabled,
              onChanged: (val) async {
                DebugConfig.notif('ReminderSection: Switch changed to $val');
                setState(() => _enabled = val);
                if (val && !_hasUsableTrigger) {
                  DebugConfig.notif('ReminderSection: Switch ON, no usable trigger → opening picker');
                  await _pickDateTime();
                } else {
                  await _saveReminder();
                }
              },
              activeThumbColor: context.cPrimary,
            ),
          ],
        ),
        if (!NotificationService.isSupportedPlatform) ...[
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: context.cText2),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  AppErrors.notificationsUnsupportedWindows,
                  style: context.bodySm.withColor(context.cText2),
                ),
              ),
            ],
          ),
        ],
        if (_enabled) ...[
          const SizedBox(height: Spacing.xs),
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Row(
                children: [
                  Icon(Icons.alarm_rounded, size: 16, color: context.cText2),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    _triggerDateTime != null
                        ? AppDateUtils.formatDateTime(_triggerDateTime!)
                        : 'Επιλογή ώρας',
                    style: context.bodyMd.copyWith(
                      color: _triggerDateTime != null ? context.cText : context.cText2,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.edit_rounded, size: 14, color: context.cText2),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: _editRecurrence,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Row(
                children: [
                  Icon(Icons.repeat_rounded, size: 16, color: context.cText2),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      _recurrence != null ? _recurrence!.describe() : 'Χωρίς επανάληψη',
                      style: context.bodyMd.copyWith(color: context.cText2),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.cText2),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
