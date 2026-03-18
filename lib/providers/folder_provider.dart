import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import 'db_provider.dart';
import 'workspace_provider.dart';

/// Root folders (χωρίς parent) του active workspace – real-time
final foldersStreamProvider = StreamProvider<List<Folder>>((ref) async* {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);

  if (wsId == null) {
    yield const [];
    return;
  }

  // 1) Αρχικό snapshot
  final initial = await db.folders.getByWorkspace(wsId);
  yield initial;

  // 2) Reactive updates από Isar
  final changes = db.folders.watchAll();

  yield* changes.asyncMap((_) {
    return db.folders.getByWorkspace(wsId);
  });
});

/// Sub-folders ενός parent – real-time
final subFoldersStreamProvider =
StreamProvider.family<List<Folder>, int>((ref, parentId) async* {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);

  if (wsId == null) {
    yield const [];
    return;
  }

  final initial = await db.folders.getByWorkspace(
    wsId,
    parentId: parentId,
  );
  yield initial;

  final changes = db.folders.watchAll();

  yield* changes.asyncMap((_) {
    return db.folders.getByWorkspace(
      wsId,
      parentId: parentId,
    );
  });
});

/// Αν χρειαστεί one-shot Future<List<Folder>>
final foldersProvider = FutureProvider<List<Folder>>((ref) async {
  final asyncValue = ref.watch(foldersStreamProvider);
  if (asyncValue.hasValue) return asyncValue.value!;
  return await ref.watch(foldersStreamProvider.future);
});
