// test/pin_kdf_test.dart
//
// S-323 (S-15): PIN KDF v2 — μορφή, roundtrip, όρια, legacy μορφές,
// auto-upgrade ratchet και `unsupported` για άγνωστες μορφές.
//
// Χρόνος: όπου δεν ελέγχεται η ίδια η παράμετρος `iterations`, τα fixtures
// χρησιμοποιούν το ελάχιστο έγκυρο (10k) ώστε το suite να μένει γρήγορο.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/crypto/pin_kdf.dart';

const _pin = '582964';

/// Hash της legacy μορφής v1 (iterated SHA-256), όπως το έγραφε η 1.3.x.
String _v1Hash(String pin, {int iterations = 1000}) {
  final salt = List<int>.generate(16, (i) => i);
  var current = <int>[...utf8.encode(pin), ...salt];
  for (var i = 0; i < iterations; i++) {
    current = sha256.convert(current).bytes;
  }
  return 'v1\$$iterations\$${base64Encode(salt)}\$${base64Encode(current)}';
}

void main() {
  group('PinKdf.hash — μορφή v2', () {
    test('v2\$pbkdf2-sha256\$iter\$saltB64\$hashB64', () async {
      final h = await PinKdf.hash(_pin, useIsolate: false);
      final parts = h.split('\$');
      expect(parts, hasLength(5));
      expect(parts[0], 'v2');
      expect(parts[1], 'pbkdf2-sha256');
      expect(parts[2], '${PinKdf.defaultIterations}');
      expect(base64Decode(parts[3]), hasLength(PinKdf.saltLength));
      expect(base64Decode(parts[4]), hasLength(PinKdf.hashLengthBytes));
    });

    test('νέο salt σε κάθε κλήση (κανένα deterministic hash)', () async {
      final a = await PinKdf.hash(_pin, iterations: 10000, useIsolate: false);
      final b = await PinKdf.hash(_pin, iterations: 10000, useIsolate: false);
      expect(a, isNot(b));
      expect(a.split('\$')[3], isNot(b.split('\$')[3]));
    });

    test('κενό PIN → PinKdfException', () async {
      expect(
        () => PinKdf.hash('', useIsolate: false),
        throwsA(isA<PinKdfException>()),
      );
    });

    test('iterations εκτός ορίων → PinKdfException', () async {
      for (final iterations in [
        PinKdf.minIterations - 1,
        PinKdf.maxIterations + 1,
        0,
        -1,
      ]) {
        expect(
          () => PinKdf.hash(_pin, iterations: iterations, useIsolate: false),
          throwsA(isA<PinKdfException>()),
          reason: '$iterations',
        );
      }
    });

    test('isolate path παράγει επαληθεύσιμο hash', () async {
      final h = await PinKdf.hash(_pin, iterations: 10000);
      expect(await PinKdf.verify(_pin, h), PinVerifyOutcome.ok);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('PinKdf.verify — v2', () {
    test('σωστό PIN → ok, λάθος → mismatch', () async {
      final h = await PinKdf.hash(_pin, iterations: 10000, useIsolate: false);
      expect(await PinKdf.verify(_pin, h, useIsolate: false),
          PinVerifyOutcome.ok);
      expect(await PinKdf.verify('999999', h, useIsolate: false),
          PinVerifyOutcome.mismatch);
    });

    test('πειραγμένο hash byte → mismatch', () async {
      final h = await PinKdf.hash(_pin, iterations: 10000, useIsolate: false);
      final parts = h.split('\$');
      final bytes = base64Decode(parts[4]);
      bytes[0] = bytes[0] ^ 0x01;
      final tampered =
          '${parts[0]}\$${parts[1]}\$${parts[2]}\$${parts[3]}\$'
          '${base64Encode(bytes)}';
      expect(await PinKdf.verify(_pin, tampered, useIsolate: false),
          PinVerifyOutcome.mismatch);
    });

    test('λάθος μήκος hash (όχι 32B) → mismatch χωρίς KDF', () async {
      final salt = base64Encode(List<int>.filled(16, 7));
      final short = 'v2\$pbkdf2-sha256\$120000\$$salt\$'
          '${base64Encode(List<int>.filled(16, 1))}';
      expect(await PinKdf.verify(_pin, short, useIsolate: false),
          PinVerifyOutcome.mismatch);
    });

    test('salt < 8 bytes → mismatch', () async {
      final salt = base64Encode(List<int>.filled(4, 7));
      final h = 'v2\$pbkdf2-sha256\$120000\$$salt\$'
          '${base64Encode(List<int>.filled(32, 1))}';
      expect(await PinKdf.verify(_pin, h, useIsolate: false),
          PinVerifyOutcome.mismatch);
    });

    test('iterations εκτός ορίων → mismatch (guard κόστους)', () async {
      final salt = base64Encode(List<int>.filled(16, 7));
      final hash = base64Encode(List<int>.filled(32, 1));
      for (final iterations in [0, 9999, 1000001]) {
        final h = 'v2\$pbkdf2-sha256\$$iterations\$$salt\$$hash';
        expect(await PinKdf.verify(_pin, h, useIsolate: false),
            PinVerifyOutcome.mismatch,
            reason: '$iterations');
      }
    });

    test('άγνωστο σχήμα / πεδία → mismatch', () async {
      for (final bad in [
        'v2\$argon2id\$120000\$aa\$bb',
        'v2\$pbkdf2-sha256\$120000\$aa',
        'v2\$pbkdf2-sha256\$abc\$aa\$bb',
      ]) {
        expect(await PinKdf.verify(_pin, bad, useIsolate: false),
            PinVerifyOutcome.mismatch,
            reason: bad);
      }
    });
  });

  group('PinKdf.verify — legacy μορφές', () {
    test('v1 (iterated SHA-256) → ok', () async {
      final v1 = _v1Hash(_pin);
      expect(await PinKdf.verify(_pin, v1, useIsolate: false),
          PinVerifyOutcome.ok);
      expect(await PinKdf.verify('999999', v1, useIsolate: false),
          PinVerifyOutcome.mismatch);
    });

    test('v1 με σπασμένο base64 → mismatch', () async {
      expect(
        await PinKdf.verify(_pin, 'v1\$1000\$!!\$!!', useIsolate: false),
        PinVerifyOutcome.mismatch,
      );
    });

    test('legacy 64-hex → ok', () async {
      final legacy = PinKdf.hashLegacy(_pin);
      expect(legacy, hasLength(64));
      expect(await PinKdf.verify(_pin, legacy, useIsolate: false),
          PinVerifyOutcome.ok);
      expect(await PinKdf.verify('999999', legacy, useIsolate: false),
          PinVerifyOutcome.mismatch);
    });

    test('hex με λάθος μήκος → mismatch', () async {
      expect(await PinKdf.verify(_pin, 'a' * 63, useIsolate: false),
          PinVerifyOutcome.mismatch);
    });
  });

  group('PinKdf.verify — unsupported / garbage', () {
    test('vN (N != 1,2) → unsupported', () async {
      for (final stored in [
        'v3\$argon2id\$x\$y\$z',
        'v9\$x',
        'v10\$whatever',
      ]) {
        expect(await PinKdf.verify(_pin, stored, useIsolate: false),
            PinVerifyOutcome.unsupported,
            reason: stored);
      }
    });

    test('garbage / κενό / υπερβολικό μήκος → mismatch', () async {
      expect(await PinKdf.verify(_pin, 'garbage', useIsolate: false),
          PinVerifyOutcome.mismatch);
      expect(await PinKdf.verify(_pin, '', useIsolate: false),
          PinVerifyOutcome.mismatch);
      expect(
        await PinKdf.verify(
          _pin,
          'x' * (PinKdf.maxStoredLength + 1),
          useIsolate: false,
        ),
        PinVerifyOutcome.mismatch,
      );
    });

    test('κενό PIN → mismatch (χωρίς KDF/exception)', () async {
      final h = await PinKdf.hash(_pin, iterations: 10000, useIsolate: false);
      expect(await PinKdf.verify('', h, useIsolate: false),
          PinVerifyOutcome.mismatch);
    });
  });

  group('PinKdf.needsUpgrade — ratchet', () {
    test('v1 + legacy hex → true', () async {
      expect(PinKdf.needsUpgrade(_v1Hash(_pin)), isTrue);
      expect(PinKdf.needsUpgrade(PinKdf.hashLegacy(_pin)), isTrue);
    });

    test('v2 στο default → false· v2 με λιγότερες → true', () async {
      final current = await PinKdf.hash(_pin, useIsolate: false);
      expect(PinKdf.needsUpgrade(current), isFalse);
      final older = await PinKdf.hash(_pin, iterations: 10000, useIsolate: false);
      expect(PinKdf.needsUpgrade(older), isTrue);
    });

    test('null/άδειο/άγνωστο/κατεστραμμένο → false', () {
      expect(PinKdf.needsUpgrade(null), isFalse);
      expect(PinKdf.needsUpgrade(''), isFalse);
      expect(PinKdf.needsUpgrade('v3\$argon2id\$x'), isFalse);
      expect(PinKdf.needsUpgrade('garbage'), isFalse);
      expect(PinKdf.needsUpgrade('v2\$pbkdf2-sha256\$abc\$x\$y'), isFalse);
    });
  });
}
