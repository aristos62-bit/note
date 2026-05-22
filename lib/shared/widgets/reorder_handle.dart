import 'package:flutter/material.dart';
import '../../core/core.dart';

class ReorderHandle extends StatelessWidget {
  final bool visible;

  const ReorderHandle({super.key, this.visible = true});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: RotatedBox(
        quarterTurns: 1,
        child: Icon(
          Icons.drag_handle_rounded,
          size: 24,
          color: context.cText2.withValues(alpha: 1),
        ),
      ),
    );
  }
}