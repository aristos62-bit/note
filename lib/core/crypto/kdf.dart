// lib/core/crypto/kdf.dart
//
// S-02: SPoT για key derivation του κρυπτογραφημένου αντιγράφου.
//
// Λεπτό wrapper πάνω στο `Pbkdf2` του πακέτου `cryptography` — καμία
// χειροποίητη κρυπτογραφία (C1). Το `crypto` του project μένει για το
// υπάρχον ΑΠΟΘΗΚΕΥΜΕΝΟ PIN hash (S-03) και δεν αγγίζεται εδώ.
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupKdfException implements Exception {
  final String message;
  const BackupKdfException(this.message);
  @override
  String toString() => 'BackupKdfException: $message';
}

class BackupKdf {
  BackupKdf._();

  /// Μέγεθος salt (bytes) — τυχαίο, νέο για κάθε αντίγραφο.
  static const int saltLength = 16;

  /// Μέγεθος κλειδιού AES-256.
  static const int keyLengthBytes = 32;

  /// Προεπιλεγμένες επαναλήψεις PBKDF2-HMAC-SHA256.
  static const int defaultIterations = 120000;

  /// Αποδεκτό εύρος επαναλήψεων κατά την αποκρυπτογράφηση. Guard απέναντι σε
  /// κακόβουλο header που θα επέβαλλε υπερβολικό κόστος (DoS).
  static const int minIterations = 10000;
  static const int maxIterations = 2000000;

  static bool isValidIterations(int iterations) =>
      iterations >= minIterations && iterations <= maxIterations;

  /// Παράγει [keyLengthBytes] κλειδί από κωδικό + salt.
  ///
  /// [useIsolate] true → εκτελείται σε isolate (το UI δεν «παγώνει» όσο
  /// τρέχουν οι επαναλήψεις). Τα ορίσματα είναι απλά (String/List<int>/int).
  static Future<Uint8List> deriveKey({
    required String password,
    required List<int> salt,
    int iterations = defaultIterations,
    bool useIsolate = true,
  }) async {
    if (password.isEmpty) {
      throw const BackupKdfException('Κενός κωδικός');
    }
    if (salt.length < 8) {
      throw const BackupKdfException('Μη έγκυρο salt');
    }
    if (!isValidIterations(iterations)) {
      throw const BackupKdfException('Μη έγκυρες επαναλήψεις PBKDF2');
    }
    final saltCopy = List<int>.from(salt, growable: false);
    if (useIsolate) {
      return Isolate.run(() => _derive(password, saltCopy, iterations));
    }
    return _derive(password, saltCopy, iterations);
  }

  static Future<Uint8List> _derive(
    String password,
    List<int> salt,
    int iterations,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: keyLengthBytes * 8,
    );
    final key = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    if (bytes.length != keyLengthBytes) {
      throw const BackupKdfException('Λάθος μέγεθος κλειδιού');
    }
    return Uint8List.fromList(bytes);
  }

  /// Κρυπτογραφικά ασφαλή τυχαία bytes (salt / nonce prefix).
  static Uint8List randomBytes(int length) {
    final rnd = Random.secure();
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = rnd.nextInt(256);
    }
    return out;
  }
}
