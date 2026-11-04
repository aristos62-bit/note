// test/attachments_strip_test.dart
//
// E09: strip συνημμένων note/event.
// - κενό → labeled «Προσθήκη»
// - μη κενό → header «Συνημμένα (N)» + icon-only add (48 dp, tooltip)
// - διαγραφή → confirm dialog (μη αναστρέψιμη) πριν το service call
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/shared/widgets/attachments_strip.dart';

Attachment _att(int id, String name) => Attachment()
  ..id = id
  ..itemId = 1
  ..fileName = name
  ..localPath = '/tmp/$name'
  ..mimeType = 'application/pdf'
  ..fileSize = 10;

Widget _wrap(List<Attachment> atts) {
  return ProviderScope(
    overrides: [
      attachmentsProvider.overrideWith((ref, itemId) => Stream.value(atts)),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [AttachmentsStrip(itemId: 1)],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('κενό strip → labeled «Προσθήκη» (48 dp)', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pump();

    expect(find.text('Προσθήκη'), findsOneWidget);
    expect(find.textContaining('Συνημμένα'), findsNothing);

    final size = tester.getSize(find.byType(TextButton));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('2 συνημμένα → header + icon-only add + κελιά', (tester) async {
    await tester.pumpWidget(_wrap([_att(1, 'a.pdf'), _att(2, 'b.pdf')]));
    await tester.pump();

    expect(find.text('Συνημμένα (2)'), findsOneWidget);
    expect(find.byTooltip('Προσθήκη αρχείου'), findsOneWidget);
    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.pdf'), findsOneWidget);

    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete target = 32 dp + tooltip/semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap([_att(1, 'a.pdf')]));
    await tester.pump();

    final size = tester.getSize(find.bySemanticsLabel('Διαγραφή αρχείου'));
    expect(size.width, greaterThanOrEqualTo(32));
    expect(size.height, greaterThanOrEqualTo(32));
    expect(find.byTooltip('Διαγραφή αρχείου'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tap delete → confirm dialog, cancel → τίποτα', (tester) async {
    await tester.pumpWidget(_wrap([_att(1, 'a.pdf')]));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.cancel_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Διαγραφή αρχείου;'), findsOneWidget);
    expect(find.text('Η ενέργεια δεν μπορεί να αναιρεθεί.'), findsOneWidget);

    await tester.tap(find.text('Άκυρο'));
    await tester.pumpAndSettle();

    expect(find.text('Διαγραφή αρχείου;'), findsNothing);
    // Το κελί παραμένει — δεν έγινε delete.
    expect(find.text('a.pdf'), findsOneWidget);
  });
}
