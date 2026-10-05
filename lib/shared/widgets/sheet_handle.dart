// lib/shared/widgets/sheet_handle.dart
//
// SPoT για τη λαβή (grabber) των bottom sheets.
// Extract από ConfirmDialog — 21 πανομοιότυπες μπάρες σε όλο το app.
// Pixel-identical: 40x4, cBorder, radius Spacing.xxs (=2).
//
// ΧΡΗΣΗ:
//   const SheetHandle(margin: EdgeInsets.symmetric(vertical: Spacing.sm)),
//   Center(child: SheetHandle()),  // όπου το sheet είχε Center
//
import 'package:flutter/material.dart';
import '../../core/core.dart';

class SheetHandle extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const SheetHandle({super.key, this.margin, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: color ?? context.cBorder,
        borderRadius: BorderRadius.circular(Spacing.xxs),
      ),
    );
  }
}
