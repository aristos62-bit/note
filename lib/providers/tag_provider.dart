// lib/providers/tag_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../models/item.dart';
import 'db_provider.dart';
import 'workspace_provider.dart';
import '../core/utils/debug_config.dart';

// ─────────────────────────────────────────────────────────────────
// Tags
// ─────────────────────────────────────────────────────────────────

/// Όλα τα tags του active workspace (ταξινομημένα κατά χρήση)
final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  final db = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return [];
  return db.tags.getAll(wsId);
});

/// Tags ενός συγκεκριμένου item
final itemTagsProvider =
FutureProvider.family<List<Tag>, int>((ref, itemId) {
  final db = ref.watch(dbProvider);
  return db.tags.getForItem(itemId);
});

/// Items που έχουν ένα συγκεκριμένο tag
final itemsByTagProvider =
FutureProvider.family<List<Item>, int>((ref, tagId) {
  final db = ref.watch(dbProvider);
  return db.tags.getItemsWithTag(tagId);
});

// ─────────────────────────────────────────────────────────────────
// TagNotifier
// ─────────────────────────────────────────────────────────────────

class TagNotifier extends AsyncNotifier<List<Tag>> {
  @override
  Future<List<Tag>> build() async {
    final db = ref.watch(dbProvider);
    final wsId = ref.watch(activeWorkspaceIdProvider);
    if (wsId == null) return [];
    return db.tags.getAll(wsId);
  }

  Future<Tag?> createOrGet(String name, {String? color}) async {
    try {
      final wsId = ref.read(activeWorkspaceIdProvider);
      if (wsId == null) return null;
      final tag = await ref.read(dbProvider).tags.createOrGet(
        name,
        wsId,
        color: color,
      );
      ref.invalidateSelf();
      return tag;
    } catch (e, s) {
      DebugConfig.error('TagNotifier.createOrGet', e, s);
      return null;
    }
  }

  Future<void> addToItem(int itemId, int tagId) async {
    try {
      await ref.read(dbProvider).tags.addToItem(itemId, tagId);
      ref.invalidateSelf();
      // Ενημέρωσε και τα tags του item
      ref.invalidate(itemTagsProvider(itemId));
    } catch (e, s) {
      DebugConfig.error('TagNotifier.addToItem', e, s);
    }
  }

  Future<void> removeFromItem(int itemId, int tagId) async {
    try {
      await ref.read(dbProvider).tags.removeFromItem(itemId, tagId);
      ref.invalidateSelf();
      ref.invalidate(itemTagsProvider(itemId));
    } catch (e, s) {
      DebugConfig.error('TagNotifier.removeFromItem', e, s);
    }
  }
}

final tagNotifierProvider =
AsyncNotifierProvider<TagNotifier, List<Tag>>(TagNotifier.new);