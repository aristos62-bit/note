// lib/models/app_settings.dart
import 'package:isar/isar.dart';
part 'app_settings.g.dart';

enum AppTheme { system, light, dark }
enum AppLanguage { greek, english, auto }
enum DefaultView { list, grid, kanban, calendar }

@Collection()
class AppSettings {
  /// Singleton — πάντα id = 1
  Id id = 1;

  @Enumerated(EnumType.name)
  AppTheme theme = AppTheme.system;

  String? accentColor;
  double fontScale = 1.0;

  @Enumerated(EnumType.name)
  DefaultView defaultView = DefaultView.list;

  @Enumerated(EnumType.name)
  AppLanguage language = AppLanguage.auto;

  bool showArchivedItems = false;
  bool showDeletedItems = false;
  bool confirmBeforeDelete = true;
  bool autoSave = true;
  int autoSaveIntervalSeconds = 30;

  bool notificationsEnabled = true;
  bool soundEnabled = true;
  bool vibrationEnabled = true;

  /// S-06: απόκρυψη περιεχομένου στις OS ειδοποιήσεις (lockscreen + tray).
  /// Default ON (privacy-first). Η DB κρατά ΠΑΝΤΑ το πραγματικό κείμενο —
  /// κρύβεται μόνο το κείμενο που στέλνεται στο OS.
  bool hideNotificationContent = true;

  bool syncEnabled = false;
  bool syncOnWifiOnly = false;
  int syncIntervalMinutes = 15;
  DateTime? lastSyncAt;

  int? defaultWorkspaceId;
  int? preferredFolderId;

  bool hasCompletedOnboarding = false;

  /// JSON map: ItemType.name → hex color (null = default)
  /// Π.χ. {"habit":"#0000FF","task":"#FF0000"}
  String? itemTypeColorsJson;

  /// Έκδοση schema για migrations. Αυξάνεται όταν γίνονται breaking changes.
  int schemaVersion = 1;

  // ── App Lock ───────────────────────────────────────────────────
  bool appLockEnabled = false;
  String? appLockPinHash;
  bool biometricEnabled = false;
  /// Πόσα ψηφία έχει το PIN (4-6). Νέα PIN = 6· 4-5 μόνο legacy.
  int appLockPinLength = 6;

  /// S-13: απόλυτο ανώτατο όριο ανά αρχείο (100 MB). Ανεξάρτητο από τη
  /// ρύθμιση — ισχύει ακόμη κι αν η αποθηκευμένη τιμή είναι εκτός λίστας.
  /// Δεν είναι πεδίο Isar (getter/const — μηδέν schema/migration/codegen).
  static const int maxAttachmentCeilingMB = 100;

  /// Μέγιστο μέγεθος αρχείου σε MB για συνημμένα. Legacy `0`, αρνητικό ή
  /// τιμή πάνω από το ceiling διαβάζονται ως [maxAttachmentCeilingMB]
  /// (S-13 Δ1/Δ4 — το «χωρίς όριο» καταργήθηκε).
  int maxAttachmentSizeMB = 20;

  /// **Ενεργό** όριο σε MB — πάντα μέσα στο `1..maxAttachmentCeilingMB`.
  /// SPoT για εμφάνιση (settings tile) και για έλεγχο (attachments/share).
  int get effectiveMaxAttachmentMB {
    final mb = maxAttachmentSizeMB;
    if (mb <= 0 || mb > maxAttachmentCeilingMB) {
      return maxAttachmentCeilingMB;
    }
    return mb;
  }

  /// Ενεργό όριο σε bytes — **ποτέ null**. Getter, όχι πεδίο Isar, άρα
  /// μηδέν schema/migration/codegen.
  int get attachmentMaxBytes => effectiveMaxAttachmentMB * 1024 * 1024;

  // ── Auto-backup ──────────────────────────────────────────────
  /// Αυτόματο zip-αντίγραφο (DB + attachments) στο background.
  bool autoBackupEnabled = false;

  /// Τελευταίο επιτυχημένο αυτόματο αντίγραφο (null = ποτέ).
  DateTime? lastAutoBackupAt;

  /// S-307 (Δ6): «Κλείδωμα αντιγράφου» — όταν είναι ON, το `.snb` κρυπτογραφείται
  /// με κωδικό χρήστη (PBKDF2) αντί για ενσωματωμένο κλειδί. Default OFF.
  bool backupLockEnabled = false;

  /// 0 = άμεσο κλείδωμα, 300 = 5 λεπτά, κλπ.
  int appLockTimeoutSeconds = 0;

  // ── App Lock: lockout (S-03, persistent) ────────────────────
  /// Συνεχόμενες αποτυχημένες προσπάθειες PIN (persisted — επιβιώνει
  /// kill/restart και lock/unlock).
  int appLockFailedAttempts = 0;

  /// Απόλυτη προθεσμία lockout σε epoch ms (0 = κανένα lockout).
  int appLockLockoutUntilEpochMs = 0;

  /// Διάρκεια του τρέχοντος lockout σε δευτερόλεπτα (0 = κανένα).
  int appLockLockoutDurationSeconds = 0;

  /// Άγκυρα `elapsedRealtime` (ms από boot) όταν ξεκίνησε το lockout.
  /// 0 = μη διαθέσιμο (πλατφόρμα χωρίς monotonic).
  int appLockLockoutMonoMs = 0;

  /// Τελευταία γνωστή wall ώρα (epoch ms) — ανιχνεύει ρολόι που γύρισε πίσω.
  int appLockLastSeenWallMs = 0;

  DateTime updatedAt = DateTime.now();
}