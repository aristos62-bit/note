import 'package:flutter/material.dart';
import '../models/models.dart';
import '../core/theme/ui_tokens.dart';
import '../core/utils/debug_config.dart';

class ItemColorHelper {
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