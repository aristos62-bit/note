// lib/core/crypto/pin_kdf.dart
//
// S-323 (S-15): SPoT για το hash του PIN (KDF v2).
//
// Μορφές που **διαβάζονται**:
//   • `v2$pbkdf2-sha256$<iter>$<saltB64>$<hashB64>`  ← τρέχουσα (PBKDF2)
//   • `v1$<iter>$<saltB64>$<hashB64>`                ← iterated SHA-256 (1.3.x)
//   • `<64 hex>`                                     ← SHA-256 χωρίς salt (legacy)
//
// Γράφεται **μόνο** v2. Τα v1/legacy αναβαθμίζονται στο επόμενο επιτυχές
// unlock (`needsUpgrade` → `hash`), χωρίς migration της βάσης: το πεδίο
// παραμένει `String?` (0 schema change).
//
// Γιατί PBKDF2 (ίδιο primitive με το `.snb`, S-02): το πακέτο `cryptography`
// παρέχει ελεγμένη υλοποίηση HMAC-SHA256 αντί για χειροποίητο iterated hash
// και τρέχει σε isolate, ώστε το UI να μη «παγώνει».
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'kdf.dart';

/// Αποτέλεσμα επαλήθευσης PIN.
///
/// `unsupported` = η αποθηκευμένη μορφή είναι **νεότερη/άγνωστη** (π.χ. `v3$…`
/// από μελλοντική έκδοση ή downgrade εγκατάστασης). Δεν είναι λάθος PIN, γι'
/// αυτό δεν πρέπει να αυξάνει τον μετρητή αποτυχιών.
enum PinVerifyOutcome { ok, mismatch, unsupported }

class PinKdfException implements Exception {
  final String message;
  const PinKdfException(this.message);
  @override
  String toString() => 'PinKdfException: $message';
}

class PinKdf {
  PinKdf._();

  /// Τρέχουσες επαναλήψεις PBKDF2-HMAC-SHA256.
  ///
  /// 120k = ίδιο νούμερο με το `.snb` (S-02). Σε pure Dart το κόστος είναι
  /// ~2 blocks SHA-256/επανάληψη· ένα 6ψήφιο PIN έχει 10^6 συνδυασμούς, άρα
  /// ο περιοριστικός παράγοντας δεν είναι οι επαναλήψεις αλλά το persisted
  /// lockout (S-03). Αύξηση στο μέλλον = 1 γραμμή, χωρίς migration (ratchet).
  static const int defaultIterations = 120000;

  /// Όρια ασφαλείας κατά την **ανάγνωση** (guard απέναντι σε κακόβουλο/
  /// κατεστραμμένο hash που θα επέβαλλε υπερβολικό κόστος).
  static const int minIterations = 10000;
  static const int maxIterations = 1000000;

  static const int saltLength = 16;
  static const int hashLengthBytes = 32; // = BackupKdf.keyLengthBytes

  /// Μεγαλύτερο έγκυρο μήκος αποθηκευμένου hash (fail-fast σε garbage).
  static const int maxStoredLength = 256;

  /// Αναγνωριστικό σχήματος μέσα στη μορφή v2.
  static const String scheme = 'pbkdf2-sha256';

  static const String _v2 = 'v2';
  static const String _v1 = 'v1';

  static bool isValidIterations(int iterations) =>
      iterations >= minIterations && iterations <= maxIterations;

  /// Παράγει νέο hash v2 με φρέσκο τυχαίο salt.
  ///
  /// [useIsolate] false = εκτέλεση στο ίδιο isolate (tests με FakeAsync, όπου
  /// το πραγματικό isolate δεν προχωρά χωρίς `runAsync`).
  static Future<String> hash(
    String pin, {
    int iterations = defaultIterations,
    bool useIsolate = true,
  }) async {
    if (pin.isEmpty) {
      throw const PinKdfException('Κενό PIN');
    }
    if (!isValidIterations(iterations)) {
      throw const PinKdfException('Μη έγκυρες επαναλήψεις PBKDF2');
    }
    final salt = BackupKdf.randomBytes(saltLength);
    final derived = await _derive(pin, salt, iterations, useIsolate);
    return '$_v2\$$scheme\$$iterations\$'
        '${base64Encode(salt)}\$${base64Encode(derived)}';
  }

  /// Επαληθεύει [pin] απέναντι σε **οποιαδήποτε** υποστηριζόμενη μορφή.
  ///
  /// Επιστρέφει `mismatch` για λάθος PIN **και** για κατεστραμμένη/άκυρη
  /// αποθήκευση. Πετά [PinKdfException] μόνο όταν το KDF/isolation απέτυχε —
  /// ο caller το μεταφράζει σε `unavailable` (χωρίς αύξηση μετρητή).
  static Future<PinVerifyOutcome> verify(
    String pin,
    String stored, {
    bool useIsolate = true,
  }) async {
    if (pin.isEmpty || stored.isEmpty || stored.length > maxStoredLength) {
      return PinVerifyOutcome.mismatch;
    }

    final parts = stored.split('\$');

    // ── Legacy: 64 hex χωρίς salt ──────────────────────────────
    if (parts.length == 1) {
      if (stored.length != 64) return PinVerifyOutcome.mismatch;
      final actual = hashLegacy(pin);
      return _constantTimeEqualsString(actual, stored)
          ? PinVerifyOutcome.ok
          : PinVerifyOutcome.mismatch;
    }

    final prefix = parts[0];
    if (prefix == _v2) return _verifyV2(pin, parts, useIsolate);
    if (prefix == _v1) return _verifyV1(pin, parts, useIsolate);

    // Άγνωστο αλλά μοιάζει με δική μας μορφή (v3$… από νεότερη έκδοση).
    if (RegExp(r'^v\d+$').hasMatch(prefix)) {
      return PinVerifyOutcome.unsupported;
    }
    return PinVerifyOutcome.mismatch;
  }

  static Future<PinVerifyOutcome> _verifyV2(
    String pin,
    List<String> parts,
    bool useIsolate,
  ) async {
    if (parts.length != 5 || parts[1] != scheme) {
      return PinVerifyOutcome.mismatch;
    }
    final iterations = int.tryParse(parts[2]);
    if (iterations == null || !isValidIterations(iterations)) {
      return PinVerifyOutcome.mismatch;
    }
    final decoded = _decodePair(parts[3], parts[4]);
    if (decoded == null) return PinVerifyOutcome.mismatch;
    final salt = decoded.$1;
    final expected = decoded.$2;
    if (salt.length < 8 || expected.length != hashLengthBytes) {
      return PinVerifyOutcome.mismatch;
    }

    final actual = await _derive(pin, salt, iterations, useIsolate);
    return _constantTimeEquals(actual, expected)
        ? PinVerifyOutcome.ok
        : PinVerifyOutcome.mismatch;
  }

  static Future<PinVerifyOutcome> _verifyV1(
    String pin,
    List<String> parts,
    bool useIsolate,
  ) async {
    if (parts.length != 4) return PinVerifyOutcome.mismatch;
    final iterations = int.tryParse(parts[1]);
    // Το v1 έγραφε πάντα `kHashIterations` (100k)· το κάτω όριο μένει χαλαρό
    // για συμβατότητα, το πάνω μπαίνει ως guard κόστους.
    if (iterations == null || iterations < 1 || iterations > maxIterations) {
      return PinVerifyOutcome.mismatch;
    }
    final decoded = _decodePair(parts[2], parts[3]);
    if (decoded == null) return PinVerifyOutcome.mismatch;
    final salt = decoded.$1;
    final expected = decoded.$2;
    if (salt.isEmpty || expected.isEmpty) return PinVerifyOutcome.mismatch;

    final actual = useIsolate
        ? await Isolate.run(() => _stretchV1(pin, salt, iterations))
        : _stretchV1(pin, salt, iterations);
    return _constantTimeEquals(actual, expected)
        ? PinVerifyOutcome.ok
        : PinVerifyOutcome.mismatch;
  }

  /// `null` = μη έγκυρο base64 (→ mismatch, όχι exception).
  static (List<int>, List<int>)? _decodePair(String saltB64, String hashB64) {
    try {
      return (base64Decode(saltB64), base64Decode(hashB64));
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> _derive(
    String pin,
    List<int> salt,
    int iterations,
    bool useIsolate,
  ) async {
    try {
      return await BackupKdf.deriveKey(
        password: pin,
        salt: salt,
        iterations: iterations,
        useIsolate: useIsolate,
      );
    } on BackupKdfException catch (e) {
      // Σφάλμα KDF/isolate — όχι λάθος PIN.
      throw PinKdfException(e.message);
    }
  }

  /// Iterated SHA-256 του v1 (`sha256(pin ‖ salt)` × iterations).
  /// Μόνο για **ανάγνωση** παλιών hashes.
  static Uint8List _stretchV1(String pin, List<int> salt, int iterations) {
    var current = <int>[...utf8.encode(pin), ...salt];
    for (var i = 0; i < iterations; i++) {
      current = sha256.convert(current).bytes;
    }
    return Uint8List.fromList(current);
  }

  /// Legacy SHA-256 hex (προ-salt) — μόνο για επαλήθευση/συμβατότητα.
  static String hashLegacy(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  /// true = το αποθηκευμένο hash πρέπει να ξαναγραφτεί σε v2.
  ///
  /// Καλείται **μόνο** μετά από επιτυχές verify (άρα το περιεχόμενο είναι
  /// έγκυρο). Άγνωστη μορφή (`v3$…`) → false: δεν μπορούμε να την
  /// αναβαθμίσουμε, και δεν πρέπει να την πατήσουμε.
  static bool needsUpgrade(String? stored) {
    if (stored == null || stored.isEmpty) return false;
    final parts = stored.split('\$');
    if (parts.length == 1) {
      return stored.length == 64; // legacy hex
    }
    if (parts[0] == _v1) return true;
    if (parts[0] == _v2) {
      if (parts.length != 5 || parts[1] != scheme) return false;
      final iterations = int.tryParse(parts[2]);
      if (iterations == null) return false;
      return iterations < defaultIterations;
    }
    return false;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Σύγκριση hex strings χωρίς hex decoding (constant-time στα code units).
  static bool _constantTimeEqualsString(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
