// test/f18_past_pending_invalidate_test.dart
//
// F18 (S257 — fix 0f289d9): ο `pastPendingRemindersProvider` είναι
// non-autoDispose FutureProvider και η λίστα είναι ΧΡΟΝΙΚΑ εξαρτημένη
// (`getPastPending` = pending + triggerAt < now + rruleIsNull) ΧΩΡΙΣ DB write
// ⇒ μέσα στο session η cached τιμή μένει stale: ληγμένη υπενθύμιση που
// «ωρίμασε» φαινόταν μόνο μετά από cold start.
//
// Fix: `ref.invalidate(pastPendingRemindersProvider)` στο άνοιγμα του dialog
// (settings_reminders_dialog.dart γρ.39 — ίδιος μηχανισμός με το `onApplied`
// της `_deleteReminders`, γρ.29).
//
// Tests ΧΩΡΙΣ Isar:
//  - ο δίαυλος τίτλων `dbProvider.items.getByIds` (γρ.64-74) είναι σε try/catch
//    (by design: «missing items ως πριν») ⇒ με ανενεργό `SuperNoteHelper.instance`
//    το AssertionError πιάνεται, `itemTitles` μένει κενό και οι rows που
//    φαίνονται έχουν τίτλο «Άγνωστο στοιχείο» ⇒ το test δεν χρειάζεται DB.
//  - τα `ctx.bodyMd/cText2/cError` είναι pure static (TypographyUI/ColorsUI ανά
//    brightness) ⇒ αρκεί bare MaterialApp.
//
//  1. [pure Riverpod] contract: non-autoDispose ⇒ CACHED μέχρι invalidate ·
//     invalidate ⇒ recompute. (Guard: αν γίνει autoDispose, το test πέφτει.)
//  2. [widget] συμπεριφορά: το 2ο άνοιγμα του dialog δείχνει ΦΡΕΣΚΙΑ λίστα.
//     red-on-old: με αφαίρεση της γρ.39 ⇒ «Παρελθούσες Υπενθυμίσεις (1)» αντί (2).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:super_note/features/settings/settings_reminders_dialog.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/providers/providers.dart';

Reminder _reminder(int id) => Reminder()
  ..id = id
  ..itemId = 1000 + id
  ..triggerAt = DateTime(2026, 10, 19, 9);

void main() {
  setUpAll(() async {
    // Parity με main.dart:22 (τα DateFormat('…','el') του AppDateUtils απαιτούν
    // αρχικοποίηση locale data — σε tests δεν τρέχει το main()).
    await initializeDateFormatting();
  });

  test('F18: cached (non-autoDispose) μέχρι invalidate · μετά recompute',
      () async {
    var computes = 0;
    final container = ProviderContainer(
      overrides: [
        pastPendingRemindersProvider.overrideWith((ref) async {
          computes++;
          // 1ος υπολογισμός: 1 ληγμένη · 2ος: 2 (μία ακόμη «ωρίμασε» στο session)
          return computes == 1 ? [_reminder(1)] : [_reminder(1), _reminder(2)];
        }),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(pastPendingRemindersProvider.future);
    final second = await container.read(pastPendingRemindersProvider.future);

    expect(computes, 1,
        reason: 'ο provider πρέπει να είναι CACHED (non-autoDispose)');
    expect(first.length, 1);
    expect(second.length, 1,
        reason: 'χωρίς invalidate η τιμή μένει stale (δεν ξαναδιαβάζει)');

    container.invalidate(pastPendingRemindersProvider);
    final third = await container.read(pastPendingRemindersProvider.future);

    expect(computes, 2, reason: 'invalidate ⇒ recompute');
    expect(third.length, 2, reason: 'μετά το invalidate ⇒ φρέσκια λίστα');
  });

  testWidgets('F18: το 2ο άνοιγμα του dialog δείχνει φρέσκια λίστα',
      (tester) async {
    var computes = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pastPendingRemindersProvider.overrideWith((ref) async {
            computes++;
            return computes == 1
                ? [_reminder(1)]
                : [_reminder(1), _reminder(2)];
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showPastRemindersDialog(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    // 1ο άνοιγμα → 1 ληγμένη
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Παρελθούσες Υπενθυμίσεις (1)'), findsOneWidget);
    expect(computes, 1);

    // κλείσιμο («Άκυρο»)
    await tester.tap(find.text('Άκυρο'));
    await tester.pumpAndSettle();
    expect(find.text('Παρελθούσες Υπενθυμίσεις (1)'), findsNothing);

    // 2ο άνοιγμα → το ref.invalidate (F18) πρέπει να δώσει ΦΡΕΣΚΙΑ λίστα
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.text('Παρελθούσες Υπενθυμίσεις (2)'),
      findsOneWidget,
      reason: 'χωρίς το ref.invalidate (γρ.39) μένει stale ⇒ «(1)» (red-on-old)',
    );
    expect(computes, 2, reason: 'ένα recompute ανά άνοιγμα');
  });
}
