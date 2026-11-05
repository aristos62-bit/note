// test/filter_aware_empty_state_test.dart
//
// E48: filter-aware empty state — όταν η λίστα άδειασε **μόνο** λόγω του
// καθολικού φίλτρου (pin/αγαπημένα) ενώ υπάρχουν στοιχεία.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/providers/ui_provider.dart';
import 'package:super_note/shared/widgets/empty_state.dart';

const _title = 'Υπάρχουν φιλτραρισμένα στοιχεία';

ProviderContainer _container(ListViewMode mode) {
  final container = ProviderContainer(
    overrides: [listViewModeProvider.overrideWith((ref) => mode)],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _host(
  ProviderContainer container, {
  required bool hasItems,
  bool compact = false,
  bool showAction = true,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: FilterAwareEmptyState(
          hasItems: hasItems,
          compact: compact,
          showAction: showAction,
          fallback: const Text('fallback'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('mode all → δείχνει το fallback', (tester) async {
    final container = _container(ListViewMode.all);
    await tester.pumpWidget(_host(container, hasItems: true));
    await tester.pumpAndSettle();

    expect(find.text('fallback'), findsOneWidget);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('pinned + κανένα στοιχείο → fallback (όχι ψεύτικο μήνυμα)',
      (tester) async {
    final container = _container(ListViewMode.pinned);
    await tester.pumpWidget(_host(container, hasItems: false));
    await tester.pumpAndSettle();

    expect(find.text('fallback'), findsOneWidget);
    expect(find.text(_title), findsNothing);
  });

  testWidgets('pinned + στοιχεία → μήνυμα φίλτρου + κουμπί «Όλα»',
      (tester) async {
    final container = _container(ListViewMode.pinned);
    await tester.pumpWidget(_host(container, hasItems: true));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsOneWidget);
    expect(find.textContaining('Πάτησε «Όλα»'), findsOneWidget);
    expect(find.text('Όλα'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    expect(find.text('fallback'), findsNothing);
  });

  testWidgets('favorites + στοιχεία → εικονίδιο αστεριού', (tester) async {
    final container = _container(ListViewMode.favorites);
    await tester.pumpWidget(_host(container, hasItems: true));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_rounded), findsNothing);
  });

  testWidgets('showAction: false (compact panel) → μήνυμα χωρίς κουμπί',
      (tester) async {
    final container = _container(ListViewMode.pinned);
    await tester.pumpWidget(_host(
      container,
      hasItems: true,
      compact: true,
      showAction: false,
    ));
    await tester.pumpAndSettle();

    expect(find.text(_title), findsOneWidget);
    expect(find.text('Όλα'), findsNothing);
  });

  testWidgets('tap «Όλα» → φίλτρο all + fallback', (tester) async {
    final container = _container(ListViewMode.favorites);
    await tester.pumpWidget(_host(container, hasItems: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Όλα'));
    await tester.pumpAndSettle();

    expect(container.read(listViewModeProvider), ListViewMode.all);
    expect(find.text('fallback'), findsOneWidget);
    expect(find.text(_title), findsNothing);

    // Άφησε το snackbar να κλείσει πριν τελειώσει το test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
