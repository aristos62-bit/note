// lib/core/utils/responsive.dart
//
// Responsive utilities για SuperNote.
// Breakpoints: Mobile < 600, Tablet 600-1024, Desktop > 1024
//
// ΧΡΗΣΗ:
//   // Breakpoint check
//   if (context.isMobile) ...
//   if (context.isTablet) ...
//
//   // Adaptive value
//   final cols = context.responsive(mobile: 1, tablet: 2, desktop: 3);
//   final pad  = context.responsivePadding;
//
//   // Adaptive layout widget
//   ResponsiveLayout(
//     mobile:  MobileView(),
//     tablet:  TabletView(),   // optional — fallback to mobile
//     desktop: DesktopView(),  // optional — fallback to tablet
//   )
//
//   // Adaptive grid
//   ResponsiveGrid(
//     children: items.map((i) => ItemCard(item: i)).toList(),
//   )
//
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'debug_config.dart';

// ════════════════════════════════════════════════════════════════
// BREAKPOINTS
// ════════════════════════════════════════════════════════════════

class Breakpoints {
  Breakpoints._();

  static const double mobile  = 600;
  static const double tablet  = 1024;
  // desktop = > 1024

  static ScreenSize of(double width) {
    if (width < mobile)  return ScreenSize.mobile;
    if (width < tablet)  return ScreenSize.tablet;
    return ScreenSize.desktop;
  }
}

enum ScreenSize { mobile, tablet, desktop }

// ════════════════════════════════════════════════════════════════
// CONTEXT EXTENSIONS
// ════════════════════════════════════════════════════════════════

extension ResponsiveContextX on BuildContext {
  double get screenWidth  => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  ScreenSize get screenSize => Breakpoints.of(screenWidth);

  bool get isMobile  => screenSize == ScreenSize.mobile;
  bool get isTablet  => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;
  bool get isWide    => !isMobile; // tablet ή desktop

  /// Επιστρέφει τιμή ανάλογα με το breakpoint.
  /// Αν tablet/desktop δεν οριστεί, χρησιμοποιεί το αμέσως μικρότερο.
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    switch (screenSize) {
      case ScreenSize.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.mobile:
        return mobile;
    }
  }

  // ── Padding ──────────────────────────────────────────────────

  /// Horizontal padding της σελίδας ανάλογα με screen size
  EdgeInsets get responsivePadding => EdgeInsets.symmetric(
    horizontal: responsive(
      mobile:  Spacing.pagePadding,
      tablet:  Spacing.xl,
      desktop: Spacing.xxxl,
    ),
    vertical: Spacing.pagePadding,
  );

  /// Μόνο horizontal padding
  double get responsiveHPadding => responsive(
    mobile:  Spacing.pagePadding,
    tablet:  Spacing.xl,
    desktop: Spacing.xxxl,
  );

  // ── Grid columns ─────────────────────────────────────────────

  /// Αριθμός στηλών για item grid
  int get gridColumns => responsive(mobile: 1, tablet: 2, desktop: 3);

  /// Αριθμός στηλών για compact grid (πχ tags, chips)
  int get chipColumns => responsive(mobile: 2, tablet: 3, desktop: 4);

  // ── Typography scale ─────────────────────────────────────────

  /// Scale factor για typography σε μεγαλύτερα screens
  double get textScale => responsive(mobile: 1.0, tablet: 1.05, desktop: 1.1);

  // ── Navigation ───────────────────────────────────────────────

  /// Χρησιμοποίησε side navigation σε tablet/desktop
  bool get useSideNav => isWide;

  /// Χρησιμοποίησε bottom nav σε mobile
  bool get useBottomNav => isMobile;
}

// ════════════════════════════════════════════════════════════════
// RESPONSIVE LAYOUT WIDGET
// ════════════════════════════════════════════════════════════════

/// Εμφανίζει διαφορετικό widget ανάλογα με το breakpoint.
/// Fallback: desktop → tablet → mobile
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    DebugConfig.print('ResponsiveLayout: ${context.screenSize.name} (${context.screenWidth.toInt()}px)');

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.of(constraints.maxWidth);
        switch (size) {
          case ScreenSize.desktop:
            return desktop ?? tablet ?? mobile;
          case ScreenSize.tablet:
            return tablet ?? mobile;
          case ScreenSize.mobile:
            return mobile;
        }
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RESPONSIVE GRID
// ════════════════════════════════════════════════════════════════

/// Grid που αλλάζει στήλες ανάλογα με το breakpoint.
/// Χρησιμοποιείται για item lists σε tablet/desktop.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? mobileCols;
  final int? tabletCols;
  final int? desktopCols;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileCols,
    this.tabletCols,
    this.desktopCols,
    this.spacing = Spacing.sm,
    this.runSpacing = Spacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.of(constraints.maxWidth);
        final cols = switch (size) {
          ScreenSize.desktop => desktopCols ?? tabletCols ?? mobileCols ?? 3,
          ScreenSize.tablet  => tabletCols  ?? mobileCols ?? 2,
          ScreenSize.mobile  => mobileCols  ?? 1,
        };

        if (cols == 1) {
          // Απλή λίστα — πιο efficient από GridView
          return Column(
            children: children
                .expand((w) => [w, SizedBox(height: runSpacing)])
                .toList()
              ..removeLast(),
          );
        }

        // Multi-column grid
        final itemWidth =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((w) => SizedBox(width: itemWidth, child: w))
              .toList(),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RESPONSIVE SCAFFOLD
// ════════════════════════════════════════════════════════════════

/// Scaffold που εμφανίζει:
/// - Mobile:  BottomNavigationBar
/// - Tablet/Desktop: NavigationRail ή Drawer αριστερά
class ResponsiveScaffold extends StatelessWidget {
  final String title;
  final int selectedIndex;
  final List<ResponsiveNavItem> navItems;
  final ValueChanged<int> onNavTap;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? appBarActions;

  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.navItems,
    required this.onNavTap,
    required this.body,
    this.floatingActionButton,
    this.appBarActions,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _MobileScaffold(
        title: title,
        selectedIndex: selectedIndex,
        navItems: navItems,
        onNavTap: onNavTap,
        body: body,
        floatingActionButton: floatingActionButton,
        appBarActions: appBarActions,
      ),
      tablet: _TabletScaffold(
        title: title,
        selectedIndex: selectedIndex,
        navItems: navItems,
        onNavTap: onNavTap,
        body: body,
        floatingActionButton: floatingActionButton,
        appBarActions: appBarActions,
      ),
    );
  }
}

class ResponsiveNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const ResponsiveNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

// ── Mobile Scaffold ───────────────────────────────────────────────

class _MobileScaffold extends StatelessWidget {
  final String title;
  final int selectedIndex;
  final List<ResponsiveNavItem> navItems;
  final ValueChanged<int> onNavTap;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? appBarActions;

  const _MobileScaffold({
    required this.title,
    required this.selectedIndex,
    required this.navItems,
    required this.onNavTap,
    required this.body,
    this.floatingActionButton,
    this.appBarActions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: appBarActions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onNavTap,
        destinations: navItems
            .map((item) => NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.selectedIcon),
          label: item.label,
        ))
            .toList(),
      ),
    );
  }
}

// ── Tablet/Desktop Scaffold ───────────────────────────────────────

class _TabletScaffold extends StatelessWidget {
  final String title;
  final int selectedIndex;
  final List<ResponsiveNavItem> navItems;
  final ValueChanged<int> onNavTap;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? appBarActions;

  const _TabletScaffold({
    required this.title,
    required this.selectedIndex,
    required this.navItems,
    required this.onNavTap,
    required this.body,
    this.floatingActionButton,
    this.appBarActions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: appBarActions,
      ),
      body: Row(
        children: [
          // NavigationRail αριστερά
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onNavTap,
            labelType: context.isDesktop
                ? NavigationRailLabelType.all
                : NavigationRailLabelType.selected,
            destinations: navItems
                .map((item) => NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: Text(item.label),
            ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Κύριο περιεχόμενο
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADAPTIVE PADDING WIDGET
// ════════════════════════════════════════════════════════════════

/// Wraps παιδί με responsive padding.
class AdaptivePadding extends StatelessWidget {
  final Widget child;
  final bool vertical;

  const AdaptivePadding({
    super.key,
    required this.child,
    this.vertical = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: vertical
          ? context.responsivePadding
          : EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
      child: child,
    );
  }
}