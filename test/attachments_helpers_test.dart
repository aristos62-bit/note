// test/attachments_helpers_test.dart
//
// E09 helpers: πληθυντικός συνημμένων + όριο μεγέθους από settings.
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/utils/app_errors.dart';
import 'package:super_note/core/utils/string_utils.dart';
import 'package:super_note/models/models.dart';

void main() {
  test('attachmentsCountLabel: 1 → ενικό, N → πληθυντικό', () {
    expect(AppStringUtils.attachmentsCountLabel(1), '1 συνημμένο');
    expect(AppStringUtils.attachmentsCountLabel(2), '2 συνημμένα');
    expect(AppStringUtils.attachmentsCountLabel(10), '10 συνημμένα');
  });

  test('AppSettings.attachmentMaxBytes: MB → bytes, 0/εκτός → ceiling (S-13)', () {
    final settings = AppSettings();

    settings.maxAttachmentSizeMB = 20;
    expect(settings.effectiveMaxAttachmentMB, 20);
    expect(settings.attachmentMaxBytes, 20 * 1024 * 1024);

    settings.maxAttachmentSizeMB = 1;
    expect(settings.attachmentMaxBytes, 1024 * 1024);

    settings.maxAttachmentSizeMB = 100;
    expect(settings.attachmentMaxBytes, 100 * 1024 * 1024);

    // S-13 Δ4: «Χωρίς όριο» καταργήθηκε — legacy 0/αρνητικό → ceiling.
    settings.maxAttachmentSizeMB = 0;
    expect(settings.effectiveMaxAttachmentMB,
        AppSettings.maxAttachmentCeilingMB);
    expect(settings.attachmentMaxBytes,
        AppSettings.maxAttachmentCeilingMB * 1024 * 1024);

    settings.maxAttachmentSizeMB = -5;
    expect(settings.attachmentMaxBytes,
        AppSettings.maxAttachmentCeilingMB * 1024 * 1024);

    // Legacy τιμές εκτός λίστας επιλογών (migration επιτρέπει ≤1000).
    settings.maxAttachmentSizeMB = 200;
    expect(settings.effectiveMaxAttachmentMB,
        AppSettings.maxAttachmentCeilingMB);

    settings.maxAttachmentSizeMB = 1000;
    expect(settings.effectiveMaxAttachmentMB,
        AppSettings.maxAttachmentCeilingMB);
  });

  test('AppErrors.attachTooLarge περιέχει το όριο σε MB', () {
    expect(AppErrors.attachTooLarge(20), contains('20 MB'));
  });
}
