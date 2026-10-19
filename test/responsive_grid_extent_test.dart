// test/responsive_grid_extent_test.dart
//
// Έλεγχοι για το auto-height grid:
// - autoGridItemExtentFor(): παρεμβολή base→max βάσει text scale
// - ResponsiveItemList: ίσο ύψος κελιών ανά γραμμή + όχι overflow σε 1.4
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/shared/widgets/widgets.dart';

void main() {
  group('autoGridItemExtentFor', () {
    test('στο text scale 1.0 επιστρέφει base', () {
      expect(autoGridItemExtentFor(100, 140, 1.0), 100);
    });

    test('στο text scale 1.4 επιστρέφει max', () {
      expect(autoGridItemExtentFor(100, 140, 1.4), 140);
    });

    test('παρεμβολή στο 1.2', () {
      expect(autoGridItemExtentFor(100, 140, 1.2), closeTo(120, 0.001));
    });

    test('clamp έξω από το εύρος 1.0–1.4', () {
      expect(autoGridItemExtentFor(100, 140, 1.6), 140);
      expect(autoGridItemExtentFor(100, 140, 0.5), 100);
    });

    test('max<=base → base (χωρίς συρρίκνωση)', () {
      expect(autoGridItemExtentFor(120, 120, 1.4), 120);
      expect(autoGridItemExtentFor(120, 100, 1.4), 120);
    });
  });

  group('ResponsiveItemList', () {
    Future<void> pump(
      WidgetTester tester, {
      required double width,
      required double textScale,
      required List<String> items,
    }) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: ResponsiveItemList<String>(
              items: items,
              itemBuilder: (ctx, s) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(s),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    const longItems = [
      'Πολύ μεγάλος τίτλος στοιχείου για έλεγχο overflow στο κελί',
      'Δεύτερο στοιχείο',
      'Τρίτο στοιχείο',
      'Τέταρτο στοιχείο',
    ];

    testWidgets('mobile 1 στήλη χωρίς overflow σε 1.4', (tester) async {
      await pump(tester, width: 400, textScale: 1.4, items: longItems);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet 2 στήλες χωρίς overflow σε 1.4', (tester) async {
      await pump(tester, width: 700, textScale: 1.4, items: longItems);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop 3 στήλες χωρίς overflow σε 1.4', (tester) async {
      await pump(tester, width: 1000, textScale: 1.4, items: longItems);
      expect(tester.takeException(), isNull);
    });

    testWidgets('κελιά ίδιας γραμμής παίρνουν ίδιο ύψος', (tester) async {
      await pump(
        tester,
        width: 700,
        textScale: 1.0,
        items: const [
          'σύντομο',
          'Πολύ μεγάλο κείμενο που τυλίγεται σε αρκετές γραμμές και '
              'ανεβάζει το ύψος του κελιού σε σχέση με το διπλανό του',
        ],
      );

      final first = tester.getSize(find.byType(Card).at(0));
      final second = tester.getSize(find.byType(Card).at(1));
      expect(first.height, second.height);
      expect(first.width, second.width);
    });
  });

  // S262 (B-Π2): κοντό viewport → κρύψιμο greeting Αρχικής
  group('isShortScreen', () {
    Future<bool> shortAt(WidgetTester tester, double height) async {
      late bool result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(400, height)),
          child: Builder(builder: (context) {
            result = context.isShortScreen;
            return const SizedBox.shrink();
          }),
        ),
      );
      return result;
    }

    testWidgets('strict < shortScreenHeight (480)', (tester) async {
      expect(Breakpoints.shortScreenHeight, 480);
      expect(await shortAt(tester, 392), isTrue); // landscape κινητού
      expect(await shortAt(tester, 479.9), isTrue);
      expect(await shortAt(tester, 480), isFalse); // όριο → όχι short
      expect(await shortAt(tester, 872.7), isFalse); // portrait κινητού
    });
  });
}
