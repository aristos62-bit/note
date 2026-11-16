// test/inbound_share_test.dart
//
// S-13: καθαρή λογική εισερχόμενου share intent — ταξινόμηση (S-13b),
// πλάνο ορίων, clamp κειμένου. Μηδέν I/O (injected exists/sizeOf).
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:super_note/services/share/inbound_share.dart';
import 'package:super_note/services/share/share_models.dart';

SharedMediaFile _media(
  SharedMediaType type,
  String path, {
  String? message,
  String? mimeType,
  SharedMediaIntakeError? intakeError,
}) =>
    SharedMediaFile(
      path: path,
      type: type,
      message: message,
      mimeType: mimeType,
      intakeError: intakeError,
    );

void main() {
  group('classify — S-13b', () {
    test('καθαρό κείμενο μένει κείμενο', () async {
      final c = await InboundShare.classify(
        [_media(SharedMediaType.text, '  Γεια σου κόσμε  ')],
        exists: (_) async => false,
      );
      expect(c.text, 'Γεια σου κόσμε');
      expect(c.filePaths, isEmpty);
    });

    test('text/* με υπαρκτό απόλυτο path → αρχείο (όχι path στο σώμα)',
        () async {
      const path = '/data/user/0/gr.gavrielatos.supernote/cache/notes.txt';
      final c = await InboundShare.classify(
        [_media(SharedMediaType.text, path, mimeType: 'text/plain')],
        exists: (_) async => true,
      );
      expect(c.text, isEmpty);
      expect(c.filePaths, [path]);
    });

    test('σχετικό path που "υπάρχει" δεν γίνεται αρχείο', () async {
      final c = await InboundShare.classify(
        [_media(SharedMediaType.text, 'notes.txt')],
        exists: (_) async => true,
      );
      expect(c.text, 'notes.txt');
      expect(c.filePaths, isEmpty);
    });

    test('url μένει κείμενο', () async {
      final c = await InboundShare.classify(
        [_media(SharedMediaType.url, 'https://example.com/a')],
        exists: (_) async => false,
      );
      expect(c.text, 'https://example.com/a');
      expect(c.filePaths, isEmpty);
    });

    test('εικόνα + κείμενο → και τα δύο, με σειρά εισόδου', () async {
      final c = await InboundShare.classify(
        [
          _media(SharedMediaType.image, '/cache/a.jpg'),
          _media(SharedMediaType.text, 'σχόλιο'),
        ],
        exists: (_) async => false,
      );
      expect(c.filePaths, ['/cache/a.jpg']);
      expect(c.text, 'σχόλιο');
    });

    test('message προστίθεται μία φορά (dedupe)', () async {
      final c = await InboundShare.classify(
        [
          _media(SharedMediaType.text, 'ίδιο', message: 'ίδιο'),
        ],
        exists: (_) async => false,
      );
      expect(c.text, 'ίδιο');
    });

    test('διπλό ίδιο path → μία εγγραφή', () async {
      final c = await InboundShare.classify(
        [
          _media(SharedMediaType.image, '/cache/a.jpg'),
          _media(SharedMediaType.image, '/cache/a.jpg'),
        ],
        exists: (_) async => false,
      );
      expect(c.filePaths, ['/cache/a.jpg']);
    });
  });

  group('classify — S-321 intake errors', () {
    test('unreadable: κανένα path, μετράει χωριστά', () async {
      final c = await InboundShare.classify(
        [
          _media(SharedMediaType.image, '',
              intakeError: SharedMediaIntakeError.unreadable),
        ],
        exists: (_) async => true,
      );
      expect(c.filePaths, isEmpty);
      expect(c.text, isEmpty);
      expect(c.unreadable, 1);
      expect(c.nativeTooLarge, 0);
    });

    test('tooLarge: μετράει ως nativeTooLarge, όχι unreadable', () async {
      final c = await InboundShare.classify(
        [
          _media(SharedMediaType.video, '',
              intakeError: SharedMediaIntakeError.tooLarge),
        ],
        exists: (_) async => false,
      );
      expect(c.filePaths, isEmpty);
      expect(c.nativeTooLarge, 1);
      expect(c.unreadable, 0);
    });

    test('unreadable + EXTRA_TEXT: το κείμενο σώζεται', () async {
      final c = await InboundShare.classify(
        [
          _media(SharedMediaType.file, '',
              intakeError: SharedMediaIntakeError.unreadable,
              message: 'δες αυτό'),
        ],
        exists: (_) async => false,
      );
      expect(c.text, 'δες αυτό');
      expect(c.unreadable, 1);
    });

    test('ανάμιξη: 2 unreadable + 1 αρχείο + 1 text', () async {
      final c = await InboundShare.classify(
        [
          _media(SharedMediaType.image, '',
              intakeError: SharedMediaIntakeError.unreadable),
          _media(SharedMediaType.image, '/cache/ok.jpg'),
          _media(SharedMediaType.image, '',
              intakeError: SharedMediaIntakeError.unreadable),
          _media(SharedMediaType.text, 'σχόλιο'),
        ],
        exists: (_) async => false,
      );
      expect(c.filePaths, ['/cache/ok.jpg']);
      expect(c.text, 'σχόλιο');
      expect(c.unreadable, 2);
    });

    test('SharedMediaFile.fromMap: error/άγνωστο type/path null → tolerant',
        () {
      final f = SharedMediaFile.fromMap({
        'path': null,
        'type': 'άγνωστο',
        'error': 'tooLarge',
      });
      expect(f.path, '');
      expect(f.type, SharedMediaType.file);
      expect(f.intakeError, SharedMediaIntakeError.tooLarge);
      expect(f.toMap()['error'], 'tooLarge');

      final g = SharedMediaFile.fromMap({'path': '/a', 'type': 'image'});
      expect(g.intakeError, isNull);
      expect(g.toMap().containsKey('error'), isFalse);
    });
  });

  group('plan — όρια', () {
    const mb = 1024 * 1024;

    InboundFile f(String path, int bytes) =>
        InboundFile(path: path, sizeBytes: bytes);

    test('αρχείο πάνω από το όριο ανά αρχείο → tooLarge', () {
      final plan = InboundShare.plan(
        [f('/a', 8 * mb), f('/b', 4 * mb)],
        perFileBytes: 5 * mb,
      );
      expect(plan.accepted.map((e) => e.path), ['/b']);
      expect(plan.skipped, [InboundSkip.tooLarge]);
      expect(plan.hasLimitSkips, isTrue);
    });

    test('ακριβώς στο όριο → περνά', () {
      final plan = InboundShare.plan(
        [f('/a', 5 * mb)],
        perFileBytes: 5 * mb,
      );
      expect(plan.accepted, hasLength(1));
      expect(plan.skipped, isEmpty);
    });

    test('πλήθος: 21 αρχεία → 20 + 1 tooMany', () {
      final plan = InboundShare.plan(
        List.generate(21, (i) => f('/f$i', 1)),
        perFileBytes: 10 * mb,
      );
      expect(plan.accepted, hasLength(ShareLimits.maxFiles));
      expect(plan.skipped, [InboundSkip.tooMany]);
    });

    test('σύνολο: 2×60MB με ceiling συνόλου 100MB → 1 + 1 overTotal', () {
      final plan = InboundShare.plan(
        [f('/a', 60 * mb), f('/b', 60 * mb)],
        perFileBytes: 100 * mb,
        maxTotalBytes: ShareLimits.maxTotalBytes,
      );
      expect(plan.accepted.map((e) => e.path), ['/a']);
      expect(plan.skipped, [InboundSkip.overTotal]);
    });

    test('missing δεν μετράει ως όριο', () async {
      final plan = await InboundShare.planFor(
        ['/missing', '/ok'],
        perFileBytes: 5 * mb,
        sizeOf: (path) async => path == '/ok' ? 1024 : null,
      );
      expect(plan.accepted.map((e) => e.path), ['/ok']);
      expect(plan.skipped, [InboundSkip.missing]);
      expect(plan.hasLimitSkips, isFalse);
      expect(plan.skippedCount, 1);
    });

    test('ντετερμινιστική σειρά (greedy, σειρά εισόδου)', () async {
      final plan = await InboundShare.planFor(
        ['/a', '/b', '/c'],
        perFileBytes: 10,
        sizeOf: (_) async => 5,
      );
      expect(plan.accepted.map((e) => e.path), ['/a', '/b', '/c']);
    });
  });

  group('clampText', () {
    test('99.999 και 100.000 → αμετάβλητο, χωρίς σημαία', () {
      final short = InboundShare.clampText('a' * 99999);
      expect(short.text.length, 99999);
      expect(short.truncated, isFalse);

      final exact = InboundShare.clampText('a' * ShareLimits.maxTextChars);
      expect(exact.text.length, ShareLimits.maxTextChars);
      expect(exact.truncated, isFalse);
    });

    test('100.001 → ακριβώς 100.000 + truncated', () {
      final c = InboundShare.clampText('a' * 100001);
      expect(c.text.length, ShareLimits.maxTextChars);
      expect(c.truncated, isTrue);
      expect(c.text.endsWith('...'), isFalse);
    });
  });
}
