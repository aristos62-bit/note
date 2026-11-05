import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ListViewMode { pinned, favorites, all }
final listViewModeProvider = StateProvider<ListViewMode>((ref) => ListViewMode.all);

/// SPoT ετικετών του καθολικού φίλτρου λιστών (toggle + filter-aware empty
/// states). Μία πηγή αλήθειας — όχι 4η αντιγραφή των ίδιων 3 strings.
extension ListViewModeLabel on ListViewMode {
  String get label => switch (this) {
        ListViewMode.pinned => 'Καρφιτσωμένα',
        ListViewMode.favorites => 'Αγαπημένα',
        ListViewMode.all => 'Όλα',
      };
}

/// Καθολική ένδειξη ότι ένα drag βρίσκεται σε εξέλιξη.
/// Χρησιμοποιείται από PopScope για να μπλοκάρει το system back gesture.
final isDraggingProvider = StateProvider<bool>((ref) => false);

/// Τρέχουσα ημερολογιακή μέρα (μόνο ημερομηνία). Ενημερώνεται από το
/// lifecycle (resume) όταν έχει αλλάξει η μέρα, ώστε τα habit stats και οι
/// ομαδοποιήσεις εργασιών (Ληξιπρόθεσμες/Σήμερα) να ξαναϋπολογίζονται.
///
/// SPoT: ζει στο ui_provider (καθαρό UI state) — το habit_provider το
/// εισάγει από εδώ, ώστε να μπορούν να το watchάρουν και άλλες οθόνες.
final dayTickProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});