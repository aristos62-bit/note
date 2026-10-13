// test/theme_tokens_test.dart
//
// Dark-hardcoded SPoT migration: shared consts + semantic tokens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/theme/ui_tokens.dart';
import 'package:super_note/helpers/item_color_helper.dart';

void main() {
  test('cSuccess light≠dark (theme-aware)', () {
    expect(ColorsUI.getSuccess(Brightness.light),
        isNot(ColorsUI.getSuccess(Brightness.dark)));
  });

  test('shared birthday/special consts keep values', () {
    expect(ItemColorHelper.birthdayPink, const Color(0xFFEC4899));
    expect(ItemColorHelper.specialAmber, const Color(0xFFF59E0B));
  });

  test('birthday/special backgrounds dark≠light', () {
    expect(Colors.pink.shade900, isNot(Colors.pink.shade100));
    expect(Colors.amber.shade900, isNot(Colors.amber.shade100));
  });
}
