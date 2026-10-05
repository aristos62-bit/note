// lib/features/settings/reminder_diagnostics_screen.dart
//
// Διαγνωστική οθόνη υπενθυμίσεων: δείχνει την κατάσταση των
// επαναλαμβανόμενων υπενθυμίσεων (πόσα μελλοντικά "παιδιά" έχουν,
// πότε εξαντλείται το batch) και μια χρονολογική λίστα όλων των
// προγραμματισμένων ειδοποιήσεων, με cross-check αν είναι όντως
// καταχωρημένες στο OS — ώστε να εντοπίζεται άμεσα τυχόν "χάσμα"
// ανάμεσα σε βάση και OS, χωρίς καλώδιο/IDE/logcat.
//
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../helpers/super_note_helper.dart';
import '../../services/services.dart';

class ReminderDiagnosticsScreen extends StatefulWidget {
  const ReminderDiagnosticsScreen({super.key});

  @override
  State<ReminderDiagnosticsScreen> createState() =>
      _ReminderDiagnosticsScreenState();
}

class _RootStatus {
  final Reminder root;
  final String itemLabel;
  final int futureCount;
  final DateTime? nextTrigger;
  final DateTime? maxTrigger;

  _RootStatus({
    required this.root,
    required this.itemLabel,
    required this.futureCount,
    required this.nextTrigger,
    required this.maxTrigger,
  });
}

class _PendingRow {
  final Reminder reminder;
  final bool isRecurringChild;
  final bool inOs;

  _PendingRow({
    required this.reminder,
    required this.isRecurringChild,
    required this.inOs,
  });
}

class _ReminderDiagnosticsScreenState
    extends State<ReminderDiagnosticsScreen> {
  bool _loading = true;
  List<_RootStatus> _roots = [];
  List<_PendingRow> _pending = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final isar = SuperNoteHelper.instance.isar;

      // ── Roots με rrule ──
      final roots = await isar.reminders
          .filter()
          .rruleIsNotNull()
          .and()
          .not()
          .rruleEqualTo('')
          .parentReminderIdIsNull()
          .findAll();

      final rootStatuses = <_RootStatus>[];
      for (final root in roots) {
        final item = await SuperNoteHelper.instance.items.getById(root.itemId);
        final future = await isar.reminders
            .filter()
            .parentReminderIdEqualTo(root.id)
            .triggerAtGreaterThan(now, include: true)
            .sortByTriggerAt()
            .findAll();
        rootStatuses.add(_RootStatus(
          root: root,
          itemLabel: item?.title ?? root.body ?? root.title ?? 'Άγνωστο',
          futureCount: future.length,
          nextTrigger: future.isNotEmpty ? future.first.triggerAt : null,
          maxTrigger: future.isNotEmpty ? future.last.triggerAt : null,
        ));
      }
      rootStatuses.sort((a, b) {
        if (a.nextTrigger == null) return -1;
        if (b.nextTrigger == null) return 1;
        return a.nextTrigger!.compareTo(b.nextTrigger!);
      });

      // ── Όλα τα pending· κρατάμε ΜΟΝΟ τα πραγματικά scheduled
      //    στο OS (children + εφάπαξ) — οι roots ΔΕΝ προγραμματίζονται
      //    ποτέ οι ίδιοι, οπότε τους αποκλείουμε για να μη βγαίνουν
      //    ψευδώς ως "λείπουν από το OS" ──
      final allPending = await isar.reminders
          .filter()
          .statusEqualTo(ReminderStatus.pending)
          .triggerAtGreaterThan(now, include: true)
          .sortByTriggerAt()
          .findAll();
      final filtered =
      allPending.where((r) => r.rrule == null || r.rrule!.isEmpty).toList();

      // ── OS-level πραγματικά προγραμματισμένα ──
      final osPending =
      await NotificationService.instance.getPendingNotifications();
      final osIds = osPending.map((p) => p.id).toSet();

      final pendingRows = filtered.map((r) {
        return _PendingRow(
          reminder: r,
          isRecurringChild: r.parentReminderId != null,
          inOs: osIds.contains(r.id),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _roots = rootStatuses;
        _pending = pendingRows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Διάγνωση Υπενθυμίσεων'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Ανανέωση',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            Text('Επαναλαμβανόμενες υπενθυμίσεις', style: context.titleMd),
            const SizedBox(height: Spacing.sm),
            if (_roots.isEmpty)
              Text('Καμία επαναλαμβανόμενη υπενθύμιση.',
                  style: context.bodySm.withColor(context.cText2)),
            ..._roots.map(_buildRootCard),
            const SizedBox(height: Spacing.lg),
            Text('Επόμενες προγραμματισμένες ειδοποιήσεις',
                style: context.titleMd),
            const SizedBox(height: Spacing.sm),
            if (_pending.isEmpty)
              Text('Καμία προγραμματισμένη ειδοποίηση.',
                  style: context.bodySm.withColor(context.cText2)),
            ..._buildGroupedPendingSections(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedPendingSections() {
    final groups = <DateTime, List<_PendingRow>>{};
    for (final row in _pending) {
      final t = row.reminder.triggerAt;
      final dayKey = DateTime(t.year, t.month, t.day);
      groups.putIfAbsent(dayKey, () => []).add(row);
    }
    final sortedDays = groups.keys.toList()..sort();

    final widgets = <Widget>[];
    for (final day in sortedDays) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xs),
        child: Text(
          _dayLabel(day),
          style: context.titleSm.withColor(context.cPrimary),
        ),
      ));
      widgets.addAll(groups[day]!.map(_buildPendingRow));
    }
    return widgets;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Σήμερα';
    if (diff == 1) return 'Αύριο';
    const weekdays = AppDateUtils.weekdayFullNames;
    final wd = weekdays[day.weekday - 1];
    String two(int n) => n.toString().padLeft(2, '0');
    return '$wd ${two(day.day)}/${two(day.month)}';
  }

  Widget _buildRootCard(_RootStatus s) {
    final starved = s.futureCount == 0;
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            Icon(
              starved ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: starved ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.itemLabel, style: context.bodyMd),
                  Text(
                    starved
                        ? 'Κανένα μελλοντικό — ΣΤΑΜΑΤΗΣΕ'
                        : 'Επόμενη: ${_fmt(s.nextTrigger!)}  •  ${s.futureCount} στη σειρά  •  μέχρι ${_fmt(s.maxTrigger!)}',
                    style: context.bodySm.withColor(context.cText2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRow(_PendingRow row) {
    final r = row.reminder;
    final t = r.triggerAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(t.hour)}:${two(t.minute)}';
    return ListTile(
      dense: true,
      leading: Icon(
        row.inOs ? Icons.notifications_active_rounded : Icons.error_outline_rounded,
        color: row.inOs ? Colors.green : Colors.red,
        size: 20,
      ),
      title: Text(r.body ?? r.title ?? 'Υπενθύμιση', style: context.bodyMd),
      subtitle: Text(
        '$time'
            '${row.isRecurringChild ? '  •  επαναλαμβανόμενο' : '  •  εφάπαξ'}'
            '${row.inOs ? '' : '  •  ⚠️ ΛΕΙΠΕΙ ΑΠΟ ΤΟ OS!'}',
        style: context.bodySm.withColor(row.inOs ? context.cText2 : Colors.red),
      ),
    );
  }
}