// test/home_short_viewport_test.dart
//
// S262 (B): σε κοντό viewport δεν βγαίνει RenderFlex overflow στην Αρχική.
// - B-Π1: shouldShowFolderStats() — τα stats κρύβονται όταν δεν χωράνε
// - B-Π2: HomeScreen — το greeting κρύβεται σε landscape κινητού (isShortScreen)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/features/home/home_folder_view.dart';
import 'package:super_note/features/home/home_screen.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/shared/widgets/widgets.dart';

Folder _folder({int id = 1, String name = 'Γενικά'}) {
  return Folder()
    ..id = id
    ..name = name
    ..workspaceId = 1
    ..icon = '📁';
}

/// 3 σημειώσεις → ακριβώς ένα '3' στην οθόνη (εύκολος έλεγχος).
List<Item> _notes(int count) => List.generate(
      count,
      (i) => Item()
        ..id = i + 1
        ..title = 'Σημείωση ${i + 1}'
        ..type = ItemType.note
        ..workspaceId = 1
        ..folderId = 1
        ..createdAt = DateTime(2026, 1, 1)
        ..updatedAt = DateTime(2026, 1, 1),
    );

List<Override> _overrides(int folderId) => [
      itemsByFolderStreamProvider(folderId)
          .overrideWith((ref) => Stream.value(_notes(3))),
    ];

Widget _folderViewAt(WidgetTester tester, {required double height}) {
  // Πλάτος κινητού (360dp) → 1 στήλη, ώστε οι κάρτες των 3 items να
  // χωράνε χωρίς test-only overflow στο header Row της κάρτας.
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return ProviderScope(
    overrides: _overrides(1),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: height,
            child: HomeFolderView(folder: _folder()),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('B-Π1 shouldShowFolderStats (strict >)', () {
    test('στα όρια: 100 → false (η λίστα θα έμενε 0dp)', () {
      expect(shouldShowFolderStats(double.infinity), isTrue);
      expect(shouldShowFolderStats(1000), isTrue);
      expect(shouldShowFolderStats(100.1), isTrue);
      expect(shouldShowFolderStats(100), isFalse);
      expect(shouldShowFolderStats(80), isFalse);
    });
  });

  group('B-Π1 HomeFolderView σε κοντό ύψος', () {
    testWidgets('80dp: stats κρυμμένα, toggle ορατό, χωρίς overflow',
        (tester) async {
      await tester.pumpWidget(_folderViewAt(tester, height: 80));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsNothing); // stats κρυμμένα
      expect(find.byType(CircleToggleButton), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('200dp: stats ορατά, χωρίς overflow', (tester) async {
      await tester.pumpWidget(_folderViewAt(tester, height: 200));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.byType(CircleToggleButton), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('error στο stream: τα stats δεν μένουν σε αιώνιο skeleton',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            itemsByFolderStreamProvider(1).overrideWith(
              (ref) => Stream<List<Item>>.error(StateError('db closed')),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 200,
                  child: HomeFolderView(folder: _folder()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('statsSkeleton')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('B-Π2 HomeScreen — κοντό viewport (landscape κινητού)', () {
    testWidgets('392dp ύψος: greeting κρυφό, folder view ορατό, χωρίς overflow',
        (tester) async {
      tester.view.physicalSize = const Size(872, 392);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foldersStreamProvider
                .overrideWith((ref) => Stream.value([_folder()])),
            selectedFolderIdProvider.overrideWith((ref) => 1),
            ..._overrides(1),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // «Καλημέρα!» / «Καλό απόγευμα!» / «Καλησπέρα!» → κανένα δεν υπάρχει
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').startsWith('Καλ'),
        ),
        findsNothing,
      );
      // Το folder view του επιλεγμένου φακέλου είναι ορατό
      expect(find.byType(CircleToggleButton), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });
}
