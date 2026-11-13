// lib/services/services.dart
//
// Barrel file — import αυτό αντί να κάνεις import κάθε service ξεχωριστά
//
// Χρήση:
//   import 'package:super_note/services/services.dart';
//
export 'notification_service.dart';
export 'notification_permission.dart';
export 'reminder_scheduler.dart';
export 'search_service.dart';
export 'habit_service.dart';
export 'attachment_service.dart';
export 'backup_service.dart';
export 'backup_archive.dart';
export 'backup/backup_container.dart';
export 'backup/backup_passphrase_cache.dart';
export 'backup/backup_rotation.dart';
export 'contact_import_service.dart';
export 'share_service.dart';
// E50: το `ShareFormatters` (humanSize) είναι πλέον κοινό SPoT μορφοποίησης
// μεγέθους και για το UI (Ρυθμίσεις → auto backup).
export 'share/share_formatters.dart';
export 'shared_intent_service.dart';
export 'app_lock_service.dart';
export 'migration_service.dart';
export 'data_root_migration.dart';
export 'security_service.dart';