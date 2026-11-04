// test/item_meta_row_test.dart
//
// S289 / E47 — ItemCard meta row σε fixed-extent grid cells.
// Ελέγχει:
// - την καθαρή συνάρτηση πυκνότητας (density)
// - dense mode: ΜΙΑ γραμμή, χωρίς overflow, με `+N` και semantics label
// - full mode: ακριβώς η σημερινή συμπεριφορά (Αρχείο chip + labels)
// - end-to-end: ReorderableItemList grid 618 dp (tablet) → scope + 92 dp
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/widgets.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('itemMetaDensityFor / itemMetaMaxTagsFor', () {
    test('χωρίς πλάτος → full (σημερινή συμπεριφορά)', () {
      expect(itemMetaDensityFor(null), ItemMetaDensity.full);
    });

    test('στενό πλάτος → minimal', () {
      expect(itemMetaDensityFor(80), ItemMetaDensity.minimal);
      expect(
        itemMetaDensityFor(kItemMetaCompactMinWidth - 0.1),
        ItemMetaDensity.minimal,
      );
    });

    test('όριο 280 → compact', () {
      expect(
        itemMetaDensityFor(kItemMetaCompactMinWidth),
        ItemMetaDensity.compact,
      );
      expect(itemMetaDensityFor(300), ItemMetaDensity.compact);
    });

    test('2 ετικέτες κάτω από 400, 3 από 400', () {
      expect(itemMetaMaxTagsFor(kItemMetaWideMinWidth - 1), 2);
      expect(itemMetaMaxTagsFor(kItemMetaWideMinWidth), 3);
    });
  });

  group('ItemMetaRow — dense mode', () {
    Item task({
      int id = 1,
      ItemPriority priority = ItemPriority.urgent,
    }) =>
        Item()
          ..id = id
          ..workspaceId = 1
          ..type = ItemType.task
          ..title = 'Εργασία'
          ..priority = priority;

    Widget app(Widget child, {double textScale = 1.0}) => MaterialApp(
          builder: (context, widget) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: widget!,
          ),
          home: Scaffold(body: Center(child: child)),
        );

    /// Κάρτα σε κελί [cellWidth] — ίδιο chrome με το πραγματικό grid.
    Widget cell({
      required Item item,
      required double cellWidth,
      List<String> tags = const [],
      DateTime? due,
      bool archived = false,
      double textScale = 1.0,
    }) =>
        app(
          ItemCardMetaScope(
            maxWidth: cellWidth,
            child: SizedBox(
              width: cellWidth,
              child: ItemCard(
                item: item,
                compact: true,
                dueDate: due,
                tagNames: tags,
                isArchived: archived,
                onTap: () {},
                onCheckboxChanged: (_) {},
                onShare: () {},
              ),
            ),
          ),
          textScale: textScale,
        );

    testWidgets('κελί 200 dp (meta 114) → κουκκίδα + ημερομηνία, χωρίς wrap',
        (tester) async {
      final due = DateTime(2026, 11, 20);
      await tester.pumpWidget(cell(
        item: task(),
        cellWidth: 200,
        tags: const ['α', 'β', 'γ'],
        due: due,
        archived: true,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Μία γραμμή: κουκκίδα προτεραιότητας + ημερομηνία + `+N`.
      expect(find.byType(PriorityBadge), findsOneWidget);
      expect(find.text(due.due), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      // Κρύβονται (πάνε στο semantics).
      expect(find.text('Αρχείο'), findsNothing);
      expect(find.text('α'), findsNothing);
      // Σταθερό ύψος κάρτας (98 = 92 + 6 μπάρα < 100 cell).
      expect(tester.getSize(find.byType(ItemCard)).height, 92);
    });

    testWidgets('meta 280 → 2 ετικέτες + `+N`', (tester) async {
      await tester.pumpWidget(cell(
        item: task(priority: ItemPriority.high),
        cellWidth: 366, // 366 - 86 = 280
        tags: const ['α', 'β', 'γ'],
        due: DateTime(2026, 11, 20),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('α'), findsOneWidget);
      expect(find.text('β'), findsOneWidget);
      expect(find.text('γ'), findsNothing);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('meta 400 → 3 ετικέτες χωρίς `+N`', (tester) async {
      await tester.pumpWidget(cell(
        item: task(priority: ItemPriority.high),
        cellWidth: 486, // 486 - 86 = 400
        tags: const ['α', 'β', 'γ', 'δ'],
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('α'), findsOneWidget);
      expect(find.text('β'), findsOneWidget);
      expect(find.text('γ'), findsOneWidget);
      expect(find.text('δ'), findsNothing);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('textScale 2.0 σε στενό κελί: κανένα overflow',
        (tester) async {
      await tester.pumpWidget(cell(
        item: task(),
        cellWidth: 200,
        tags: const ['πολύ-μεγάλη-ετικέτα'],
        due: DateTime(2026, 11, 20),
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('παθολογικά στενό κελί (60 dp) → μόνο κουκκίδα, χωρίς crash',
        (tester) async {
      await tester.pumpWidget(cell(
        item: task(),
        cellWidth: 60,
        tags: const ['α'],
        due: DateTime(2026, 11, 20),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PriorityBadge), findsOneWidget);
    });

    testWidgets('semantics: το κρυφό info μένει αναγνώσιμο (TalkBack)',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(cell(
        item: task(),
        cellWidth: 200,
        tags: const ['α', 'β', 'γ'],
        due: DateTime(2026, 11, 20),
        archived: true,
      ));
      await tester.pumpAndSettle();

      final label = tester.getSemantics(find.byType(ItemMetaRow)).label;
      expect(label, contains('Αρχείο'));
      expect(label, contains('Επείγον'));
      expect(label, contains('γ'));
      handle.dispose();
    });
  });

  group('ItemMetaRow — full mode (χωρίς scope)', () {
    testWidgets('Αρχείο + priority chips ορατά, όπως σήμερα', (tester) async {
      final item = Item()
        ..id = 1
        ..workspaceId = 1
        ..type = ItemType.task
        ..title = 'Εργασία'
        ..priority = ItemPriority.urgent;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: ItemCard(
              item: item,
              compact: true,
              isArchived: true,
              onCheckboxChanged: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Αρχείο'), findsOneWidget);
      expect(find.text('Επείγον'), findsOneWidget);
    });
  });

  group('ReorderableItemList grid (e2e, tablet 618 dp)', () {
    testWidgets('δύο στήλες: scope στην κάρτα, κελί 200+ dp, 0 overflow',
        (tester) async {
      tester.view.physicalSize = const Size(618, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = [
        Item()
          ..id = 1
          ..workspaceId = 1
          ..type = ItemType.task
          ..title = 'Πρώτη'
          ..priority = ItemPriority.urgent,
        Item()
          ..id = 2
          ..workspaceId = 1
          ..type = ItemType.task
          ..title = 'Δεύτερη'
          ..priority = ItemPriority.low,
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReorderableItemList(
            items: items,
            onReorder: (_, __) {},
            itemBuilder: (ctx, item, i) => ItemCard(
              item: item,
              compact: true,
              dueDate: DateTime(2026, 11, 20),
              tagNames: const ['α', 'β', 'γ'],
              onTap: () {},
              onCheckboxChanged: (_) {},
              onShare: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Το scope μπαίνει ανά κελί (μέσα στο keyed Stack).
      expect(find.byType(ItemCardMetaScope), findsNWidgets(2));
      // Στενό meta (273 - 86 = 187 < 280) → minimal, σταθερό ύψος 92.
      expect(find.text('+3'), findsNWidgets(2));
      expect(find.text('α'), findsNothing);
      for (final n in [0, 1]) {
        expect(tester.getSize(find.byType(ItemCard).at(n)).height, 92);
      }
    });
  });
}
