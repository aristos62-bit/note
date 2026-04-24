import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider για την αποθήκευση του επιλεγμένου folder ID στην HomeScreen.
/// null = "Όλοι", int = folder id
/// ΣΗΜΑΝΤΙΚΟ: Πάντα ξεκινάει με null (Όλοι), ανεξάρτητα από τις ρυθμίσεις.
final homeSelectedFolderProvider = StateProvider<int?>((ref) => null);

enum ListViewMode { pinned, favorites, all }
final listViewModeProvider = StateProvider<ListViewMode>((ref) => ListViewMode.all);