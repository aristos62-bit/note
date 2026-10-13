import 'package:flutter/material.dart';
import '../models/models.dart';
import '../core/theme/ui_tokens.dart';
import '../core/utils/debug_config.dart';

class ItemColorHelper {
  /// SPoT εικονίδια γενεθλίων/ειδικών ημερών (item.icon για ItemType.event).
  /// Το '⭐' είναι legacy (παλιές ειδικές) — διαβάζεται, δεν γράφεται ποτέ.
  static const String kBirthdayIcon = '🎂';
  static const String kSpecialDayIcon = '✅';
  static const String kLegacySpecialDayIcon = '⭐';

  /// Brand χρώματα γενεθλίων/ειδικών ( dots/legend/icons — ίδια και στα 2 modes).
  static const Color birthdayPink = Color(0xFFEC4899); // pink-500
  static const Color specialAmber = Color(0xFFF59E0B); // amber-500

  /// Γενέθλια = event με 🎂 (αυτόματη ετήσια, χωρίς καμπάνα).
  static bool isBirthdayEvent(Item? item) =>
      item != null &&
      item.type == ItemType.event &&
      item.icon == kBirthdayIcon;

  /// Ειδική ημέρα = event με ✅ (ή legacy ⭐) — μόνο καμπάνα, ποτέ αυτόματη.
  static bool isSpecialDayEvent(Item? item) =>
      item != null &&
      item.type == ItemType.event &&
      (item.icon == kSpecialDayIcon || item.icon == kLegacySpecialDayIcon);

  /// Φόντο κάρτας γενεθλίων (φούξια tint, ίδια οικογένεια με calendar dots).
  static Color birthdayBackground(BuildContext context) {
    final isDark = context.brightness == Brightness.dark;
    return isDark ? Colors.pink.shade900 : Colors.pink.shade100;
  }

  /// Φόντο κάρτας ειδικής ημέρας (πορτοκαλί tint).
  static Color specialDayBackground(BuildContext context) {
    final isDark = context.brightness == Brightness.dark;
    return isDark ? Colors.amber.shade900 : Colors.amber.shade100;
  }

  /// Accent (μπάρα/icon) γενεθλίων/ειδικών — null για κανονικά items.
  static Color? specialAccent(Item? item) {
    if (isBirthdayEvent(item)) return birthdayPink;
    if (isSpecialDayEvent(item)) return specialAmber;
    return null;
  }

  static Color backgroundColorForType(ItemType type, BuildContext context,
      {String? overrideHex}) {
    if (overrideHex != null) {
      final parsed = parseHex(overrideHex);
      if (parsed != null) return parsed;
    }
    final isDark = context.brightness == Brightness.dark;
    switch (type) {
      case ItemType.note:
        return isDark ? Colors.yellow.shade300 : const Color(0xFFFFF0B5);
      case ItemType.journal:
        return isDark ? Colors.purple.shade400 : const Color(0xFFE0C0FF);
      case ItemType.task:
        return isDark ? Colors.blue.shade600 : const Color(0xFFD0F0C0);
      case ItemType.habit:
        return isDark ? Colors.green.shade100 : const Color(0xFFFFD6A5);
      case ItemType.event:
        return isDark ? Colors.orange.shade400 : const Color(0xFFB8D9FF);
      case ItemType.appointment:
        return isDark ? Colors.green.shade400 : const Color(0xFFD0F0C0);
      case ItemType.contact:
        return isDark ? Colors.cyanAccent.shade100 : const Color(0xFFE0D0C0);
      case ItemType.knowledge:
        return isDark ? Colors.teal.shade400 : const Color(0xFFB2DFDB);
      case ItemType.project:
        return isDark ? Colors.green.shade800 : const Color(0xFFB8D9FF);
      default:
        return ColorsUI.getCard(context.brightness);
    }
  }

  static Color textColorForBackground(Color backgroundColor, BuildContext context) {
    return ColorsUI.getAccessibleTextColor(backgroundColor);
  }

  static Color iconColorForType(ItemType type, BuildContext context) {
    return ColorsUI.itemTypeColor(type, context.brightness);
  }

  /// SPoT για hex → Color. Επιστρέφει null αν άκυρο, logάρει warning.
  static Color? parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final clean = hex.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (e) {
      DebugConfig.warning('ItemColorHelper.parseHex: invalid hex "$hex" ($e)');
      return null;
    }
  }
}