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

/// Notifier για CRUD operations σε folders
class FolderNotifier extends AsyncNotifier<List<Folder>> {
  @override
  Future<List<Folder>> build() async {
    final db   = ref.watch(dbProvider);
    final wsId = ref.watch(activeWorkspaceIdProvider);
    if (wsId == null) return [];
    return db.folders.getByWorkspace(wsId);
  }

  Future<void> create(
      String name, {
        String? icon,
        String? color,
        int? parentFolderId,
      }) async {
    final wsId = ref.read(activeWorkspaceIdProvider);
    if (wsId == null) return;
    await ref.read(dbProvider).folders.create(
      name:            name,
      workspaceId:     wsId,
      icon:            icon,
      color:           color,
      parentFolderId:  parentFolderId,
    );
    ref.invalidateSelf();
    ref.invalidate(foldersStreamProvider);
    ref.invalidate(foldersProvider);
  }

  Future<void> delete(int id) async {
    await ref.read(dbProvider).folders.delete(id);
    ref.invalidateSelf();
    ref.invalidate(foldersStreamProvider);
    ref.invalidate(foldersProvider);
  }

  Future<void> rename(int id, {
    String? name,
    String? icon,
    String? color,
  }) async {
    await ref.read(dbProvider).folders.update(
      id,
      name:  name,
      icon:  icon,
      color: color,
    );
    ref.invalidateSelf();
    ref.invalidate(foldersStreamProvider);
    ref.invalidate(foldersProvider);
  }
}

final folderNotifierProvider =
AsyncNotifierProvider<FolderNotifier, List<Folder>>(FolderNotifier.new);