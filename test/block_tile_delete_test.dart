// test/block_tile_delete_test.dart
//
// Ο7 — E22: το ✕ του block είναι ορατό μόνο σε hover (desktop/web) ή focus
// (touch), έχει hit area 48×48 (kMinInteractiveDimension) και δεν αλλάζει
// το layout όταν κρύβεται (Visibility με maintainSize). Χωρίς Isar/providers.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/item_block.dart';
import 'package:super_note/shared/widgets/block_editor_widget.dart';

ItemBlock _blk(BlockType type, {String? text}) => ItemBlock()
  ..itemId = 1
  ..type = type
  ..text = text;

const _deleteKey = ValueKey('block_delete');

Future<void> _pumpTile(
  WidgetTester tester, {
  required VoidCallback onDelete,
  String text = 'γραμμή',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // Περιορισμένο πλάτος/ύψος ώστε το hover-out να βγαίνει εκτός tile.
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: BlockTileWidget(
              index: 0,
              block: _blk(BlockType.text, text: text),
              onDelete: onDelete,
              onToggleCheck: () {},
              onTextChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

Visibility _deleteVisibility(WidgetTester tester) => tester.widget<Visibility>(
      find.descendant(
        of: find.byKey(_deleteKey),
        matching: find.byType(Visibility),
      ),
    );

void main() {
  testWidgets('το ✕ ξεκινά κρυφό (χωρίς hover/focus)', (tester) async {
    await _pumpTile(tester, onDelete: () {});
    expect(_deleteVisibility(tester).visible, isFalse);
  });

  testWidgets('focus στο TextField → εμφανίζεται το ✕ και διαγράφει',
      (tester) async {
    var deleted = 0;
    await _pumpTile(tester, onDelete: () => deleted++);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(_deleteVisibility(tester).visible, isTrue);

    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(deleted, 1);
  });

  testWidgets('hover (mouse) → εμφανίζεται το ✕ χωρίς focus', (tester) async {
    await _pumpTile(tester, onDelete: () {});

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    await gesture.moveTo(tester.getCenter(find.byType(BlockTileWidget)));
    await tester.pump();
    expect(_deleteVisibility(tester).visible, isTrue);

    // Έξοδος του ποντικιού (κάτω από το tile) → κρύβεται ξανά.
    await gesture.moveTo(const Offset(700, 550));
    await tester.pump();
    expect(_deleteVisibility(tester).visible, isFalse);
  });

  testWidgets('hit area = 48×48 (kMinInteractiveDimension)', (tester) async {
    await _pumpTile(tester, onDelete: () {});
    final size = tester.getSize(find.byKey(_deleteKey));
    expect(size.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(size.height, greaterThanOrEqualTo(kMinInteractiveDimension));
  });

  testWidgets('το κρυφό ✕ δεν καταλαμβάνει taps (maintainInteractivity false)',
      (tester) async {
    var deleted = 0;
    await _pumpTile(tester, onDelete: () => deleted++);
    // Χωρίς focus/hover: tap πάνω στο (αόρατο) ✕ δεν πρέπει να διαγράψει.
    await tester.tap(find.byKey(_deleteKey), warnIfMissed: false);
    await tester.pump();
    expect(deleted, 0);
  });
}
