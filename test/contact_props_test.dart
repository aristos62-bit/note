// test/contact_props_test.dart
//
// ContactProps SPoT (Φ4a βήμα 12): phones-compat — List<String> + [{number/phone/value}] + scalar.
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/contact_props.dart';

void main() {
  test('strings list', () {
    expect(ContactProps.parsePhonesValue('["2101","6970"]'), ['2101', '6970']);
  });

  test('maps list (number/phone/value)', () {
    expect(
      ContactProps.parsePhonesValue('[{"number":"2101"},{"phone":"6970"},{"value":"6980"}]'),
      ['2101', '6970', '6980'],
    );
  });

  test('mixed + empties filtered', () {
    expect(ContactProps.parsePhonesValue('["2101","","6970",null]'), ['2101', '6970']);
  });

  test('malformed/plain', () {
    expect(ContactProps.parsePhonesValue(null), isEmpty);
    expect(ContactProps.parsePhonesValue(''), isEmpty);
    expect(ContactProps.parsePhonesValue('[]'), isEmpty);
    expect(ContactProps.parsePhonesValue('not-a-phone!!'), isEmpty);
    expect(ContactProps.parsePhonesValue('2101234567'), ['2101234567']);
  });

  test('fromProperties fallback chain', () {
    expect(ContactProps.fromProperties([]).primaryPhone, isNull);
  });
}
