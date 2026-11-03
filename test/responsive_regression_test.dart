// test/responsive_regression_test.dart
//
// S288 (device pass β): guards για 2 layout regressions που βρέθηκαν στη συσκευή.
// - Αρχική @320 dp: 3 στήλες → RenderFlex overflow 7,3–9,3 px (share 48 dp + badge).
// - Ημερολόγιο tablet: two-pane μόνο με ≥640 dp πλάτος περιεχομένου.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:super_note/features/calendar/calendar_screen.dart';
import 'package:super_note/features/home/home_screen.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/shared/widgets/widgets.dart';

Folder _folder() => Folder()
  ..id = 1
  ..name = 'Γενικά'
  ..workspaceId = 1
  ..icon = '📁';

/// Καρφιτσωμένα items → το grid της Αρχικής (όχι empty state).
List<Item> _pinnedNotes(int count) => List.generate(
      count,
      (i) => Item()
        ..id = i + 1
        ..title = 'Καρφιτσωμένη σημείωση ${i + 1}'
        ..type = ItemType.note
        ..workspaceId = 1
        ..folderId = 1
        ..pinned = true
        ..createdAt = DateTime(2026, 1, 1)
        ..updatedAt = DateTime(2026, 1, 1),
    );

Widget _homeAt(WidgetTester tester, {required double width}) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final pinned = _pinnedNotes(3);
  return ProviderScope(
    overrides: [
      foldersStreamProvider.overrideWith((ref) => Stream.value([_folder()])),
      // null → εμφανίζεται το section «Καρφιτσωμένα/Αγαπημένα» (grid).
      selectedFolderIdProvider.overrideWith((ref) => null),
      itemsByFolderStreamProvider(1)
          .overrideWith((ref) => Stream.value(const <Item>[])),
      pinnedAndFavoritesProvider.overrideWith(
        (ref) => Stream.value((pinned: pinned, favorites: const <Item>[])),
      ),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('S288 Αρχική — στήλες grid', () {
    test('320 dp → 2 στήλες · 360–599 dp → 3 · ≥600 dp → 4', () {
      expect(homeGridColumns(320), 2);
      expect(homeGridColumns(359), 2);
      expect(homeGridColumns(360), 3);
      expect(homeGridColumns(392), 3);
      expect(homeGridColumns(599), 3);
      expect(homeGridColumns(600), 4);
      expect(homeGridColumns(900), 4);
    });

    testWidgets('320 dp με καρφιτσωμένα: κανένα RenderFlex overflow',
        (tester) async {
      await tester.pumpWidget(_homeAt(tester, width: 320));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Οι κάρτες σχεδιάστηκαν (όχι empty state).
      expect(find.textContaining('Καρφιτσωμένη'), findsWidgets);

      final delegates = tester
          .widgetList<SliverGrid>(find.byType(SliverGrid))
          .map((grid) => grid.gridDelegate)
          .whereType<SliverGridDelegateWithFixedCrossAxisCount>()
          .toList();
      expect(delegates, isNotEmpty);
      expect(
        delegates.any((d) => d.crossAxisCount == 2),
        isTrue,
        reason: 'το grid των καρτών πρέπει να έχει 2 στήλες στα 320 dp',
      );
    });
  });

  group('S288 Ημερολόγιο — two-pane threshold', () {
    test('497 dp περιεχόμενο (tablet 618 dp με rail) → single column', () {
      expect(shouldUseTwoPane(497), isFalse);
      expect(shouldUseTwoPane(639), isFalse);
      expect(shouldUseTwoPane(640), isTrue);
      expect(shouldUseTwoPane(679), isTrue); // tablet 800 dp
      expect(calendarTwoPaneMinWidth, 640.0);
    });

    test('S288c: landscape + πληκτρολόγιο (37 dp ύψος) → single column', () {
      expect(shouldUseTwoPane(670, availableHeight: 37), isFalse);
      expect(shouldUseTwoPane(670, availableHeight: 199), isFalse);
      expect(shouldUseTwoPane(670, availableHeight: 200), isTrue);
      expect(shouldUseTwoPane(670, availableHeight: 270), isTrue); // landscape
    });
  });

  group('S288b Ημερολόγιο — κοντό viewport (mobile body)', () {
    // Το block (month grid + header + toggle) είναι ~420 dp σταθερό.
    Widget harness(
      WidgetTester tester, {
      required double height,
      required double blockHeight,
    }) {
      tester.view.physicalSize = Size(392, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 392,
            height: height,
            child: CalendarMobileBody(
              calendarBlock: SizedBox(
                key: const Key('block'),
                height: blockHeight,
                child: const SizedBox.expand(),
              ),
              dayList: const SizedBox.expand(key: Key('list')),
            ),
          ),
        ),
      );
    }

    testWidgets('415 dp viewport + 420 dp block: κανένα overflow, λίστα ≥45%',
        (tester) async {
      await tester.pumpWidget(harness(tester, height: 415, blockHeight: 420));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final listHeight = tester.getSize(find.byKey(const Key('list'))).height;
      expect(
        listHeight,
        greaterThanOrEqualTo(415 * (1 - calendarBlockMaxShare) - 1),
      );

      // Το block δεν χώρεσε → μπήκε σε shrinkWrap scroll list.
      final scrollList = tester.widget<ListView>(
        find.descendant(
          of: find.byType(CalendarMobileBody),
          matching: find.byType(ListView),
        ),
      );
      expect(scrollList.shrinkWrap, isTrue);
    });

    testWidgets('792 dp viewport: το block παίρνει το φυσικό του ύψος',
        (tester) async {
      await tester.pumpWidget(harness(tester, height: 792, blockHeight: 420));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const Key('block'))).height, 420);
      expect(tester.getSize(find.byKey(const Key('list'))).height, 372);
    });

    testWidgets('37 dp viewport (landscape + πληκτρολόγιο): κρύβεται το block',
        (tester) async {
      await tester.pumpWidget(harness(tester, height: 37, blockHeight: 420));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('block')), findsNothing);
      expect(tester.getSize(find.byKey(const Key('list'))).height, 37);
    });
  });

  group('S288d Ημερολόγιο — folder selector με ανοιχτό πληκτρολόγιο', () {
    // Το S288d διαβάζει `View.of(context).viewInsets` (το MediaQuery.viewInsets
    // το καταναλώνει το Scaffold του shell), γι' αυτό ρυθμίζουμε το ίδιο το
    // FlutterView του tester — όχι ένα MediaQuery wrapper. dpr = 1 ώστε τα
    // physical == logical pixels.
    void configureView(WidgetTester tester, {double keyboardInset = 0}) {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(412, 915);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    }

    Widget screen() {
      return ProviderScope(
        overrides: [
          itemsStreamProvider
              .overrideWith((ref) => Stream.value(const <Item>[])),
          foldersStreamProvider
              .overrideWith((ref) => Stream.value(const <Folder>[])),
        ],
        child: const MaterialApp(home: CalendarScreen()),
      );
    }

    testWidgets('χωρίς πληκτρολόγιο: ο selector είναι ορατός', (tester) async {
      configureView(tester);
      await tester.pumpWidget(screen());
      await tester.pump();

      expect(find.byType(DraggableFolderSelector), findsOneWidget);
    });

    testWidgets('με πληκτρολόγιο (233 dp): ο selector κρύβεται', (tester) async {
      configureView(tester, keyboardInset: 233);
      await tester.pumpWidget(screen());
      await tester.pump();

      expect(find.byType(DraggableFolderSelector), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('S288e Εργασίες — κελί grid (κάρτα + μπάρα προόδου)', () {
    // Η κάρτα εργασίας = ItemCard (compact, checkbox 48 + chip προτεραιότητας)
    // + μπάρα προόδου 6 dp. Στο tablet 618 dp η κάρτα είναι ~200 dp πλάτος και
    // το chip μένει σε μία γραμμή — 92 + 6 = 98 dp, δηλαδή το παλιό
    // `gridItemExtent: 94` έβγαζε overflow 4 px.
    Widget card({double cellHeight = 100}) {
      final item = Item()
        ..workspaceId = 1
        ..type = ItemType.task
        ..title = 'Επείγον'
        ..priority = ItemPriority.urgent;

      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: cellHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ItemCard(
                    item: item,
                    compact: true,
                    onCheckboxChanged: (_) {},
                    onShare: () {},
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 2),
                    child: SizedBox(height: 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('κελί 100 dp: χωρίς overflow (98 dp περιεχόμενο)',
        (tester) async {
      await tester.pumpWidget(card());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final cardHeight = tester.getSize(find.byType(ItemCard)).height;
      expect(cardHeight + 6, lessThanOrEqualTo(100));
    });

    testWidgets('παλιό κελί 94 dp: τεκμηριώνει το overflow που διορθώθηκε',
        (tester) async {
      await tester.pumpWidget(card(cellHeight: 94));
      await tester.pumpAndSettle();

      // Ο έλεγχος κρατά την αιτία: 92 + 6 = 98 > 94.
      expect(tester.takeException(), isNotNull);
      expect(tester.getSize(find.byType(ItemCard)).height, 92);
    });
  });
}
