// test/import_dedup_test.dart
//
// Import dedup batch (Φ4a βήμα 16): pure duplicate-check πάνω σε sets.
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/services/contact_import_service.dart';

Contact _c(String? name, [List<String> numbers = const []]) => Contact(
      displayName: name,
      phones: [for (final n in numbers) Phone(number: n)],
    );

void main() {
  test('name match (case-insensitive)', () {
    expect(
      ContactImportService.isDuplicate(
          _c('John Doe'), {'john doe'}, <String>{}),
      isTrue,
    );
    expect(
      ContactImportService.isDuplicate(
          _c('Jane'), {'john doe'}, <String>{}),
      isFalse,
    );
  });

  test('phone match (strings + legacy shapes)', () {
    expect(
      ContactImportService.isDuplicate(
          _c(null, ['6970000000']), <String>{}, {'6970000000'}),
      isTrue,
    );
    expect(
      ContactImportService.isDuplicate(
          _c(null, ['6970000001']), <String>{}, {'6970000000'}),
      isFalse,
    );
  });

  test('empty sets → false (προχωράμε)', () {
    expect(
      ContactImportService.isDuplicate(
          _c('John', ['6970']), <String>{}, <String>{}),
      isFalse,
    );
    expect(
      ContactImportService.isDuplicate(
          _c(null, []), <String>{}, <String>{}),
      isFalse,
    );
  });
}
