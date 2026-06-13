// lib/models/app_settings.dart
// TODO: Σελίδα προς Ανάπτυξη
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
  /// Πόσα ψηφία έχει το PIN (4-6)
  int appLockPinLength = 6;

  /// Μέγιστο μέγεθος αρχείου σε MB για συνημμένα (0 = χωρίς όριο)
  int maxAttachmentSizeMB = 20;

  /// 0 = άμεσο κλείδωμα, 300 = 5 λεπτά, κλπ.
  int appLockTimeoutSeconds = 0;

  DateTime updatedAt = DateTime.now();
}