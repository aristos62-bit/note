// test/attachment_open_test.dart
//
// S-16/1β: AttachmentService.open — fail-closed guard πριν από κάθε opener.
// Όλες οι περιπτώσεις εδώ επιστρέφουν ΠΡΙΝ το platform call (χωρίς channels).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:super_note/core/core.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/services/attachment_service.dart';

Attachment _att(String path) => Attachment()
  ..id = 1
  ..itemId = 1
  ..fileName = p.basename(path)
  ..localPath = path
  ..mimeType = 'application/pdf'
  ..fileSize = 10;

void main() {
  late Directory tmp;
  late Directory root;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sn_open_test_');
    root = Directory(p.join(tmp.path, AttachmentPathGuard.dirName))
      ..createSync(recursive: true);
    AttachmentPathGuard.configure(documentsDir: tmp.path);
  });

  tearDown(() {
    AttachmentPathGuard.reset();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String?> open(String path) =>
      AttachmentService.instance.open(_att(path));

  test('unconfigured → attachNotFound', () async {
    AttachmentPathGuard.reset();
    expect(await open(p.join(root.path, 'a.pdf')), AppErrors.attachNotFound);
  });

  test('κενό localPath → attachNotFound', () async {
    expect(await open(''), AppErrors.attachNotFound);
  });

  test('σχετικό path → attachNotFound', () async {
    expect(await open(p.join('attachments', 'a.pdf')),
        AppErrors.attachNotFound);
  });

  test('εκτός root → attachNotFound', () async {
    final outside = p.join(tmp.path, 'secret.pdf');
    expect(await open(outside), AppErrors.attachNotFound);
  });

  test('sibling attachments2 → attachNotFound', () async {
    final sibling = p.join(tmp.path, 'attachments2', 'a.pdf');
    expect(await open(sibling), AppErrors.attachNotFound);
  });

  test('εντός root αλλά λείπει → attachNotFound', () async {
    final missing = p.join(root.path, 'missing.pdf');
    expect(await open(missing), AppErrors.attachNotFound);
  });

  test('φάκελος εντός root → attachNotFound', () async {
    final dir = Directory(p.join(root.path, 'folder'))..createSync();
    expect(await open(dir.path), AppErrors.attachNotFound);
  });
}
