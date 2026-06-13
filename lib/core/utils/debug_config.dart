// lib/core/utils/debug_config.dart
//
// Κεντρικός διαχειριστής debug logs για SuperNote.
//
// ΧΡΗΣΗ:
//   DebugConfig.print('Κάτι έγινε');
//   DebugConfig.db('Item saved: ${item.id}');
//   DebugConfig.nav('Navigating to NoteDetail');
//   DebugConfig.startup('DB initialized');
//   DebugConfig.error('Failed to load', error, stackTrace);
//
// ΓΙΑ ΝΑ ΕΝΕΡΓΟΠΟΙΗΣΕΙΣ LOGS:
//   Άλλαξε το _debug = true  (όλα)
//   ή ενεργοποίησε μεμονωμένες κατηγορίες παρακάτω
//
import 'package:flutter/foundation.dart';

class DebugConfig {

  // ─────────────────────────────────────────────────────────
  // ΔΙΑΚΟΠΤΕΣ
  // ─────────────────────────────────────────────────────────

  /// Κεντρικός διακόπτης — αν false, ΟΛΟΙ οι logs είναι OFF
  // static const bool _debug = kDebugMode; // Αυτόματα OFF στο release build
  static const bool _debug = false; // ON στο release build

  // Μεμονωμένες κατηγορίες — χρήσιμο για να βλέπεις μόνο ό,τι θες
  static const bool _logDb       = true;  // Database operations
  static const bool _logNav      = true;  // Navigation
  static const bool _logProvider = true;  // Riverpod provider changes
  static const bool _logNotif    = true;  // Notifications
  static const bool _logSync     = true; // Sync operations (verbose)
  static const bool _logSearch   = true; // Search queries (verbose)

  // ─────────────────────────────────────────────────────────
  // STARTUP TIMER
  // ─────────────────────────────────────────────────────────

  static final Stopwatch _startupWatch = Stopwatch()..start();

  static void startup(String label) {
    if (!_debug) return;
    final ms = _startupWatch.elapsedMilliseconds;
    debugPrint('🚀 STARTUP +${ms}ms  $label');
  }

  // ─────────────────────────────────────────────────────────
  // ΓΕΝΙΚΑ LOGS
  // ─────────────────────────────────────────────────────────

  static void print(Object? object) {
    if (!_debug) return;
    debugPrint('💬 $object');
  }

  // ─────────────────────────────────────────────────────────
  // ΚΑΤΗΓΟΡΙΕΣ
  // ─────────────────────────────────────────────────────────

  /// Database operations (Isar queries, saves, deletes)
  static void db(String message) {
    if (!_debug || !_logDb) return;
    debugPrint('🗄️  DB | $message');
  }

  /// Navigation events
  static void nav(String message) {
    if (!_debug || !_logNav) return;
    debugPrint('🧭 NAV | $message');
  }

  /// Riverpod provider state changes
  static void provider(String message) {
    if (!_debug || !_logProvider) return;
    debugPrint('⚡ PRV | $message');
  }

  /// Notification scheduling/cancellation
  static void notif(String message) {
    if (!_debug || !_logNotif) return;
    debugPrint('🔔 NTF | $message');
  }

  /// Sync operations
  static void sync(String message) {
    if (!_debug || !_logSync) return;
    debugPrint('🔄 SYN | $message');
  }

  /// Search queries
  static void search(String message) {
    if (!_debug || !_logSearch) return;
    debugPrint('🔍 SRH | $message');
  }

  // ─────────────────────────────────────────────────────────
  // ERRORS — εμφανίζονται ΠΑΝΤΑ στο debug mode
  // ─────────────────────────────────────────────────────────

  static void error(String message, [Object? error, StackTrace? stack]) {
    if (!_debug) return;
    debugPrint('❌ ERR | $message');
    if (error != null) debugPrint('   → $error');
    if (stack != null) debugPrint('   → $stack');
  }

  static void warning(String message) {
    if (!_debug) return;
    debugPrint('⚠️  WRN | $message');
  }

  // ─────────────────────────────────────────────────────────
  // HELPER
  // ─────────────────────────────────────────────────────────

  static bool get isDebug => _debug;
}