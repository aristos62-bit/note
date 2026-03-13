// lib/providers/folder_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import 'db_provider.dart';
import 'workspace_provider.dart';

// ─────────────────────────────────────────────────────────────────
// Folders του active workspace
// ─────────────────────────────────────────────────────────────────

/// Φέρνει τα root folders (χωρίς parent) του active workspace
final foldersProvider = FutureProvider<List<Folder>>((ref) async {
  final db = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return [];
  return db.folders.getByWorkspace(wsId);
});

/// Φέρνει τα sub-folders ενός συγκεκριμένου folder
final subFoldersProvider =
FutureProvider.family<List<Folder>, int>((ref, parentId) async {
  final db = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return [];
  return db.folders.getByWorkspace(wsId, parentId: parentId);
});

/// Notifier για CRUD operations
class FolderNotifier extends AsyncNotifier<List<Folder>> {
  @override
  Future<List<Folder>> build() async {
    final db = ref.watch(dbProvider);
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
      name: name,
      workspaceId: wsId,
      icon: icon,
      color: color,
      parentFolderId: parentFolderId,
    );
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await ref.read(dbProvider).folders.delete(id);
    ref.invalidateSelf();
  }
}

final folderNotifierProvider =
AsyncNotifierProvider<FolderNotifier, List<Folder>>(FolderNotifier.new);