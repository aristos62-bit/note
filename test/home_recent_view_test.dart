// test/home_recent_view_test.dart
//
// O5/E44: το «Πρόσφατα» δείχνει τα 10 πραγματικά πρόσφατα και
// δεν επιτρέπει drag (χρονική προβολή, όχι χειροκίνητη σειρά).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/features/home/home_folder_view.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/shared/widgets/widgets.dart';

Folder _folder() => Folder()
  ..id = 1
  ..name = 'Γενικά'
  ..workspaceId = 1;

/// 12 σημειώσεις· updatedAt αυξάνει με το id (12 = νεότερο).
List<Item> _notes(int count) => List.generate(
  count,
      (i) => Item()
    ..id = i + 1
    ..title = 'Σημείωση ${i + 1}'
    ..workspaceId = 1
    ..type = ItemType.note
    ..folderId = 1
    ..createdAt = DateTime(2026, 1, 1)
    ..updatedAt = DateTime(2026, 1, i + 1),
);

Widget _view({required List<Item> items}) => ProviderScope(
  overrides: [
    itemsByFolderStreamProvider(1)
        .overrideWith((ref) => Stream.value(items)),
  ],
  child: MaterialApp(
    home: Scaffold(body: HomeFolderView(folder: _folder())),
  ),
);

Future<void> _pump(WidgetTester tester, Widget w) async {
  // 360dp → 1 στήλη· 2000dp → χωράνε και τα 10 cards (χωρίς lazy offscreen).
  tester.view.physicalSize = const Size(360, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('δείχνει 10 από 12 — τα νεότερα', (tester) async {
    await _pump(tester, _view(items: _notes(12)));

    expect(find.text('Σημείωση 1'), findsNothing);
    expect(find.text('Σημείωση 2'), findsNothing);
    expect(find.text('Σημείωση 3'), findsOneWidget);
    expect(find.text('Σημείωση 12'), findsOneWidget);
  });

  testWidgets('σειρά: νεότερο πάνω (12 πριν από 11)', (tester) async {
    await _pump(tester, _view(items: _notes(12)));

    final y12 = tester.getTopLeft(find.text('Σημείωση 12')).dy;
    final y11 = tester.getTopLeft(find.text('Σημείωση 11')).dy;
    expect(y12, lessThan(y11));
  });

  testWidgets('drag ανενεργό στο «Πρόσφατα» (κανένα handle)', (tester) async {
    await _pump(tester, _view(items: _notes(12)));
    expect(find.byType(ReorderHandle), findsNothing);
  });

  testWidgets('χωρίς overflow / exceptions', (tester) async {
    await _pump(tester, _view(items: _notes(12)));
    expect(tester.takeException(), isNull);
  });
}