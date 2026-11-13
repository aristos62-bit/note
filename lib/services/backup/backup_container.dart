// lib/services/backup/backup_container.dart
//
// S-02: κρυπτογραφημένο container αντιγράφου ασφαλείας (.snb).
//
// Δομή:
//   header (48 bytes για v1)  ← AAD για ΟΛΑ τα chunks
//   chunk_0 ciphertext || tag
//   chunk_1 ciphertext || tag
//   ...
//
// Σχεδιαστικές αποφάσεις (εγκεκριμένες):
//  • AES-256-GCM (AesGcm.with256bits του `cryptography`).
//  • Κλειδί = PBKDF2-HMAC-SHA256(κωδικός, salt, iterations, 256 bits).
//  • STREAM construction: nonce = 8-byte τυχαίο prefix + 4-byte BE counter.
//  • AAD ανά chunk = header bytes ‖ 4-byte BE index. Το `plaintextLength`
//    βρίσκεται ΜΕΣΑ στο header → truncation/reordering ανιχνεύονται.
//  • Γράφουμε ΠΑΝΤΑ σε `<dest>.partial` και κάνουμε rename → ποτέ μισό
//    αρχείο με το τελικό όνομα.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../../core/crypto/kdf.dart';
import '../../core/utils/debug_config.dart';

/// Μορφή αρχείου αντιγράφου.
enum BackupFormat { snb, zip, isar, unknown }

/// Λάθος κωδικός πρόσβασης ή αλλοιωμένο/κατεστραμμένο container.
class BackupAuthException implements Exception {
  final String message;
  const BackupAuthException(this.message);
  @override
  String toString() => 'BackupAuthException: $message';
}

/// Δομικά μη έγκυρο container (magic/version/μήκη/όρια).
class SnbFormatException implements Exception {
  final String message;
  const SnbFormatException(this.message);
  @override
  String toString() => 'SnbFormatException: $message';
}

/// Header του `.snb` (v1).
class SnbHeader {
  static const List<int> magic = <int>[0x53, 0x4E, 0x42, 0x4B]; // 'SNBK'
  static const int currentVersion = 1;
  static const int kdfPbkdf2HmacSha256 = 1;
  static const int maxHeaderRead = 128;

  final int version;
  final int kdf;
  final int iterations;
  final Uint8List salt;
  final Uint8List noncePrefix;
  final int chunkSize;
  final int plaintextLength;

  const SnbHeader({
    required this.version,
    required this.kdf,
    required this.iterations,
    required this.salt,
    required this.noncePrefix,
    required this.chunkSize,
    required this.plaintextLength,
  });

  int get headerLength =>
      4 + // magic
      1 + // version
      1 + // kdf
      4 + // iterations
      1 + salt.length +
      1 + noncePrefix.length +
      4 + // chunkSize
      8; // plaintextLength

  int get chunkCount {
    if (plaintextLength == 0) return 1;
    return (plaintextLength + chunkSize - 1) ~/ chunkSize;
  }

  int get totalEncryptedLength =>
      headerLength +
      plaintextLength +
      BackupContainer.macLength * chunkCount;

  Uint8List toBytes() {
    final out = Uint8List(headerLength);
    final data = ByteData.sublistView(out);
    var o = 0;
    out.setRange(o, o + 4, magic);
    o += 4;
    out[o++] = version;
    out[o++] = kdf;
    data.setUint32(o, iterations, Endian.big);
    o += 4;
    out[o++] = salt.length;
    out.setRange(o, o + salt.length, salt);
    o += salt.length;
    out[o++] = noncePrefix.length;
    out.setRange(o, o + noncePrefix.length, noncePrefix);
    o += noncePrefix.length;
    data.setUint32(o, chunkSize, Endian.big);
    o += 4;
    data.setUint64(o, plaintextLength, Endian.big);
    o += 8;
    return out;
  }

  /// Parse από τα πρώτα bytes του αρχείου.
  static SnbHeader parse(List<int> bytes) {
    if (bytes.length < 4) {
      throw const SnbFormatException('Λείπει η υπογραφή SNBK');
    }
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != magic[i]) {
        throw const SnbFormatException('Λείπει η υπογραφή SNBK');
      }
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    var o = 4;
    int need(int n) {
      if (o + n > bytes.length) {
        throw const SnbFormatException('Κολοβό header');
      }
      return o;
    }

    final version = bytes[need(1)];
    o += 1;
    if (version != currentVersion) {
      throw SnbFormatException('Μη υποστηριζόμενη έκδοση container: $version');
    }
    final kdf = bytes[need(1)];
    o += 1;
    if (kdf != kdfPbkdf2HmacSha256) {
      throw SnbFormatException('Μη υποστηριζόμενη μέθοδος κλειδιού: $kdf');
    }
    final iterations = data.getUint32(need(4), Endian.big);
    o += 4;
    if (!BackupKdf.isValidIterations(iterations)) {
      throw const SnbFormatException('Μη έγκυρες επαναλήψεις PBKDF2');
    }
    final saltLength = bytes[need(1)];
    o += 1;
    if (saltLength < 8 || saltLength > 64) {
      throw const SnbFormatException('Μη έγκυρο μήκος salt');
    }
    need(saltLength);
    final salt = Uint8List.fromList(bytes.sublist(o, o + saltLength));
    o += saltLength;
    final nonceLength = bytes[need(1)];
    o += 1;
    if (nonceLength != BackupContainer.noncePrefixLength) {
      throw const SnbFormatException('Μη έγκυρο μήκος nonce prefix');
    }
    need(nonceLength);
    final noncePrefix = Uint8List.fromList(bytes.sublist(o, o + nonceLength));
    o += nonceLength;
    final chunkSize = data.getUint32(need(4), Endian.big);
    o += 4;
    if (chunkSize < BackupContainer.minChunkSize ||
        chunkSize > BackupContainer.maxChunkSize) {
      throw const SnbFormatException('Μη έγκυρο μέγεθος chunk');
    }
    final plaintextLength = data.getUint64(need(8), Endian.big);
    o += 8;
    if (plaintextLength < 0) {
      throw const SnbFormatException('Μη έγκυρο μήκος περιεχομένου');
    }
    return SnbHeader(
      version: version,
      kdf: kdf,
      iterations: iterations,
      salt: salt,
      noncePrefix: noncePrefix,
      chunkSize: chunkSize,
      plaintextLength: plaintextLength,
    );
  }
}

class BackupContainer {
  BackupContainer._();

  static const String suffix = '.snb';
  static const int noncePrefixLength = 8;
  static const int nonceLength = 12; // 8-byte prefix + 4-byte counter
  static const int macLength = 16;
  static const int defaultChunkSize = 1 << 20; // 1 MiB
  static const int minChunkSize = 4 * 1024;
  static const int maxChunkSize = 8 * 1024 * 1024;

  /// Default όριο plaintext (το ίδιο με το restore guard του service).
  static const int defaultMaxPlaintextBytes = 500 * 1024 * 1024;

  static bool isSnbPath(String path) => path.toLowerCase().endsWith(suffix);

  /// Ανιχνεύει τη μορφή από magic bytes (τα extensions δεν αρκούν).
  static Future<BackupFormat> detectFormat(String path) async {
    final ext = p.extension(path).toLowerCase();
    RandomAccessFile? raf;
    try {
      final file = File(path);
      if (!await file.exists()) return BackupFormat.unknown;
      raf = await file.open();
      final head = await raf.read(4);
      if (head.length == 4) {
        if (_hasBytes(head, SnbHeader.magic)) return BackupFormat.snb;
        // 'PK\x03\x04' (zip local file header) ή 'PK\x05\x06' (empty zip)
        if (head[0] == 0x50 && head[1] == 0x4B) return BackupFormat.zip;
      }
      if (ext == '.snb') return BackupFormat.snb;
      if (ext == '.zip') return BackupFormat.zip;
      return BackupFormat.isar;
    } catch (e) {
      DebugConfig.warning('BackupContainer.detectFormat failed: $e');
      return BackupFormat.unknown;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  /// Διαβάζει/επικυρώνει το header χωρίς να αποκρυπτογραφήσει τίποτα.
  static Future<SnbHeader> readHeader(
    File file, {
    int maxPlaintextBytes = defaultMaxPlaintextBytes,
  }) async {
    final length = await file.length();
    if (length < 48) {
      throw const SnbFormatException('Πολύ μικρό αρχείο container');
    }
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final raw = await raf.read(SnbHeader.maxHeaderRead);
      final header = SnbHeader.parse(raw);
      if (header.plaintextLength > maxPlaintextBytes) {
        throw const SnbFormatException('Το περιεχόμενο υπερβαίνει το όριο');
      }
      if (header.totalEncryptedLength != length) {
        throw const SnbFormatException('Μη έγκυρο μέγεθος container');
      }
      return header;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  /// Κρυπτογραφεί το [source] σε [destPath] (AES-256-GCM, chunked).
  /// Επιστρέφει το μέγεθος του τελικού αρχείου σε bytes.
  static Future<int> encryptFileTo({
    required File source,
    required String destPath,
    required String passphrase,
    int iterations = BackupKdf.defaultIterations,
    int chunkSize = defaultChunkSize,
  }) async {
    if (passphrase.isEmpty) {
      throw const BackupKdfException('Κενός κωδικός');
    }
    if (chunkSize < minChunkSize || chunkSize > maxChunkSize) {
      throw const SnbFormatException('Μη έγκυρο μέγεθος chunk');
    }
    final plaintextLength = await source.length();
    final salt = BackupKdf.randomBytes(BackupKdf.saltLength);
    final noncePrefix = BackupKdf.randomBytes(noncePrefixLength);
    final header = SnbHeader(
      version: SnbHeader.currentVersion,
      kdf: SnbHeader.kdfPbkdf2HmacSha256,
      iterations: iterations,
      salt: salt,
      noncePrefix: noncePrefix,
      chunkSize: chunkSize,
      plaintextLength: plaintextLength,
    );
    final headerBytes = header.toBytes();
    final key = await BackupKdf.deriveKey(
      password: passphrase,
      salt: salt,
      iterations: iterations,
    );
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(key);

    final partial = File('$destPath.partial');
    RandomAccessFile? out;
    RandomAccessFile? input;
    try {
      out = await partial.open(mode: FileMode.writeOnly);
      await out.writeFrom(headerBytes);
      input = await source.open();
      var offset = 0;
      var index = 0;
      while (offset < plaintextLength) {
        final len = min(chunkSize, plaintextLength - offset);
        final chunk = await _readFully(input, len);
        final box = await algorithm.encrypt(
          chunk,
          secretKey: secretKey,
          nonce: _nonce(noncePrefix, index),
          aad: _aad(headerBytes, index),
        );
        await out.writeFrom(box.cipherText);
        await out.writeFrom(box.mac.bytes);
        offset += len;
        index++;
      }
      if (plaintextLength == 0) {
        // Ένα κενό chunk ώστε να επαληθεύεται το κλειδί πάντα.
        final box = await algorithm.encrypt(
          const <int>[],
          secretKey: secretKey,
          nonce: _nonce(noncePrefix, 0),
          aad: _aad(headerBytes, 0),
        );
        await out.writeFrom(box.mac.bytes);
      }
      await out.flush();
      await out.close();
      out = null;
      await input.close();
      input = null;

      final dest = File(destPath);
      if (await dest.exists()) await dest.delete();
      await partial.rename(destPath);
      final size = await dest.length();
      DebugConfig.db('BackupContainer.encrypt: plaintext=$plaintextLength '
          'snb=$size chunks=${header.chunkCount}');
      return size;
    } catch (e, stack) {
      DebugConfig.error('BackupContainer.encrypt', e, stack);
      try {
        await out?.close();
      } catch (_) {}
      try {
        await input?.close();
      } catch (_) {}
      try {
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Αποκρυπτογραφεί το [source] σε [destPath]. Επιστρέφει το μέγεθος.
  ///
  /// Λάθος κωδικός/αλλοίωση → [BackupAuthException]. Δομικό πρόβλημα →
  /// [SnbFormatException].
  static Future<int> decryptFileTo({
    required File source,
    required String destPath,
    required String passphrase,
    int maxPlaintextBytes = defaultMaxPlaintextBytes,
  }) async {
    if (passphrase.isEmpty) {
      throw const BackupAuthException('Απαιτείται κωδικός');
    }
    final header = await readHeader(source, maxPlaintextBytes: maxPlaintextBytes);
    final headerBytes = header.toBytes();
    final key = await BackupKdf.deriveKey(
      password: passphrase,
      salt: header.salt,
      iterations: header.iterations,
    );
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(key);

    final partial = File('$destPath.partial');
    RandomAccessFile? input;
    RandomAccessFile? out;
    try {
      input = await source.open();
      await input.setPosition(header.headerLength);
      out = await partial.open(mode: FileMode.writeOnly);
      var written = 0;
      for (var index = 0; index < header.chunkCount; index++) {
        final len = min(header.chunkSize, header.plaintextLength - written);
        final raw = await _readFully(input, len + macLength);
        final cipherText = Uint8List.sublistView(raw, 0, len);
        final macBytes = Uint8List.sublistView(raw, len, len + macLength);
        final List<int> clear;
        try {
          clear = await algorithm.decrypt(
            SecretBox(cipherText, nonce: _nonce(header.noncePrefix, index), mac: Mac(macBytes)),
            secretKey: secretKey,
            aad: _aad(headerBytes, index),
          );
        } on SecretBoxAuthenticationError {
          throw const BackupAuthException(
              'Λάθος κωδικός ή κατεστραμμένο αρχείο');
        }
        await out.writeFrom(clear);
        written += len;
      }
      await out.flush();
      await out.close();
      out = null;
      await input.close();
      input = null;

      if (written != header.plaintextLength) {
        throw const SnbFormatException('Ελλιπές περιεχόμενο container');
      }
      final dest = File(destPath);
      if (await dest.exists()) await dest.delete();
      await partial.rename(destPath);
      DebugConfig.db('BackupContainer.decrypt: plaintext=$written');
      return written;
    } catch (e) {
      // Καθαρισμός ΜΟΝΟ σε αποτυχία — ποτέ μισό plaintext με τελικό όνομα.
      try {
        await out?.close();
      } catch (_) {}
      try {
        await input?.close();
      } catch (_) {}
      try {
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
      if (e is BackupAuthException || e is SnbFormatException) rethrow;
      DebugConfig.warning('BackupContainer.decrypt failed: $e');
      rethrow;
    }
  }

  // ── internals ────────────────────────────────────────────────────

  static bool _hasBytes(List<int> actual, List<int> expected) {
    if (actual.length < expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }

  static Uint8List _nonce(Uint8List prefix, int index) {
    final nonce = Uint8List(nonceLength);
    nonce.setRange(0, prefix.length, prefix);
    ByteData.sublistView(nonce).setUint32(prefix.length, index, Endian.big);
    return nonce;
  }

  static Uint8List _aad(Uint8List headerBytes, int index) {
    final aad = Uint8List(headerBytes.length + 4);
    aad.setRange(0, headerBytes.length, headerBytes);
    ByteData.sublistView(aad)
        .setUint32(headerBytes.length, index, Endian.big);
    return aad;
  }

  /// Διαβάζει ακριβώς [length] bytes (ή πετά EOF).
  static Future<Uint8List> _readFully(RandomAccessFile file, int length) async {
    final out = Uint8List(length);
    var read = 0;
    while (read < length) {
      final chunk = await file.read(length - read);
      if (chunk.isEmpty) {
        throw const SnbFormatException('Απρόσμενο τέλος αρχείου');
      }
      out.setRange(read, read + chunk.length, chunk);
      read += chunk.length;
    }
    return out;
  }
}
