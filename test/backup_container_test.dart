// test/backup_container_test.dart
//
// S-02: pure tests για το κρυπτογραφημένο container (.snb) — χωρίς Isar/plugin.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:super_note/services/backup/backup_container.dart';
import 'package:super_note/services/backup/backup_progress.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('snb_test_');
  });

  tearDown(() async {
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } catch (_) {}
  });

  /// Ελάχιστες επαναλήψεις PBKDF2 (το εύρος επιτρέπει 10k) για γρήγορα tests.
  const fastIterations = 10000;

  Future<File> writeBytes(String name, List<int> bytes) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsBytes(bytes);
    return f;
  }

  Future<File> encrypt(List<int> plaintext,
      {String passphrase = 'secret123',
      int chunkSize = BackupContainer.defaultChunkSize}) async {
    final src = await writeBytes('plain.bin', plaintext);
    final dest = p.join(tmp.path, 'out.snb');
    await BackupContainer.encryptFileTo(
      source: src,
      destPath: dest,
      passphrase: passphrase,
      iterations: fastIterations,
      chunkSize: chunkSize,
    );
    return File(dest);
  }

  group('round-trip', () {
    test('μικρό αρχείο (1 chunk)', () async {
      final plaintext = List<int>.generate(3000, (i) => i % 251);
      final snb = await encrypt(plaintext);
      final out = p.join(tmp.path, 'dec.bin');

      final size = await BackupContainer.decryptFileTo(
        source: snb,
        destPath: out,
        passphrase: 'secret123',
      );

      expect(size, plaintext.length);
      expect(await File(out).readAsBytes(), plaintext);
    });

    test('πολλαπλά chunks (10KB / 4KB)', () async {
      final plaintext = List<int>.generate(10000, (i) => (i * 7) % 256);
      final snb = await encrypt(plaintext, chunkSize: 4096);
      final header = await BackupContainer.readHeader(snb);
      expect(header.chunkCount, 3);
      expect(header.plaintextLength, plaintext.length);

      final out = p.join(tmp.path, 'dec.bin');
      await BackupContainer.decryptFileTo(
        source: snb,
        destPath: out,
        passphrase: 'secret123',
      );
      expect(await File(out).readAsBytes(), plaintext);
    });

    test('κενό περιεχόμενο (μόνο tag)', () async {
      final snb = await encrypt(const <int>[]);
      final out = p.join(tmp.path, 'empty.bin');
      final size = await BackupContainer.decryptFileTo(
        source: snb,
        destPath: out,
        passphrase: 'secret123',
      );
      expect(size, 0);
      expect(await File(out).length(), 0);
    });

    test('δεν αφήνει `.partial` μετά την επιτυχία', () async {
      await encrypt(const <int>[1, 2, 3, 4, 5]);
      final leftovers = await tmp
          .list()
          .where((e) => e.path.toLowerCase().endsWith('.partial'))
          .toList();
      expect(leftovers, isEmpty);
    });
  });

  group('ασφάλεια', () {
    test('λάθος κωδικός → BackupAuthException', () async {
      final snb = await encrypt(List<int>.filled(64, 9));
      final out = p.join(tmp.path, 'dec.bin');
      await expectLater(
        BackupContainer.decryptFileTo(
          source: snb,
          destPath: out,
          passphrase: 'wrong-password',
        ),
        throwsA(isA<BackupAuthException>()),
      );
      expect(await File(out).exists(), isFalse);
      expect(await File('$out.partial').exists(), isFalse);
    });

    test('αλλοιωμένο ciphertext → BackupAuthException', () async {
      final snb = await encrypt(List<int>.filled(5000, 3), chunkSize: 4096);
      final bytes = await snb.readAsBytes();
      final header = SnbHeader.parse(bytes);
      bytes[header.headerLength + 5] ^= 0xFF;
      final tampered = await writeBytes('tampered.snb', bytes);

      await expectLater(
        BackupContainer.decryptFileTo(
          source: tampered,
          destPath: p.join(tmp.path, 'dec.bin'),
          passphrase: 'secret123',
        ),
        throwsA(isA<BackupAuthException>()),
      );
    });

    test('κολοβό αρχείο → SnbFormatException', () async {
      final snb = await encrypt(List<int>.filled(9000, 1), chunkSize: 4096);
      final length = await snb.length();
      final raf = await snb.open(mode: FileMode.append);
      // Αφαίρεση των 10 τελευταίων bytes (tag του τελευταίου chunk).
      await raf.truncate(length - 10);
      await raf.close();

      await expectLater(
        BackupContainer.decryptFileTo(
          source: snb,
          destPath: p.join(tmp.path, 'dec.bin'),
          passphrase: 'secret123',
        ),
        throwsA(isA<SnbFormatException>()),
      );
    });

    test('επιπλέον bytes στο τέλος → SnbFormatException', () async {
      final snb = await encrypt(List<int>.filled(100, 1));
      final raf = await snb.open(mode: FileMode.append);
      await raf.writeFrom(<int>[0, 0, 0, 0]);
      await raf.close();

      await expectLater(
        BackupContainer.decryptFileTo(
          source: snb,
          destPath: p.join(tmp.path, 'dec.bin'),
          passphrase: 'secret123',
        ),
        throwsA(isA<SnbFormatException>()),
      );
    });
  });

  group('header + detectFormat', () {
    test('parse του header που γράφτηκε', () async {
      final snb = await encrypt(List<int>.filled(10, 0), chunkSize: 8192);
      final header = await BackupContainer.readHeader(snb);
      expect(header.version, SnbHeader.currentVersion);
      expect(header.keyMode, SnbHeader.keyModePbkdf2);
      expect(header.requiresPassphrase, isTrue);
      expect(header.iterations, fastIterations);
      expect(header.salt.length, 16);
      expect(header.embeddedKey, isNull);
      expect(header.noncePrefix.length, BackupContainer.noncePrefixLength);
      expect(header.chunkSize, 8192);
      expect(header.plaintextLength, 10);
    });

    test('λάθος magic → SnbFormatException', () async {
      final bad = await writeBytes('bad.snb', List<int>.filled(64, 7));
      await expectLater(
        BackupContainer.readHeader(bad),
        throwsA(isA<SnbFormatException>()),
      );
    });

    test('πολύ μικρό αρχείο → SnbFormatException', () async {
      final tiny = await writeBytes('tiny.snb', <int>[0x53, 0x4E]);
      await expectLater(
        BackupContainer.readHeader(tiny),
        throwsA(isA<SnbFormatException>()),
      );
    });

    test('detectFormat: snb / zip / isar', () async {
      final snb = await encrypt(const <int>[1, 2, 3]);
      expect(await BackupContainer.detectFormat(snb.path), BackupFormat.snb);

      final zip = await writeBytes(
          'x.zip', <int>[0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]);
      expect(await BackupContainer.detectFormat(zip.path), BackupFormat.zip);

      final isar = await writeBytes('x.isar', Uint8List(2048));
      expect(await BackupContainer.detectFormat(isar.path), BackupFormat.isar);

      expect(await BackupContainer.detectFormat(p.join(tmp.path, 'nope')),
          BackupFormat.unknown);
    });
  });

  // S-307 (Δ1): το default path ΔΕΝ έχει κωδικό — ενσωματωμένο κλειδί.
  group('embedded key (S-307)', () {
    test('encrypt χωρίς κωδικό → decrypt χωρίς κωδικό', () async {
      final plaintext = List<int>.generate(7000, (i) => (i * 3) % 256);
      final src = await writeBytes('plain.bin', plaintext);
      final dest = p.join(tmp.path, 'embedded.snb');
      await BackupContainer.encryptFileTo(
        source: src,
        destPath: dest,
        chunkSize: 4096,
      );
      final snb = File(dest);
      final header = await BackupContainer.readHeader(snb);
      expect(header.version, SnbHeader.currentVersion);
      expect(header.keyMode, SnbHeader.keyModeEmbedded);
      expect(header.requiresPassphrase, isFalse);
      expect(header.iterations, 0);
      expect(header.salt, isEmpty);
      expect(header.embeddedKey, isNotNull);
      expect(header.embeddedKey!.length, 32);

      final out = p.join(tmp.path, 'dec.bin');
      final size = await BackupContainer.decryptFileTo(
        source: snb,
        destPath: out,
      );
      expect(size, plaintext.length);
      expect(await File(out).readAsBytes(), plaintext);
    });

    test('κενός κωδικός ⇒ embedded (όχι PBKDF2)', () async {
      final src = await writeBytes('plain.bin', List<int>.filled(10, 4));
      final dest = p.join(tmp.path, 'empty_pass.snb');
      await BackupContainer.encryptFileTo(
        source: src,
        destPath: dest,
        passphrase: '',
      );
      final header = await BackupContainer.readHeader(File(dest));
      expect(header.keyMode, SnbHeader.keyModeEmbedded);
      expect(header.requiresPassphrase, isFalse);
    });

    test('αλλοιωμένο embedded key → BackupAuthException', () async {
      final src = await writeBytes('plain.bin', List<int>.filled(5000, 8));
      final dest = p.join(tmp.path, 'embedded.snb');
      await BackupContainer.encryptFileTo(
        source: src,
        destPath: dest,
        chunkSize: 4096,
      );
      final snb = File(dest);
      final bytes = await snb.readAsBytes();
      final header = SnbHeader.parse(bytes);
      // Το κλειδί βρίσκεται πριν το nonce prefix — άλλαξέ το.
      final keyOffset = header.headerLength -
          1 -
          BackupContainer.noncePrefixLength -
          4 -
          8 -
          header.embeddedKey!.length;
      bytes[keyOffset] ^= 0xFF;
      final tampered = await writeBytes('tampered_key.snb', bytes);
      await expectLater(
        BackupContainer.decryptFileTo(
          source: tampered,
          destPath: p.join(tmp.path, 'dec.bin'),
        ),
        throwsA(isA<BackupAuthException>()),
      );
    });
  });

  // S-307 (Δ4): πρόοδος + ακύρωση.
  group('progress + cancel (S-307)', () {
    test('encrypt/decrypt αναφέρουν πρόοδο μέχρι 100%', () async {
      final src = await writeBytes(
          'plain.bin', List<int>.generate(20000, (i) => i % 251));
      final dest = p.join(tmp.path, 'p.snb');
      final enc = <int>[];
      await BackupContainer.encryptFileTo(
        source: src,
        destPath: dest,
        passphrase: 'secret123',
        iterations: fastIterations,
        chunkSize: 4096,
        onProgress: (prog) {
          expect(prog.phase, BackupPhase.encrypt);
          enc.add(prog.done);
        },
      );
      expect(enc, isNotEmpty);
      expect(enc.last, 20000);

      final dec = <int>[];
      await BackupContainer.decryptFileTo(
        source: File(dest),
        destPath: p.join(tmp.path, 'd.bin'),
        passphrase: 'secret123',
        onProgress: (prog) {
          expect(prog.phase, BackupPhase.decrypt);
          dec.add(prog.done);
        },
      );
      expect(dec, isNotEmpty);
      expect(dec.last, 20000);
    });

    test('ακύρωση στο encrypt → BackupCancelledException, χωρίς τελικό αρχείο',
        () async {
      final src = await writeBytes('plain.bin', List<int>.filled(50000, 2));
      final dest = p.join(tmp.path, 'cancelled.snb');
      await expectLater(
        BackupContainer.encryptFileTo(
          source: src,
          destPath: dest,
          chunkSize: 4096,
          isCancelled: () => true,
        ),
        throwsA(isA<BackupCancelledException>()),
      );
      expect(await File(dest).exists(), isFalse);
      expect(await File('$dest.partial').exists(), isFalse);
    });

    test('ακύρωση στο decrypt → BackupCancelledException, χωρίς plaintext',
        () async {
      final src = await writeBytes('plain.bin', List<int>.filled(50000, 2));
      final dest = p.join(tmp.path, 'cancel_dec.snb');
      await BackupContainer.encryptFileTo(
        source: src,
        destPath: dest,
        chunkSize: 4096,
      );
      final out = p.join(tmp.path, 'dec.bin');
      await expectLater(
        BackupContainer.decryptFileTo(
          source: File(dest),
          destPath: out,
          isCancelled: () => true,
        ),
        throwsA(isA<BackupCancelledException>()),
      );
      expect(await File(out).exists(), isFalse);
    });
  });

  // S-307: το v1 (legacy, πάντα PBKDF2, 48-byte header) διαβάζεται.
  group('v1 legacy header', () {
    List<int> v1Bytes() => <int>[
          ...SnbHeader.magic,
          1, // version
          1, // keyMode (pbkdf2)
          0, 0, 0x30, 0x39, // iterations = 12345
          16, // salt length
          ...List<int>.filled(16, 5),
          8, // nonce prefix length
          ...List<int>.filled(8, 6),
          0, 0, 0x10, 0x00, // chunkSize = 4096
          0, 0, 0, 0, 0, 0, 0x27, 0x10, // plaintextLength = 10000
        ];

    test('parse v1 → requiresPassphrase, headerLength 48', () {
      final header = SnbHeader.parse(v1Bytes());
      expect(header.version, SnbHeader.legacyVersion);
      expect(header.keyMode, SnbHeader.keyModePbkdf2);
      expect(header.requiresPassphrase, isTrue);
      expect(header.embeddedKey, isNull);
      expect(header.salt.length, 16);
      expect(header.headerLength, 48);
      expect(header.plaintextLength, 10000);
    });

    test('v1: toBytes αναπαράγει τα ΑΚΡΙΒΩΣ ίδια bytes (AAD)', () {
      final bytes = v1Bytes();
      final header = SnbHeader.parse(bytes);
      expect(header.toBytes(), bytes);
      expect(header.totalEncryptedLength,
          48 + 10000 + BackupContainer.macLength * header.chunkCount);
    });
  });
}
