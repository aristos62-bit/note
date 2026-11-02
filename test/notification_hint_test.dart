// test/notification_hint_test.dart
//
// E08 (S284): dumb widgets — πίνακας ορατότητας, προτεραιότητα in-app,
// compact icon size, pin του Windows κειμένου (S202 parity) και 140%/στενό
// πλάτος χωρίς overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/services/notification_permission.dart';
import 'package:super_note/shared/widgets/notification_hint.dart';

Widget _wrap(Widget child, {double textScale = 1.0, double width = 360}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('denied + in-app ON → μήνυμα συστήματος', (tester) async {
    await tester.pumpWidget(_wrap(const NotificationPermissionHint(
      osState: NotificationPermissionState.denied,
      inAppEnabled: true,
    )));
    expect(find.text(AppErrors.notifBlockedBySystem), findsOneWidget);
    expect(find.text(AppErrors.notifDisabledInApp), findsNothing);
  });

  testWidgets('in-app OFF έχει προτεραιότητα (1 μόνο μήνυμα)', (tester) async {
    await tester.pumpWidget(_wrap(const NotificationPermissionHint(
      osState: NotificationPermissionState.denied,
      inAppEnabled: false,
    )));
    expect(find.text(AppErrors.notifDisabledInApp), findsOneWidget);
    expect(find.text(AppErrors.notifBlockedBySystem), findsNothing);
  });

  testWidgets('granted → καμία γραμμή', (tester) async {
    await tester.pumpWidget(_wrap(const NotificationPermissionHint(
      osState: NotificationPermissionState.granted,
      inAppEnabled: true,
    )));
    expect(find.byType(NotificationHintRow), findsNothing);
  });

  testWidgets('unknown + inApp null → καμία γραμμή (fail-open)',
      (tester) async {
    await tester.pumpWidget(_wrap(const NotificationPermissionHint(
      osState: NotificationPermissionState.unknown,
    )));
    expect(find.byType(NotificationHintRow), findsNothing);
  });

  testWidgets('compact → σύντομο κείμενο + icon 16 (vs 20)', (tester) async {
    await tester.pumpWidget(_wrap(const NotificationPermissionHint(
      osState: NotificationPermissionState.denied,
      inAppEnabled: true,
      compact: true,
    )));
    expect(find.text(AppErrors.notifBlockedBySystemShort), findsOneWidget);
    expect(tester.widget<Icon>(find.byType(Icon)).size, 16);

    await tester.pumpWidget(_wrap(const NotificationPermissionHint(
      osState: NotificationPermissionState.denied,
      inAppEnabled: true,
    )));
    expect(tester.widget<Icon>(find.byType(Icon)).size, 20);
  });

  testWidgets('Windows hint (S202) παραμένει byte-identical', (tester) async {
    await tester.pumpWidget(_wrap(const NotificationHintRow(
      icon: Icons.info_outline_rounded,
      text: AppErrors.notificationsUnsupportedWindows,
    )));
    expect(find.text(AppErrors.notificationsUnsupportedWindows), findsOneWidget);
  });

  testWidgets('140% σε 296.7 dp → κανένα overflow', (tester) async {
    await tester.pumpWidget(_wrap(
      const NotificationPermissionHint(
        osState: NotificationPermissionState.denied,
        inAppEnabled: true,
      ),
      textScale: 1.4,
      width: 296.7,
    ));
    expect(tester.takeException(), isNull);
    expect(find.text(AppErrors.notifBlockedBySystem), findsOneWidget);
  });
}
