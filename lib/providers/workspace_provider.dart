// lib/providers/workspace_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workspace.dart';
import 'db_provider.dart';
import '../core/utils/debug_config.dart';

// ─────────────────────────────────────────────────────────────────
// Λίστα όλων των workspaces
// ─────────────────────────────────────────────────────────────────

/// Φέρνει όλα τα workspaces (ταξινομημένα κατά sortOrder)
final workspacesProvider = FutureProvider<List<Workspace>>((ref) {
  final db = ref.watch(dbProvider);
  return db.workspaces.getAll();
});

/// Φέρνει το default workspace
final defaultWorkspaceProvider = FutureProvider<Workspace?>((ref) {
  final db = ref.watch(dbProvider);
  return db.workspaces.getDefault();
});

/// Το τρέχον επιλεγμένο workspace ID.
/// Αρχικά null — γίνεται set από το app startup (βλ. main.dart ή app.dart).
///
/// ΣΗΜΑΝΤΙΚΟ: Δεν βάζουμε ref.listen εδώ γιατί δημιουργεί circular dependency.
/// Η αρχικοποίηση γίνεται χειροκίνητα στο startup:
///
///   final ws = await ref.read(defaultWorkspaceProvider.future);
///   ref.read(activeWorkspaceIdProvider.notifier).state = ws?.id;
///
final activeWorkspaceIdProvider = StateProvider<int?>((ref) => null);

/// Notifier για CRUD operations
class WorkspaceNotifier extends AsyncNotifier<List<Workspace>> {
  @override
  Future<List<Workspace>> build() {
    return ref.watch(dbProvider).workspaces.getAll();
  }

  Future<void> create(String name, {String? icon, String? color}) async {
    try {
      await ref.read(dbProvider).workspaces.create(
        name: name,
        icon: icon,
        color: color,
      );
      ref.invalidateSelf(); // Refresh λίστα
    } catch (e, s) {
      DebugConfig.error('WorkspaceNotifier.create', e, s);
    }
  }
}

final workspaceNotifierProvider =
AsyncNotifierProvider<WorkspaceNotifier, List<Workspace>>(
  WorkspaceNotifier.new,
);