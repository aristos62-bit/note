// lib/core/theme/app_theme.dart
//
// ThemeData για SuperNote — χρησιμοποιεί ColorsUI + TypographyUI.
//
// ΧΡΗΣΗ στο main.dart:
//   MaterialApp(
//     theme:     AppThemeData.light,
//     darkTheme: AppThemeData.dark,
//     themeMode: ThemeMode.system,
//   )
//
import 'package:flutter/material.dart';
import 'ui_tokens.dart';
import 'app_spacing.dart';

class AppThemeData {

  // ─────────────────────────────────────────────────────────────
  // LIGHT
  // ─────────────────────────────────────────────────────────────

  static ThemeData get light => _buildTheme(Brightness.light);

  // ─────────────────────────────────────────────────────────────
  // DARK
  // ─────────────────────────────────────────────────────────────

  static ThemeData get dark => _buildTheme(Brightness.dark);

  // ─────────────────────────────────────────────────────────────
  // BUILDER
  // ─────────────────────────────────────────────────────────────

  static ThemeData _buildTheme(Brightness brightness) {
    final b   = brightness;
    final isL = b == Brightness.light;

    final colorScheme = ColorScheme(
      brightness: b,
      primary:          ColorsUI.getPrimary(b),
      onPrimary:        ColorsUI.getOnPrimary(b),
      secondary:        ColorsUI.getSecondary(b),
      onSecondary:      ColorsUI.getOnSecondary(b),
      tertiary:         ColorsUI.getTertiary(b),
      onTertiary:       ColorsUI.getOnTertiary(b),
      error:            ColorsUI.getError(b),
      onError:          ColorsUI.getOnError(b),
      surface:          ColorsUI.getSurface(b),
      onSurface:        ColorsUI.getTextPrimary(b),
      surfaceContainerHighest: ColorsUI.getCard(b),
      outline:          ColorsUI.getBorder(b),
    );

    return ThemeData(
      useMaterial3:  true,
      brightness:    b,
      colorScheme:   colorScheme,
      textTheme:     TypographyUI.getTextTheme(b),
      scaffoldBackgroundColor: ColorsUI.getBackground(b),

      // ── AppBar ─────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: ColorsUI.getBackground(b),
        foregroundColor: ColorsUI.getTextPrimary(b),
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: ColorsUI.getSurface(b),
        titleTextStyle: TypographyUI.titleLarge(b),
        centerTitle: false,
        iconTheme: IconThemeData(
          color: ColorsUI.getTextPrimary(b),
          size: AppIconSize.md,
        ),
      ),

      // ── Card ───────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: ColorsUI.getCard(b),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBR,
          side: BorderSide(color: ColorsUI.getBorder(b), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Input ──────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColorsUI.getInputFill(b),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputBR,
          borderSide: BorderSide(color: ColorsUI.getInputBorder(b)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBR,
          borderSide: BorderSide(color: ColorsUI.getInputBorder(b)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBR,
          borderSide: BorderSide(
            color: ColorsUI.getInputFocusBorder(b),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBR,
          borderSide: BorderSide(color: ColorsUI.getError(b)),
        ),
        hintStyle: TypographyUI.placeholder(b),
        labelStyle: TypographyUI.bodyMedium(b),
        errorStyle: TypographyUI.error(b),
        floatingLabelStyle: TextStyle(color: ColorsUI.getPrimary(b)),
      ),

      // ── Elevated Button ────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorsUI.getPrimary(b),
          foregroundColor: ColorsUI.getOnPrimary(b),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBR,
          ),
          textStyle: TypographyUI.buttonBase(),
        ),
      ),

      // ── Outlined Button ────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorsUI.getPrimary(b),
          side: BorderSide(color: ColorsUI.getPrimary(b)),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonBR,
          ),
          textStyle: TypographyUI.buttonBase(),
        ),
      ),

      // ── Text Button ────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ColorsUI.getPrimary(b),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.xs,
          ),
          textStyle: TypographyUI.buttonBase(),
        ),
      ),

      // ── FloatingActionButton ───────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ColorsUI.getPrimary(b),
        foregroundColor: ColorsUI.getOnPrimary(b),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // ── BottomNavigationBar ────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: ColorsUI.getSurface(b),
        selectedItemColor: ColorsUI.getPrimary(b),
        unselectedItemColor: ColorsUI.getTextSecondary(b),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TypographyUI.labelSmall(b),
        unselectedLabelStyle: TypographyUI.labelSmall(b),
      ),

      // ── NavigationBar (M3) ─────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ColorsUI.getSurface(b),
        indicatorColor: ColorsUI.getPrimary(b).withValues(alpha:0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TypographyUI.labelSmall(b)
                .copyWith(color: ColorsUI.getPrimary(b));
          }
          return TypographyUI.labelSmall(b)
              .copyWith(color: ColorsUI.getTextSecondary(b));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: ColorsUI.getPrimary(b));
          }
          return IconThemeData(color: ColorsUI.getTextSecondary(b));
        }),
      ),

      // ── Chip ───────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: ColorsUI.getSurface(b),
        selectedColor: ColorsUI.getPrimary(b).withValues(alpha:0.12),
        labelStyle: TypographyUI.labelMedium(b),
        side: BorderSide(color: ColorsUI.getBorder(b)),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.chipBR,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xxs,
        ),
      ),

      // ── ListTile ───────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: Spacing.listItemInsets,
        titleTextStyle: TypographyUI.bodyLarge(b),
        subtitleTextStyle: TypographyUI.bodySmall(b),
        iconColor: ColorsUI.getTextSecondary(b),
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBR,
        ),
      ),

      // ── Divider ────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: ColorsUI.getDivider(b),
        thickness: 1,
        space: 1,
      ),

      // ── Dialog ─────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: ColorsUI.getSurface(b),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.dialogBR,
        ),
        titleTextStyle: TypographyUI.titleLarge(b),
        contentTextStyle: TypographyUI.bodyMedium(b),
      ),

      // ── SnackBar ───────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isL
            ? ColorsUI.textPrimaryLight
            : ColorsUI.textPrimaryDark,
        contentTextStyle: TypographyUI.bodyMedium(b).copyWith(
          color: isL ? Colors.white : Colors.black,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBR,
        ),
      ),

      // ── Switch ─────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ColorsUI.getOnPrimary(b);
          }
          return ColorsUI.getTextDisabled(b);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ColorsUI.getPrimary(b);
          }
          return ColorsUI.getBorder(b);
        }),
      ),

      // ── Checkbox ───────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return ColorsUI.getTextDisabled(b);
          }
          if (states.contains(WidgetState.selected)) {
            return ColorsUI.getPrimary(b);
          }
          return ColorsUI.getSurface(b); // unselected
        }),
        checkColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return ColorsUI.getTextSecondary(b);
          }
          return ColorsUI.getOnPrimary(b);
        }),
        side: BorderSide(color: ColorsUI.getBorder(b), width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      ),
    );
  }
}