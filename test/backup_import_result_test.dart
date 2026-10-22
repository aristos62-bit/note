// test/backup_import_result_test.dart
//
// E33: pure contract tests για restart semantics και busy message.
// Χωρίς Isar/plugin calls.
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/app_errors.dart';
import 'package:super_note/services/backup_service.dart';

void main() {
  group('BackupImportResult (E33)', () {
    test('success μετά το close → restartRequired true', () {
      final result = BackupImportResult.success(restartRequired: true);

      expect(result.success, isTrue);
      expect(result.restartRequired, isTrue);
      expect(result.cancelled, isFalse);
      expect(result.error, isNull);
    });

    test('failure μετά το close → restartRequired true', () {
      final result =
          BackupImportResult.failure('boom', restartRequired: true);

      expect(result.success, isFalse);
      expect(result.restartRequired, isTrue);
      expect(result.error, 'boom');
    });

    test('abort πριν το close → restartRequired false', () {
      final failure = BackupImportResult.failure('busy');
      final cancelled = BackupImportResult.cancelled();

      expect(failure.restartRequired, isFalse);
      expect(cancelled.restartRequired, isFalse);
      expect(cancelled.cancelled, isTrue);
    });
  });

  test('AppErrors.backupBusy είναι το κοινό μήνυμα maintenance', () {
    expect(AppErrors.backupBusy, contains('απασχολημένη'));
  });
}
