// test/app_errors_test.dart
//
// AppErrors SPoT (Φ4a βήμα 5): σταθερές + παραμετρικές.
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/shared/widgets/archive_helper.dart';

void main() {
  test('βασικές σταθερές non-empty + σταθερές τιμές', () {
    expect(AppErrors.needTitle, 'Παρακαλώ προσθέστε τίτλο');
    expect(AppErrors.saveFailed, 'Σφάλμα κατά την αποθήκευση');
    expect(AppErrors.dateRequired, isNotEmpty);
    expect(AppErrors.longPressRestoreHint, contains('παρατεταμένα'));
    expect(AppErrors.shareFailed, isNotEmpty);
    expect(AppErrors.loadFailed, isNotEmpty);
    expect(AppErrors.contactsPermission, isNotEmpty);
    expect(AppErrors.eventCreateFailed, isNotEmpty);
  });

  test('archived/restored για κάθε ItemLabel', () {
    for (final label in ItemLabel.values) {
      final noun = label == ItemLabel.note
          ? 'σημείωση'
          : label == ItemLabel.entry
              ? 'εγγραφή'
              : 'στοιχείο';
      expect(AppErrors.archived(noun), contains('αρχειοθετήθηκε'));
      expect(AppErrors.restored(noun), contains('επαναφέρθηκε'));
    }
  });

  test('παραμετρικές κρατούν τα ορίσματα', () {
    expect(AppErrors.movedToFolder('Γενικά'), contains('Γενικά'));
    expect(AppErrors.attachMaxFiles(3, 'Φωτο'), contains('3'));
    expect(AppErrors.attachExists('a.png'), contains('a.png'));
    expect(AppErrors.attachSaved('b.pdf'), contains('b.pdf'));
    expect(AppErrors.birthdayCreated('Νίκος'), contains('Νίκος'));
    expect(AppErrors.birthdayReplaced('Νίκος'), contains('Νίκος'));
    expect(AppErrors.oversizeSkipped(2), contains('2'));
  });
}
