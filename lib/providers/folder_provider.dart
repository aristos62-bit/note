import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import 'db_provider.dart';
import 'workspace_provider.dart';
import '../core/utils/debug_config.dart';

/// Root folders (χωρίς parent) του active workspace – real-time
final foldersStreamProvider = StreamProvider<List<Folder>>((ref) {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return Stream.value(const []);
  DebugConfig.db('📁 foldersStreamProvider: wsId=$wsId');
  return db.folders.watchByWorkspace(wsId);
});

final subFoldersStreamProvider =
StreamProvider.family<List<Folder>, int>((ref, parentId) {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return Stream.value(const []);
  return db.folders.watchByWorkspace(wsId, parentId: parentId);
});

/// Αν χρειαστεί one-shot Future<List<Folder>>
final foldersProvider = FutureProvider<List<Folder>>((ref) async {
  final asyncValue = ref.watch(foldersStreamProvider);
  if (asyncValue.hasValue) return asyncValue.value!;
  return await ref.watch(foldersStreamProvider.future);
});

/// Real-time stream ενός folder by ID
final folderByIdProvider =
    StreamProvider.family<Folder?, int>((ref, id) {
  final db = ref.watch(dbProvider);
  return db.folders.watchById(id);
});

// ─── 🆕 ΚΕΝΤΡΙΚΟ PROVIDER ΓΙΑ ΤΟ ΕΠΙΛΕΓΜΕΝΟ FOLDER ──────────────────
/// Το id του φακέλου που έχει επιλέξει ο χρήστης ή έχει προεπιλεγεί.
/// Όλες οι οθόνες και ο DraggableFolderSelector διαβάζουν από εδώ.
final selectedFolderIdProvider = StateProvider<int?>((ref) => null);

// ─────────────────────────────────────────────────────────────────────

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
    try {
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
    } catch (e, s) {
      DebugConfig.error('FolderNotifier.create', e, s);
    }
  }

  Future<void> delete(int id) async {
    final db = ref.read(dbProvider);
    final folder = await db.folders.getById(id);
    if (folder == null) return;

    // Απαγόρευση διαγραφής system folder
    if (folder.isSystem) {
      throw Exception('Ο φάκελος "${folder.name}" είναι σύστημα και δεν μπορεί να διαγραφεί.');
    }

    // Έλεγχος αν υπάρχουν items μέσα
    final itemsInFolder = await db.items.getByFolder(id);
    if (itemsInFolder.isNotEmpty) {
      throw Exception('Ο φάκελος "${folder.name}" περιέχει ${itemsInFolder.length} στοιχεία. Μετακινήστε ή διαγράψτε τα πρώτα.');
    }

    // Έλεγχος αν υπάρχουν υποφάκελοι
    final subFolders = await db.folders.getByWorkspace(
      folder.workspaceId,
      parentId: id,
    );
    if (subFolders.isNotEmpty) {
      throw Exception('Ο φάκελος "${folder.name}" περιέχει ${subFolders.length} υποφακέλους. Διαγράψτε τους πρώτα.');
    }

    // Δεν έχει περιεχόμενο – προχώρα στη διαγραφή
    try {
      await db.folders.delete(id);
      ref.invalidateSelf();
      ref.invalidate(foldersStreamProvider);
      ref.invalidate(foldersProvider);
    } catch (e, s) {
      DebugConfig.error('FolderNotifier.delete', e, s);
    }
  }

  /// Αναδιάταξη φακέλων (drag & drop)
  Future<void> reorderFolders(List<Folder> newOrder) async {
    try {
      await ref.read(dbProvider).folders.reorder(newOrder);
      ref.invalidateSelf();
      ref.invalidate(foldersStreamProvider);
      ref.invalidate(foldersProvider);
    } catch (e, s) {
      DebugConfig.error('FolderNotifier.reorderFolders', e, s);
    }
  }

  Future<void> rename(int id, {
    String? name,
    String? icon,
    String? color,
  }) async {
    try {
      await ref.read(dbProvider).folders.update(
        id,
        name:  name,
        icon:  icon,
        color: color,
      );
      ref.invalidateSelf();
      ref.invalidate(foldersStreamProvider);
      ref.invalidate(foldersProvider);
    } catch (e, s) {
      DebugConfig.error('FolderNotifier.rename', e, s);
    }
  }
}

final folderNotifierProvider =
AsyncNotifierProvider<FolderNotifier, List<Folder>>(FolderNotifier.new);