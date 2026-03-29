// lib/shared/widgets/empty_state.dart
//
// Empty state widget για όταν μια λίστα είναι κενή.
// ✅ Responsive: μέγεθος icon/text ανάλογα με screen
// ✅ Dark mode: χρησιμοποιεί μόνο ColorsUI / context extensions
// ✅ DebugConfig: log όταν εμφανίζεται
//
// ΧΡΗΣΗ:
//   // Για συγκεκριμένο ItemType (αυτόματο icon + μήνυμα)
//   EmptyState.forType(ItemType.note, onAction: () => createNote())
//
//   // Custom
//   EmptyState(
//     icon: Icons.search_off_rounded,
//     title: 'Δεν βρέθηκαν αποτελέσματα',
//     subtitle: 'Δοκίμασε διαφορετικούς όρους αναζήτησης',
//   )
//
//   // Με action button
//   EmptyState(
//     icon: Icons.note_add_rounded,
//     title: 'Δεν υπάρχουν σημειώσεις',
//     actionLabel: 'Δημιούργησε την πρώτη',
//     onAction: () => createNote(),
//   )
//
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../models/item.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Αν true, εμφανίζεται πιο μικρό (για embedded χρήση μέσα σε panel)
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  // ── Factory για ItemType ──────────────────────────────────────

  factory EmptyState.forType(
      ItemType type, {
        VoidCallback? onAction,
        bool compact = false,
      }) {
    final data = _emptyStateData[type] ?? _emptyStateData[ItemType.note]!;
    return EmptyState(
      icon:        data.icon,
      title:       data.title,
      subtitle:    data.subtitle,
      actionLabel: data.actionLabel,
      onAction:    onAction,
      compact:     compact,
    );
  }

  // ── Factory για search ────────────────────────────────────────

  factory EmptyState.search({
    required String query,
    bool compact = false,
  }) {
    return EmptyState(
      icon:     Icons.search_off_rounded,
      title:    'Δεν βρέθηκαν αποτελέσματα',
      subtitle: query.isEmpty
          ? 'Ξεκίνα να πληκτρολογείς για αναζήτηση'
          : 'Δεν βρέθηκε τίποτα για "$query"',
      compact:  compact,
    );
  }

  // ── Factory για error ─────────────────────────────────────────

  factory EmptyState.error({
    String? message,
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon:        Icons.error_outline_rounded,
      title:       'Κάτι πήγε στραβά',
      subtitle:    message ?? 'Παρουσιάστηκε σφάλμα κατά τη φόρτωση.',
      actionLabel: onRetry != null ? 'Δοκίμασε ξανά' : null,
      onAction:    onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.print('EmptyState shown: "$title"');

    // Responsive sizes
    final iconSize = context.responsive<double>(
      mobile:  compact ? 48 : 72,
      tablet:  compact ? 56 : 88,
      desktop: compact ? 64 : 96,
    );
    final spacing = compact ? Spacing.sm : Spacing.lg;

    return Center(
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ───────────────────────────────────────────
            _AnimatedIcon(icon: icon, size: iconSize),

            SizedBox(height: spacing),

            // ── Title ──────────────────────────────────────────
            Text(
              title,
              style: (compact ? context.titleMd : context.h3)
                  .withColor(context.cText),
              textAlign: TextAlign.center,
            ),

            // ── Subtitle ───────────────────────────────────────
            if (subtitle != null) ...[
              SizedBox(height: compact ? Spacing.xs : Spacing.sm),
              Text(
                subtitle!,
                style: context.bodyMd.withColor(context.cText2),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Action button ──────────────────────────────────
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? Spacing.md : Spacing.xl),
              FilledButton.icon(
                onPressed: () {
                  DebugConfig.print('EmptyState action: "$actionLabel"');
                  onAction!();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: Spacing.sm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonBR,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ANIMATED ICON — fade-in + subtle scale
// ════════════════════════════════════════════════════════════════

class _AnimatedIcon extends StatefulWidget {
  final IconData icon;
  final double size;

  const _AnimatedIcon({required this.icon, required this.size});

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDuration.slow,
    )..forward();

    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width:  widget.size * 1.4,
          height: widget.size * 1.4,
          decoration: BoxDecoration(
            color: context.cPrimary.withValues(alpha:0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            size:  widget.size,
            color: context.cPrimary.withValues(alpha:0.5),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// EMPTY STATE DATA PER ITEM TYPE
// ════════════════════════════════════════════════════════════════

class _EmptyData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;

  const _EmptyData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });
}

const Map<ItemType, _EmptyData> _emptyStateData = {
  ItemType.note: _EmptyData(
    icon:        Icons.note_rounded,
    title:       'Δεν υπάρχουν σημειώσεις',
    subtitle:    'Δημιούργησε τη πρώτη σου σημείωση',
    actionLabel: 'Νέα σημείωση',
  ),
  ItemType.task: _EmptyData(
    icon:        Icons.check_circle_outline_rounded,
    title:       'Δεν υπάρχουν εργασίες',
    subtitle:    'Πρόσθεσε εργασίες για να οργανωθείς',
    actionLabel: 'Νέα εργασία',
  ),
  ItemType.event: _EmptyData(
    icon:        Icons.event_rounded,
    title:       'Δεν υπάρχουν συμβάντα',
    subtitle:    'Πρόσθεσε συμβάντα στο ημερολόγιό σου',
    actionLabel: 'Νέο συμβάν',
  ),
  ItemType.contact: _EmptyData(
    icon:        Icons.people_outline_rounded,
    title:       'Δεν υπάρχουν επαφές',
    subtitle:    'Πρόσθεσε τις επαφές σου εδώ',
    actionLabel: 'Νέα επαφή',
  ),
  ItemType.habit: _EmptyData(
    icon:        Icons.loop_rounded,
    title:       'Δεν υπάρχουν συνήθειες',
    subtitle:    'Ξεκίνα να χτίζεις καλές συνήθειες',
    actionLabel: 'Νέα συνήθεια',
  ),
  ItemType.project: _EmptyData(
    icon:        Icons.folder_open_rounded,
    title:       'Δεν υπάρχουν έργα',
    subtitle:    'Οργάνωσε τις εργασίες σου σε έργα',
    actionLabel: 'Νέο έργο',
  ),
  ItemType.goal: _EmptyData(
    icon:        Icons.flag_outlined,
    title:       'Δεν υπάρχουν στόχοι',
    subtitle:    'Ορίσε στόχους και παρακολούθησε την πρόοδό σου',
    actionLabel: 'Νέος στόχος',
  ),
  ItemType.finance: _EmptyData(
    icon:        Icons.account_balance_wallet_outlined,
    title:       'Δεν υπάρχουν εγγραφές',
    subtitle:    'Ξεκίνα να παρακολουθείς τα οικονομικά σου',
    actionLabel: 'Νέα εγγραφή',
  ),
  ItemType.bookmark: _EmptyData(
    icon:        Icons.bookmark_border_rounded,
    title:       'Δεν υπάρχουν σελιδοδείκτες',
    subtitle:    'Αποθήκευσε links που θες να θυμάσαι',
    actionLabel: 'Νέος σελιδοδείκτης',
  ),
  ItemType.journal: _EmptyData(
    icon:        Icons.auto_stories_rounded,
    title:       'Δεν υπάρχουν καταχωρήσεις',
    subtitle:    'Ξεκίνα να γράφεις το ημερολόγιό σου',
    actionLabel: 'Νέα καταχώρηση',
  ),
  ItemType.checklist: _EmptyData(
    icon:        Icons.checklist_rounded,
    title:       'Δεν υπάρχουν λίστες',
    subtitle:    'Δημιούργησε λίστες για να θυμάσαι τα πάντα',
    actionLabel: 'Νέα λίστα',
  ),
  ItemType.appointment: _EmptyData(
    icon:        Icons.event_available_rounded,
    title:       'Δεν υπάρχουν ραντεβου',
    subtitle:    'Δημιούργησε τα ραντεβου σου για να εισαι πάντα έτοιμος',
    actionLabel: 'Νέο Ραντεβού',
  ),
  ItemType.knowledge: _EmptyData(
    icon:        Icons.lightbulb_outline_rounded,
    title:       'Δεν υπάρχουν σημειώσεις γνώσης',
    subtitle:    'Αποθήκευσε ό,τι μαθαίνεις εδώ',
    actionLabel: 'Νέα σημείωση γνώσης',
  ),
};