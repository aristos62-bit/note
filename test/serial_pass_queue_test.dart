// test/serial_pass_queue_test.dart
// S246: unit tests για το SPoT `SerialPassQueue` (pure Dart — χωρίς Isar/Flutter binding).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/serial_pass_queue.dart';

void main() {
  group('SerialPassQueue (S246)', () {
    test('1. σειρά: FIFO — ένα pass τη φορά, το επόμενο περιμένει', () async {
      final queue = SerialPassQueue(label: 'Test.queue');
      final events = <String>[];
      final gate = Completer<void>();

      final f1 = queue.run(() async {
        events.add('a-start');
        await gate.future;
        events.add('a-end');
      });
      final f2 = queue.run(() async {
        events.add('b-start');
        events.add('b-end');
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, ['a-start'], reason: 'το b δεν ξεκινά όσο τρέχει το a');

      gate.complete();
      await Future.wait([f1, f2]);
      expect(events, ['a-start', 'a-end', 'b-start', 'b-end']);
    });

    test('2. NEVER-THROW: σφάλμα task δεν διαρρέει· η αλυσίδα συνεχίζει',
        () async {
      final queue = SerialPassQueue(label: 'Test.queue');
      var ranAfter = false;

      await queue.run(() async => throw StateError('boom'));
      await queue.run(() async => ranAfter = true);

      expect(ranAfter, isTrue);
    });

    test('3. timeout: fail-open — το επόμενο pass τρέχει· onTimeout μία φορά',
        () async {
      var timeouts = 0;
      final queue = SerialPassQueue(
        label: 'Test.queue',
        timeout: const Duration(milliseconds: 40),
        onTimeout: () => timeouts++,
      );
      var ranAfter = false;

      await queue.run(() => Completer<void>().future); // δεν ολοκληρώνεται ποτέ
      await queue.run(() async => ranAfter = true);

      expect(timeouts, 1);
      expect(ranAfter, isTrue);
    });

    test('4. χωρίς timeout: onTimeout δεν καλείται', () async {
      var timeouts = 0;
      final queue = SerialPassQueue(
        label: 'Test.queue',
        timeout: const Duration(milliseconds: 40),
        onTimeout: () => timeouts++,
      );

      await queue.run(() async {});

      expect(timeouts, 0);
    });

    test('5. parity: TimeoutException από το ίδιο το task → onTimeout',
        () async {
      var timeouts = 0;
      final queue = SerialPassQueue(
        label: 'Test.queue',
        onTimeout: () => timeouts++,
      );

      await queue.run(() async => throw TimeoutException('task-side'));

      expect(timeouts, 1);
    });

    test('6. independence: δύο instances = ανεξάρτητες ουρές', () async {
      final q1 = SerialPassQueue(label: 'Test.one');
      final q2 = SerialPassQueue(label: 'Test.two');
      final events = <String>[];
      final gate = Completer<void>();

      final f1 = q1.run(() async {
        events.add('q1-start');
        await gate.future;
        events.add('q1-end');
      });
      await q2.run(() async => events.add('q2-done'));

      expect(events, ['q1-start', 'q2-done'],
          reason: 'το q2 δεν μπλοκάρεται από το μπλοκαρισμένο q1');

      gate.complete();
      await f1;
      expect(events, ['q1-start', 'q2-done', 'q1-end']);
    });
  });
}
