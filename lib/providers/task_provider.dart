import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'providers.dart';
import 'dart:async';

/// Επεκτείνει ένα Item με dueDate και tags
class TaskWithDetails {
  final Item task;
  final DateTime? dueDate;
  final List<Tag> tags;
  final int? parentId; // ← ΝΕΟ: αποφεύγουμε ref.read(itemPropertiesProvider) στο build

  TaskWithDetails({
    required this.task,
    required this.dueDate,
    required this.tags,
    this.parentId, // ← ΝΕΟ
  });
}

/// Ανεξάρτητο stream μόνο για tasks — ΔΕΝ derive από itemsStreamProvider
final tasksStreamProvider = StreamProvider<List<Item>>((ref) {
  final db = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  final showArchived = ref.watch(showArchivedProvider);
  if (wsId == null) return Stream.value(const []);
  return db.items.watchByWorkspace(
    wsId,
    type: ItemType.task,
    includeArchived: showArchived,
  );
});

/// ✅ Real-time stream με TaskWithDetails.
/// Αντικατέστησε το FutureProvider που χρησιμοποιούσε ref.read (non-reactive).
/// Τώρα χρησιμοποιεί ref.watch(itemsStreamProvider) για αυτόματη ανανέωση.
final tasksWithDetailsProvider = StreamProvider<List<TaskWithDetails>>((ref) async* {
  yield* ref.watch(tasksStreamProvider).when(
    data: (tasks) async* {

      // Future.wait: όλα τα tasks φορτώνονται παράλληλα
      final result = await Future.wait(
        tasks.map((task) async {
          final results = await Future.wait([
            ref.read(itemPropertiesProvider(task.id).future),
            ref.read(itemTagsProvider(task.id).future),
          ]);
          final properties = results[0] as List<ItemProperty>;
          final tags       = results[1] as List<Tag>;
          final dueDate    = properties
              .where((p) => p.key == 'due_date')
              .firstOrNull
              ?.dateValue;
          // ✅ Εξαγωγή parentId — μηδέν extra DB query, τα properties φορτώθηκαν ήδη
          final parentIdStr = properties
              .where((p) => p.key == 'parent_id')
              .firstOrNull
              ?.value;
          final parentId = parentIdStr != null ? int.tryParse(parentIdStr) : null;
          return TaskWithDetails(task: task, dueDate: dueDate, tags: tags, parentId: parentId);
        }),
      );
      yield result;
    },
    loading: () async* {},
    error:   (_, __) async* {},
  );
});

/// ✅ Stream υποεργασιών ενός task — real-time reactive.
/// Χρησιμοποιεί ref.listen αντί του deprecated .stream.
/// Σταθερή σειρά εισαγωγής μέσω sort by id.
final subtasksStreamProvider =
StreamProvider.family<List<Item>, int>((ref, parentId) {
  final controller = StreamController<List<Item>>();

  Future<void> refresh() async {
    final tasks = ref.read(tasksStreamProvider).valueOrNull ?? [];
    final result = <Item>[];
    for (final task in tasks) {
      final props = await ref.read(itemPropertiesProvider(task.id).future);
      final pid = props
          .where((p) => p.key == 'parent_id')
          .firstOrNull
          ?.value;
      if (pid != null && int.tryParse(pid) == parentId) {
        result.add(task);
      }
    }
    result.sort((a, b) => a.id.compareTo(b.id));
    if (!controller.isClosed) controller.add(result);
  }

  ref.listen<AsyncValue<List<Item>>>(
    tasksStreamProvider,
        (_, next) { if (next.hasValue) refresh(); },
    fireImmediately: true,
  );

  ref.onDispose(() => controller.close());
  return controller.stream;
});