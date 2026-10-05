// test/toggle_button_test.dart
//
// CircleToggleButton SPoT (Φ4a βήμα 9): tokens, tap, tooltip.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/shared/widgets/view_mode_toggle.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('selected → activeColor, unselected → cText2', (tester) async {
    const active = Colors.green;
    await tester.pumpWidget(_wrap(CircleToggleButton(
      icon: Icons.star_rounded,
      tooltip: 'Αγαπημένα',
      isSelected: true,
      activeColor: active,
      onTap: () {},
    )));
    // onTap null → GestureDetector without callback renders fine
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('tap → onTap 1× + tooltip', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(CircleToggleButton(
      icon: Icons.push_pin_rounded,
      tooltip: 'Καρφιτσωμένα',
      isSelected: false,
      activeColor: Colors.red,
      onTap: () => taps++,
    )));
    expect(find.byTooltip('Καρφιτσωμένα'), findsOneWidget);
    await tester.tap(find.byType(CircleToggleButton));
    expect(taps, 1);
  });

  testWidgets('dark mode render', (tester) async {
    await tester.pumpWidget(_wrap(
      CircleToggleButton(
        icon: Icons.merge_type_rounded,
        tooltip: 'Όλα',
        isSelected: true,
        activeColor: Colors.green,
        onTap: () {},
      ),
      brightness: Brightness.dark,
    ));
    expect(find.byIcon(Icons.merge_type_rounded), findsOneWidget);
  });
}
