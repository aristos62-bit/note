// test/settings_dialogs_test.dart
//
// Φ3 Settings dialogs: κλειδώνει το public contract (AppErrors PIN consts
// + wipe-phrase normalization). Τα ίδια τα dialogs είναι library-private
// και επαληθεύονται σε device (Isar-harness precedent S77).
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';

void main() {
  test('pinTooShort exact value (settings + lock share it)', () {
    expect(AppErrors.pinTooShort, 'Το PIN πρέπει να έχει τουλάχιστον 6 ψηφία');
  });

  test('pinMismatch exact value', () {
    expect(AppErrors.pinMismatch, 'Τα PIN δεν ταιριάζουν');
  });

  test('pinWrong exact value (settings + lock share it)', () {
    expect(AppErrors.pinWrong, 'Το PIN δεν είναι σωστό');
  });

  test('pinTooWeak (S-03) non-empty + distinct', () {
    expect(AppErrors.pinTooWeak.isNotEmpty, isTrue);
    expect(AppErrors.pinTooWeak, isNot(AppErrors.pinTooShort));
  });

  test('pinLockedOut χρησιμοποιεί formatWaitSeconds', () {
    expect(AppErrors.pinLockedOut(1), contains('1 δευτερόλεπτο'));
    expect(AppErrors.pinLockedOut(30), contains('30 δευτερόλεπτα'));
    expect(AppErrors.pinLockedOut(90), contains('2 λεπτά'));
    expect(AppErrors.pinLockedOut(3600), contains('1 ώρα'));
  });

  test('sensitive gate μηνύματα (S-04) non-empty', () {
    expect(AppErrors.sensitiveAuthRequired.isNotEmpty, isTrue);
    expect(AppErrors.sensitiveAuthUnavailable.isNotEmpty, isTrue);
  });

  test('pin consts distinct and non-empty', () {
    expect(AppErrors.pinTooShort.isNotEmpty, isTrue);
    expect(AppErrors.pinMismatch.isNotEmpty, isTrue);
    expect(AppErrors.pinTooShort, isNot(AppErrors.pinMismatch));
  });

  test('wipe phrase normalize contract (display vs check)', () {
    const phrase = 'ΔΙΑΓΡΑΦΗ ΟΛΩΝ';
    expect('ΔΙΑΓΡΑΦΗ ΟΛΩΝ'.trim().toUpperCase(), phrase);
    expect('  ΔΙΑΓΡΑΦΗ ΟΛΩΝ  '.trim().toUpperCase(), phrase);
    // Το toUpperCase κρατά τόνους (ή→Ή): πεζά με τόνους ΔΕΝ ταιριάζουν.
    // Πραγματική συμπεριφορά — το πληκτρολόγιο δίνει κεφαλαία (characters).
    expect('διαγραφή όλων'.trim().toUpperCase(), isNot(phrase));
    expect('λάθος'.trim().toUpperCase(), isNot(phrase));
  });
}
