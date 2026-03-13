// lib/core/theme/app_spacing.dart
import 'package:flutter/material.dart';
import 'ui_tokens.dart';
import 'dart:ui' as ui;

// ════════════════════════════════════════════════════════════════
// SPACING
// ════════════════════════════════════════════════════════════════

class Spacing {
  Spacing._();

  static const double xxs  = 2.0;
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double xxl  = 48.0;
  static const double xxxl = 64.0;

  // Semantic aliases
  static const double pagePadding     = md;
  static const double cardPadding     = md;
  static const double listItemPadding = sm;
  static const double sectionGap      = lg;
  static const double itemGap         = sm;
  static const double iconTextGap     = sm;
  static const double chipGap         = xs;
  static const double bottomNavHeight = 64.0;
  static const double fabSize         = 56.0;
  static const double appBarHeight    = 56.0;

  // EdgeInsets helpers
  static const EdgeInsets pageInsets   = EdgeInsets.all(pagePadding);
  static const EdgeInsets pageInsetH   = EdgeInsets.symmetric(horizontal: pagePadding);
  static const EdgeInsets pageInsetV   = EdgeInsets.symmetric(vertical: pagePadding);
  static const EdgeInsets cardInsets   = EdgeInsets.all(cardPadding);
  static const EdgeInsets listItemInsets = EdgeInsets.symmetric(
    horizontal: pagePadding,
    vertical: listItemPadding,
  );
}

// ════════════════════════════════════════════════════════════════
// BORDER RADIUS
// ════════════════════════════════════════════════════════════════

class AppRadius {
  AppRadius._();

  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 24.0;
  static const double full = 999.0;

  // Semantic aliases
  static const double button      = md;
  static const double card        = lg;
  static const double chip        = full;
  static const double input       = sm;
  static const double dialog      = xl;
  static const double avatar      = full;
  static const double badge       = full;
  static const double bottomSheet = xl;

  // BorderRadius helpers
  static BorderRadius get cardBR   => BorderRadius.circular(card);
  static BorderRadius get buttonBR => BorderRadius.circular(button);
  static BorderRadius get chipBR   => BorderRadius.circular(chip);
  static BorderRadius get inputBR  => BorderRadius.circular(input);
  static BorderRadius get dialogBR => BorderRadius.circular(dialog);
  static BorderRadius get bottomSheetBR => const BorderRadius.only(
    topLeft:  ui.Radius.circular(bottomSheet),
    topRight: ui.Radius.circular(bottomSheet),
  );
}

// ════════════════════════════════════════════════════════════════
// SHADOWS
// ════════════════════════════════════════════════════════════════

class AppShadows {
  AppShadows._();

  static List<BoxShadow> card(Brightness b) => [
    BoxShadow(
      color: b == Brightness.light
          ? ColorsUI.shadowLight
          : ColorsUI.shadowDark,
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> elevated(Brightness b) => [
    BoxShadow(
      color: b == Brightness.light
          ? ColorsUI.shadowLight
          : ColorsUI.shadowDark,
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> fab(Brightness b) => [
    BoxShadow(
      color: (b == Brightness.light
          ? ColorsUI.primaryLight
          : ColorsUI.primaryDark).withValues(alpha:0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get none => [];
}

// ════════════════════════════════════════════════════════════════
// DURATIONS (animations)
// ════════════════════════════════════════════════════════════════

class AppDuration {
  AppDuration._();

  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast    = Duration(milliseconds: 150);
  static const Duration normal  = Duration(milliseconds: 250);
  static const Duration slow    = Duration(milliseconds: 400);
  static const Duration page    = Duration(milliseconds: 300);
}

// ════════════════════════════════════════════════════════════════
// ICON SIZES
// ════════════════════════════════════════════════════════════════

class AppIconSize {
  AppIconSize._();

  static const double xs  = 14.0;
  static const double sm  = 18.0;
  static const double md  = 24.0;  // default Material icon size
  static const double lg  = 32.0;
  static const double xl  = 48.0;
  static const double xxl = 64.0;

  // Semantic
  static const double navBar    = md;
  static const double listItem  = md;
  static const double fab       = md;
  static const double emptyState = xxl;
  static const double typeIcon  = lg;  // Item type icon σε cards
}
