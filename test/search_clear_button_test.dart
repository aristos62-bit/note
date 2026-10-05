// test/search_clear_button_test.dart
//
// SearchClearButton SPoT (Φ4a βήμα 4):
// ζωντανό X χωρίς parent setState, clear + onCleared, iconSize.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/shared/widgets/search_clear_button.dart';

Widget _wrap(TextEditingController ctrl, {VoidCallback? onCleared, double iconSize = 24}) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.light),
    home: Scaffold(
      body: SearchClearButton(
        controller: ctrl,
        onCleared: onCleared,
        iconSize: iconSize,
      ),
    ),
  );
}

void main() {
  testWidgets('empty → SizedBox, typing → X χωρίς parent setState',
      (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (_) {
          builds++;
          return SearchClearButton(controller: ctrl);
        }),
      ),
    ));
    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    final before = builds;

    // Πληκτρολόγηση: ο builder του ValueListenableBuilder ξανατρέχει,
    // το parent ΔΕΝ ξαναχτίζεται (regression test του bug).
    ctrl.text = 'αβγ';
    await tester.pump();
    expect(builds, before);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('tap X → κενό controller + onCleared 1×', (tester) async {
    final ctrl = TextEditingController(text: 'query');
    addTearDown(ctrl.dispose);
    var cleared = 0;
    await tester.pumpWidget(
        _wrap(ctrl, onCleared: () => cleared++));
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(ctrl.text, isEmpty);
    expect(cleared, 1);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('iconSize default 24 / custom 20', (tester) async {
    final ctrl = TextEditingController(text: 'x');
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(_wrap(ctrl));
    var icon = tester.widget<Icon>(find.byIcon(Icons.close_rounded));
    expect(icon.size, 24);
    await tester.pumpWidget(_wrap(ctrl, iconSize: 20));
    icon = tester.widget<Icon>(find.byIcon(Icons.close_rounded));
    expect(icon.size, 20);
  });

  testWidgets('χωρίς onCleared → clear χωρίς crash', (tester) async {
    final ctrl = TextEditingController(text: 'y');
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(_wrap(ctrl));
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(ctrl.text, isEmpty);
  });

  testWidgets('tooltip Καθαρισμός αναζήτησης', (tester) async {
    final ctrl = TextEditingController(text: 'z');
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(_wrap(ctrl));
    final btn = tester.widget<IconButton>(find.byType(IconButton));
    expect(btn.tooltip, 'Καθαρισμός αναζήτησης');
  });
}
