import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ListViewMode { pinned, favorites, all }
final listViewModeProvider = StateProvider<ListViewMode>((ref) => ListViewMode.all);

/// Καθολική ένδειξη ότι ένα drag βρίσκεται σε εξέλιξη.
/// Χρησιμοποιείται από PopScope για να μπλοκάρει το system back gesture.
final isDraggingProvider = StateProvider<bool>((ref) => false);