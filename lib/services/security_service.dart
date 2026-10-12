// lib/services/security_service.dart
//
// Πρώτο MethodChannel του project (Android FLAG_SECURE):
// μπλοκάρει recents-thumbnail + screenshots/screen-record όσο το
// app-lock είναι ενεργό. Άλλες πλατφόρμες → no-op (MissingPlugin).
import 'package:flutter/services.dart';
import '../core/utils/debug_config.dart';

class SecurityService {
  SecurityService._();
  static const _ch = MethodChannel('super_note/security');

  /// true = ασφαλής οθόνη· false = επαναφορά. Ποτέ δεν πετάει.
  static Future<bool> setSecure(bool secure) async {
    try {
      await _ch.invokeMethod('setSecure', {'secure': secure});
      DebugConfig.notif('SecurityService.setSecure=$secure');
      return true;
    } catch (e, stack) {
      DebugConfig.error('SecurityService.setSecure', e, stack);
      return false;
    }
  }
}
