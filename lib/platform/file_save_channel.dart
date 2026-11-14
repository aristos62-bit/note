// lib/platform/file_save_channel.dart
//
// S-307 (Δ3): πλατφορμικό κανάλι για αποθήκευση αρχείου μέσω SAF
// (`ACTION_CREATE_DOCUMENT`) χωρίς bytes μέσω του channel.
//
// Γιατί όχι `file_picker.saveFile`: στο Android απαιτεί ολόκληρο το αρχείο
// στη μνήμη (`bytes`), άρα δεν κλιμακώνει. Εδώ το αντιγράφημα γίνεται
// streaming στο Kotlin (`openOutputStream` + 1MB buffer).
//
// Μόνο Android — iOS/desktop χρησιμοποιούν τις υπάρχουσες ροές του service.
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/utils/debug_config.dart';
import '../services/backup/backup_progress.dart';

class FileSaveChannel {
  FileSaveChannel._();

  static const MethodChannel _channel = MethodChannel('super_note/files');

  /// Το native save υπάρχει μόνο στο Android (iOS εκτός scope — share_plus).
  static bool get isSupported => Platform.isAndroid;

  /// Ανοίγει το system picker και γράφει το [sourcePath] streaming.
  ///
  /// Επιστρέφει το uri του προορισμού ή null σε ακύρωση του χρήστη.
  /// Σε αποτυχία πετά [PlatformException] (ο caller μεταφράζει το μήνυμα).
  static Future<String?> saveDocument({
    required String sourcePath,
    required String fileName,
    BackupProgressCallback? onProgress,
  }) async {
    if (!isSupported) return null;
    if (onProgress != null) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'copyProgress') {
          final args = call.arguments;
          if (args is Map) {
            final done = args['done'];
            final total = args['total'];
            onProgress(BackupProgress(
              BackupPhase.copy,
              done is int ? done : 0,
              total is int ? total : 0,
            ));
          }
        }
      });
    }
    try {
      onProgress?.call(const BackupProgress(BackupPhase.copy, 0, 0));
      return await _channel.invokeMethod<String>('saveDocument', {
        'sourcePath': sourcePath,
        'fileName': fileName,
      });
    } finally {
      if (onProgress != null) {
        _channel.setMethodCallHandler(null);
      }
    }
  }

  /// Ελεύθερος χώρος σε bytes για ένα **πραγματικό** filesystem path.
  ///
  /// Επιστρέφει null όταν δεν είναι διαθέσιμος (desktop/αποτυχία) — οι
  /// callers τότε βασίζονται στο try/catch του write (S-307).
  static Future<int?> freeSpace(String path) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<int>('freeSpace', {'path': path});
    } catch (e) {
      DebugConfig.warning('FileSaveChannel.freeSpace failed: $e');
      return null;
    }
  }
}
