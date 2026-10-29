// test/block_numbering_test.dart
//
// Ο7 — E22: η αρίθμηση των numbered blocks γίνεται σε ένα πέρασμα (O(n))
// αντί για sublist(0, i) ανά block, με ίδιο αποτέλεσμα (συνεχής αρίθμηση
// σε όλη τη σημείωση). Καθαρό Dart — χωρίς Isar/widgets.
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/models/item_block.dart';
import 'package:super_note/shared/widgets/block_editor_widget.dart';

ItemBlock _blk(BlockType type, {String? text}) => ItemBlock()
  ..itemId = 1
  ..type = type
  ..text = text;

void main() {
  group('numberedIndexesFor', () {
    test('κενή λίστα → κενή αρίθμηση', () {
      expect(numberedIndexesFor(const []), isEmpty);
    });

    test('χωρίς numbered blocks → όλα 0', () {
      final blocks = [
        _blk(BlockType.text, text: 'a'),
        _blk(BlockType.heading1, text: 'b'),
        _blk(BlockType.bulletList, text: 'c'),
      ];
      expect(numberedIndexesFor(blocks), [0, 0, 0]);
    });

    test('μικτή σημείωση: συνεχής αρίθμηση μόνο στα numbered', () {
      final blocks = [
        _blk(BlockType.text, text: 'a'),
        _blk(BlockType.numbered, text: '1'),
        _blk(BlockType.text, text: 'b'),
        _blk(BlockType.numbered, text: '2'),
        _blk(BlockType.numbered, text: '3'),
      ];
      // Το tile δείχνει index + 1 → 1, 2, 3 στα numbered.
      expect(numberedIndexesFor(blocks), [0, 0, 1, 1, 2]);
    });

    test('10 συνεχόμενα numbered → 0..9 (δείχνονται 1..10)', () {
      final blocks =
          List.generate(10, (i) => _blk(BlockType.numbered, text: '$i'));
      expect(numberedIndexesFor(blocks), List.generate(10, (i) => i));
    });

    test('40+ blocks: αρίθμηση ανεξάρτητη από το μέγεθος της λίστας', () {
      final blocks = List.generate(
        41,
        (i) => _blk(i.isEven ? BlockType.numbered : BlockType.text),
      );
      final out = numberedIndexesFor(blocks);
      expect(out.length, 41);
      expect(out.last, 20); // 21 numbered (0,2,...,40) → τελευταίο index 20
    });

    test('numbered μετά από heading συνεχίζει την ίδια σειρά', () {
      final blocks = [
        _blk(BlockType.numbered),
        _blk(BlockType.heading2),
        _blk(BlockType.numbered),
        _blk(BlockType.quote),
        _blk(BlockType.numbered),
      ];
      expect(numberedIndexesFor(blocks), [0, 1, 1, 2, 2]);
    });
  });
}
