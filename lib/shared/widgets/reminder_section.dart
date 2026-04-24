// lib/shared/widgets/reminder_section.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../helpers/super_note_helper.dart';
import '../../models/models.dart';
import '../../services/reminder_scheduler.dart';

// ---------------------------------------------------------------------
// Helper: Convert Recurrence ↔ RRULE
// ---------------------------------------------------------------------

String? recurrenceToRRULE(Recurrence? recurrence) {
  if (recurrence == null) return null;
  switch (recurrence.type) {
    case RecurrenceType.daily:
      return 'FREQ=DAILY;INTERVAL=${recurrence.interval}';
    case RecurrenceType.weekly:
      if (recurrence.days != null && recurrence.days!.isNotEmpty) {
        const dayMap = {1: 'MO', 2: 'TU', 3: 'WE', 4: 'TH', 5: 'FR', 6: 'SA', 7: 'SU'};
        final byday = recurrence.days!.map((d) => dayMap[d]).join(',');
        return 'FREQ=WEEKLY;INTERVAL=${recurrence.interval};BYDAY=$byday';
      } else {
        return 'FREQ=WEEKLY;INTERVAL=${recurrence.interval}';
      }
    case RecurrenceType.monthly:
      if (recurrence.dayOfMonth != null) {
        return 'FREQ=MONTHLY;INTERVAL=${recurrence.interval};BYMONTHDAY=${recurrence.dayOfMonth}';
      } else {
        return 'FREQ=MONTHLY;INTERVAL=${recurrence.interval}';
      }
    case RecurrenceType.custom:
    // Custom will not be stored as custom; it's mapped to daily/weekly/monthly.
    // However, keep for safety.
      return 'FREQ=DAILY;INTERVAL=${recurrence.interval}';
  }
}

Recurrence? rruleToRecurrence(String? rrule) {
  if (rrule == null || rrule.isEmpty) return null;
  final parts = rrule.split(';');
  String? freq;
  int interval = 1;
  List<int>? days;
  int? dayOfMonth;

  for (final p in parts) {
    if (p.startsWith('FREQ=')) freq = p.substring(5);
    if (p.startsWith('INTERVAL=')) interval = int.tryParse(p.substring(9)) ?? 1;
    if (p.startsWith('BYDAY=')) {
      final byday = p.substring(6);
      const dayMapRev = {'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7};
      days = byday.split(',').map((d) => dayMapRev[d]).whereType<int>().toList();
    }
    if (p.startsWith('BYMONTHDAY=')) {
      dayOfMonth = int.tryParse(p.substring(11));
    }
  }

  RecurrenceType type;
  switch (freq) {
    case 'DAILY': type = RecurrenceType.daily; break;
    case 'WEEKLY': type = RecurrenceType.weekly; break;
    case 'MONTHLY': type = RecurrenceType.monthly; break;
    default: type = RecurrenceType.daily;
  }
  return Recurrence(
    type: type,
    interval: interval,
    days: days,
    dayOfMonth: dayOfMonth,
  );
}

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    DebugConfig.notif('ReminderSection._loadData: itemId=${widget.itemId}');
    setState(() => _isLoading = true);
    final reminders = await SuperNoteHelper.instance.reminders.getForItem(widget.itemId);
    DebugConfig.notif('ReminderSection._loadData: found ${reminders.length} reminders for item ${widget.itemId}');
    for (final r in reminders) {
      DebugConfig.notif('  reminder id=${r.id} status=${r.status.name} trigger=${r.triggerAt} rrule=${r.rrule}');
    }
    if (reminders.isNotEmpty) {
      final r = reminders.first;
      _reminderId = r.id;
      _triggerDateTime = r.triggerAt;
      _enabled = true;
      _recurrence = rruleToRecurrence(r.rrule);
      DebugConfig.notif('ReminderSection._loadData: loaded existing reminder id=${r.id}, enabled=true');
    } else {
      _reminderId = null;
      _triggerDateTime = null;
      _enabled = false;
      _recurrence = null;
      DebugConfig.notif('ReminderSection._loadData: no reminders found, enabled=false');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveReminder() async {
    DebugConfig.notif('ReminderSection._saveReminder: enabled=$_enabled, trigger=$_triggerDateTime, reminderId=$_reminderId, itemId=${widget.itemId}');

    if (!_enabled || _triggerDateTime == null) {
      DebugConfig.notif('ReminderSection._saveReminder: disabled or no trigger → deleting if exists');
      if (_reminderId != null) {
        DebugConfig.notif('ReminderSection._saveReminder: deleting ALL reminders for itemId=${widget.itemId}');
        await ReminderScheduler.instance.deleteAllRemindersForItem(widget.itemId);
        _reminderId = null;
        DebugConfig.notif('ReminderSection._saveReminder: all reminders deleted');
      }
      return;
    }

    final rrule = recurrenceToRRULE(_recurrence);
    const title = 'Υπενθύμιση';
    final body = widget.itemTitle;
    DebugConfig.notif('ReminderSection._saveReminder: rrule=$rrule, title=$title, body=$body');

    if (_reminderId != null) {
      DebugConfig.notif('ReminderSection._saveReminder: updating existing reminder id=$_reminderId');
      final existing = await SuperNoteHelper.instance.reminders.getForItem(widget.itemId);
      DebugConfig.notif('ReminderSection._saveReminder: found ${existing.length} existing reminders');
      if (existing.isNotEmpty) {
        final r = existing.first;
        DebugConfig.notif('ReminderSection._saveReminder: before update: id=${r.id} trigger=${r.triggerAt} status=${r.status.name}');
        r.triggerAt = _triggerDateTime!;
        r.rrule = rrule;
        r.title = title;
        r.body = body;
        r.updatedAt = DateTime.now();
        await SuperNoteHelper.instance.isar.writeTxn(() async {
          await SuperNoteHelper.instance.isar.reminders.put(r);
        });
        DebugConfig.notif('ReminderSection._saveReminder: updated reminder id=${r.id}, new trigger=${r.triggerAt}');
        await ReminderScheduler.instance.scheduleReminder(r);
      } else {
        DebugConfig.notif('ReminderSection._saveReminder: WARNING - _reminderId=$_reminderId but no reminders found in DB!');
      }
    } else {
      DebugConfig.notif('ReminderSection._saveReminder: creating NEW reminder for itemId=${widget.itemId}');
      final newReminder = await SuperNoteHelper.instance.reminders.create(
        itemId: widget.itemId,
        triggerAt: _triggerDateTime!,
        rrule: rrule,
        title: title,
        body: body,
      );
      _reminderId = newReminder.id;
      DebugConfig.notif('ReminderSection._saveReminder: created reminder id=${newReminder.id}, trigger=${newReminder.triggerAt}, status=${newReminder.status.name}');
      await ReminderScheduler.instance.scheduleReminder(newReminder);
    }
    DebugConfig.notif('ReminderSection._saveReminder: DONE');
  }

  Future<void> _pickDateTime() async {
    DebugConfig.notif('ReminderSection._pickDateTime: called');
    final now = DateTime.now();
    final initial = _triggerDateTime ?? widget.defaultStartTime ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: 'Ημερομηνία υπενθύμισης',
      locale: const Locale('el'),
    );
    if (!mounted) return;
    if (date == null) {
      DebugConfig.notif('ReminderSection._pickDateTime: date picker cancelled');
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
      return;
    }
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    DebugConfig.notif('ReminderSection._pickDateTime: selected dt=$dt');
    setState(() => _triggerDateTime = dt);
    await _saveReminder();
  }

  Future<void> _editRecurrence() async {
    final result = await showRecurrencePicker(
      context: context,
      initialRecurrence: _recurrence,
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
                if (val && _triggerDateTime == null) {
                  DebugConfig.notif('ReminderSection: Switch ON, no trigger yet → opening picker');
                  await _pickDateTime();
                } else {
                  await _saveReminder();
                }
              },
              activeThumbColor: context.cPrimary,
            ),
          ],
        ),
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

// ---------------------------------------------------------------------
// Recurrence Picker Modal (with custom unit support)
// ---------------------------------------------------------------------

Future<Recurrence?> showRecurrencePicker({
  required BuildContext context,
  Recurrence? initialRecurrence,
}) {
  return showModalBottomSheet<Recurrence>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColorsUI.getSurface(Theme.of(context).brightness),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppRadius.bottomSheet),
        topRight: Radius.circular(AppRadius.bottomSheet),
      ),
    ),
    builder: (ctx) => _RecurrencePickerModal(initialRecurrence: initialRecurrence),
  );
}

class _RecurrencePickerModal extends StatefulWidget {
  final Recurrence? initialRecurrence;
  const _RecurrencePickerModal({this.initialRecurrence});

  @override
  State<_RecurrencePickerModal> createState() => _RecurrencePickerModalState();
}

class _RecurrencePickerModalState extends State<_RecurrencePickerModal> {
  late RecurrenceType _type;
  late int _interval;
  late List<int> _weeklyDays;
  late int? _monthlyDay;
  late String _customUnit; // 'days', 'weeks', 'months'

  final _intervalController = TextEditingController();
  final _monthlyDayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.initialRecurrence ?? const Recurrence();
    _type = init.type;
    _interval = init.interval;
    _weeklyDays = init.days?.toList() ?? [];
    _monthlyDay = init.dayOfMonth;
    _customUnit = 'days'; // default
    _intervalController.text = _interval.toString();
    _monthlyDayController.text = _monthlyDay?.toString() ?? '';
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _monthlyDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.md,
        left: Spacing.lg,
        right: Spacing.lg,
        top: Spacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Επανάληψη υπενθύμισης', style: context.titleMd),
          const SizedBox(height: Spacing.md),
          // Type selector
          Row(
            children: RecurrenceType.values.map((t) {
              final isActive = _type == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: isActive ? context.cPrimary.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: isActive ? context.cPrimary : ColorsUI.getBorder(context.brightness),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t == RecurrenceType.daily ? 'Καθημερινά' :
                        t == RecurrenceType.weekly ? 'Εβδομαδιαία' :
                        t == RecurrenceType.monthly ? 'Μηνιαία' : 'Προσαρμοσμένο',
                        style: context.labelSm.withColor(isActive ? context.cPrimary : context.cText),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.md),
          // Interval (common for all types)
          Row(
            children: [
              Text('Κάθε', style: context.bodyMd),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: TextFormField(
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.inputBR,
                      borderSide: BorderSide(color: ColorsUI.getBorder(context.brightness)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
                  ),
                  onChanged: (v) {
                    final i = int.tryParse(v);
                    if (i != null && i > 0) setState(() => _interval = i);
                  },
                ),
              ),
              const SizedBox(width: Spacing.sm),
              if (_type != RecurrenceType.custom)
                Text(
                  _type == RecurrenceType.daily ? 'ημέρες' :
                  _type == RecurrenceType.weekly ? 'εβδομάδες' :
                  'μήνες',
                  style: context.bodyMd,
                ),
            ],
          ),
          // Custom unit selector (only when custom type)
          if (_type == RecurrenceType.custom) ...[
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _customUnit, // διορθωμένο: χρήση initialValue
                    items: const [
                      DropdownMenuItem(value: 'days', child: Text('ημέρες')),
                      DropdownMenuItem(value: 'weeks', child: Text('εβδομάδες')),
                      DropdownMenuItem(value: 'months', child: Text('μήνες')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _customUnit = value);
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.inputBR,
                        borderSide: BorderSide(color: ColorsUI.getBorder(context.brightness)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Spacing.md),
          // Weekly days (if weekly)
          if (_type == RecurrenceType.weekly) ...[
            Text('Ημέρες της εβδομάδας', style: context.labelMd),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.xs,
              children: [
                for (int i = 1; i <= 7; i++)
                  _WeekdayChip(
                    day: i,
                    selected: _weeklyDays.contains(i),
                    onToggle: (selected) {
                      setState(() {
                        if (selected) {
                          _weeklyDays.add(i);
                        } else {
                          _weeklyDays.remove(i);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
          // Monthly day (if monthly)
          if (_type == RecurrenceType.monthly) ...[
            Text('Ημέρα του μήνα', style: context.labelMd),
            const SizedBox(height: Spacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _monthlyDayController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.inputBR,
                        borderSide: BorderSide(color: ColorsUI.getBorder(context.brightness)),
                      ),
                    ),
                    onChanged: (v) {
                      final d = int.tryParse(v);
                      if (d != null && d >= 1 && d <= 31) setState(() => _monthlyDay = d);
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Άκυρο'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Recurrence recurrence;
                    if (_type == RecurrenceType.custom) {
                      // Map custom to daily/weekly/monthly based on selected unit
                      switch (_customUnit) {
                        case 'weeks':
                          recurrence = Recurrence(
                            type: RecurrenceType.weekly,
                            interval: _interval,
                          );
                          break;
                        case 'months':
                          recurrence = Recurrence(
                            type: RecurrenceType.monthly,
                            interval: _interval,
                          );
                          break;
                        default:
                          recurrence = Recurrence(
                            type: RecurrenceType.daily,
                            interval: _interval,
                          );
                      }
                    } else {
                      recurrence = Recurrence(
                        type: _type,
                        interval: _interval,
                        days: _type == RecurrenceType.weekly && _weeklyDays.isNotEmpty ? _weeklyDays : null,
                        dayOfMonth: _type == RecurrenceType.monthly ? _monthlyDay : null,
                      );
                    }
                    Navigator.pop(context, recurrence);
                  },
                  child: const Text('Εφαρμογή'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  final int day;
  final bool selected;
  final ValueChanged<bool> onToggle;

  const _WeekdayChip({
    required this.day,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const names = ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
    return GestureDetector(
      onTap: () => onToggle(!selected),
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
        decoration: BoxDecoration(
          color: selected ? context.cPrimary.withValues(alpha: 0.12) : ColorsUI.getSurface(context.brightness),
          borderRadius: BorderRadius.circular(AppRadius.badge),
          border: Border.all(color: selected ? context.cPrimary : ColorsUI.getBorder(context.brightness)),
        ),
        child: Text(names[day - 1], style: context.labelSm.withColor(selected ? context.cPrimary : context.cText2)),
      ),
    );
  }
}