// lib/services/backup/backup_container.dart
//
// S-02 / S-307: container αντιγράφου ασφαλείας (.snb).
//
// Δομή:
//   header (v1 = 48 bytes, v2 = 49/65 bytes)  ← AAD για ΟΛΑ τα chunks
//   chunk_0 ciphertext || tag
//   chunk_1 ciphertext || tag
//   ...
//
// Σχεδιαστικές αποφάσεις:
//  • AES-256-GCM (AesGcm.with256bits του `cryptography`) — ΠΑΝΤΑ. Το container
//    δεν είναι ποτέ plaintext, ανεξάρτητα από τον τρόπο κλειδιού.
//  • STREAM construction: nonce = 8-byte τυχαίο prefix + 4-byte BE counter.
//  • AAD ανά chunk = header bytes ‖ 4-byte BE index. Το `plaintextLength`
//    βρίσκεται ΜΕΣΑ στο header → truncation/reordering ανιχνεύονται.
//  • Γράφουμε ΠΑΝΤΑ σε `<dest>.partial` και κάνουμε rename → ποτέ μισό
//    αρχείο με το τελικό όνομα.
//
// S-307 (Δ1): δύο τρόποι κλειδιού (`keyMode`):
//  • `embedded` (νέο default): 32 τυχαία bytes ΜΕΣΑ στο header. Μηδέν κωδικός
//    χρήστη, μηδέν PBKDF2. Το αρχείο παραμένει ακέραιο/anti-tamper (GCM),
//    αλλά δεν είναι εμπιστευτικό απέναντι σε όποιον το κατέχει (εγκεκριμένο).
//  • `pbkdf2` (legacy v1 + προαιρετικό «Κλείδωμα αντιγράφου»): κλειδί =
//    PBKDF2-HMAC-SHA256(κωδικός, salt, iterations).
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../../core/crypto/kdf.dart';
import '../../core/utils/debug_config.dart';
import 'backup_progress.dart';

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

/// Header του `.snb` (v1 legacy + v2 με `keyMode`).
class SnbHeader {
  static const List<int> magic = <int>[0x53, 0x4E, 0x42, 0x4B]; // 'SNBK'

  /// Τρέχουσα έκδοση που γράφουμε.
  static const int currentVersion = 2;

  /// Έκδοση που διαβάζουμε για συμβατότητα (πάντα PBKDF2).
  static const int legacyVersion = 1;

  /// Μέθοδοι κλειδιού (`keyMode`).
  static const int keyModePbkdf2 = 1;
  static const int keyModeEmbedded = 2;

  static const int maxHeaderRead = 128;

  /// Ελάχιστο λογικό μέγεθος αρχείου (magic + version + keyMode + ...).
  static const int minFileLength = 32;

  final int version;
  final int keyMode;

  /// Επαναλήψεις PBKDF2 (0 για embedded).
  final int iterations;

  /// Salt PBKDF2 (άδειο για embedded).
  final Uint8List salt;

  /// Κλειδί 32 bytes για embedded (null για PBKDF2).
  final Uint8List? embeddedKey;

  final Uint8List noncePrefix;
  final int chunkSize;
  final int plaintextLength;

  const SnbHeader({
    required this.version,
    required this.keyMode,
    required this.iterations,
    required this.salt,
    required this.embeddedKey,
    required this.noncePrefix,
    required this.chunkSize,
    required this.plaintextLength,
  });

  /// true όταν απαιτείται κωδικός χρήστη για το κλειδί.
  bool get requiresPassphrase => keyMode == keyModePbkdf2;

  int get headerLength =>
      4 + // magic
      1 + // version
      1 + // keyMode
      4 + // iterations
      1 + salt.length +
      // Το v1 ΔΕΝ είχε key-length byte (μόνο το v2).
      (version >= currentVersion ? 1 + (embeddedKey?.length ?? 0) : 0) +
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
    final keyBytes = embeddedKey ?? const <int>[];
    final out = Uint8List(headerLength);
    final data = ByteData.sublistView(out);
    var o = 0;
    out.setRange(o, o + 4, magic);
    o += 4;
    out[o++] = version;
    out[o++] = keyMode;
    data.setUint32(o, iterations, Endian.big);
    o += 4;
    out[o++] = salt.length;
    out.setRange(o, o + salt.length, salt);
    o += salt.length;
    if (version >= currentVersion) {
      out[o++] = keyBytes.length;
      out.setRange(o, o + keyBytes.length, keyBytes);
      o += keyBytes.length;
    }
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
    if (version != legacyVersion && version != currentVersion) {
      throw SnbFormatException('Μη υποστηριζόμενη έκδοση container: $version');
    }

    final keyMode = bytes[need(1)];
    o += 1;
    if (keyMode != keyModePbkdf2 && keyMode != keyModeEmbedded) {
      throw SnbFormatException('Μη υποστηριζόμενη μέθοδος κλειδιού: $keyMode');
    }
    // Το v1 είχε ΠΑΝΤΑ PBKDF2 (το πεδίο λεγόταν `kdf`).
    if (version == legacyVersion && keyMode != keyModePbkdf2) {
      throw const SnbFormatException('Μη έγκυρη μέθοδος κλειδιού για v1');
    }

    final iterations = data.getUint32(need(4), Endian.big);
    o += 4;
    if (keyMode == keyModePbkdf2 &&
        !BackupKdf.isValidIterations(iterations)) {
      throw const SnbFormatException('Μη έγκυρες επαναλήψεις PBKDF2');
    }

    final saltLength = bytes[need(1)];
    o += 1;
    if (keyMode == keyModePbkdf2) {
      if (saltLength < 8 || saltLength > 64) {
        throw const SnbFormatException('Μη έγκυρο μήκος salt');
      }
    } else if (saltLength != 0) {
      throw const SnbFormatException('Μη έγκυρο salt για ενσωματωμένο κλειδί');
    }
    need(saltLength);
    final salt = Uint8List.fromList(bytes.sublist(o, o + saltLength));
    o += saltLength;

    Uint8List? embeddedKey;
    if (version >= currentVersion) {
      final keyLength = bytes[need(1)];
      o += 1;
      if (keyMode == keyModeEmbedded) {
        if (keyLength != BackupKdf.keyLengthBytes) {
          throw const SnbFormatException('Μη έγκυρο μήκος κλειδιού');
        }
      } else if (keyLength != 0) {
        throw const SnbFormatException('Μη έγκυρο μήκος κλειδιού');
      }
      need(keyLength);
      if (keyLength > 0) {
        embeddedKey = Uint8List.fromList(bytes.sublist(o, o + keyLength));
      }
      o += keyLength;
    }

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
      keyMode: keyMode,
      iterations: iterations,
      salt: salt,
      embeddedKey: embeddedKey,
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

  /// S-307 (Δ4): 256 KiB — μικρότερο chunk = ομαλότερη πρόοδος/απόκριση.
  static const int defaultChunkSize = 256 * 1024;
  static const int minChunkSize = 4 * 1024;
  static const int maxChunkSize = 8 * 1024 * 1024;

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
  ///
  /// S-307: χωρίς όριο plaintext — το μέγεθος ακολουθεί τη βάση.
  static Future<SnbHeader> readHeader(File file) async {
    final length = await file.length();
    if (length < SnbHeader.minFileLength) {
      throw const SnbFormatException('Πολύ μικρό αρχείο container');
    }
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final raw = await raf.read(SnbHeader.maxHeaderRead);
      final header = SnbHeader.parse(raw);
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

  /// true όταν το `.snb` απαιτεί κωδικό (legacy v1 ή «Κλείδωμα αντιγράφου»).
  static Future<bool> requiresPassphrase(String path) async {
    final header = await readHeader(File(path));
    return header.requiresPassphrase;
  }

  /// Κρυπτογραφεί το [source] σε [destPath] (AES-256-GCM, chunked).
  ///
  /// [passphrase] null/κενό → ενσωματωμένο τυχαίο κλειδί στο header (Δ1).
  /// Επιστρέφει το μέγεθος του τελικού αρχείου σε bytes.
  static Future<int> encryptFileTo({
    required File source,
    required String destPath,
    String? passphrase,
    int iterations = BackupKdf.defaultIterations,
    int chunkSize = defaultChunkSize,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (chunkSize < minChunkSize || chunkSize > maxChunkSize) {
      throw const SnbFormatException('Μη έγκυρο μέγεθος chunk');
    }
    final useEmbedded = passphrase == null || passphrase.isEmpty;
    final plaintextLength = await source.length();
    final salt = useEmbedded
        ? Uint8List(0)
        : BackupKdf.randomBytes(BackupKdf.saltLength);
    final embeddedKey =
        useEmbedded ? BackupKdf.randomBytes(BackupKdf.keyLengthBytes) : null;
    final noncePrefix = BackupKdf.randomBytes(noncePrefixLength);
    final header = SnbHeader(
      version: SnbHeader.currentVersion,
      keyMode:
          useEmbedded ? SnbHeader.keyModeEmbedded : SnbHeader.keyModePbkdf2,
      iterations: useEmbedded ? 0 : iterations,
      salt: salt,
      embeddedKey: embeddedKey,
      noncePrefix: noncePrefix,
      chunkSize: chunkSize,
      plaintextLength: plaintextLength,
    );
    final headerBytes = header.toBytes();
    final key = useEmbedded
        ? embeddedKey!
        : await BackupKdf.deriveKey(
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
      onProgress?.call(BackupProgress(BackupPhase.encrypt, 0, plaintextLength));
      while (offset < plaintextLength) {
        if (isCancelled?.call() ?? false) {
          throw const BackupCancelledException();
        }
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
        onProgress
            ?.call(BackupProgress(BackupPhase.encrypt, offset, plaintextLength));
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
      DebugConfig.db('BackupContainer.encrypt: mode=${header.keyMode} '
          'plaintext=$plaintextLength snb=$size chunks=${header.chunkCount}');
      return size;
    } catch (e, stack) {
      if (e is! BackupCancelledException) {
        DebugConfig.error('BackupContainer.encrypt', e, stack);
      }
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
  /// [SnbFormatException]. Ακύρωση → [BackupCancelledException].
  static Future<int> decryptFileTo({
    required File source,
    required String destPath,
    String? passphrase,
    BackupProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final header = await readHeader(source);
    final Uint8List key;
    if (header.requiresPassphrase) {
      if (passphrase == null || passphrase.isEmpty) {
        throw const BackupAuthException('Απαιτείται κωδικός');
      }
      key = await BackupKdf.deriveKey(
        password: passphrase,
        salt: header.salt,
        iterations: header.iterations,
      );
    } else {
      key = header.embeddedKey!;
    }
    final headerBytes = header.toBytes();
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
      onProgress
          ?.call(BackupProgress(BackupPhase.decrypt, 0, header.plaintextLength));
      for (var index = 0; index < header.chunkCount; index++) {
        if (isCancelled?.call() ?? false) {
          throw const BackupCancelledException();
        }
        final len = min(header.chunkSize, header.plaintextLength - written);
        final raw = await _readFully(input, len + macLength);
        final cipherText = Uint8List.sublistView(raw, 0, len);
        final macBytes = Uint8List.sublistView(raw, len, len + macLength);
        final List<int> clear;
        try {
          clear = await algorithm.decrypt(
            SecretBox(cipherText,
                nonce: _nonce(header.noncePrefix, index), mac: Mac(macBytes)),
            secretKey: secretKey,
            aad: _aad(headerBytes, index),
          );
        } on SecretBoxAuthenticationError {
          throw const BackupAuthException(
              'Λάθος κωδικός ή κατεστραμμένο αρχείο');
        }
        await out.writeFrom(clear);
        written += len;
        onProgress?.call(
            BackupProgress(BackupPhase.decrypt, written, header.plaintextLength));
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
      if (e is BackupAuthException ||
          e is SnbFormatException ||
          e is BackupCancelledException) {
        rethrow;
      }
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
