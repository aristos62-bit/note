// lib/core/utils/composed_text_scaler.dart
//
// S288 (a11y E01 · Βήμα 11): συνθέτει το system text scale με το app scale
// και clamp-άρει το τελικό αποτέλεσμα (μέγιστο [maxScaleFactor]).
//
// Γιατί δεν αρκεί το `TextScaler.linear(fontScale)`:
// αντικαθιστά το system scale — χρήστης με system 1.5 και app 1.0 έβλεπε 1.0.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Συνθέτει το system text scale με το app scale και clamp-άρει το τελικό
/// αποτέλεσμα ώστε να μην ξεπερνά το [maxScaleFactor].
class ComposedTextScaler extends TextScaler {
  const ComposedTextScaler({
    required this.system,
    required this.app,
    this.maxScaleFactor = 2.0,
  });

  final TextScaler system;
  final TextScaler app;
  final double maxScaleFactor;

  @override
  double scale(double fontSize) {
    final composed = app.scale(system.scale(fontSize));
    return math.min(composed, fontSize * maxScaleFactor);
  }

  /// Deprecated στο SDK, αλλά παραμένει abstract μέλος του [TextScaler].
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => scale(1.0);

  @override
  bool operator ==(Object other) =>
      other is ComposedTextScaler &&
      other.system == system &&
      other.app == app &&
      other.maxScaleFactor == maxScaleFactor;

  @override
  int get hashCode => Object.hash(system, app, maxScaleFactor);

  @override
  String toString() =>
      'ComposedTextScaler(system: $system, app: $app, '
      'max: $maxScaleFactor)';
}
