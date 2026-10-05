// test/sheet_handle_test.dart
//
// SPoT grabber bottom sheets: 40x4, cBorder default, Spacing.xxs radius.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/shared/widgets/sheet_handle.dart';

Widget _wrap(Widget child, {Brightness b = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: b),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('SheetHandle renders 40x4 with border color (light)',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const SheetHandle(margin: EdgeInsets.symmetric(vertical: Spacing.sm)),
    ));
    final container =
        tester.widget<Container>(find.byType(Container).first);
    expect(
      container.constraints,
      BoxConstraints.tight(const Size(40, 4)),
    );
    final box = container.decoration! as BoxDecoration;
    expect(box.color, ColorsUI.getBorder(Brightness.light));
    expect(
      box.borderRadius,
      BorderRadius.circular(Spacing.xxs),
    );
    final size = tester.getSize(find.byType(SheetHandle));
    expect(size, const Size(40, 20)); // 4 + δύο sm margins (8+8)
  });

  testWidgets('SheetHandle respects custom color + dark mode', (tester) async {
    const custom = Color(0xFFFF0000);
    await tester.pumpWidget(_wrap(
      const SheetHandle(color: custom),
      b: Brightness.dark,
    ));
    final container =
        tester.widget<Container>(find.byType(Container).first);
    final box = container.decoration! as BoxDecoration;
    expect(box.color, custom);
  });

  testWidgets('SheetHandle default margin is null', (tester) async {
    await tester.pumpWidget(_wrap(const SheetHandle()));
    final container =
        tester.widget<Container>(find.byType(Container).first);
    expect(container.margin, null);
  });
}
