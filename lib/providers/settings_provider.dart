// lib/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import 'db_provider.dart';

// ─────────────────────────────────────────────────────────────────
// Settings — Reactive Stream (ενημερώνει το UI αμέσως)
// ─────────────────────────────────────────────────────────────────

/// Stream των settings — το UI ενημερώνεται άμεσα σε κάθε αλλαγή
final settingsStreamProvider = StreamProvider<AppSettings?>((ref) {
  return ref.watch(dbProvider).settings.watch();
});

/// Future για αρχικό load
final settingsProvider = FutureProvider<AppSettings>((ref) {
  return ref.watch(dbProvider).settings.get();
});

// ─────────────────────────────────────────────────────────────────
// SettingsNotifier — για updates
// ─────────────────────────────────────────────────────────────────

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(dbProvider).settings.get();
  }

  /// Generic update — περνάς function που αλλάζει τα settings.
  /// ΣΗΜΑΝΤΙΚΟ: Ονομάζεται updateSettings() και ΟΧΙ update()
  /// γιατί το AsyncNotifier έχει built-in update() που θα συγκρουόταν.
  Future<void> updateSettings(void Function(AppSettings) updater) async {
    await ref.read(dbProvider).settings.update(updater);
    ref.invalidateSelf();
  }

  // ── Convenience methods ─────────────────────────────────

  Future<void> setTheme(AppTheme theme) =>
      updateSettings((s) => s.theme = theme);

  Future<void> setLanguage(AppLanguage language) =>
      updateSettings((s) => s.language = language);

  Future<void> setDefaultView(DefaultView view) =>
      updateSettings((s) => s.defaultView = view);

  Future<void> toggleNotifications(bool enabled) =>
      updateSettings((s) => s.notificationsEnabled = enabled);

  Future<void> toggleSync(bool enabled) =>
      updateSettings((s) => s.syncEnabled = enabled);

  Future<void> setDefaultWorkspace(int workspaceId) =>
      updateSettings((s) => s.defaultWorkspaceId = workspaceId);

  Future<void> setPreferredFolder(int? folderId) =>
      updateSettings((s) => s.preferredFolderId = folderId);

  Future<void> completeOnboarding() =>
      updateSettings((s) => s.hasCompletedOnboarding = true);

  Future<void> setAccentColor(String hex) =>
      updateSettings((s) => s.accentColor = hex);
}

final settingsNotifierProvider =
AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// ─────────────────────────────────────────────────────────────────
// Convenience derived providers
// ─────────────────────────────────────────────────────────────────

/// Το τρέχον theme — χρήση στο MaterialApp
final appThemeProvider = Provider<AppTheme>((ref) {
  final settingsAsync = ref.watch(settingsStreamProvider);
  return settingsAsync.valueOrNull?.theme ?? AppTheme.system;
});

final onboardingCompleteProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsStreamProvider);
  return settingsAsync.valueOrNull?.hasCompletedOnboarding ?? false;
});

final preferredFolderIdProvider = Provider<int?>((ref) {
  final settingsAsync = ref.watch(settingsNotifierProvider);
  return settingsAsync.valueOrNull?.preferredFolderId;
});