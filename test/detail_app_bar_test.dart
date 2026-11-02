// test/detail_app_bar_test.dart
//
// E11: Έλεγχοι για το κοινό DetailAppBar.
// • Σειρά + tooltips ενεργειών.
// • null callback = κρυφή ενέργεια.
// • Save disabled όσο isSaving (spinner + «Αποθήκευση...»).
// • Καμία επικάλυψη με το back / κανένα overflow σε 320dp και 360dp.
//
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/theme/app_spacing.dart';
import 'package:super_note/shared/widgets/detail_app_bar.dart';

/// Το IconButton είναι ancestor του Tooltip (ButtonStyleButton το τυλίγει).
Finder _action(String tip) => find.ancestor(
      of: find.byTooltip(tip),
      matching: find.byType(IconButton),
    );

Widget _host({
  bool isSaving = false,
  bool withReminder = true,
  bool withFavorite = true,
  bool withPin = true,
  bool withArchive = true,
  bool withDelete = true,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true, platform: TargetPlatform.android),
    home: Scaffold(
      appBar: DetailAppBar(
        isSaving: isSaving,
        isFavorite: true,
        isPinned: true,
        isArchived: false,
        onSave: () {},
        onReminder: withReminder ? () {} : null,
        onFavorite: withFavorite ? () {} : null,
        onPin: withPin ? () {} : null,
        onArchive: withArchive ? () {} : null,
        onDelete: withDelete ? () {} : null,
      ),
      body: const SizedBox.shrink(),
    ),
  );
}

void main() {
  test('preferredSize = Spacing.appBarHeight', () {
    expect(const DetailAppBar().preferredSize.height, Spacing.appBarHeight);
    expect(const DetailAppBar().preferredSize.height, 56.0);
  });

  testWidgets('6 ενέργειες, canonical σειρά και tooltips', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.byType(IconButton), findsNWidgets(6));
    for (final String tip in <String>[
      'Αποθήκευση',
      'Υπενθύμιση',
      'Αφαίρεση αγαπημένου',
      'Αποκαρφίτσωμα',
      'Αρχειοθέτηση',
      'Διαγραφή',
    ]) {
      expect(find.byTooltip(tip), findsOneWidget, reason: tip);
    }

    final List<double> xs = <String>[
      'Αποθήκευση',
      'Υπενθύμιση',
      'Αφαίρεση αγαπημένου',
      'Αποκαρφίτσωμα',
      'Αρχειοθέτηση',
      'Διαγραφή',
    ].map((String tip) => tester.getCenter(_action(tip)).dx).toList();
    expect(xs, orderedEquals(<double>[...xs]..sort()));
  });

  testWidgets('null callbacks κρύβουν τις αντίστοιχες ενέργειες',
      (tester) async {
    await tester.pumpWidget(
      _host(withReminder: false, withPin: false, withArchive: false),
    );

    expect(find.byType(IconButton), findsNWidgets(3));
    expect(find.byTooltip('Υπενθύμιση'), findsNothing);
    expect(find.byTooltip('Αποκαρφίτσωμα'), findsNothing);
    expect(find.byTooltip('Αρχειοθέτηση'), findsNothing);
    expect(find.byTooltip('Αποθήκευση'), findsOneWidget);
    expect(find.byTooltip('Αφαίρεση αγαπημένου'), findsOneWidget);
    expect(find.byTooltip('Διαγραφή'), findsOneWidget);
  });

  testWidgets('isSaving: spinner + label, save disabled', (tester) async {
    await tester.pumpWidget(_host(isSaving: true));

    expect(find.text('Αποθήκευση...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final IconButton save = tester.widget<IconButton>(_action('Αποθήκευση'));
    expect(save.onPressed, isNull);

    final IconButton reminder =
        tester.widget<IconButton>(_action('Υπενθύμιση'));
    expect(reminder.onPressed, isNotNull);
  });

  testWidgets('compact density + icon 20', (tester) async {
    await tester.pumpWidget(_host());

    final Size button = tester.getSize(_action('Αποθήκευση'));
    expect(button.width, 40.0);
    expect(button.height, 40.0);

    final Icon icon = tester.widget<Icon>(
      find.descendant(
        of: _action('Αποθήκευση'),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.size, 20.0);
  });

  for (final double width in <double>[320, 360]) {
    testWidgets('${width}dp: 6 ενέργειες χωρίς overflow/επικάλυψη',
        (tester) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_host(isSaving: true));
      await tester.pump();

      expect(tester.takeException(), isNull);

      final double firstX = tester.getTopLeft(_action('Αποθήκευση')).dx;
      // Το back κουμπί καταλαμβάνει τα πρώτα 56dp — καμία επικάλυψη.
      expect(firstX, greaterThanOrEqualTo(56.0));
      expect(firstX, width - 6 * 40.0);
    });
  }
}
