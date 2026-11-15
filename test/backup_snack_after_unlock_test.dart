// test/backup_snack_after_unlock_test.dart
//
// S-314: τα terminal snackbars των ροών αντιγράφου (export/import/attachment)
// περιμένουν ξεκλείδωμα πριν εμφανιστούν — αλλιώς ζωγραφίζονται κάτω από το
// lock overlay και λήγουν αόρατα (default 4s).
//
// Εδώ ελέγχεται το συμβόλαιο του `waitUntilContentUnblocked` πάνω στο σήμα
// `appContentBlockedProvider` (το ίδιο που χρησιμοποιεί και το back-block).
// Η σύνθεση του σήματος από gate + PIN lock καλύπτεται από `lock_gate_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/providers/providers.dart';

/// Controllable «blocked» πηγή για το test.
final _blockedProvider = StateProvider<bool>((ref) => true);

ProviderContainer _container({bool blocked = true}) {
  final container = ProviderContainer(overrides: [
    appContentBlockedProvider
        .overrideWith((ref) => ref.watch(_blockedProvider)),
    _blockedProvider.overrideWith((ref) => blocked),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Probe που αναπαράγει το `_notify` των ροών: περιμένει unblock και μετά
/// δείχνει το snackbar (ή καταγράφει timeout χωρίς να δείξει τίποτα).
class _Probe extends ConsumerWidget {
  const _Probe({required this.log, this.timeout});

  final List<String> log;
  final Duration? timeout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final ok = await waitUntilContentUnblocked(
              ref,
              timeout: timeout ?? const Duration(minutes: 2),
            );
            if (!ok) {
              log.add('timeout');
              return;
            }
            log.add('shown');
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('done')));
          },
          child: const Text('go'),
        ),
      ),
    );
  }
}

Widget _app(ProviderContainer container, _Probe probe) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: probe),
  );
}

void main() {
  testWidgets('κλειδωμένο → δεν εμφανίζεται· unlock → εμφανίζεται μία φορά',
      (tester) async {
    final container = _container(blocked: true);
    final log = <String>[];
    await tester.pumpWidget(_app(container, _Probe(log: log)));

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('done'), findsNothing);
    expect(log, isEmpty);

    // Ο χρήστης ξεκλειδώνει.
    container.read(_blockedProvider.notifier).state = false;
    await tester.pump();
    await tester.pump();

    expect(find.text('done'), findsOneWidget);
    expect(log, ['shown']);
    // Δεν εμφανίστηκε δεύτερη φορά.
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('timeout → δεν εμφανίζεται τίποτα και δεν κρεμάει',
      (tester) async {
    final container = _container(blocked: true);
    final log = <String>[];
    await tester.pumpWidget(_app(
      container,
      _Probe(log: log, timeout: const Duration(seconds: 5)),
    ));

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('done'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.text('done'), findsNothing);
    expect(log, ['timeout']);
  });

  testWidgets('ελεύθερο περιεχόμενο → αμέσως, χωρίς αναμονή', (tester) async {
    final container = _container(blocked: false);
    final log = <String>[];
    await tester.pumpWidget(_app(container, _Probe(log: log)));

    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.text('done'), findsOneWidget);
    expect(log, ['shown']);
  });
}
