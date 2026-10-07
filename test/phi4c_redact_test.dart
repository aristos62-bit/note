// test/phi4c_redact_test.dart
//
// Unit tests για το PII redact helper (Φ4c-3, pure, χωρίς DB).
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/string_utils.dart';

void main() {
  group('redact', () {
    test('null → [text 0ch]', () {
      expect(AppStringUtils.redact(null), '[text 0ch]');
    });

    test('κρατά μόνο το μήκος', () {
      expect(AppStringUtils.redact('Ζάχαρο Χάπι'), '[text 11ch]');
    });

    test('custom label', () {
      expect(AppStringUtils.redact('a', label: 'tag'), '[tag 1ch]');
    });

    test('extension getter', () {
      expect('abc'.redacted, '[text 3ch]');
    });

    test('δεν διαρρέει ποτέ περιεχόμενο', () {
      const secret = 'μυστικό';
      final out = AppStringUtils.redact(secret);
      expect(out.contains(secret), isFalse);
      expect(out, '[text ${secret.length}ch]');
    });
  });
}
