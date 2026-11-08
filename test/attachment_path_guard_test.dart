// test/attachment_path_guard_test.dart
//
// S-18: λεξικός έλεγχος «εντός attachments root» (fail-closed, χωρίς I/O).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:super_note/core/core.dart';

void main() {
  late Directory tmp;
  late String root;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sn_guard_test_');
    AttachmentPathGuard.configure(documentsDir: tmp.path);
    root = p.normalize(p.join(tmp.path, AttachmentPathGuard.dirName));
  });

  tearDown(() {
    AttachmentPathGuard.reset();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('dirName = attachments (SPoT)', () {
    expect(AttachmentPathGuard.dirName, 'attachments');
  });

  test('αρχείο εντός root → normalized path', () {
    final path = p.join(root, 'a.png');
    expect(AttachmentPathGuard.resolve(path), path);
  });

  test('υποφάκελος εντός root → περνά', () {
    final path = p.join(root, 'sub', 'a.png');
    expect(AttachmentPathGuard.resolve(path), path);
  });

  test('sibling attachments2 → null', () {
    final path = p.join(tmp.path, 'attachments2', 'a.png');
    expect(AttachmentPathGuard.resolve(path), isNull);
  });

  test('traversal .. → null', () {
    final path =
        '${p.join(root, 'sub')}${p.separator}..${p.separator}..${p.separator}secret.txt';
    expect(AttachmentPathGuard.resolve(path), isNull);
  });

  test('.. που επιστρέφει εντός → normalized, περνά', () {
    final path = '$root${p.separator}a${p.separator}..${p.separator}b.png';
    expect(AttachmentPathGuard.resolve(path), p.join(root, 'b.png'));
  });

  test('null / κενό → null', () {
    expect(AttachmentPathGuard.resolve(null), isNull);
    expect(AttachmentPathGuard.resolve(''), isNull);
  });

  test('root == path → null (το root δεν είναι παιδί του εαυτού του)', () {
    expect(AttachmentPathGuard.resolve(root), isNull);
  });

  test('σχετικό path → null', () {
    expect(AttachmentPathGuard.resolve('attachments/a.png'), isNull);
  });

  test('trailing separator στο documentsDir → καθαρίζεται', () {
    AttachmentPathGuard.configure(
        documentsDir: '${tmp.path}${p.separator}');
    final path = p.join(root, 'a.png');
    expect(AttachmentPathGuard.resolve(path), path);
  });

  test('unconfigured (reset) → fail-closed null', () {
    AttachmentPathGuard.reset();
    expect(AttachmentPathGuard.resolve(p.join(root, 'a.png')), isNull);
  });

  test('μη-απόλυτο documentsDir → fail-closed (root null)', () {
    AttachmentPathGuard.configure(documentsDir: 'relative/docs');
    expect(AttachmentPathGuard.resolve(p.join(root, 'a.png')), isNull);
  });

  test('UNC path → null', () {
    expect(AttachmentPathGuard.resolve(r'\\server\share\a.png'), isNull);
  });

  test('case-insensitive μόνο σε Windows (ακολουθεί το FS)', () {
    final upper = p.join(root, 'A.PNG').toUpperCase();
    final result = AttachmentPathGuard.resolve(upper);
    if (Platform.isWindows) {
      expect(result, isNotNull);
    } else {
      expect(result, isNull);
    }
  });

  group('S-25 isRiskyToLaunch', () {
    test('εκτελέσιμοι τύποι (Windows) → true', () {
      for (final n in [
        'a.exe', 'A.EXE', 'a.Bat', 'a.cmd', 'a.ps1', 'a.lnk', 'a.msi',
        'a.pdf.exe', 'a.exe.', 'a.exe ', '.exe', '1_report.vbs',
        r'evil.exe::$DATA',
      ]) {
        expect(AttachmentPathGuard.isRiskyToLaunch(n, windows: true), isTrue,
            reason: n);
      }
    });

    test('ασφαλείς τύποι → false', () {
      for (final n in [
        'a.pdf', 'a.png', 'a.exe.pdf', 'a', 'a.txt', 'a.docx', 'exe',
        'a.exe.txt',
      ]) {
        expect(AttachmentPathGuard.isRiskyToLaunch(n, windows: true), isFalse,
            reason: n);
      }
    });

    test('εκτός Windows → πάντα false', () {
      expect(AttachmentPathGuard.isRiskyToLaunch('a.exe', windows: false),
          isFalse);
    });

    test('null / κενό → false', () {
      expect(AttachmentPathGuard.isRiskyToLaunch(null, windows: true), isFalse);
      expect(AttachmentPathGuard.isRiskyToLaunch('', windows: true), isFalse);
    });

    test('πλήρες path → κρίνει μόνο το basename', () {
      expect(
          AttachmentPathGuard.isRiskyToLaunch(
              p.join('docs', 'attachments', 'a.exe'),
              windows: true),
          isTrue);
      expect(
          AttachmentPathGuard.isRiskyToLaunch(
              p.join('docs', 'attachments', 'a.pdf'),
              windows: true),
          isFalse);
    });
  });
}
