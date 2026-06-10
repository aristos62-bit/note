// lib/providers/property_provider.dart
//
// Providers για ItemProperty — EAV properties κάθε item.
// Χρησιμοποιείται κυρίως για:
//   task:     due_date, start_date, estimated_hours
//   event:    start_time, end_time, location
//   habit:    streak, frequency
//   finance:  amount, category
//   contact:  phone, email, birthday
//
// ΧΡΗΣΗ:
//   // Διάβασμα
//   final props = ref.watch(itemPropertiesProvider(itemId)).valueOrNull ?? [];
//   final dueProp = props.firstWhereOrNull((p) => p.key == 'due_date');
//   final dueDate = dueProp?.dateValue;
//
//   // Γράψιμο
//   await ref.read(propertyNotifierProvider(itemId).notifier)
//       .setDate('due_date', selectedDate);
//
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/debug_config.dart';
import '../models/item_property.dart';
import 'db_provider.dart';

// ── Read providers ────────────────────────────────────────────────

/// Όλα τα properties ενός item
final itemPropertiesProvider =
FutureProvider.family<List<ItemProperty>, int>((ref, itemId) {
  final db = ref.watch(dbProvider);
  DebugConfig.db('itemPropertiesProvider load itemId=$itemId');
  return db.properties.getAll(itemId);
});

/// Μία συγκεκριμένη property by key
final itemPropertyProvider =
FutureProvider.family<ItemProperty?, (int, String)>((ref, args) {
  final (itemId, key) = args;
  final db = ref.watch(dbProvider);
  return db.properties.get(itemId, key);
});

// ── Convenience due_date provider ────────────────────────────────

/// Due date ενός item (από property key='due_date')
final dueDateProvider =
FutureProvider.family<DateTime?, int>((ref, itemId) async {
  final prop = await ref.watch(
      itemPropertyProvider((itemId, 'due_date')).future);
  return prop?.dateValue;
});

// ── Notifier ─────────────────────────────────────────────────────

class PropertyNotifier
    extends FamilyAsyncNotifier<List<ItemProperty>, int> {
  @override
  Future<List<ItemProperty>> build(int arg) {
    DebugConfig.db('PropertyNotifier build itemId=$arg');
    return ref.watch(dbProvider).properties.getAll(arg);
  }

  Future<void> setDate(String key, DateTime? date) async {
    try {
      if (date == null) {
        await ref.read(dbProvider).properties.delete(arg, key);
      } else {
        await ref.read(dbProvider).properties.setDate(arg, key, date);
      }
      ref.invalidateSelf();
      ref.invalidate(itemPropertiesProvider(arg));
      ref.invalidate(dueDateProvider(arg));
    } catch (e, s) {
      DebugConfig.error('PropertyNotifier.setDate', e, s);
    }
  }

  Future<void> setNumber(String key, double? value, {String? unit}) async {
    try {
      if (value == null) {
        await ref.read(dbProvider).properties.delete(arg, key);
      } else {
        await ref.read(dbProvider).properties.setNumber(arg, key, value,
            unit: unit);
      }
      ref.invalidateSelf();
      ref.invalidate(itemPropertiesProvider(arg));
    } catch (e, s) {
      DebugConfig.error('PropertyNotifier.setNumber', e, s);
    }
  }

  Future<void> setText(String key, String? value) async {
    try {
      if (value == null || value.isEmpty) {
        await ref.read(dbProvider).properties.delete(arg, key);
      } else {
        await ref.read(dbProvider).properties
            .set(itemId: arg, key: key, value: value);
      }
      ref.invalidateSelf();
      ref.invalidate(itemPropertiesProvider(arg));
    } catch (e, s) {
      DebugConfig.error('PropertyNotifier.setText', e, s);
    }
  }

  Future<void> remove(String key) async {
    try {
      await ref.read(dbProvider).properties.delete(arg, key);
      ref.invalidateSelf();
      ref.invalidate(itemPropertiesProvider(arg));
      ref.invalidate(dueDateProvider(arg));
    } catch (e, s) {
      DebugConfig.error('PropertyNotifier.remove', e, s);
    }
  }
}

final propertyNotifierProvider = AsyncNotifierProviderFamily<
    PropertyNotifier, List<ItemProperty>, int>(PropertyNotifier.new);