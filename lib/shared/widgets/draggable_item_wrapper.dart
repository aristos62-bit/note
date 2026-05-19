// lib/shared/widgets/draggable_item_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

/// Ενιαίο Draggable wrapper για όλα τα item cards.
/// Χρησιμοποιεί LongPressDraggable ώστε το γρήγορο swipe
/// να πηγαίνει στο scroll και μόνο το παρατεταμένο πάτημα
/// να ενεργοποιεί το drag-to-reorder.
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

    return LongPressDraggable<int>(           // ✅ LongPress αντί για άμεσο drag
      data: itemId,
      delay: const Duration(milliseconds: 400), // ✅ 400ms → αρκετός χρόνος για scroll
      hapticFeedbackOnStart: true,              // ✅ haptic feedback όταν αρχίζει το drag
      onDragStarted: () {
        HapticFeedback.mediumImpact();          // ✅ επιπλέον haptic για confirmation
        ref.read(isDraggingProvider.notifier).state = true;
      },
      onDragEnd: (_) {
        ref.read(isDraggingProvider.notifier).state = false;
      },
      feedback: SizedBox(
        width: feedbackWidth,
        child: Material(
          color: Colors.transparent,
          elevation: 6,                         // ✅ σκιά κατά το drag για οπτικό feedback
          borderRadius: BorderRadius.circular(8),
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