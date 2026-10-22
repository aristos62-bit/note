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
    test('7. maintenance: enqueue gate — το pass σκιπάρεται αμέσως', () async {
      final queue = SerialPassQueue(label: 'Test.queue');
      var ran = false;

      queue.pauseForMaintenance();
      expect(queue.isPaused, isTrue);
      expect(queue.isIdle, isTrue);

      await queue.run(() async => ran = true);
      expect(ran, isFalse, reason: 'μετά το pause δεν εκτελείται νέο pass');

      queue.resumeAfterMaintenance();
      await queue.run(() async => ran = true);
      await Future<void>.delayed(Duration.zero);
      expect(ran, isTrue);
      expect(queue.isIdle, isTrue);
    });

    test('8. maintenance: execution gate — pass που περίμενε σκιπάρεται',
            () async {
          final queue = SerialPassQueue(label: 'Test.queue');
          final gate = Completer<void>();
          var bRan = false;

          final f1 = queue.run(() => gate.future);
          final f2 = queue.run(() async => bRan = true);

          await Future<void>.delayed(Duration.zero);
          expect(queue.inFlightCount, 1);

          queue.pauseForMaintenance();
          gate.complete();

          await f1;
          await f2;

          expect(bRan, isFalse, reason: 'το b σκιπαρίστηκε λόγω maintenance');
          expect(queue.isIdle, isTrue);
          queue.resumeAfterMaintenance();
        });

    test('9. waitForIdle: περιμένει το πραγματικό τέλος του pass', () async {
      final queue = SerialPassQueue(label: 'Test.queue');
      final gate = Completer<void>();

      final f = queue.run(() => gate.future);
      await Future<void>.delayed(Duration.zero);
      expect(queue.inFlightCount, 1);

      queue.pauseForMaintenance();
      final sw = Stopwatch()..start();
      final idleFuture = queue.waitForIdle(const Duration(seconds: 2));

      await Future<void>.delayed(const Duration(milliseconds: 80));
      gate.complete();

      expect(await idleFuture, isTrue);
      sw.stop();
      expect(queue.isIdle, isTrue);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(70));

      await f;
      queue.resumeAfterMaintenance();
    });

    test('10. waitForIdle: timeout → false (ο caller κάνει abort)', () async {
      final queue = SerialPassQueue(
        label: 'Test.queue',
        timeout: const Duration(seconds: 5),
      );
      final gate = Completer<void>();

      final f = queue.run(() => gate.future);
      await Future<void>.delayed(Duration.zero);

      queue.pauseForMaintenance();
      final ok = await queue.waitForIdle(const Duration(milliseconds: 100));
      expect(ok, isFalse, reason: 'δεν καθάρισε εντός 100ms');
      expect(queue.inFlightCount, 1);

      gate.complete();
      await f;
      expect(
        await queue.waitForIdle(const Duration(seconds: 1)),
        isTrue,
      );
      expect(queue.isIdle, isTrue);

      queue.resumeAfterMaintenance();
    });

    test('11. zombie (F2): timeout ≠ τέλος — το in-flight μένει μέχρι το πραγματικό',
            () async {
          var timeouts = 0;
          final queue = SerialPassQueue(
            label: 'Test.queue',
            timeout: const Duration(milliseconds: 40),
            onTimeout: () => timeouts++,
          );
          final gate = Completer<void>();

          await queue.run(() => gate.future);

          expect(timeouts, 1);
          expect(queue.inFlightCount, 1,
              reason: 'το task τρέχει ακόμη μετά το fail-open timeout');

          gate.completeError(StateError('late boom'));

          expect(
            await queue.waitForIdle(const Duration(seconds: 2)),
            isTrue,
            reason: 'το late error δεν αφήνει zombie counter',
          );
          expect(queue.inFlightCount, 0);
        });

    test('12. independence: pause στη μία ουρά δεν επηρεάζει την άλλη',
            () async {
          final q1 = SerialPassQueue(label: 'Test.one');
          final q2 = SerialPassQueue(label: 'Test.two');
          var ran2 = false;

          q1.pauseForMaintenance();
          await q2.run(() async => ran2 = true);

          expect(ran2, isTrue);
          expect(q2.isIdle, isTrue);
          expect(q1.isPaused, isTrue);
          q1.resumeAfterMaintenance();
        });

    test('13. pause/resume: idempotent', () async {
      final queue = SerialPassQueue(label: 'Test.queue');

      queue.pauseForMaintenance();
      queue.pauseForMaintenance();
      expect(queue.isPaused, isTrue);

      queue.resumeAfterMaintenance();
      queue.resumeAfterMaintenance();
      expect(queue.isPaused, isFalse);

      var ran = false;
      await queue.run(() async => ran = true);
      expect(ran, isTrue);
    });
  });
}
