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

/// Stats με έναν μόνο ενεργό τύπο → ακριβώς ένα '3' στην οθόνη (εύκολος έλεγχος).
FolderViewData _viewData() => FolderViewData(
      stats: {ItemType.note: 3},
      pinned: const <Item>[],
      favorites: const <Item>[],
      recent: const <Item>[],
    );

List<Override> _overrides(int folderId) => [
      folderViewDataProvider(folderId)
          .overrideWith((ref) => Stream.value(_viewData())),
      itemsByFolderStreamProvider(folderId)
          .overrideWith((ref) => Stream.value(const <Item>[])),
    ];

Widget _folderViewAt({required double height}) {
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
      await tester.pumpWidget(_folderViewAt(height: 80));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsNothing); // stats κρυμμένα
      expect(find.byType(CircleToggleButton), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('200dp: stats ορατά, χωρίς overflow', (tester) async {
      await tester.pumpWidget(_folderViewAt(height: 200));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.byType(CircleToggleButton), findsNWidgets(4));
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
