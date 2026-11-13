// test/backup_container_test.dart
//
// S-02: pure tests για το κρυπτογραφημένο container (.snb) — χωρίς Isar/plugin.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:super_note/services/backup/backup_container.dart';

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
      expect(header.kdf, SnbHeader.kdfPbkdf2HmacSha256);
      expect(header.iterations, fastIterations);
      expect(header.salt.length, 16);
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
}
