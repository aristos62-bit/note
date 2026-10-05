// lib/shared/widgets/search_clear_button.dart
//
// SPoT για το X καθαρισμού των search fields (Φ4a βήμα 4).
// Ενοποιεί 4 stale `controller.text.isNotEmpty` suffixIcons
// (trash, item_list_embedded, collection_entries, search) + 1 νέο
// (appointment _ContactSearchSheet) — όλα είχαν/έλειπαν το ίδιο κουμπί.
//
// Το κλειδί: ValueListenableBuilder στον controller — το X ενημερώνεται
// ζωντανά σε κάθε keystroke, χωρίς parent setState (το παλιό διάβαζε το
// text μέσα στο build, οπότε έμενε μπαγιάτικο μέχρι το debounce).
// No-leak by design: ο builder κάνει αυτόματα remove-listener.
//
// ΧΡΗΣΗ:
//   suffixIcon: SearchClearButton(
//     controller: _searchCtrl,
//     onCleared: () => _onSearchChanged(''),
//   ),
//
import 'package:flutter/material.dart';
import '../../core/core.dart';

class SearchClearButton extends StatelessWidget {
  /// Ο controller του search field (State-owned, stable instance).
  final TextEditingController controller;

  /// Τρέχει μετά το clear (π.χ. reset query/filter/focus).
  final VoidCallback? onCleared;

  /// Μέγεθος εικονιδίου (default 24 — το search_screen χρησιμοποιεί 20).
  final double iconSize;

  const SearchClearButton({
    super.key,
    required this.controller,
    this.onCleared,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        if (value.text.isEmpty) return const SizedBox.shrink();
        return IconButton(
          icon: Icon(Icons.close_rounded, color: context.cText2, size: iconSize),
          tooltip: 'Καθαρισμός αναζήτησης',
          onPressed: () {
            controller.clear();
            onCleared?.call();
          },
        );
      },
    );
  }
}
