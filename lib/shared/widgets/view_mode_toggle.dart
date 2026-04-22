import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../providers/ui_provider.dart';

class ViewModeToggle extends ConsumerWidget {
  const ViewModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(listViewModeProvider);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ToggleButton(
            icon: Icons.push_pin_rounded,
            tooltip: 'Καρφιτσωμένα',
            isSelected: current == ListViewMode.pinned,
            activeColor: Colors.red,
            onTap: () => ref.read(listViewModeProvider.notifier).state = ListViewMode.pinned,
          ),
          const SizedBox(width: Spacing.md),
          _ToggleButton(
            icon: Icons.star_rounded,
            tooltip: 'Αγαπημένα',
            isSelected: current == ListViewMode.favorites,
            activeColor: Colors.amber,
            onTap: () => ref.read(listViewModeProvider.notifier).state = ListViewMode.favorites,
          ),
          const SizedBox(width: Spacing.md),
          _ToggleButton(
            icon: Icons.merge_type_rounded,
            tooltip: 'Όλα',
            isSelected: current == ListViewMode.all,
            activeColor: Colors.green,
            onTap: () => ref.read(listViewModeProvider.notifier).state = ListViewMode.all,
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? activeColor : context.cText2;
    final bgColor = isSelected
        ? activeColor.withValues(alpha: 0.12)
        : ColorsUI.getSurface(context.brightness);
    final borderColor = isSelected ? activeColor : ColorsUI.getBorder(context.brightness);

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
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
    );
  }
}