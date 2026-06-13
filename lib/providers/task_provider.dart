import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'providers.dart';
import '../core/utils/debug_config.dart';

/// Επεκτείνει ένα Item με dueDate, tags, parentId και subtasks
class TaskWithDetails {
  final Item task;
  final DateTime? dueDate;
  final List<Tag> tags;
  final int? parentId;
  final List<Item> subtasks; // ✅ ΝΕΟ — μηδέν ref.watch στο _TaskCard

  TaskWithDetails({
    required this.task,
    required this.dueDate,
    required this.tags,
    this.parentId,
    this.subtasks = const [],
  });
}

/// Ανεξάρτητο stream μόνο για tasks
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

/// ✅ Real-time stream με TaskWithDetails + subtasks.
/// Ένα μόνο Future.wait — μηδέν cascade rebuilds.
final tasksWithDetailsProvider = StreamProvider<List<TaskWithDetails>>((ref) async* {
  yield* ref.watch(tasksStreamProvider).when(
    data: (tasks) async* {
      // ✅ Batch load: 2 DB calls συνολικά αντί για 2×N
      final taskIds = tasks.map((t) => t.id).toList();
      final db = ref.watch(dbProvider);
      final batchResults = await Future.wait([
        db.properties.getAllForItems(taskIds),
        db.tags.getAllForItems(taskIds),
      ]);
      final propsMap = batchResults[0] as Map<int, List<ItemProperty>>;
      final tagsMap  = batchResults[1] as Map<int, List<Tag>>;

      // Πρώτο pass: σύνθεση από cache — μηδέν επιπλέον DB calls
      final result = tasks.map((task) {
        final properties = propsMap[task.id] ?? [];
        final tags       = tagsMap[task.id] ?? [];
        final dueDate    = properties
            .where((p) => p.key == 'due_date')
            .firstOrNull
            ?.dateValue;
        final parentIdStr = properties
            .where((p) => p.key == 'parent_id')
            .firstOrNull
            ?.value;
        final parentId = parentIdStr != null ? int.tryParse(parentIdStr) : null;
        return TaskWithDetails(
          task: task,
          dueDate: dueDate,
          tags: tags,
          parentId: parentId,
        );
      }).toList();

      // ✅ Δεύτερο pass: subtasks από cache — μηδέν DB queries
      final withSubtasks = result.map((td) {
        if (td.parentId != null) return td; // subtask δεν έχει δικά του subtasks
        final subs = result
            .where((other) => other.parentId == td.task.id)
            .map((other) => other.task)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
        return TaskWithDetails(
          task: td.task,
          dueDate: td.dueDate,
          tags: td.tags,
          parentId: td.parentId,
          subtasks: subs,
        );
      }).toList();

      yield withSubtasks;
    },
    loading: () async* {},
    error: (e, s) async* {
      DebugConfig.error('tasksWithDetailsProvider.stream', e, s);
    },
  );
});

/// Subtasks για χρήση στο task_detail_screen — παράγεται από cache
final subtasksStreamProvider =
StreamProvider.family<List<Item>, int>((ref, parentId) async* {
  yield* ref.watch(tasksWithDetailsProvider).when(
    data: (allTasks) async* {
      final td = allTasks.where((t) => t.task.id == parentId).firstOrNull;
      yield td?.subtasks ?? [];
    },
    loading: () async* {},
    error: (e, s) async* {
      DebugConfig.error('tasksWithDetailsProvider.stream', e, s);
    },
  );
});