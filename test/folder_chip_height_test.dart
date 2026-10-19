// test/folder_chip_height_test.dart
//
// S262 (A): τα folder chips δεν κόβουν το label σε μεγάλο text scale.
// - A1 DraggableFolderSelector: ύψος 58 (1.0) → 66 (1.4) + maxLines 1
// - A1b DraggableFolderSelector: min πλάτος 80dp (φαρδαίνει @1.4, χωρίς ellipsis)
// - A1c DraggableFolderSelector: «Όλοι» — ψεύτικο vs πραγματικό drag-over
// - A2 FolderChipSelector (_FolderChip): ύψος 56 (1.0) → 64 (1.4),
//   emoji ακλιμάκωτο (pattern Icon 18dp του Draggable) + maxLines 1
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';
import 'package:super_note/shared/widgets/draggable_folder_selector.dart';
import 'package:super_note/shared/widgets/folder_selector.dart';

Folder _folder(int id, String name) {
  return Folder()
    ..id = id
    ..name = name
    ..workspaceId = 1
    ..icon = '📁';
}

Widget _scaled({required double textScale, required Widget child}) {
  return MaterialApp(
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: c!,
    ),
    home: Scaffold(body: child),
  );
}

Future<void> _pumpDraggable(
  WidgetTester tester,
  double textScale, {
  List<Folder>? folders,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        foldersStreamProvider.overrideWith(
          (ref) => Stream.value(folders ?? [_folder(1, 'Γενικά')]),
        ),
      ],
      child: _scaled(
        textScale: textScale,
        child: const Align(
          alignment: Alignment.topLeft,
          child: DraggableFolderSelector(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpHomeChips(WidgetTester tester, double textScale) async {
  await tester.pumpWidget(
    ProviderScope(
      child: _scaled(
        textScale: textScale,
        child: Align(
          alignment: Alignment.topLeft,
          child: FolderChipSelector(
            folders: [_folder(1, 'Γενικά')],
            selectedFolderId: null,
            onSelect: (_) {},
            onFolderLongPress: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Το πλησιέστερο «chip» κουτί πάνω από το label
/// (Container του A1 · Container/AnimatedContainer του A2).
Size _chipSize(WidgetTester tester, String label) {
  final chip = find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (w) => w is Container || w is AnimatedContainer,
        ),
      )
      .first;
  return tester.getSize(chip);
}

/// Το label δεν κόβεται: ύψος μέσα στο chip == ύψος ίδιου Text χωρίς όριο.
/// (Αν το slot του chip είναι μικρότερο, το Text συρρικνώνεται σε ύψος.)
Future<void> _expectLabelNotClipped(
  WidgetTester tester,
  String label,
  double textScale,
) async {
  final inChip = tester.getSize(find.text(label)).height;
  final style = tester.widget<Text>(find.text(label)).style!;

  await tester.pumpWidget(
    _scaled(
      textScale: textScale,
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          label,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
  final free = tester.getSize(find.text(label)).height;

  expect(
    inChip,
    closeTo(free, 0.01),
    reason: 'Το label του chip κόβεται (συρρικνώνεται σε ύψος)',
  );
}

void main() {
  group('A1 DraggableFolderSelector — ύψος chip', () {
    testWidgets('58 στο text scale 1.0', (tester) async {
      await _pumpDraggable(tester, 1.0);
      expect(_chipSize(tester, 'Όλοι').height, 58);
      await _expectLabelNotClipped(tester, 'Όλοι', 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('66 στο 1.4 — label σε 1 γραμμή (χωρίς κόψιμο)', (tester) async {
      await _pumpDraggable(tester, 1.4);
      expect(_chipSize(tester, 'Όλοι').height, 66);
      await _expectLabelNotClipped(tester, 'Όλοι', 1.4);
      expect(tester.takeException(), isNull);
    });
  });

  group('A1b DraggableFolderSelector — πλάτος chip (min 80, όχι ellipsis)', () {
    /// Το label δεν έχει οριζόντιο ellipsis: πλάτος == πλάτος ελεύθερου Text.
    Future<void> expectLabelNotEllipsized(
      WidgetTester tester,
      String label,
      double textScale,
    ) async {
      final inChip = tester.getSize(find.text(label)).width;
      final style = tester.widget<Text>(find.text(label)).style!;

      await tester.pumpWidget(
        _scaled(
          textScale: textScale,
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
      final free = tester.getSize(find.text(label)).width;

      expect(inChip, closeTo(free, 0.01),
          reason: 'Το label του chip έχει οριζόντιο ellipsis (κόβεται)');
    }

    testWidgets('min 80dp στο 1.0 (ίδια εμφάνιση με πριν όταν χωράει)',
        (tester) async {
      await _pumpDraggable(tester, 1.0);
      // Το πλάτος = max(80, label + padding 8 + border 2) — ποτέ μικρότερο από πριν.
      final textW = tester.getSize(find.text('Γενικά')).width;
      expect(_chipSize(tester, 'Γενικά').width,
          closeTo(math.max(80, textW + 10), 0.01));
      await expectLabelNotEllipsized(tester, 'Γενικά', 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.4: το chip φαρδαίνει ώστε το label να μη γίνεται «Διάφο…»',
        (tester) async {
      await _pumpDraggable(
        tester,
        1.4,
        folders: [_folder(2, 'Διάφορα')],
      );
      expect(_chipSize(tester, 'Διάφορα').width, greaterThan(80));
      await expectLabelNotEllipsized(tester, 'Διάφορα', 1.4);
      expect(tester.takeException(), isNull);
    });
  });

  group('A1c DraggableFolderSelector — «Όλοι» chip: ψεύτικο vs πραγματικό drag-over', () {
    Border chipBorder(WidgetTester tester, String label) {
      final chip = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate((w) => w is Container),
            )
            .first,
      );
      return (chip.decoration as BoxDecoration).border as Border;
    }

    testWidgets('border 1dp όταν δεν γίνεται drag (folderId=null, dragOver=null)',
        (tester) async {
      await _pumpDraggable(tester, 1.0);
      expect(chipBorder(tester, 'Όλοι').top.width, 1,
          reason: 'Το «Όλοι» δείχνει ψεύτικο drag-over border 2dp');
      expect(tester.takeException(), isNull);
    });

    testWidgets('drag πάνω στο «Όλοι» → border 2dp (το highlight δουλεύει)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foldersStreamProvider
                .overrideWith((ref) => Stream.value([_folder(1, 'Γενικά')])),
          ],
          child: _scaled(
            textScale: 1.0,
            child: const Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LongPressDraggable<int>(
                    data: 99,
                    feedback: Material(child: Text('drag')),
                    child: Text('drag me'),
                  ),
                  DraggableFolderSelector(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('drag me')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(find.text('Όλοι')));
      await tester.pump();

      expect(chipBorder(tester, 'Όλοι').top.width, 2,
          reason: 'Χάθηκε το drag-over highlight του «Όλοι»');

      await gesture.cancel(); // όχι drop: δεν θέλουμε DB στο test
      await tester.pumpAndSettle();
    });
  });

  group('A2 FolderChipSelector (home) — ύψος chip', () {
    testWidgets('56 στο text scale 1.0', (tester) async {
      await _pumpHomeChips(tester, 1.0);
      expect(_chipSize(tester, 'Όλοι').height, 56);
      await _expectLabelNotClipped(tester, 'Όλοι', 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('64 στο 1.4 — label σε 1 γραμμή, χωρίς overflow',
        (tester) async {
      await _pumpHomeChips(tester, 1.4);
      expect(_chipSize(tester, 'Όλοι').height, 64);
      await _expectLabelNotClipped(tester, 'Όλοι', 1.4);
      expect(tester.takeException(), isNull);
    });

    testWidgets('emoji ακλιμάκωτο: ίδιο ύψος σε 1.0 και 1.4', (tester) async {
      await _pumpHomeChips(tester, 1.0);
      final at10 = tester.getSize(find.text('📂')).height;
      await _pumpHomeChips(tester, 1.4);
      final at14 = tester.getSize(find.text('📂')).height;
      expect(at10, closeTo(18, 0.01)); // σταθερό line box 18dp
      // Αν το emoji ακολουθούσε το text scale θα ήταν ×1.4 → αποτυγχάνει
      expect(at14, closeTo(at10, 0.01));
    });
  });
}
