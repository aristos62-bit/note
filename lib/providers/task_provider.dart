import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'providers.dart';
import 'dart:async';

/// Επεκτείνει ένα Item με dueDate και tags
class TaskWithDetails {
  final Item task;
  final DateTime? dueDate;
  final List<Tag> tags;

  TaskWithDetails({
    required this.task,
    required this.dueDate,
    required this.tags,
  });
}

/// ✅ Real-time stream με TaskWithDetails.
/// Αντικατέστησε το FutureProvider που χρησιμοποιούσε ref.read (non-reactive).
/// Τώρα χρησιμοποιεί ref.watch(itemsStreamProvider) για αυτόματη ανανέωση.
final tasksWithDetailsProvider = StreamProvider<List<TaskWithDetails>>((ref) async* {
  yield* ref.watch(itemsStreamProvider).when(
    data: (items) async* {
      final tasks = items.where((i) => i.type == ItemType.task).toList();

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
          return TaskWithDetails(task: task, dueDate: dueDate, tags: tags);
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
  // ignore: close_sinks — κλείνει στο onDispose
  final controller = StreamController<List<Item>>();

  Future<void> refresh() async {
    final allItems = ref.read(itemsStreamProvider).valueOrNull ?? [];
    final result   = <Item>[];
    for (final item in allItems) {
      if (item.type != ItemType.task) continue;
      final props = await ref.read(itemPropertiesProvider(item.id).future);
      final pid   = props
          .where((p) => p.key == 'parent_id')
          .firstOrNull
          ?.value;
      if (pid != null && int.tryParse(pid) == parentId) {
        result.add(item);
      }
    }
    // Σταθερή σειρά εισαγωγής βάσει auto-increment id
    result.sort((a, b) => a.id.compareTo(b.id));
    if (!controller.isClosed) controller.add(result);
  }

  // Αντικατάσταση deprecated .stream — χρησιμοποιούμε ref.listen
  ref.listen<AsyncValue<List<Item>>>(
    itemsStreamProvider,
        (_, next) { if (next.hasValue) refresh(); },
    fireImmediately: true,
  );

  ref.onDispose(() => controller.close());
  return controller.stream;
});