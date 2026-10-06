import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/shared/widgets/widgets.dart';

void main() {
  group('kFolderCreateTypes parity', () {
    test('has 8 entries (browser 7 + appointment)', () {
      expect(kFolderCreateTypes.length, 8);
    });

    test('contains note and appointment', () {
      final types = kFolderCreateTypes.map((t) => t.$1).toSet();
      expect(types, contains(ItemType.note));
      expect(types, contains(ItemType.appointment));
    });

    test('appointment label is Ραντεβού', () {
      expect(ItemTypeIcon.labelFor(ItemType.appointment), 'Ραντεβού');
    });

    test('appointment routes via forType', () {
      expect(AppRoutes.forType(ItemType.appointment, 1), '/appointments/1');
    });
  });

  group('FolderCreateSheet', () {
    testWidgets('tap Ραντεβού returns appointment', (tester) async {
      ItemType? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await FolderCreateSheet.show(
                    ctx,
                    folderName: 'F',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Ραντεβού'), findsOneWidget);

      await tester.ensureVisible(find.text('Ραντεβού'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ραντεβού'));
      await tester.pumpAndSettle();
      expect(result, ItemType.appointment);
    });
  });
}
