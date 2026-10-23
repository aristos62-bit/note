// test/folder_picker_resolve_test.dart
//
// S272 (E38): resolveFolderForNewItem — σε «Όλοι» ανοίγει picker χωρίς να
// αλλάζει η κοινή επιλογή· με έγκυρη επιλογή επιστρέφει απευθείας.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/shared/widgets/widgets.dart';

Folder _folder({int id = 1, String name = 'Γενικά'}) => Folder()
  ..id = id
  ..name = name
  ..workspaceId = 1
  ..icon = '📁';

Widget _harness({
  required List<Override> overrides,
  required void Function(int?) onResult,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) {
          // Στην εφαρμογή οι οθόνες watch-άρουν το stream (folder selector)·
          // το ίδιο κάνουμε εδώ ώστε ο picker να έχει ζεστή λίστα.
          ref.watch(foldersStreamProvider);
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  onResult(await resolveFolderForNewItem(context, ref));
                },
                child: const Text('go'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets('έγκυρη επιλογή → χωρίς διάλογο, επιστρέφει το id',
      (tester) async {
    int? result;
    await tester.pumpWidget(_harness(
      overrides: [
        foldersStreamProvider.overrideWith(
          (ref) => Stream.value([_folder()]),
        ),
        selectedFolderIdProvider.overrideWith((ref) => 1),
      ],
      onResult: (v) => result = v,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(result, 1);
    expect(find.text('Επιλογή φακέλου'), findsNothing);
  });

  testWidgets('«Όλοι» → picker, επιλογή φακέλου → επιστρέφει id',
      (tester) async {
    int? result;
    await tester.pumpWidget(_harness(
      overrides: [
        foldersStreamProvider.overrideWith(
          (ref) => Stream.value([
            _folder(),
            _folder(id: 2, name: 'Δουλειά'),
          ]),
        ),
      ],
      onResult: (v) => result = v,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Επιλογή φακέλου'), findsOneWidget);
    await tester.tap(find.text('Δουλειά'));
    await tester.pumpAndSettle();

    expect(result, 2);
  });

  testWidgets('stale επιλογή (διαγραμμένος φάκελος) → καθαρίζει + picker',
      (tester) async {
    int? result;
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foldersStreamProvider.overrideWith(
            (ref) => Stream.value([_folder()]),
          ),
          selectedFolderIdProvider.overrideWith((ref) => 99),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context, listen: false);
              ref.watch(foldersStreamProvider);
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await resolveFolderForNewItem(context, ref);
                  },
                  child: const Text('go'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(container.read(selectedFolderIdProvider), isNull);
    expect(find.text('Επιλογή φακέλου'), findsOneWidget);

    await tester.tap(find.text('Γενικά'));
    await tester.pumpAndSettle();
    expect(result, 1);
  });
}
