// lib/services/security_service.dart
//
// Πρώτο MethodChannel του project (Android FLAG_SECURE):
// μπλοκάρει recents-thumbnail + screenshots/screen-record όσο το
// app-lock είναι ενεργό. Άλλες πλατφόρμες → no-op (MissingPlugin).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/utils/debug_config.dart';

class SecurityService {
  SecurityService._();
  static const _ch = MethodChannel('super_note/security');

  /// S-17: τελευταία τιμή που εφαρμόστηκε επιτυχώς. Αποφεύγει περιττά
  /// channel calls (π.χ. reassert σε κάθε resume) — ίδιο state, ίδιο αποτέλεσμα.
  static bool? _lastApplied;

  /// Warn-once: το κάθε αποτυχημένο κανάλι δεν πρέπει να πλημμυρίζει logs.
  static bool _warned = false;

  /// true = ασφαλής οθόνη· false = επαναφορά. Ποτέ δεν πετάει.
  ///
  /// S-17: idempotent. Οι αποτυχίες **δεν** cache-άρονται — το επόμενο
  /// reassert/retry πρέπει να ξαναδοκιμάσει.
  static Future<bool> setSecure(bool secure, {bool force = false}) async {
    if (!force && _lastApplied == secure) {
      DebugConfig.notif('SecurityService.setSecure=$secure (skipped — already)');
      return true;
    }
    try {
      await _ch
          .invokeMethod('setSecure', {'secure': secure})
          .timeout(const Duration(seconds: 2));
      _lastApplied = secure;
      _warned = false;
      DebugConfig.notif('SecurityService.setSecure=$secure');
      return true;
    } catch (e) {
      _lastApplied = null;
      if (!_warned) {
        _warned = true;
        DebugConfig.warning('SecurityService.setSecure failed: $e');
      } else {
        DebugConfig.notif('SecurityService.setSecure failed again: $e');
      }
      return false;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _lastApplied = null;
    _warned = false;
  }
}
