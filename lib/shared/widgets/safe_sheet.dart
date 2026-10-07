// lib/shared/widgets/safe_sheet.dart
//
// SPoT sheet shell — γενίκευση του canonical pattern:
//   SafeArea > Column(min) > SheetHandle + title + Flexible > SingleChildScrollView
// (βλ. FolderCreateSheet, color-picker sheet).
// O caller κρατά το δικό του showModalBottomSheet (κατά προτίμηση showSafeSheet)
// και δίνει ΜΟΝΟ στατικό content (Column — ΟΧΙ scrollable, αλλιώς φωλιάζει).
//
// ΧΡΗΣΗ:
//   await showSafeSheet<ItemType?>(context, child: SafeSheet(
//     title: 'Επέλεξε',
//     child: Column(mainAxisSize: MainAxisSize.min, children: [...]),
//     actions: [FilledButton(...), OutlinedButton(...)],
//   ));
//
import 'package:flutter/material.dart';
import '../../core/core.dart';
import 'sheet_handle.dart';

/// Κοινό chrome για sheets (surface + bottomSheet shape).
/// Το pop γίνεται με sheet-context στον caller (όχι blind pop).
Future<T?> showSafeSheet<T>(
  BuildContext context, {
  required Widget child,
  bool scrollControlled = false,
}) {
  DebugConfig.nav('showSafeSheet scrollControlled=$scrollControlled');
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    backgroundColor: ColorsUI.getSurface(context.brightness),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(AppRadius.bottomSheet),
        topRight: Radius.circular(AppRadius.bottomSheet),
      ),
    ),
    builder: (_) => child,
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
                child: Text(title!, style: context.titleSm),
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
