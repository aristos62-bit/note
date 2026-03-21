// lib/core/utils/transitions.dart
//
// Page transitions για όλη την εφαρμογή.
//
// ΧΡΗΣΗ με GoRouter (pageBuilder αντί builder):
//   pageBuilder: (context, state, child) =>
//       AppTransitions.slideUp(state, child)
//
// ΧΡΗΣΗ με Navigator.push:
//   Navigator.of(context).push(AppTransitions.slideRoute(NoteDetailScreen(...)))
//
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_spacing.dart';

// ════════════════════════════════════════════════════════════════
// APP TRANSITIONS
// ════════════════════════════════════════════════════════════════

class AppTransitions {
  AppTransitions._();

  // ── GoRouter CustomTransitionPage ────────────────────────────

  /// Slide από δεξιά (default για detail screens)
  static CustomTransitionPage<void> slideRight(
      GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key:             state.pageKey,
      child:           child,
      transitionDuration:        AppDuration.page,
      reverseTransitionDuration: AppDuration.page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end:   Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve:  Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  /// Slide από κάτω (για modals, detail creation)
  static CustomTransitionPage<void> slideUp(
      GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key:             state.pageKey,
      child:           child,
      transitionDuration:        AppDuration.page,
      reverseTransitionDuration: AppDuration.page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.3),
            end:   Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve:  Curves.easeOutCubic,
          )),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  /// Fade (για tab switches μέσα στο Shell)
  static CustomTransitionPage<void> fade(
      GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key:             state.pageKey,
      child:           child,
      transitionDuration:        AppDuration.normal,
      reverseTransitionDuration: AppDuration.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
              parent: animation, curve: Curves.easeIn),
          child: child,
        );
      },
    );
  }

  // ── Navigator.push MaterialPageRoute alternatives ────────────

  /// Slide από δεξιά — χρησιμοποίησε αντί για MaterialPageRoute
  static Route<T> slideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder:   (_, __, ___) => page,
      transitionDuration:        AppDuration.page,
      reverseTransitionDuration: AppDuration.page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end:   Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve:  Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  /// Slide από κάτω — για detail screens που ανοίγουν σαν modal
  static Route<T> slideUpRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration:        AppDuration.page,
      reverseTransitionDuration: AppDuration.page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.3),
            end:   Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve:  Curves.easeOutCubic,
          )),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  /// Fade — για screens χωρίς ιεραρχία (search, settings)
  static Route<T> fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration:        AppDuration.normal,
      reverseTransitionDuration: AppDuration.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
              parent: animation, curve: Curves.easeIn),
          child: child,
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ANIMATED WIDGETS — για micro-animations μέσα στις σελίδες
// ════════════════════════════════════════════════════════════════

/// Fade-in + slide-up όταν εμφανίζεται το widget
class AppFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset; // πόσο pixels από κάτω

  const AppFadeSlide({
    super.key,
    required this.child,
    this.delay      = Duration.zero,
    this.duration   = AppDuration.normal,
    this.slideOffset = 16.0,
  });

  @override
  State<AppFadeSlide> createState() => _AppFadeSlideState();
}

class _AppFadeSlideState extends State<AppFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>  _fade;
  late final Animation<Offset>  _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: widget.duration,
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset / 100),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Staggered list animation — κάθε item εμφανίζεται με delay
class AppStaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration itemDelay;

  const AppStaggeredList({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 60),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(children.length, (i) => AppFadeSlide(
        delay: itemDelay * i,
        child: children[i],
      )),
    );
  }
}

/// Pulse animation — για loading indicators, empty states
class AppPulse extends StatefulWidget {
  final Widget child;
  const AppPulse({super.key, required this.child});

  @override
  State<AppPulse> createState() => _AppPulseState();
}

class _AppPulseState extends State<AppPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _anim, child: widget.child);
}