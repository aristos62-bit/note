// lib/providers/db_provider.dart
//
// Το κεντρικό provider που δίνει πρόσβαση στον SuperNoteHelper.
// Όλα τα άλλα providers εξαρτώνται από αυτό.
//
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../helpers/super_note_helper.dart';

/// Παρέχει το SuperNoteHelper instance σε όλη την εφαρμογή.
/// Πρέπει να έχει κληθεί SuperNoteHelper.init() πριν χρησιμοποιηθεί.
final dbProvider = Provider<SuperNoteHelper>((ref) {
  return SuperNoteHelper.instance;
});