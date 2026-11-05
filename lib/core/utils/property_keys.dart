// lib/core/utils/property_keys.dart
//
// E41 — SPoT για τα keys των EAV properties (`ItemProperty`).
// Δεν αλλάζει σχήμα DB: όλα είναι απλά string keys.
//
// Χρήση:
//   import '../../core/core.dart';
//   props.where((p) => p.key == PropertyKeys.endDate)

class PropertyKeys {
  PropertyKeys._();

  static const String startTime = 'start_time';
  static const String endTime = 'end_time';

  /// E41: ημερομηνία λήξης πολυήμερου συμβάντος.
  /// Date-only, **inclusive**, τοπικό μεσάνυχτα (χωρίς ώρα/ζώνη).
  static const String endDate = 'end_date';

  /// E41: χρώμα γραμμής πολυήμερου (`#RRGGBB`). Απουσία = default accent.
  static const String spanColor = 'span_color';

  // ─── E39: keys που διαβάζει το share pipeline ─────────────────
  // Μόνο constants. ΔΕΝ μπαίνουν στα `technical` / `calendar` παρακάτω:
  //   • technical → θα εξαφάνιζε notes/due_date από τα search snippets
  //   • calendar  → θα προκαλούσε άσκοπο bump του ημερολογίου
  // Καμία αλλαγή σε σχήμα DB ή σε υπάρχον key.

  /// E39: ημερομηνία ραντεβού (ISO 8601 string).
  static const String date = 'date';

  /// E39: ώρα ραντεβού (`HH:mm`).
  static const String time = 'time';

  /// E39: προθεσμία task (ISO 8601 string).
  static const String dueDate = 'due_date';

  /// E39: ελεύθερο κείμενο σημειώσεων (task / event / contact / appointment).
  static const String notes = 'notes';

  /// Τεχνικά keys — ΔΕΝ συμμετέχουν στην αναζήτηση (θόρυβος + άχρηστα
  /// snippets: hex / ISO strings).
  static const Set<String> technical = {endDate, spanColor};

  /// Keys που επηρεάζουν το ημερολόγιο → bump `calendarDataVersionProvider`
  /// (το `itemsStreamProvider` δεν βλέπει αλλαγές σε `itemPropertys`).
  static const Set<String> calendar = {startTime, endTime, endDate, spanColor};
}
