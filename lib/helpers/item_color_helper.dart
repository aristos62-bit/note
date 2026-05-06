import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../core/theme/ui_tokens.dart';

class ItemColorHelper {
  static Color backgroundColorForType(ItemType type, BuildContext context) {
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
    final luminance = 0.299 * backgroundColor.r +
        0.587 * backgroundColor.g +
        0.114 * backgroundColor.b;
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  static Color iconColorForType(ItemType type, BuildContext context) {
    return ColorsUI.itemTypeColor(type, context.brightness);
  }
}