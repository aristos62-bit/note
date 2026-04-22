import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart';
import '../models/tag.dart';
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
  // ref.read αντί ref.watch: δεν κάνει re-trigger σε κάθε stream event
  final items = await ref.read(itemsStreamProvider.future);
  final tasks = items.where((i) => i.type == ItemType.task).toList();

  final result = <TaskWithDetails>[];
  for (final task in tasks) {
    final properties = await ref.read(itemPropertiesProvider(task.id).future);
    final dueDate = properties
        .where((p) => p.key == 'due_date')
        .firstOrNull
        ?.dateValue;
    final tags = await ref.read(itemTagsProvider(task.id).future);
    result.add(TaskWithDetails(task: task, dueDate: dueDate, tags: tags));
  }
  return result;
});