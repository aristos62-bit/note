// test/settings_import_progress_dialog_test.dart
//
// S256/F9 — widget test για το SettingsImportProgressDialog.
//
// Pure: με `contacts: []` το importContacts επιστρέφει στο
// contact_import_service.dart:111, πριν αγγίξει Isar/πλατφόρμα → χωρίς DB.
//
// Τι επαληθεύει: η ροή κάνει ΑΚΡΙΒΩΣ ένα pop (S256/F9: το pop γίνεται από τη
// ροή μετά το await και όχι από το `build`) και το από-κάτω route (οι
// Ρυθμίσεις) μένει στο stack.
//
// ΟΡΙΟ (ειλικρινές): η παλιά υλοποίηση (pop μέσα στο build) εκδηλωνόταν σε
// παράθυρο sub-frame· δεν αναπαράγεται ντετερμινιστικά χωρίς Isar, άρα αυτό
// είναι contract/guard test (όχι red-on-old repro).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/features/settings/settings_contacts_dialogs.dart';
import 'package:super_note/services/services.dart';

/// Καταγράφει τα pop του Navigator.
class _PopSpy extends NavigatorObserver {
  final List<Route<dynamic>> popped = [];

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
    super.didPop(route, previousRoute);
  }
}

void main() {
  // parity με τη ροή (settings_contacts_flow.dart:74)
  Widget buildApp(NavigatorObserver observer) => MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<ImportResult>(
                  context: context,
                  barrierDismissible: false,
                  useRootNavigator: true,
                  builder: (_) => const SettingsImportProgressDialog(
                    contacts: [],
                    fields: [],
                    workspaceId: 1,
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

  Future<void> openDialog(WidgetTester tester, NavigatorObserver observer) async {
    await tester.pumpWidget(buildApp(observer));
    await tester.tap(find.text('OPEN'));
    await tester.pump(); // push του route (initState → _startImport)
    await tester.pump(); // microtask: ολοκληρώνεται το importContacts → pop
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
  }

  testWidgets('F9: ένα pop — το dialog κλείνει και το από-κάτω route μένει',
      (tester) async {
    final spy = _PopSpy();

    await openDialog(tester, spy);
    await settle(tester);

    expect(find.byType(SettingsImportProgressDialog), findsNothing,
        reason: 'το dialog πρέπει να έχει κλείσει');
    expect(find.text('OPEN'), findsOneWidget,
        reason: 'διπλό pop θα έκλεινε και το από-κάτω route');
    expect(spy.popped.length, 1, reason: 'πρέπει να γίνει ΑΚΡΙΒΩΣ ένα pop');
    expect(tester.takeException(), isNull);
  });
}
