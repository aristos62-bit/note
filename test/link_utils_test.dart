// test/link_utils_test.dart
//
// Unit tests για extractUrls (pure, χωρίς platform channels).
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/shared/widgets/link_text.dart';

void main() {
  group('extractUrls', () {
    test('βρίσκει http/https', () {
      expect(extractUrls('δες https://example.com/a και http://x.gr'),
          ['https://example.com/a', 'http://x.gr']);
    });

    test('κόβει τελικά σημεία στίξης', () {
      expect(extractUrls('δες https://x.gr.'), ['https://x.gr']);
    });

    test('χωρίς διπλότυπα', () {
      expect(extractUrls('https://x.gr και https://x.gr'), ['https://x.gr']);
    });

    test('χωρίς urls → κενό', () {
      expect(extractUrls('απλό κείμενο'), isEmpty);
    });

    test('url σε παρένθεση', () {
      expect(extractUrls('(δες https://x.gr/a)'), ['https://x.gr/a']);
    });

    test('παρενθέσεις μέσα στο URL (Wikipedia)', () {
      expect(extractUrls('δες https://en.wikipedia.org/wiki/Flutter_(software) end'),
          ['https://en.wikipedia.org/wiki/Flutter_(software)']);
    });

    test('κλείνει η εξωτερική παρένθεση, κρατά την εσωτερική', () {
      expect(extractUrls('(δες https://x.gr/a_(b))'),
          ['https://x.gr/a_(b)']);
    });
  });
}
