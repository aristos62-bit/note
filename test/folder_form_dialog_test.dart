// test/folder_form_dialog_test.dart
//
// FolderFormDialog SPoT (Φ4a βήμα 3):
// presets/defaults, clean+parseHex edge, show() create/edit flows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/helpers/item_color_helper.dart';
import 'package:super_note/shared/widgets/folder_form_dialog.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.light),
    home: Scaffold(body: child),
  );
}

Widget _opener({
  required void Function(BuildContext ctx) onTap,
}) {
  return _wrap(Builder(
    builder: (ctx) => ElevatedButton(
      onPressed: () => onTap(ctx),
      child: const Text('open'),
    ),
  ));
}

void main() {
  test('presets non-empty + defaults μέσα στις λίστες', () {
    expect(kFolderIcons, isNotEmpty);
    expect(kFolderColors, isNotEmpty);
    expect(kFolderIcons, contains(kDefaultFolderIcon));
    expect(kFolderColors, contains(kDefaultFolderColor));
    expect(ItemColorHelper.parseHex(kDefaultFolderColor), isNotNull);
  });

  test('clean + parseHex edge cases', () {
    expect(AppStringUtils.clean('  Ταξίδια   2026  '), 'Ταξίδια 2026');
    expect(AppStringUtils.clean('   '), isEmpty);
    expect(ItemColorHelper.parseHex(null), isNull);
    expect(ItemColorHelper.parseHex('not-a-color'), isNull);
  });

  testWidgets('create: empty → disabled, valid → result με clean name',
      (tester) async {
    FolderFormResult? got;
    await tester.pumpWidget(_opener(onTap: (ctx) async {
      got = await FolderFormDialog.show(
        ctx,
        title: 'Νέος Φάκελος',
        confirmLabel: 'Δημιουργία',
      );
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Νέος Φάκελος'), findsOneWidget);

    // Κενό → disabled
    final btnEmpty =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Δημιουργία'));
    expect(btnEmpty.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  Ταξίδια  ');
    await tester.pump();
    final btnReady =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Δημιουργία'));
    expect(btnReady.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Δημιουργία'));
    await tester.pumpAndSettle();

    expect(got, isNotNull);
    expect(got!.name, 'Ταξίδια');
    expect(got!.icon, kDefaultFolderIcon);
    expect(got!.color, kDefaultFolderColor);
  });

  testWidgets('edit: prefill + αλλαγή icon', (tester) async {
    FolderFormResult? got;
    await tester.pumpWidget(_opener(onTap: (ctx) async {
      got = await FolderFormDialog.show(
        ctx,
        title: 'Επεξεργασία Φακέλου',
        confirmLabel: 'Αποθήκευση',
        initialName: 'Παλιό',
        initialIcon: '🏠',
        initialColor: '#EC4899',
      );
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Επεξεργασία Φακέλου'), findsOneWidget);

    await tester.tap(find.text('🎵').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Αποθήκευση'));
    await tester.pumpAndSettle();

    expect(got, isNotNull);
    expect(got!.name, 'Παλιό');
    expect(got!.icon, '🎵');
    expect(got!.color, '#EC4899');
  });
}
