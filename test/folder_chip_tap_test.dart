// test/folder_chip_tap_test.dart
//
// FolderChip tap zones (pattern συλλογών):
// κέντρο κάρτας → select μόνο · ⋮ → menu μόνο (χωρίς αόρατο 48px κουτί).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/folder_selector.dart';

Folder _folder(int id, String name, {bool isSystem = false}) {
  return Folder()
    ..id = id
    ..name = name
    ..workspaceId = 1
    ..icon = '📁'
    ..isSystem = isSystem;
}

Widget _wrap({
  required List<Folder> folders,
  required int? selectedId,
  required ValueChanged<int?> onSelect,
  required ValueChanged<Folder> onMenu,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: FolderChipSelector(
          folders: folders,
          selectedFolderId: selectedId,
          onSelect: onSelect,
          onFolderLongPress: onMenu,
        ),
      ),
    ),
  );
}

Future<void> _pumpChip(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

void main() {
  group('FolderChip tap zones (pattern συλλογών)', () {
    testWidgets('tap κέντρου → select 1×, menu 0×', (tester) async {
      var selects = 0;
      var menus = 0;
      int? selected;
      await _pumpChip(
        tester,
        _wrap(
          folders: [_folder(1, 'Τάδε')],
          selectedId: null,
          onSelect: (id) {
            selects++;
            selected = id;
          },
          onMenu: (_) => menus++,
        ),
      );
      final label = find.text('Τάδε');
      expect(label, findsOneWidget);
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.tap(label);
      await tester.pump();
      expect(selects, 1);
      expect(selected, 1);
      expect(menus, 0);
    });

    testWidgets('tap ⋮ → menu 1×, select 0×', (tester) async {
      var selects = 0;
      var menus = 0;
      await _pumpChip(
        tester,
        _wrap(
          folders: [_folder(1, 'Τάδε')],
          selectedId: null,
          onSelect: (_) => selects++,
          onMenu: (_) => menus++,
        ),
      );
      final more = find.byTooltip('Επιλογές φακέλου');
      expect(more, findsOneWidget);
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pump();
      expect(menus, 1);
      expect(selects, 0);
    });

    testWidgets('⋮ και μετά σώμα → select κανονικά', (tester) async {
      var selects = 0;
      var menus = 0;
      await _pumpChip(
        tester,
        _wrap(
          folders: [_folder(1, 'Τάδε')],
          selectedId: null,
          onSelect: (_) => selects++,
          onMenu: (_) => menus++,
        ),
      );
      final more = find.byTooltip('Επιλογές φακέλου');
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pump();
      expect(menus, 1);
      final label = find.text('Τάδε');
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.tap(label);
      await tester.pump();
      expect(selects, 1);
    });

    testWidgets('«Όλοι» → select null, χωρίς ⋮', (tester) async {
      int? selected = -99;
      await _pumpChip(
        tester,
        _wrap(
          folders: [_folder(1, 'Τάδε')],
          selectedId: 1,
          onSelect: (id) => selected = id,
          onMenu: (_) {},
        ),
      );
      // Μόνο 1 ⋮ (του φακέλου)· το «Όλοι» δεν έχει.
      expect(find.byTooltip('Επιλογές φακέλου'), findsOneWidget);
      await tester.ensureVisible(find.text('Όλοι'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Όλοι'));
      await tester.pump();
      expect(selected, isNull);
    });

    testWidgets('system chip → χωρίς ⋮, σώμα selects', (tester) async {
      var selects = 0;
      await _pumpChip(
        tester,
        _wrap(
          folders: [_folder(2, 'Γενικά', isSystem: true)],
          selectedId: null,
          onSelect: (_) => selects++,
          onMenu: (_) {},
        ),
      );
      expect(find.byTooltip('Επιλογές φακέλου'), findsNothing);
      await tester.ensureVisible(find.text('Γενικά'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Γενικά'));
      await tester.pump();
      expect(selects, 1);
    });
  });
}
