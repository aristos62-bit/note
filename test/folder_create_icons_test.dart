// test/folder_create_icons_test.dart
//
// Ο7 — E22 (D8): το μενού δημιουργίας σε φάκελο χρησιμοποιεί πλέον
// Material icons (ItemTypeIcon) αντί για emoji, με 2-tuple λίστα
// (type, label). Χωρίς Isar — μόνο rendering του sheet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/widgets.dart';

void main() {
  group('kFolderCreateTypes', () {
    test('2-tuple (type, label) — χωρίς emoji', () {
      expect(kFolderCreateTypes.length, 8);
      for (final t in kFolderCreateTypes) {
        expect(t.$1, isA<ItemType>());
        expect(t.$2, isNotEmpty);
        expect(t.$2.contains('📝'), isFalse);
      }
    });

    test('labels = SPoT ItemTypeIcon.labelFor', () {
      for (final t in kFolderCreateTypes) {
        expect(t.$2, ItemTypeIcon.labelFor(t.$1));
      }
    });
  });

  testWidgets('FolderCreateSheet: ένα ItemTypeIcon ανά τύπο', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FolderCreateSheet(folderName: 'F')),
      ),
    );

    expect(find.byType(ItemTypeIcon), findsNWidgets(kFolderCreateTypes.length));
    expect(find.byType(ListTile), findsNWidgets(kFolderCreateTypes.length));

    // Κάθε γραμμή δείχνει το σωστό icon του τύπου της.
    for (final t in kFolderCreateTypes) {
      expect(find.byIcon(ItemTypeIcon.iconDataFor(t.$1)), findsWidgets);
      expect(find.text(t.$2), findsOneWidget);
    }

    // Καμία emoji γραμμή (η παλιά υλοποίηση).
    expect(find.text('📝'), findsNothing);
    expect(find.text('✅'), findsNothing);
  });
}
