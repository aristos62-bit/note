import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'providers.dart';

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

/// Provider που φορτώνει όλες τις εργασίες μαζί με dueDate και tags.
/// Χρησιμοποιεί ref.read για να μην ξαναφορτώνει σε κάθε stream event.
/// Invalidate γίνεται χειροκίνητα από το task_list_screen.
final tasksWithDetailsProvider = FutureProvider<List<TaskWithDetails>>((ref) async {
  final items = await ref.read(itemsStreamProvider.future);
  final tasks = items.where((i) => i.type == ItemType.task).toList();

  // Future.wait: όλα τα tasks φορτώνονται παράλληλα
  // Εντός κάθε task, properties και tags επίσης παράλληλα
  return Future.wait(
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
});