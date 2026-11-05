import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../providers/ui_provider.dart';

class ViewModeToggle extends ConsumerWidget {
  const ViewModeToggle({super.key});

  /// Το φίλτρο είναι ΚΑΘΟΛΙΚΟ (listViewModeProvider): μία αλλαγή ισχύει σε
  /// όλες τις λίστες. Ενημερώνουμε τον χρήστη για να μη διαβαστεί μια άδεια
  /// λίστα ως «χάθηκαν δεδομένα».
  void _select(BuildContext context, WidgetRef ref, ListViewMode mode) {
    ref.read(listViewModeProvider.notifier).state = mode;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar() // 3 διπλανά κουμπιά → ένα μήνυμα, όχι στοίβα
      ..showSnackBar(const SnackBar(
        content: Text(AppErrors.filterAppliedToAllLists),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(listViewModeProvider);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: CircleToggleButton.row(
        children: [
          CircleToggleButton(
            icon: Icons.push_pin_rounded,
            tooltip: 'Καρφιτσωμένα',
            isSelected: current == ListViewMode.pinned,
            activeColor: context.cError,
            onTap: () => _select(context, ref, ListViewMode.pinned),
          ),
          CircleToggleButton(
            icon: Icons.star_rounded,
            tooltip: 'Αγαπημένα',
            isSelected: current == ListViewMode.favorites,
            activeColor: context.cWarning,
            onTap: () => _select(context, ref, ListViewMode.favorites),
          ),
          CircleToggleButton(
            icon: Icons.merge_type_rounded,
            tooltip: 'Όλα',
            isSelected: current == ListViewMode.all,
            activeColor: context.cSuccess,
            onTap: () => _select(context, ref, ListViewMode.all),
          ),
        ],
      ),
    );
  }
}

// ── Κοινό κυκλικό toggle (SPoT Φ4a βήμα 9 — ενοποιεί 3 private _ToggleButton) ──

class CircleToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const CircleToggleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  /// Κοινή οριζόντια σειρά toggles (Φ4a βήμα 10 — μόνο layout, όχι semantics).
  /// Τα margins/paddings μένουν στους callers (διαφέρουν: central symmetric xs
  /// vs home/folder only-top sm).
  static Widget row({required List<Widget> children}) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(width: Spacing.xs),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? activeColor : context.cText2;
    final bgColor = isSelected
        ? activeColor.withValues(alpha: 0.12)
        : ColorsUI.getSurface(context.brightness);
    final borderColor = isSelected ? activeColor : ColorsUI.getBorder(context.brightness);

    return Semantics(
      button: true,
      selected: isSelected,
      label: tooltip,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: AppDuration.fast,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}