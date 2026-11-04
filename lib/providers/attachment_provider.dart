// lib/providers/attachment_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attachment.dart';
import 'db_provider.dart';

/// Συνημμένα ενός item — reactive (E09).
/// autoDispose: φεύγει από τη μνήμη όταν κλείσει το detail screen.
final attachmentsProvider =
StreamProvider.autoDispose.family<List<Attachment>, int>((ref, itemId) {
  return ref.watch(dbProvider).attachments.watchForItem(itemId);
});

/// Πλήθος συνημμένων ανά itemId — ένα watch για όλα τα cards (E09 badge).
final attachmentCountsProvider =
StreamProvider.autoDispose<Map<int, int>>((ref) {
  return ref.watch(dbProvider).attachments.watchCounts();
});