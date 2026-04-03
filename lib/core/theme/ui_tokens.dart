// lib/core/theme/ui_tokens.dart
//
// Design System tokens για SuperNote.
// Περιέχει ColorsUI + TypographyUI + SuperNote-specific additions.
//
// ΧΡΗΣΗ:
//   import 'package:super_note/core/theme/ui_tokens.dart';
//
//   // Σε widget:
//   color: context.cPrimary
//   style: context.bodyMd
//   color: ColorsUI.itemTypeColor(ItemType.note, brightness)
//
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/item.dart';

// ════════════════════════════════════════════════════════════════
// COLORS 0xFF6750A4  --  0xFFD0BCFF
// ════════════════════════════════════════════════════════════════

class ColorsUI {
  // ── Primary ──────────────────────────────────────────────────
  static const Color primaryLight = Color(0xD87C9F67);
  static const Color primaryDark  = Color(0xC2D0ED67);

  static const Color secondaryLight = Color(0xFF625B71);
  static const Color secondaryDark  = Color(0xFFCCC2DC);

  static const Color tertiaryLight = Color(0xFF7D5260);
  static const Color tertiaryDark  = Color(0xFFEFB8C8);

  // "On" colors
  static const Color onPrimaryLight = Colors.white;
  static const Color onPrimaryDark  = Colors.black;
  static const Color onSecondaryLight = Colors.white;
  static const Color onSecondaryDark  = Colors.black;
  static const Color onTertiaryLight = Colors.white;
  static const Color onTertiaryDark  = Colors.black;
  static const Color onErrorLight = Colors.white;
  static const Color onErrorDark  = Colors.black;

  // ── Semantic — Light ─────────────────────────────────────────
  static const Color successLight  = Color(0xFF2E7D32);
  static const Color warningLight  = Color(0xFFED6C02);
  static const Color errorLight    = Color(0xFFC62828);
  static const Color infoLight     = Color(0xFF0277BD);

  static const Color incomeLight   = Color(0xFF2E7D32);
  static const Color expenseLight  = Color(0xFFC62828);
  static const Color transferLight = Color(0xFF0277BD);

  // ── Semantic — Dark ──────────────────────────────────────────
  static const Color successDark  = Color(0xFF81C784);
  static const Color warningDark  = Color(0xFFFFB74D);
  static const Color errorDark    = Color(0xFFE57373);
  static const Color infoDark     = Color(0xFF64B5F6);

  static const Color incomeDark   = Color(0xFF81C784);
  static const Color expenseDark  = Color(0xFFE57373);
  static const Color transferDark = Color(0xFF64B5F6);

  // ── Background / Surface ─────────────────────────────────────
  static const Color backgroundLight = Color(0xFFD7DACD);
  static const Color backgroundDark  = Color(0xFF242525);

  static const Color surfaceLight = Color(0xA9F2F3F1);
  static const Color surfaceDark  = Color(0x8448474C);

  static const Color cardLight = Color(0xFFF6F6F1);
  static const Color cardDark  = Color(0x935F5F65);

  // ── Text ─────────────────────────────────────────────────────
  static const Color textPrimaryLight   = Color(0xFF1C1B1F);
  static const Color textPrimaryDark    = Color(0xFFE6E1E5);
  static const Color textSecondaryLight = Color(0xFF49454F);
  static const Color textSecondaryDark  = Color(0xFFCAC4D0);
  static const Color textTertiaryLight  = Color(0xFF79747E);
  static const Color textTertiaryDark   = Color(0xFF938F99);
  static const Color textDisabledLight  = Color(0xFFBDBDBD);
  static const Color textDisabledDark   = Color(0xFF5F5F5F);

  // ── Border / Divider ─────────────────────────────────────────
  static const Color borderLight  = Color(0xFFE0E0E0);
  static const Color borderDark   = Color(0xFF3E3E3E);
  static const Color dividerLight = Color(0xFFE0E0E0);
  static const Color dividerDark  = Color(0xFF3E3E3E);

  // ── Overlays / Shadows ───────────────────────────────────────
  static const Color overlayLight = Color(0x1F000000);
  static const Color overlayDark  = Color(0x1FFFFFFF);
  static const Color shadowLight  = Color(0x1A000000);
  static const Color shadowDark   = Color(0x33000000);

  // ── Inputs ───────────────────────────────────────────────────
  static const Color inputFillLight        = Color(0xFFF5F5F5);
  static const Color inputFillDark         = Color(0xFF2B2930);
  static const Color inputBorderLight      = Color(0xFFBDBDBD);
  static const Color inputBorderDark       = Color(0xFF5F5F5F);
  static const Color inputFocusBorderLight = Color(0xFF6750A4);
  static const Color inputFocusBorderDark  = Color(0xFFD0BCFF);

  // ── Gradients ────────────────────────────────────────────────
  static const List<Color> splashGradient = [
    Color(0xFF42A5F5),
    Color(0xFF1976D2),
    Color(0xFF7B1FA2),
  ];

  static final List<Color> loginGradient = [
    Colors.blue.shade600,
    Colors.blue.shade800,
  ];

  // ── Chart Colors ─────────────────────────────────────────────
  static const List<Color> chartColorsLight = [
    Color(0xFF6750A4), Color(0xFF2E7D32), Color(0xFFED6C02),
    Color(0xFF0277BD), Color(0xFFC62828), Color(0xFF7D5260),
    Color(0xFF00838F), Color(0xFFF57F17),
  ];
  static const List<Color> chartColorsDark = [
    Color(0xFFD0BCFF), Color(0xFF81C784), Color(0xFFFFB74D),
    Color(0xFF64B5F6), Color(0xFFE57373), Color(0xFFEFB8C8),
    Color(0xFF4DD0E1), Color(0xFFFFF176),
  ];

  // ════════════════════════════════════════════════════════════
  // SUPERNOTE-SPECIFIC COLORS
  // ════════════════════════════════════════════════════════════

  /// Χρώμα για κάθε ItemType — χρησιμοποιείται στα icons και cards
  static Color itemTypeColor(ItemType type, Brightness b) {
    final colors = b == Brightness.light ? _itemColorsLight : _itemColorsDark;
    return colors[type] ?? getPrimary(b);
  }

  static const Map<ItemType, Color> _itemColorsLight = {
    ItemType.note:      Color(0xFF6750A4), // purple
    ItemType.task:      Color(0xFF0277BD), // blue
    ItemType.event:     Color(0xFF2E7D32), // green
    ItemType.contact:   Color(0xFF00838F), // teal
    ItemType.habit:     Color(0xFFED6C02), // orange
    ItemType.project:   Color(0xFF7D5260), // pink
    ItemType.goal:      Color(0xFFF57F17), // amber
    ItemType.finance:   Color(0xFF2E7D32), // green
    ItemType.bookmark:  Color(0xFF0277BD), // blue
    ItemType.journal:   Color(0xFF7D5260), // pink
    ItemType.appointment: Color(0xFFF6D605),// yellow
    ItemType.checklist: Color(0xFF00838F), // teal
    ItemType.knowledge: Color(0xFF6750A4), // purple
  };

  static const Map<ItemType, Color> _itemColorsDark = {
    ItemType.note:      Color(0xFFD0BCFF), // purple
    ItemType.task:      Color(0xFF64B5F6), // blue
    ItemType.event:     Color(0xFF81C784), // green
    ItemType.contact:   Color(0xFF4DD0E1), // teal
    ItemType.habit:     Color(0xFFFFB74D), // orange
    ItemType.project:   Color(0xFFEFB8C8), // pink
    ItemType.goal:      Color(0xFFFFF176), // amber
    ItemType.finance:   Color(0xFF81C784), // green
    ItemType.bookmark:  Color(0xFF64B5F6), // blue
    ItemType.journal:   Color(0xFFEFB8C8), // pink
    ItemType.appointment: Color(0xFF81C784),// green
    ItemType.checklist: Color(0xFF4DD0E1), // teal
    ItemType.knowledge: Color(0xFFD0BCFF), // purple
  };

  /// Χρώμα για priority badge
  static Color priorityColor(ItemPriority priority, Brightness b) {
    switch (priority) {
      case ItemPriority.urgent: return b == Brightness.light ? errorLight : errorDark;
      case ItemPriority.high:   return b == Brightness.light ? warningLight : warningDark;
      case ItemPriority.medium: return b == Brightness.light ? infoLight : infoDark;
      case ItemPriority.low:    return b == Brightness.light ? successLight : successDark;
      case ItemPriority.none:   return b == Brightness.light ? textDisabledLight : textDisabledDark;
    }
  }

  /// Soft background για priority badge (10% opacity)
  static Color priorityColorSoft(ItemPriority priority, Brightness b) =>
      priorityColor(priority, b).withValues(alpha:0.12);

  /// Pinned item highlight color
  static Color pinnedColor(Brightness b) =>
      b == Brightness.light ? const Color(0xFFC3EF9E) : const Color(0xFF856B91);

  /// Streak color για habits (gradient από orange σε red)
  static Color streakColor(int streak, Brightness b) {
    if (streak >= 30) return b == Brightness.light ? const Color(0xFFC62828) : const Color(0xFFE57373);
    if (streak >= 14) return b == Brightness.light ? const Color(0xFFED6C02) : const Color(0xFFFFB74D);
    if (streak >= 7)  return b == Brightness.light ? const Color(0xFFF57F17) : const Color(0xFFFFF176);
    if (streak >= 0)  return b == Brightness.light ? const Color(0xFF2E7D32) : const Color(0xFF81C784);
    return b == Brightness.light ? const Color(0xFF2E7D32) : const Color(0xFF81C784); // fallback
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  static Color byBrightness({
    required Brightness brightness,
    required Color light,
    required Color dark,
  }) => brightness == Brightness.light ? light : dark;

  static Color getPrimary(Brightness b)         => byBrightness(brightness: b, light: primaryLight, dark: primaryDark);
  static Color getSecondary(Brightness b)        => byBrightness(brightness: b, light: secondaryLight, dark: secondaryDark);
  static Color getTertiary(Brightness b)         => byBrightness(brightness: b, light: tertiaryLight, dark: tertiaryDark);
  static Color getOnPrimary(Brightness b)        => byBrightness(brightness: b, light: onPrimaryLight, dark: onPrimaryDark);
  static Color getOnSecondary(Brightness b)      => byBrightness(brightness: b, light: onSecondaryLight, dark: onSecondaryDark);
  static Color getOnTertiary(Brightness b)       => byBrightness(brightness: b, light: onTertiaryLight, dark: onTertiaryDark);
  static Color getOnError(Brightness b)          => byBrightness(brightness: b, light: onErrorLight, dark: onErrorDark);
  static Color getBackground(Brightness b)       => byBrightness(brightness: b, light: backgroundLight, dark: backgroundDark);
  static Color getSurface(Brightness b)          => byBrightness(brightness: b, light: surfaceLight, dark: surfaceDark);
  static Color getCard(Brightness b)             => byBrightness(brightness: b, light: cardLight, dark: cardDark);
  static Color getTextPrimary(Brightness b)      => byBrightness(brightness: b, light: textPrimaryLight, dark: textPrimaryDark);
  static Color getTextSecondary(Brightness b)    => byBrightness(brightness: b, light: textSecondaryLight, dark: textSecondaryDark);
  static Color getTextTertiary(Brightness b)     => byBrightness(brightness: b, light: textTertiaryLight, dark: textTertiaryDark);
  static Color getTextDisabled(Brightness b)     => byBrightness(brightness: b, light: textDisabledLight, dark: textDisabledDark);
  static Color getDivider(Brightness b)          => byBrightness(brightness: b, light: dividerLight, dark: dividerDark);
  static Color getBorder(Brightness b)           => byBrightness(brightness: b, light: borderLight, dark: borderDark);
  static Color getInputFill(Brightness b)        => byBrightness(brightness: b, light: inputFillLight, dark: inputFillDark);
  static Color getInputBorder(Brightness b)      => byBrightness(brightness: b, light: inputBorderLight, dark: inputBorderDark);
  static Color getInputFocusBorder(Brightness b) => byBrightness(brightness: b, light: inputFocusBorderLight, dark: inputFocusBorderDark);
  static Color getSuccess(Brightness b)          => byBrightness(brightness: b, light: successLight, dark: successDark);
  static Color getWarning(Brightness b)          => byBrightness(brightness: b, light: warningLight, dark: warningDark);
  static Color getError(Brightness b)            => byBrightness(brightness: b, light: errorLight, dark: errorDark);
  static Color getInfo(Brightness b)             => byBrightness(brightness: b, light: infoLight, dark: infoDark);
  static Color getIncomeColor(Brightness b)      => byBrightness(brightness: b, light: incomeLight, dark: incomeDark);
  static Color getExpenseColor(Brightness b)     => byBrightness(brightness: b, light: expenseLight, dark: expenseDark);
  static Color getTransferColor(Brightness b)    => byBrightness(brightness: b, light: transferLight, dark: transferDark);
  static List<Color> getChartColors(Brightness b) => b == Brightness.light ? chartColorsLight : chartColorsDark;

  // ── Accessibility ────────────────────────────────────────────
  static bool hasGoodContrast(Color foreground, Color background) =>
      _calculateContrastRatio(foreground, background) >= 7.0;

  static double _calculateContrastRatio(Color c1, Color c2) {
    final lum1 = _getRelativeLuminance(c1);
    final lum2 = _getRelativeLuminance(c2);
    final lighter = lum1 > lum2 ? lum1 : lum2;
    final darker  = lum1 > lum2 ? lum2 : lum1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _getRelativeLuminance(Color color) {
    final r = _linearize(color.r);
    final g = _linearize(color.g);
    final b = _linearize(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _linearize(double c) {
    if (c <= 0.03928) return c / 12.92;
    return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  static Color getAccessibleTextColor(Color background) {
    final luminance = _getRelativeLuminance(background);
    return luminance > 0.5 ? textPrimaryLight : textPrimaryDark;
  }
}

// ════════════════════════════════════════════════════════════════
// TYPOGRAPHY
// ════════════════════════════════════════════════════════════════

class TypographyUI {
  static const String primaryFont = 'Roboto';

  // ── Display ──────────────────────────────────────────────────
  static TextStyle displayLarge(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25, height: 1.12, color: ColorsUI.getTextPrimary(b));
  static TextStyle displayMedium(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 45, fontWeight: FontWeight.w400, height: 1.16, color: ColorsUI.getTextPrimary(b));
  static TextStyle displaySmall(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 36, fontWeight: FontWeight.w400, height: 1.22, color: ColorsUI.getTextPrimary(b));

  // ── Headline ─────────────────────────────────────────────────
  static TextStyle headlineLarge(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 32, fontWeight: FontWeight.w600, height: 1.25, color: ColorsUI.getTextPrimary(b));
  static TextStyle headlineMedium(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 28, fontWeight: FontWeight.w600, height: 1.29, color: ColorsUI.getTextPrimary(b));
  static TextStyle headlineSmall(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 24, fontWeight: FontWeight.w600, height: 1.33, color: ColorsUI.getTextPrimary(b));

  // ── Title ────────────────────────────────────────────────────
  static TextStyle titleLarge(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 22, fontWeight: FontWeight.w600, height: 1.27, color: ColorsUI.getTextPrimary(b));
  static TextStyle titleMedium(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15, height: 1.50, color: ColorsUI.getTextPrimary(b));
  static TextStyle titleSmall(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.43, color: ColorsUI.getTextPrimary(b));

  // ── Label ────────────────────────────────────────────────────
  static TextStyle labelLarge(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.43, color: ColorsUI.getTextPrimary(b));
  static TextStyle labelMedium(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, height: 1.33, color: ColorsUI.getTextPrimary(b));
  static TextStyle labelSmall(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, height: 1.45, color: ColorsUI.getTextPrimary(b));

  // ── Body ─────────────────────────────────────────────────────
  static TextStyle bodyLarge(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, height: 1.50, color: ColorsUI.getTextPrimary(b));
  static TextStyle bodyMedium(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, height: 1.43, color: ColorsUI.getTextPrimary(b));
  static TextStyle bodySmall(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.33, color: ColorsUI.getTextSecondary(b));

  // ── Specialized ──────────────────────────────────────────────
  static TextStyle currencyLarge(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.22, color: ColorsUI.getTextPrimary(b), fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle currencyMedium(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 24, fontWeight: FontWeight.w700, height: 1.33, color: ColorsUI.getTextPrimary(b), fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle currencySmall(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 16, fontWeight: FontWeight.w600, height: 1.50, color: ColorsUI.getTextPrimary(b), fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle error(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.33, color: ColorsUI.getError(b));
  static TextStyle success(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.33, color: ColorsUI.getSuccess(b));
  static TextStyle helperText(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.33, color: ColorsUI.getTextSecondary(b));
  static TextStyle placeholder(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, height: 1.50, color: ColorsUI.getTextSecondary(b));
  static TextStyle buttonBase() => const TextStyle(fontFamily: primaryFont, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.43);

  // ── SuperNote Specific ───────────────────────────────────────

  /// Για τον editor (note content) — μεγαλύτερο line height για ευκολία ανάγνωσης
  static TextStyle editorBody(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 16, fontWeight: FontWeight.w400, height: 1.75, letterSpacing: 0.3, color: ColorsUI.getTextPrimary(b));

  /// Για headings μέσα στον editor
  static TextStyle editorH1(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 26, fontWeight: FontWeight.w700, height: 1.3, color: ColorsUI.getTextPrimary(b));
  static TextStyle editorH2(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 22, fontWeight: FontWeight.w600, height: 1.3, color: ColorsUI.getTextPrimary(b));
  static TextStyle editorH3(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 18, fontWeight: FontWeight.w600, height: 1.3, color: ColorsUI.getTextPrimary(b));

  /// Για code blocks
  static TextStyle editorCode(Brightness b) => TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w400, height: 1.6, letterSpacing: 0.5, color: ColorsUI.getTextPrimary(b));

  /// Για streak number (habits)
  static TextStyle streakNumber(Brightness b) => TextStyle(fontFamily: primaryFont, fontSize: 42, fontWeight: FontWeight.w800, height: 1.0, color: ColorsUI.getTextPrimary(b), fontFeatures: const [FontFeature.tabularFigures()]);

  static TextTheme getTextTheme(Brightness b) => TextTheme(
    displayLarge: displayLarge(b),
    displayMedium: displayMedium(b),
    displaySmall: displaySmall(b),
    headlineLarge: headlineLarge(b),
    headlineMedium: headlineMedium(b),
    headlineSmall: headlineSmall(b),
    titleLarge: titleLarge(b),
    titleMedium: titleMedium(b),
    titleSmall: titleSmall(b),
    bodyLarge: bodyLarge(b),
    bodyMedium: bodyMedium(b),
    bodySmall: bodySmall(b),
    labelLarge: labelLarge(b),
    labelMedium: labelMedium(b),
    labelSmall: labelSmall(b),
  );
}

// ════════════════════════════════════════════════════════════════
// EXTENSIONS
// ════════════════════════════════════════════════════════════════

extension TextStyleX on TextStyle {
  TextStyle get bold     => copyWith(fontWeight: FontWeight.w700);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get italic   => copyWith(fontStyle: FontStyle.italic);
  TextStyle get underline => copyWith(decoration: TextDecoration.underline);
  TextStyle get strikethrough => copyWith(decoration: TextDecoration.lineThrough);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
  TextStyle withOpacity(double opacity) => copyWith(color: color?.withValues(alpha:opacity));
}

extension ThemeContextX on BuildContext {
  Brightness get brightness => Theme.of(this).brightness;
  bool get isDark => brightness == Brightness.dark;

  // ── Colors ───────────────────────────────────────────────────
  Color get cPrimary    => ColorsUI.getPrimary(brightness);
  Color get cOnPrimary  => ColorsUI.getOnPrimary(brightness);
  Color get cSecondary  => ColorsUI.getSecondary(brightness);
  Color get cBg         => ColorsUI.getBackground(brightness);
  Color get cSurface    => ColorsUI.getSurface(brightness);
  Color get cCard       => ColorsUI.getCard(brightness);
  Color get cText       => ColorsUI.getTextPrimary(brightness);
  Color get cText2      => ColorsUI.getTextSecondary(brightness);
  Color get cText3      => ColorsUI.getTextTertiary(brightness);
  Color get cDisabled   => ColorsUI.getTextDisabled(brightness);
  Color get cBorder     => ColorsUI.getBorder(brightness);
  Color get cDivider    => ColorsUI.getDivider(brightness);
  Color get cError      => ColorsUI.getError(brightness);
  Color get cSuccess    => ColorsUI.getSuccess(brightness);
  Color get cWarning    => ColorsUI.getWarning(brightness);
  Color get cInfo       => ColorsUI.getInfo(brightness);
  Color get cInputFill  => ColorsUI.getInputFill(brightness);

  // SuperNote-specific
  Color itemTypeColor(ItemType type) => ColorsUI.itemTypeColor(type, brightness);
  Color priorityColor(ItemPriority p) => ColorsUI.priorityColor(p, brightness);
  Color priorityColorSoft(ItemPriority p) => ColorsUI.priorityColorSoft(p, brightness);
  Color get cPinned => ColorsUI.pinnedColor(brightness);

  // ── Typography ───────────────────────────────────────────────
  TextStyle get h1 => TypographyUI.headlineLarge(brightness);
  TextStyle get h2 => TypographyUI.headlineMedium(brightness);
  TextStyle get h3 => TypographyUI.headlineSmall(brightness);

  TextStyle get titleLg => TypographyUI.titleLarge(brightness);
  TextStyle get titleMd => TypographyUI.titleMedium(brightness);
  TextStyle get titleSm => TypographyUI.titleSmall(brightness);

  TextStyle get bodyLg => TypographyUI.bodyLarge(brightness);
  TextStyle get bodyMd => TypographyUI.bodyMedium(brightness);
  TextStyle get bodySm => TypographyUI.bodySmall(brightness);

  TextStyle get labelLg => TypographyUI.labelLarge(brightness);
  TextStyle get labelMd => TypographyUI.labelMedium(brightness);
  TextStyle get labelSm => TypographyUI.labelSmall(brightness);

  TextStyle get moneyLg => TypographyUI.currencyLarge(brightness);
  TextStyle get moneyMd => TypographyUI.currencyMedium(brightness);
  TextStyle get moneySm => TypographyUI.currencySmall(brightness);

  TextStyle get btn        => TypographyUI.buttonBase();
  TextStyle get helper     => TypographyUI.helperText(brightness);
  TextStyle get errorStyle => TypographyUI.error(brightness);

  // Editor
  TextStyle get editorBody => TypographyUI.editorBody(brightness);
  TextStyle get editorH1   => TypographyUI.editorH1(brightness);
  TextStyle get editorH2   => TypographyUI.editorH2(brightness);
  TextStyle get editorH3   => TypographyUI.editorH3(brightness);
  TextStyle get editorCode => TypographyUI.editorCode(brightness);
}