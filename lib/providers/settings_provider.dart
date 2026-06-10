// lib/providers/settings_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/reminder_scheduler.dart';
import 'db_provider.dart';
import '../core/utils/debug_config.dart';

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

// ── Helpers για itemTypeColorsJson ──────────────────────────────

Map<String, String?> _itemTypeColorsFromJson(String? json) {
  if (json == null || json.isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return {};
    return decoded.map((k, v) => MapEntry(k.toString(), v?.toString()));
  } catch (e, s) {
    DebugConfig.error('settings._itemTypeColorsFromJson', e, s);
    return {};
  }
}

String _itemTypeColorsToJson(Map<String, String?> map) {
  return jsonEncode(map);
}

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (e, s) {
    DebugConfig.error('settings._parseHexColor', e, s);
    return null;
  }
}

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
    try {
      await ref.read(dbProvider).settings.update(updater);
      ref.invalidateSelf();
    } catch (e, s) {
      DebugConfig.error('SettingsNotifier.updateSettings', e, s);
    }
  }

  // ── Convenience methods ─────────────────────────────────

  Future<void> setTheme(AppTheme theme) =>
      updateSettings((s) => s.theme = theme);

  Future<void> setLanguage(AppLanguage language) =>
      updateSettings((s) => s.language = language);

  Future<void> setDefaultView(DefaultView view) =>
      updateSettings((s) => s.defaultView = view);

  Future<void> toggleNotifications(bool enabled) async {
    try {
      await updateSettings((s) => s.notificationsEnabled = enabled);
      if (enabled) {
        await ReminderScheduler.instance.scheduleAll();
      } else {
        await NotificationService.instance.cancelAll();
      }
    } catch (e, s) {
      DebugConfig.error('SettingsNotifier.toggleNotifications', e, s);
    }
  }

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

  Future<void> setItemTypeColor(ItemType type, String? hex) async {
    try {
      await updateSettings((s) {
        final map = _itemTypeColorsFromJson(s.itemTypeColorsJson);
        if (hex == null) {
          map.remove(type.name);
        } else {
          map[type.name] = hex;
        }
        s.itemTypeColorsJson = map.isEmpty ? null : _itemTypeColorsToJson(map);
      });
    } catch (e, s) {
      DebugConfig.error('SettingsNotifier.setItemTypeColor', e, s);
    }
  }
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

/// Επιστρέφει το override χρώμα για ένα ItemType (ή null για default)
final itemTypeCardColorOverrideProvider =
    Provider.family<Color?, ItemType>((ref, type) {
  final settingsAsync = ref.watch(settingsNotifierProvider);
  final json = settingsAsync.valueOrNull?.itemTypeColorsJson;
  final map = _itemTypeColorsFromJson(json);
  final hex = map[type.name];
  return _parseHexColor(hex);
});