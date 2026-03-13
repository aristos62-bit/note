// lib/models/item_property.dart
import 'package:isar/isar.dart';
part 'item_property.g.dart';

// ─────────────────────────────────────────────────────────────────
// Enum για τον τύπο της property value
// ─────────────────────────────────────────────────────────────────
enum PropertyType {
  text,       // Απλό string
  number,     // Αριθμός (stored as string, parsed στη χρήση)
  date,       // DateTime (ISO 8601 string)
  boolean,    // "true" / "false"
  url,        // Link
  email,      // Email address
  phone,      // Τηλέφωνο
  currency,   // Χρηματικό ποσό (με unit)
  percent,    // Ποσοστό 0-100
  rating,     // 1-5 ή 1-10
  select,     // Μία επιλογή από λίστα
  multiSelect,// Πολλές επιλογές (JSON array)
  location,   // GPS coords ή address
  duration,   // Διάρκεια σε seconds
  color,      // Hex color
  json,       // Arbitrary JSON
}

// ─────────────────────────────────────────────────────────────────
// Παραδείγματα keys ανά ItemType:
//
// task:     due_date, start_date, estimated_hours, actual_hours, assignee
// event:    start_time, end_time, location, all_day, recurrence
// contact:  phone, email, birthday, company, website, address
// habit:    frequency, streak, goal_count, unit, start_date
// project:  deadline, budget, client, completion_percent
// goal:     target_date, progress, target_value, current_value, unit
// finance:  amount, currency, category, account, transaction_type
// bookmark: url, domain, description, thumbnail, read_status
// journal:  mood, weather, word_count
// ─────────────────────────────────────────────────────────────────

@Collection()
class ItemProperty {
  Id id = Isar.autoIncrement;

  /// Ποιο item ανήκει
  @Index(composite: [CompositeIndex('key')])
  late int itemId;

  /// Το όνομα της property (π.χ. "due_date", "phone", "streak")
  late String key;

  /// Η τιμή πάντα stored ως String (parse ανάλογα με το type)
  String? value;

  /// Ο τύπος — καθορίζει πώς θα γίνει parse το value
  @Enumerated(EnumType.name)
  PropertyType type = PropertyType.text;

  /// Μονάδα μέτρησης (π.χ. "€", "$", "kg", "km", "hours")
  String? unit;

  /// Σειρά εμφάνισης στο UI
  int sortOrder = 0;

  /// Αν είναι ορατή στο UI ή internal/hidden
  bool isVisible = true;

  // ─── Timestamps ─────────────────────────────────────────
  DateTime createdAt = DateTime.now();
  DateTime? updatedAt;

  // ─── Helpers ────────────────────────────────────────────

  /// Parse value ως DateTime (για type == date)
  DateTime? get dateValue =>
      value != null ? DateTime.tryParse(value!) : null;

  /// Parse value ως double (για type == number, currency, percent)
  double? get numberValue =>
      value != null ? double.tryParse(value!) : null;

  /// Parse value ως bool (για type == boolean)
  bool get boolValue => value == 'true';

  /// Formatted display string
  String get displayValue {
    if (value == null) return '';
    switch (type) {
      case PropertyType.currency:
        return '${unit ?? '€'}${numberValue?.toStringAsFixed(2) ?? value}';
      case PropertyType.percent:
        return '$value%';
      case PropertyType.date:
        return dateValue?.toLocal().toString().split(' ').first ?? value!;
      default:
        return value!;
    }
  }
}