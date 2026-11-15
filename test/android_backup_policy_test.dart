// test/android_backup_policy_test.dart
//
// S-21 (S316): κλειδώνει το συμβόλαιο «καμία διαρροή δεδομένων μέσω
// cloud backup / device-to-device transfer».
//
// Γιατί υπάρχει test: το fix είναι **δηλωτικό** (manifest + res/xml) — μια
// σιωπηλή διαγραφή γραμμής δεν θα την έπιανε κανένα άλλο test. Εδώ ελέγχουμε
// την **πηγή**, όχι το APK· η επαλήθευση του APK γίνεται με `aapt2` στο
// device-test evidence του S316.
//
// Δεν χρειάζεται νέο dependency: μόνο `dart:io` + `flutter_test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ρίζα του project: ανεβαίνουμε μέχρι το `pubspec.yaml`.
/// Το `flutter test` τρέχει από τη ρίζα, αλλά έτσι δεν εξαρτόμαστε από το CWD.
Directory projectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('Δεν βρέθηκε το pubspec.yaml (ρίζα project)');
}

/// Τα domains που ορίζουν τα Android docs για backup rules.
/// Το `root` είναι το κρίσιμο: περιέχει το `<dataDir>/app_flutter`
/// (βάση + συνημμένα) — το `file` domain ΔΕΝ το καλύπτει.
const backupDomains = <String>[
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
  'device_root',
  'device_file',
  'device_database',
  'device_sharedpref',
];

final _excludeTag = RegExp(r'<exclude\b[^>]*>');

/// Τα σχόλια XML αναφέρουν τα tags (`<device-transfer>`, `<include>`) — αν δεν
/// αφαιρεθούν, το parsing διαβάζει το σχόλιο αντί για το πραγματικό section.
String stripComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

/// Επιστρέφει το περιεχόμενο του section (`cloud-backup` / `device-transfer`).
String sectionOf(String xml, String tag) {
  final start = xml.indexOf('<$tag');
  expect(start, isNot(-1), reason: 'λείπει το <$tag> από το data_extraction_rules');
  final end = xml.indexOf('</$tag>', start);
  expect(end, isNot(-1), reason: 'λείπει το </$tag>');
  return xml.substring(start, end);
}

void main() {
  final root = projectRoot();
  final manifestFile =
      File('${root.path}/android/app/src/main/AndroidManifest.xml');
  final rulesFile = File(
      '${root.path}/android/app/src/main/res/xml/data_extraction_rules.xml');

  group('S-21: Android backup / D2D policy', () {
    test('manifest: allowBackup=false παραμένει', () {
      final manifest = manifestFile.readAsStringSync();
      expect(manifest, contains('android:allowBackup="false"'));
    });

    test('manifest: fullBackupContent=false (Android 11 και κάτω)', () {
      final manifest = manifestFile.readAsStringSync();
      expect(manifest, contains('android:fullBackupContent="false"'));
    });

    test('manifest: dataExtractionRules δείχνει στο res/xml', () {
      final manifest = manifestFile.readAsStringSync();
      expect(manifest,
          contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    });

    test('το data_extraction_rules.xml υπάρχει', () {
      expect(rulesFile.existsSync(), isTrue,
          reason: 'λείπει το ${rulesFile.path}');
    });

    test('και τα δύο sections υπάρχουν και κανένα <include>', () {
      final xml = stripComments(rulesFile.readAsStringSync());
      // Αν λείπει το <device-transfer>, το D2D είναι ΠΛΗΡΩΣ ενεργό (docs).
      final cloud = sectionOf(xml, 'cloud-backup');
      final d2d = sectionOf(xml, 'device-transfer');
      expect(cloud, isNotEmpty);
      expect(d2d, isNotEmpty);
      expect(xml, isNot(contains('<include')),
          reason: 'με <include> θα άλλαζε η σημασία των rules');
      expect(xml, isNot(contains('<cross-platform-transfer')),
          reason: 'iOS transfer δεν ορίζεται (δεν υπάρχει iOS app)');
    });

    test('κάθε section εξαιρεί όλα τα domains με path="."', () {
      final xml = stripComments(rulesFile.readAsStringSync());
      for (final tag in ['cloud-backup', 'device-transfer']) {
        final tags = _excludeTag
            .allMatches(sectionOf(xml, tag))
            .map((m) => m.group(0)!)
            .toList();
        expect(tags.length, backupDomains.length,
            reason: 'το <$tag> πρέπει να έχει ${backupDomains.length} excludes');
        for (final domain in backupDomains) {
          final hits = tags
              .where((t) =>
                  t.contains('domain="$domain"') && t.contains('path="."'))
              .length;
          expect(hits, 1,
              reason: 'το <$tag> πρέπει να εξαιρεί domain="$domain" path="."');
        }
      }
    });
  });
}
