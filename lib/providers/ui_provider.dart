import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider για την αποθήκευση του επιλεγμένου folder ID στην HomeScreen.
/// null = "Όλοι", int = folder id
/// ΣΗΜΑΝΤΙΚΟ: Πάντα ξεκινάει με null (Όλοι), ανεξάρτητα από τις ρυθμίσεις.
final homeSelectedFolderProvider = StateProvider<int?>((ref) => null);

enum ListViewMode { pinned, favorites, all }
final listViewModeProvider = StateProvider<ListViewMode>((ref) => ListViewMode.all);

/// Καθολική ένδειξη ότι ένα drag βρίσκεται σε εξέλιξη.
/// Χρησιμοποιείται από PopScope για να μπλοκάρει το system back gesture.
final isDraggingProvider = StateProvider<bool>((ref) => false);