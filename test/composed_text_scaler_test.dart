// test/composed_text_scaler_test.dart
//
// S288 (a11y E01 · Βήμα 11): σύνθεση system + app text scale με clamp.
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';

ComposedTextScaler _scaler(double system, double app) {
  return ComposedTextScaler(
    system: TextScaler.linear(system),
    app: TextScaler.linear(app),
  );
}

void main() {
  test('system 1.0 + app 1.4 → 1.4', () {
    final s = _scaler(1.0, 1.4);
    expect(s.scale(10), closeTo(14, 0.001));
  });

  test('system 1.5 + app 1.0 → 1.5', () {
    final s = _scaler(1.5, 1.0);
    expect(s.scale(10), closeTo(15, 0.001));
  });

  test('system 1.3 + app 1.2 → 1.56 (σύνθεση, όχι αντικατάσταση)', () {
    final s = _scaler(1.3, 1.2);
    expect(s.scale(10), closeTo(15.6, 0.001));
  });

  test('system 2.0 + app 1.4 → clamp 2.0', () {
    final s = _scaler(2.0, 1.4);
    expect(s.scale(10), closeTo(20, 0.001));
  });

  test('textScaleFactor συμβαδίζει με scale(1.0)', () {
    final s = _scaler(1.5, 1.0);
    // ignore: deprecated_member_use
    expect(s.textScaleFactor, closeTo(1.5, 0.001));
  });

  test('equality: ίδια πεδία → ίσο, διαφορετικά → άνισο', () {
    expect(_scaler(1.0, 1.0), _scaler(1.0, 1.0));
    expect(_scaler(1.0, 1.0).hashCode, _scaler(1.0, 1.0).hashCode);
    expect(_scaler(1.0, 1.0), isNot(_scaler(1.5, 1.0)));
  });
}
