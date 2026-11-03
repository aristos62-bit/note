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
  });
}
