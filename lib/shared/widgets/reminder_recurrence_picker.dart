// lib/shared/widgets/reminder_recurrence_picker.dart
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import 'safe_sheet.dart';

Future<Recurrence?> showRecurrencePicker({
  required BuildContext context,
  Recurrence? initialRecurrence,
  DateTime? initialTrigger,
}) {
  return showSafeSheet<Recurrence>(
    context,
    scrollControlled: true,
    child: RecurrencePickerModal(
      initialRecurrence: initialRecurrence,
      initialTrigger: initialTrigger,
    ),
  );
}

class RecurrencePickerModal extends StatefulWidget {
  final Recurrence? initialRecurrence;
  final DateTime? initialTrigger;
  const RecurrencePickerModal({super.key, this.initialRecurrence, this.initialTrigger});

  @override
  State<RecurrencePickerModal> createState() => RecurrencePickerModalState();
}

class RecurrencePickerModalState extends State<RecurrencePickerModal> {
  late RecurrenceType _type;
  late int _interval;
  late List<int> _weeklyDays;
  int? _monthlyDay;
  late String _customUnit;

  final _intervalController = TextEditingController();
  final _monthlyDayController = TextEditingController();

  void _applyDefaultsForType(RecurrenceType type) {
    if (widget.initialRecurrence != null) return;
    switch (type) {
      case RecurrenceType.weekly:
        if (widget.initialTrigger != null) {
          _weeklyDays = [widget.initialTrigger!.weekday];
        }
        _interval = 1;
      case RecurrenceType.monthly:
        if (widget.initialTrigger != null) {
          _monthlyDay = widget.initialTrigger!.day;
        }
        _interval = 1;
      case RecurrenceType.yearly:
        _interval = 1;
      default:
        _interval = 1;
    }
    _intervalController.text = _interval.toString();
    _monthlyDayController.text = _monthlyDay?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initialRecurrence;
    _type = init?.type ?? RecurrenceType.daily;
    if (init != null) {
      if (init.days != null) _weeklyDays = init.days!.toList();
      if (init.dayOfMonth != null) _monthlyDay = init.dayOfMonth;
      _interval = init.interval;
    } else {
      _weeklyDays = [];
      _monthlyDay = null;
      _applyDefaultsForType(_type);
    }
    _customUnit = 'days';
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
    return SafeSheet(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Επανάληψη υπενθύμισης', style: context.titleSm, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: Spacing.md),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: RecurrenceType.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final t = RecurrenceType.values[index];
                final isActive = _type == t;
                return GestureDetector(
                  onTap: () => setState(() {
                    _type = t;
                    if (t == RecurrenceType.weekly) {
                      _weeklyDays = _weeklyDays
                          .where((d) => d >= 1 && d <= 7)
                          .toList();
                      if (_weeklyDays.isEmpty &&
                          widget.initialTrigger != null) {
                        _weeklyDays = [widget.initialTrigger!.weekday];
                        DebugConfig.notif(
                            'RecurrencePicker: weekly reset to trigger weekday');
                      }
                    } else if (t == RecurrenceType.monthly) {
                      if (_monthlyDay == null ||
                          _monthlyDay! < 1 ||
                          _monthlyDay! > 31) {
                        _monthlyDay = widget.initialTrigger?.day;
                        _monthlyDayController.text =
                            _monthlyDay?.toString() ?? '';
                      }
                    }
                    _applyDefaultsForType(t);
                  }),
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.sm),
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
                        t == RecurrenceType.monthly ? 'Μηνιαία' :
                        t == RecurrenceType.yearly ? 'Κάθε Χρόνο' : 'Προσαρμοσμένο',
                        style: context.labelSm.withColor(isActive ? context.cPrimary : context.cText),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Spacing.md),
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
                  _type == RecurrenceType.yearly ? 'χρόνο' :
                  'μήνες',
                  style: context.bodyMd,
                ),
            ],
          ),
          if (_type == RecurrenceType.custom) ...[
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _customUnit,
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
                      final safeWeekly = _weeklyDays
                          .where((d) => d >= 1 && d <= 7)
                          .toList();
                      recurrence = Recurrence(
                        type: _type,
                        interval: _interval,
                        days: _type == RecurrenceType.weekly &&
                                safeWeekly.isNotEmpty
                            ? safeWeekly
                            : _type == RecurrenceType.monthly &&
                                    _monthlyDay != null
                                ? [_monthlyDay!]
                                : null,
                      );
                    }
                    Navigator.pop(context, recurrence);
                  },
                  child: const Text('Εφαρμογή'),
                ),
              ),
            ]),
            const SizedBox(height: Spacing.md),
          ],
        ),
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
    const names = AppDateUtils.weekdayNames;
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
