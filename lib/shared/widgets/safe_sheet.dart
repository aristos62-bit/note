// lib/shared/widgets/safe_sheet.dart
//
// SPoT sheet shell — γενίκευση του canonical pattern:
//   SafeArea > Column(min) > SheetHandle + title + Flexible > SingleChildScrollView
// (βλ. FolderCreateSheet, color-picker sheet).
// Type A (inner-pop) → `child:`. Type B (wrapped-callback) → `builder:`
// (δίνει sheetCtx — ποτέ blind pop με caller-ctx).
// `useSafeArea` ΔΕΝ εκτίθεται σκόπιμα (διπλό SafeArea — το φέρνει το SafeSheet).
//
// ΧΡΗΣΗ:
//   await showSafeSheet<ItemType?>(context, child: SafeSheet(
//     title: 'Επέλεξε',
//     child: Column(mainAxisSize: MainAxisSize.min, children: [...]),
//     actions: [FilledButton(...), OutlinedButton(...)],
//   ));
//   await showSafeSheet<String>(context, scrollControlled: true,
//     builder: (sheetCtx) => SafeSheet(
//       child: Column(children: [
//         ListTile(onTap: () => Navigator.pop(sheetCtx, 'a')),
//       ])));
//
import 'package:flutter/material.dart';
import '../../core/core.dart';
import 'sheet_handle.dart';

/// Κοινό chrome για sheets (surface + bottomSheet shape).
/// Το pop γίνεται με sheet-context στον caller (όχι blind pop).
/// Type A (inner-pop: το pop γίνεται ΜΕΣΑ στο subtree) → `child:`.
/// Type B (wrapped-callback: _popAnd/closures έξω από το sheet) → `builder:`
/// (δίνει sheetCtx — ποτέ blind pop με caller-ctx).
/// `useSafeArea` ΔΕΝ εκτίθεται σκόπιμα (διπλό SafeArea — το φέρνει το SafeSheet).
typedef SheetChildBuilder = Widget Function(BuildContext sheetCtx);

Future<T?> showSafeSheet<T>(
  BuildContext context, {
  Widget? child,
  SheetChildBuilder? builder,
  bool scrollControlled = false,
  Color? barrierColor,
}) {
  if (child == null && builder == null) {
    throw ArgumentError(
        'showSafeSheet: δώσε child ή builder (ένα από τα δύο)');
  }
  if (child != null && builder != null) {
    throw ArgumentError('showSafeSheet: μόνο ένα από child/builder');
  }
  DebugConfig.nav(
      'showSafeSheet scrollControlled=$scrollControlled barrier=${barrierColor != null}');
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    barrierColor: barrierColor,
    backgroundColor: ColorsUI.getSurface(context.brightness),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppRadius.bottomSheet),
        topRight: Radius.circular(AppRadius.bottomSheet),
      ),
    ),
    builder: (sheetCtx) => builder != null ? builder(sheetCtx) : child!,
  );
}

class SafeSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final List<Widget>? actions;

  const SafeSheet({
    super.key,
    this.title,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(
              margin: EdgeInsets.symmetric(vertical: Spacing.sm),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg, vertical: Spacing.xs),
                child: Text(title!,
                    style: context.titleSm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: child,
              ),
            ),
            if (actions != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.responsiveHPadding,
                  Spacing.sm,
                  context.responsiveHPadding,
                  Spacing.sm,
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: Spacing.sm),
                      Expanded(child: actions![i]),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
