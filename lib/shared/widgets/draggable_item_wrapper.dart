// lib/shared/widgets/draggable_item_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

/// Ενιαίο Draggable wrapper για όλα τα item cards.
/// Αναλαμβάνει το isDraggingProvider και το feedback sizing.
class DraggableItemWrapper extends ConsumerWidget {
  final int itemId;
  final Widget child;
  final double feedbackWidthFactor;

  const DraggableItemWrapper({
    super.key,
    required this.itemId,
    required this.child,
    this.feedbackWidthFactor = 0.8,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackWidth =
        MediaQuery.of(context).size.width * feedbackWidthFactor;

    return Draggable<int>(
      data: itemId,
      onDragStarted: () {
        ref.read(isDraggingProvider.notifier).state = true;
      },
      onDragEnd: (_) {
        ref.read(isDraggingProvider.notifier).state = false;
      },
      feedback: SizedBox(
        width: feedbackWidth,
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: child,
      ),
      child: child,
    );
  }
}