// test/backup_kdf_test.dart
//
// S-02: επαλήθευση του BackupKdf wrapper.
//  • Γνωστά PBKDF2-HMAC-SHA256 test vectors (cross-check με ανεξάρτητη
//    αναφορά υλοποίηση πάνω στο `crypto` — μόνο για το test).
//  • Guard όρια, randomBytes.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/crypto/kdf.dart';

/// Ανεξάρτητη αναφορά PBKDF2-HMAC-SHA256 (RFC 8018) — ΜΟΝΟ για tests.
List<int> _referencePbkdf2(
  String password,
  List<int> salt,
  int iterations,
  int dkLen,
) {
  final hmac = Hmac(sha256, utf8.encode(password));
  final out = <int>[];
  var block = 1;
  while (out.length < dkLen) {
    final blockBytes = <int>[
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ];
    var u = hmac.convert(<int>[...salt, ...blockBytes]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.addAll(t);
    block++;
  }
  return out.sublist(0, dkLen);
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2 αναφορά (control)', () {
    test('γνωστά vectors SHA-256 (c=1,2,4096)', () {
      expect(
        _hex(_referencePbkdf2('password', utf8.encode('salt'), 1, 32)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
      expect(
        _hex(_referencePbkdf2('password', utf8.encode('salt'), 2, 32)),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
      expect(
        _hex(_referencePbkdf2('password', utf8.encode('salt'), 4096, 32)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });
  });

  group('BackupKdf', () {
    test('συμπίπτει με την αναφορά (c=minIterations)', () async {
      final salt = utf8.encode('0123456789abcdef');
      final expected =
          _referencePbkdf2('password', salt, BackupKdf.minIterations, 32);
      final actual = await BackupKdf.deriveKey(
        password: 'password',
        salt: salt,
        iterations: BackupKdf.minIterations,
        useIsolate: false,
      );
      expect(actual.length, 32);
      expect(_hex(actual), _hex(expected));
    });

    test('isolate → ίδιο κλειδί', () async {
      final salt = List<int>.generate(16, (i) => i);
      final direct = await BackupKdf.deriveKey(
        password: 'correct horse battery staple',
        salt: salt,
        iterations: BackupKdf.minIterations,
        useIsolate: false,
      );
      final isolated = await BackupKdf.deriveKey(
        password: 'correct horse battery staple',
        salt: salt,
        iterations: BackupKdf.minIterations,
        useIsolate: true,
      );
      expect(_hex(isolated), _hex(direct));
    });

    test('διαφορετικό salt → διαφορετικό κλειδί', () async {
      final a = await BackupKdf.deriveKey(
        password: 'p',
        salt: List<int>.filled(16, 1),
        iterations: BackupKdf.minIterations,
        useIsolate: false,
      );
      final b = await BackupKdf.deriveKey(
        password: 'p',
        salt: List<int>.filled(16, 2),
        iterations: BackupKdf.minIterations,
        useIsolate: false,
      );
      expect(_hex(a), isNot(_hex(b)));
    });

    test('κενός κωδικός → BackupKdfException', () async {
      expect(
        () => BackupKdf.deriveKey(password: '', salt: List<int>.filled(16, 0)),
        throwsA(isA<BackupKdfException>()),
      );
    });

    test('μη έγκυρες επαναλήψεις → BackupKdfException', () async {
      expect(
        () => BackupKdf.deriveKey(
          password: 'p',
          salt: List<int>.filled(16, 0),
          iterations: 5,
        ),
        throwsA(isA<BackupKdfException>()),
      );
      expect(BackupKdf.isValidIterations(BackupKdf.minIterations), isTrue);
      expect(BackupKdf.isValidIterations(BackupKdf.maxIterations), isTrue);
      expect(BackupKdf.isValidIterations(BackupKdf.maxIterations + 1), isFalse);
      expect(BackupKdf.isValidIterations(9999), isFalse);
    });

    test('randomBytes: μήκος + μοναδικότητα', () {
      final a = BackupKdf.randomBytes(BackupKdf.saltLength);
      final b = BackupKdf.randomBytes(BackupKdf.saltLength);
      expect(a.length, BackupKdf.saltLength);
      expect(_hex(a), isNot(_hex(b)));
    });
  });
}
