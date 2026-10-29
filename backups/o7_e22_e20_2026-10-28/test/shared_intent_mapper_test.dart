// test/shared_intent_mapper_test.dart
//
// Unit tests για τα pure helpers του SharedIntentService.
// Χωρίς DB/plugin init — μόνο static μέθοδοι + value objects.
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:super_note/services/shared_intent_service.dart';

SharedMediaFile text(String s) =>
    SharedMediaFile(path: s, type: SharedMediaType.text);
SharedMediaFile url(String s) =>
    SharedMediaFile(path: s, type: SharedMediaType.url);
SharedMediaFile img(String p) =>
    SharedMediaFile(path: p, type: SharedMediaType.image);

void main() {
  group('combineText', () {
    test('text + url ενώνονται', () {
      final out = SharedIntentService.combineText(
          [text('γεια'), url('https://example.com')]);
      expect(out, 'γεια\nhttps://example.com');
    });

    test('iOS message προσαρτάται μία φορά', () {
      final f = SharedMediaFile(
          path: '/tmp/a.jpg',
          type: SharedMediaType.image,
          message: 'δες αυτό');
      expect(SharedIntentService.combineText([f]), 'δες αυτό');
    });

    test('κενά αγνοούνται', () {
      expect(SharedIntentService.combineText([text('  ')]), '');
    });
  });

  group('buildTitle', () {
    test('1η μη-κενή γραμμή', () {
      expect(
          SharedIntentService.buildTitle('\n  Τίτλος εδώ\nδεύτερη'),
          'Τίτλος εδώ');
    });

    test('truncate 80', () {
      final long = 'x' * 100;
      expect(SharedIntentService.buildTitle(long).length <= 80, true);
    });

    test('fallback ποτέ κενός', () {
      final t = SharedIntentService.buildTitle('   ');
      expect(t.isNotEmpty, true);
      expect(t.startsWith('Κοινοποίηση'), true);
    });
  });

  group('isFileType', () {
    test('image/video/file → true, text/url → false', () {
      expect(SharedIntentService.isFileType(img('/a.jpg')), true);
      expect(
          SharedIntentService.isFileType(SharedMediaFile(
              path: '/a.mp4', type: SharedMediaType.video)),
          true);
      expect(
          SharedIntentService.isFileType(SharedMediaFile(
              path: '/a.pdf', type: SharedMediaType.file)),
          true);
      expect(SharedIntentService.isFileType(text('hi')), false);
      expect(SharedIntentService.isFileType(url('https://x.gr')), false);
    });
  });

  group('isDuplicate', () {
    test('ίδιο share <2s → duplicate, άλλο → όχι', () {
      final svc = SharedIntentService.instance;
      final a = [text('ένα')];
      expect(svc.isDuplicate(a), false);
      expect(svc.isDuplicate(a), true);
      expect(svc.isDuplicate([text('δύο')]), false);
    });
  });

  group('shareTitle', () {
    test('link-only → host', () {
      expect(
          SharedIntentService.shareTitle(
              text: 'https://en.wikipedia.org/wiki/Flutter',
              filePaths: const []),
          '🔗 en.wikipedia.org');
    });

    test('κείμενο → 1η γραμμή', () {
      expect(
          SharedIntentService.shareTitle(
              text: 'Τίτλος\nσώμα', filePaths: const []),
          'Τίτλος');
    });

    test('file-only single → basename', () {
      expect(
          SharedIntentService.shareTitle(
              text: '', filePaths: const ['/tmp/photo.jpg']),
          'photo.jpg');
    });

    test('file-only multi → basename + πλήθος', () {
      expect(
          SharedIntentService.shareTitle(
              text: '', filePaths: const ['/a.jpg', '/b.jpg', '/c.jpg']),
          'a.jpg +2');
    });

    test('κενό → fallback', () {
      expect(
          SharedIntentService.shareTitle(text: '', filePaths: const [])
              .startsWith('Κοινοποίηση'),
          true);
    });
  });
}
