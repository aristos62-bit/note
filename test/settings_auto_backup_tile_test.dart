// test/settings_auto_backup_tile_test.dart
//
// E49 (S304): «Τελευταίο:» στο tile «Αυτόματο αντίγραφο».
//
// Το `lastAutoBackupAt` γράφεται **απευθείας στη DB** από το `BackupService`
// (auto-backup, χωρίς `settingsNotifierProvider`) → το tile πρέπει να διαβάζει
// το live `settingsStreamProvider`, ώστε νέο αντίγραφο να φαίνεται **χωρίς
// restart**. Όσο το stream δεν έχει εκπέμψει, fallback στο snapshot.
//
// Τα 2 invariants:
//  1. stream emission με νέο `lastAutoBackupAt` ⇒ το subtitle αλλάζει.
//  2. χωρίς emission ⇒ το subtitle δείχνει το snapshot (όχι «Ποτέ»).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/features/settings/settings_tiles.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';

final _oldAt = DateTime(2026, 11, 8, 20, 57);
final _newAt = DateTime(2026, 11, 13, 11, 1);

AppSettings _settingsWith(DateTime? last) {
  final s = AppSettings();
  s.autoBackupEnabled = true;
  s.lastAutoBackupAt = last;
  return s;
}

String _expectedLast(DateTime value) =>
    'Τελευταίο: ${AppDateUtils.formatDateTime(value)}';

Future<void> _pump(
  WidgetTester tester,
  StreamController<AppSettings?> controller,
  AppSettings snapshot,
) async {
  await tester.pumpWidget(
    ProviderScope(
      // Το ίδιο stream που ακούει και το `BackupPassphraseGate`.
      overrides: [
        settingsStreamProvider.overrideWith((ref) => controller.stream),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SettingsAutoBackupTile(settings: snapshot),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    // Το `formatDateTime` χρησιμοποιεί DateFormat(..., 'el').
    await initializeDateFormatting('el');
  });

  testWidgets('E49: νέο lastAutoBackupAt από το stream → νέο «Τελευταίο:»',
      (tester) async {
    final controller = StreamController<AppSettings?>();
    addTearDown(controller.close);

    await _pump(tester, controller, _settingsWith(_oldAt));

    expect(find.textContaining(_expectedLast(_oldAt)), findsOneWidget);

    // Ό,τι κάνει το auto-backup: γράφει νέο timestamp στη DB ⇒ stream event.
    controller.add(_settingsWith(_newAt));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining(_expectedLast(_newAt)), findsOneWidget);
    expect(find.textContaining(_expectedLast(_oldAt)), findsNothing);
  });

  testWidgets('E49: χωρίς stream value → fallback στο snapshot',
      (tester) async {
    final controller = StreamController<AppSettings?>();
    addTearDown(controller.close);

    await _pump(tester, controller, _settingsWith(_oldAt));

    expect(find.textContaining(_expectedLast(_oldAt)), findsOneWidget);
    expect(find.textContaining('Τελευταίο: Ποτέ'), findsNothing);
  });
}
