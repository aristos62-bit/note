// test/search_highlight_test.dart
//
// SPoT AppStringUtils.highlight — adoption από _SearchResultCard.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/string_utils.dart';

const _normal = TextStyle(fontSize: 14);
const _hl = TextStyle(fontWeight: FontWeight.w700);

void main() {
  test('empty text → single empty span', () {
    final spans = AppStringUtils.highlight('', 'abc', normalStyle: _normal);
    expect(spans.length, 1);
    expect(spans.first.text, '');
  });

  test('empty/blank query → single whole-text span', () {
    for (final q in ['', '   ']) {
      final spans = AppStringUtils.highlight('Hello', q, normalStyle: _normal);
      expect(spans.length, 1);
      expect(spans.first.text, 'Hello');
    }
  });

  test('no match → single whole-text span', () {
    final spans =
        AppStringUtils.highlight('Hello', 'zzz', normalStyle: _normal);
    expect(spans.length, 1);
    expect(spans.first.text, 'Hello');
  });

  test('single match → pre + highlight + post', () {
    final spans = AppStringUtils.highlight('Hello World', 'wor',
        normalStyle: _normal, highlightStyle: _hl);
    expect(spans.map((s) => s.text).toList(), ['Hello ', 'Wor', 'ld']);
    expect(spans[1].style?.fontWeight, FontWeight.w700);
    expect(spans[0].style, _normal);
  });

  test('multi match → N highlights', () {
    final spans = AppStringUtils.highlight('aaa', 'a',
        normalStyle: _normal, highlightStyle: _hl);
    expect(spans.length, 3);
    expect(spans.where((s) => s.style?.fontWeight == FontWeight.w700).length,
        3);
  });

  test('case-insensitive + trimmed query', () {
    final spans = AppStringUtils.highlight('Hello World', '  HELLO ',
        normalStyle: _normal, highlightStyle: _hl);
    expect(spans.map((s) => s.text).toList(), ['Hello', ' World']);
    expect(spans.first.style?.fontWeight, FontWeight.w700);
  });
}
