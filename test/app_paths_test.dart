// test/app_paths_test.dart
//
// S-01: SPoT της ρίζας δεδομένων. Εδώ ελέγχεται **μόνο** η καθαρή λογική
// (`resolveRoot`) και τα ονόματα — κανένα path_provider, κανένα I/O.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:super_note/core/core.dart';

void main() {
  group('resolveRoot (Windows)', () {
    test('LOCALAPPDATA → <local>\\SuperNoteData', () {
      final local = p.join('C:', 'Users', 'u', 'AppData', 'Local');
      final root = AppPaths.resolveRoot(isWindows: true, localAppData: local);
      expect(root, p.normalize(p.join(local, AppPaths.dataDirName)));
      expect(root, endsWith('SuperNoteData'));
    });

    test('χωρίς LOCALAPPDATA → fallback support dir', () {
      final support = p.join('C:', 'Users', 'u', 'AppData', 'Roaming', 'co', 'app');
      final root = AppPaths.resolveRoot(
        isWindows: true,
        localAppData: '   ',
        supportPath: support,
      );
      expect(root, p.normalize(support));
    });

    test('χωρίς LOCALAPPDATA/support → fallback documents', () {
      final docs = p.join('C:', 'Users', 'u', 'Documents');
      final root = AppPaths.resolveRoot(
        isWindows: true,
        supportPath: null,
        documentsPath: docs,
      );
      expect(root, p.normalize(docs));
    });

    test('χωρίς κανένα στοιχείο → null (ο caller αποφασίζει)', () {
      expect(AppPaths.resolveRoot(isWindows: true), isNull);
    });
  });

  group('resolveRoot (εκτός Windows: no-op)', () {
    test('documents → ίδιο root (καμία μετανάστευση)', () {
      final docs = p.join('home', 'u', 'documents');
      final root = AppPaths.resolveRoot(
        isWindows: false,
        documentsPath: docs,
      );
      expect(root, p.normalize(docs));
    });

    test('χωρίς documents → null', () {
      expect(AppPaths.resolveRoot(isWindows: false), isNull);
    });
  });

  group('ονόματα/διαδρομές (SPoT)', () {
    test('σταθερές ονομάτων', () {
      expect(AppPaths.dbName, 'super_note_db');
      expect(AppPaths.dbFileName, 'super_note_db.isar');
      expect(AppPaths.stagingDirName, '.staging');
      expect(AppPaths.migrationSafetyDirName, '.migration_safety');
      expect(AppPaths.attachmentsIn('root'),
          p.join('root', AttachmentPathGuard.dirName));
    });

    test('dbFileIn / stagingIn / migrationSafetyIn', () {
      final root = p.join('C:', 'data');
      expect(AppPaths.dbFileIn(root), p.join(root, 'super_note_db.isar'));
      expect(AppPaths.stagingIn(root), p.join(root, '.staging'));
      expect(AppPaths.migrationSafetyIn(root),
          p.join(root, '.migration_safety'));
    });

    test('sameRoot: case-insensitive στα Windows, exact εκτός', () {
      const a = r'C:\Users\u\SuperNoteData';
      const b = r'c:\users\u\supernotedata';
      expect(AppPaths.sameRoot(a, b), Platform.isWindows);
      expect(AppPaths.sameRoot(a, a), isTrue);
      expect(AppPaths.sameRoot(a, r'C:\Users\u\SuperNoteData2'), isFalse);
    });
  });
}
