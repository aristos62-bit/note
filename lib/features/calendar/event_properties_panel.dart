// lib/features/calendar/event_properties_panel.dart
//
// E41 — Panel ιδιοτήτων συμβάντος (εξαγωγή από `event_detail_screen.dart`,
// E06 ευκαιριακό split). Περιέχει: Ολοήμερο, Έναρξη, Λήξη (πολυήμερο),
// Χρώμα γραμμής. Η λογική των pickers μένει στον caller (parent screen),
// ώστε το panel να είναι dumb/testable.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../helpers/item_color_helper.dart';
import 'span_utils.dart';

class EventPropertiesPanel extends ConsumerWidget {
  final Item item;
  final ValueChanged<DateTime?> onPickStart;
  final ValueChanged<DateTime?> onPickEnd;
  final VoidCallback onPickSpanColor;
  final ValueChanged<bool> onToggleAllDay;

  const EventPropertiesPanel({
    super.key,
    required this.item,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPickSpanColor,
    required this.onToggleAllDay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));

    return propsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(Spacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (props) {
        String? prop(String key) =>
            props.where((p) => p.key == key).firstOrNull?.value;

        final allDay = prop('all_day') == 'true';
        final startStr = prop(PropertyKeys.startTime);
        final startTime = startStr != null ? DateTime.tryParse(startStr) : null;
        final range = spanRangeOf(props);
        final spanHex = spanColorOf(props);
        final spanPreview = spanHex != null
            ? spanBarColor(
                ItemColorHelper.parseHex(spanHex) ??
                    spanDefaultColor(context.brightness),
                context.brightness,
              )
            : spanDefaultColor(context.brightness);

        // 🎂 γενέθλια: χωρίς λήξη/χρώμα (αυτόματη ετήσια, display-only).
        final showSpan = !ItemColorHelper.isBirthdayEvent(item);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Spacing.sm),

              // All day toggle
              PropRow(
                icon: Icons.wb_sunny_rounded,
                label: 'Ολοήμερο',
                child: Switch(
                  value: allDay,
                  onChanged: onToggleAllDay,
                  activeThumbColor: context.cPrimary,
                ),
              ),

              // Start time
              PropRow(
                icon: Icons.schedule_rounded,
                label: 'Έναρξη',
                child: GestureDetector(
                  onTap: () => onPickStart(startTime),
                  child: Text(
                    startTime != null
                        ? (allDay ? startTime.short : startTime.dateTime)
                        : 'Επιλογή',
                    style: context.bodyMd.withColor(
                        startTime != null ? context.cText : context.cText2),
                  ),
                ),
              ),

              // End date (πολυήμερο) — μόνο όταν υπάρχει έναρξη
              if (showSpan && startTime != null)
                PropRow(
                  icon: Icons.event_repeat_rounded,
                  label: 'Λήξη',
                  child: GestureDetector(
                    onTap: () => onPickEnd(startTime),
                    child: Text(
                      range != null ? range.end.short : 'Μία ημέρα',
                      style: context.bodyMd.withColor(
                          range != null ? context.cText : context.cText2),
                    ),
                  ),
                ),

              // Χρώμα γραμμής (default = accent τύπου event)
              if (showSpan && startTime != null)
                PropRow(
                  icon: Icons.border_color_outlined,
                  label: 'Χρώμα',
                  child: GestureDetector(
                    onTap: onPickSpanColor,
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 4,
                          decoration: BoxDecoration(
                            color: spanPreview,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          spanHex == null ? 'Προεπιλογή' : 'Γραμμή',
                          style: context.bodyMd.withColor(context.cText2),
                        ),
                      ],
                    ),
                  ),
                ),

              if (showSpan && spanHex != null)
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 2),
                  child: Text(
                    'Το χρώμα προσαρμόζεται αυτόματα για ευκρίνεια.',
                    style: context.bodySm.withColor(context.cText2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROP ROW
// ════════════════════════════════════════════════════════════════

class PropRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const PropRow({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.cText2),
          const SizedBox(width: Spacing.sm),
          SizedBox(
            width: 80,
            child: Text(label, style: context.bodyMd.withColor(context.cText2)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
