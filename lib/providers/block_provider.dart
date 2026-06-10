// lib/providers/block_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/debug_config.dart';
import '../models/item_block.dart';
import 'db_provider.dart';

// ─────────────────────────────────────────────────────────────────
// Blocks ενός item — reactive με Stream
// ─────────────────────────────────────────────────────────────────

/// Stream blocks ενός item — ενημερώνεται αυτόματα όταν αλλάξει κάτι
/// Χρησιμοποίησε αυτό στον editor για real-time updates
final blocksStreamProvider =
StreamProvider.family<List<ItemBlock>, int>((ref, itemId) {
  final db = ref.watch(dbProvider);
  return db.blocks.watchByItem(itemId);
});

/// Future blocks — για αρχικό load
final blocksProvider =
FutureProvider.family<List<ItemBlock>, int>((ref, itemId) {
  final db = ref.watch(dbProvider);
  return db.blocks.getByItem(itemId);
});

/// Children blocks (για toggle/nested blocks)
final childBlocksProvider =
FutureProvider.family<List<ItemBlock>, int>((ref, parentBlockId) {
  final db = ref.watch(dbProvider);
  return db.blocks.getChildren(parentBlockId);
});

// ─────────────────────────────────────────────────────────────────
// BlockNotifier — CRUD για blocks ενός item
// ─────────────────────────────────────────────────────────────────

class BlockNotifier extends FamilyAsyncNotifier<List<ItemBlock>, int> {
  @override
  Future<List<ItemBlock>> build(int arg) {
    return ref.watch(dbProvider).blocks.getByItem(arg);
  }

  Future<void> addBlock({
    required BlockType type,
    String? text,
    String? url,
    String? filePath,
    String? metadata,
    int? parentBlockId,
  }) async {
    try {
      await ref.read(dbProvider).blocks.create(
        itemId: arg,
        type: type,
        text: text,
        url: url,
        filePath: filePath,
        metadata: metadata,
        parentBlockId: parentBlockId,
      );
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('BlockNotifier.addBlock', e, s);
    }
  }

  Future<void> updateText(int blockId, String text) async {
    try {
      await ref.read(dbProvider).blocks.updateText(blockId, text);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('BlockNotifier.updateText', e, s);
    }
  }

  Future<void> toggleCheck(int blockId) async {
    try {
      await ref.read(dbProvider).blocks.toggleCheck(blockId);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('BlockNotifier.toggleCheck', e, s);
    }
  }

  Future<void> delete(int blockId) async {
    try {
      await ref.read(dbProvider).blocks.delete(blockId);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('BlockNotifier.delete', e, s);
    }
  }

  Future<void> reorder(List<ItemBlock> blocks) async {
    try {
      await ref.read(dbProvider).blocks.reorder(blocks);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('BlockNotifier.reorder', e, s);
    }
  }
}

final blockNotifierProvider =
AsyncNotifierProviderFamily<BlockNotifier, List<ItemBlock>, int>(
  BlockNotifier.new,
);