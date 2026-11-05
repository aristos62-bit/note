// test/share_formatters_test.dart
//
// E39 — ShareFormatters: μέγεθος, καθαρό όνομα, ενότητα 📎.
// Καθαρή λογική → unit tests χωρίς DB/widgets.

import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/services/share/share_formatters.dart';
import 'package:super_note/services/share/share_models.dart';

void main() {
  group('humanSize', () {
    test('μηδέν ή αρνητικό → 0B', () {
      expect(ShareFormatters.humanSize(0), '0B');
      expect(ShareFormatters.humanSize(-5), '0B');
    });

    test('κάτω από 1024 → B χωρίς δεκαδικό', () {
      expect(ShareFormatters.humanSize(1), '1B');
      expect(ShareFormatters.humanSize(1023), '1023B');
    });

    test('KB με 1 δεκαδικό', () {
      expect(ShareFormatters.humanSize(1024), '1.0KB');
      expect(ShareFormatters.humanSize(1536), '1.5KB');
    });

    test('MB / GB με 1 δεκαδικό', () {
      expect(ShareFormatters.humanSize(1024 * 1024), '1.0MB');
      expect(ShareFormatters.humanSize(5 * 1024 * 1024), '5.0MB');
      expect(ShareFormatters.humanSize(1024 * 1024 * 1024), '1.0GB');
    });
  });

  group('displayName', () {
    test('κρατά το fileName (trimmed)', () {
      expect(
        ShareFormatters.displayName(
          fileName: '  έκθεση.pdf ',
          path: r'C:\tmp\x.pdf',
        ),
        'έκθεση.pdf',
      );
    });

    test('κενό fileName → basename (Windows path)', () {
      expect(
        ShareFormatters.displayName(
          fileName: '',
          path: r'C:\Users\a\Δοκιμή.docx',
        ),
        'Δοκιμή.docx',
      );
    });

    test('κενό (whitespace) fileName → basename (Unix path)', () {
      expect(
        ShareFormatters.displayName(
          fileName: '   ',
          path: '/data/user/0/files/pic.jpg',
        ),
        'pic.jpg',
      );
    });

    test('χωρίς όνομα και χωρίς basename → αρχείο', () {
      expect(ShareFormatters.displayName(fileName: '', path: ''), 'αρχείο');
      expect(ShareFormatters.displayName(fileName: '', path: '/data/'), 'αρχείο');
    });
  });

  group('attachmentsSection', () {
    test('κενή λίστα → κενή ενότητα', () {
      expect(ShareFormatters.attachmentsSection(const <ShareFile>[]), isEmpty);
    });

    test('μέγεθος 0 → χωρίς παρένθεση, ενικό', () {
      final lines = ShareFormatters.attachmentsSection(const [
        ShareFile(path: '/a/b.txt', displayName: 'b.txt'),
      ]);
      expect(lines.length, 3);
      expect(lines[0], '');
      expect(lines[1], '📎 Συνημμένα: 1 συνημμένο');
      expect(lines[2], '  • b.txt');
    });

    test('με μέγεθος → παρένθεση, πληθυντικός, σειρά', () {
      final lines = ShareFormatters.attachmentsSection(const [
        ShareFile(path: '/a/b.txt', displayName: 'b.txt', sizeBytes: 1536),
        ShareFile(path: '/a/c.png', displayName: 'c.png', sizeBytes: 2048),
      ]);
      expect(lines[1], '📎 Συνημμένα: 2 συνημμένα');
      expect(lines[2], '  • b.txt (1.5KB)');
      expect(lines[3], '  • c.png (2.0KB)');
    });
  });
}
