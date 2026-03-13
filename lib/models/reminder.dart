// lib/models/reminder.dart
import 'package:isar/isar.dart';
part 'reminder.g.dart';

// ─────────────────────────────────────────────────────────────────
// Παραδείγματα RRULE (iCalendar standard):
//
// Κάθε μέρα:             FREQ=DAILY
// Κάθε εβδομάδα Δευτέρα: FREQ=WEEKLY;BYDAY=MO
// Κάθε μήνα στις 1:      FREQ=MONTHLY;BYMONTHDAY=1
// Κάθε χρόνο:            FREQ=YEARLY
// 3 φορές:               FREQ=DAILY;COUNT=3
// Μέχρι ημερομηνία:      FREQ=DAILY;UNTIL=20251231T000000Z
// ─────────────────────────────────────────────────────────────────

enum ReminderStatus {
  pending,   // Δεν έχει στείλει ακόμα
  sent,      // Έχει σταλεί
  dismissed, // Ο χρήστης το απέρριψε
  snoozed,   // Αναβλήθηκε
}

@Collection()
class Reminder {
  Id id = Isar.autoIncrement;

  /// Ποιο item αφορά αυτή η υπενθύμιση
  @Index()
  late int itemId;

  /// Πότε να στείλει notification
  @Index()
  late DateTime triggerAt;

  /// RRULE format για επαναλαμβανόμενες υπενθυμίσεις
  /// null = μόνο μία φορά
  /// Παράδειγμα: "FREQ=DAILY" ή "FREQ=WEEKLY;BYDAY=MO,WE,FR"
  String? rrule;

  /// Τίτλος notification (αν null, χρησιμοποιείται ο τίτλος του item)
  String? title;

  /// Μήνυμα notification
  String? body;

  @Enumerated(EnumType.name)
  ReminderStatus status = ReminderStatus.pending;

  /// Πότε στάλθηκε
  DateTime? notifiedAt;

  /// Αν έχει snoozed, νέο trigger time
  DateTime? snoozeUntil;

  /// ID του notification στο flutter_local_notifications
  /// Χρησιμοποιείται για cancel/update
  int? notificationId;

  DateTime createdAt = DateTime.now();
  DateTime? updatedAt;

  /// Ελέγχει αν η υπενθύμιση είναι ενεργή
  bool get isActive =>
      status == ReminderStatus.pending &&
          (snoozeUntil == null || DateTime.now().isAfter(snoozeUntil!));

  /// Ελέγχει αν είναι repeating
  bool get isRepeating => rrule != null && rrule!.isNotEmpty;
}