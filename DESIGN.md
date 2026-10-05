# SuperNote — DESIGN.md (αρχιτεκτονική, v Session 59)

## Layers (αμετάβλητα)
`lib/{main, core, models, providers, services, helpers, features, shared}` + barrels.
Κανόνας: import από barrel, όχι individual files.

## SPoTs (Session 50)
- Χρώμα: `ColorsUI` + `ItemColorHelper.parseHex/textColorForBackground/iconColorForType`
- Κείμενο/ημερομηνίες: `AppStringUtils/StringX`, `AppDateUtils/DateTimeX`
- Recurrence: `Recurrence` (safeDay/safeMonthDay, getPeriodStart/nextPeriodStart, nextOccurrence, toRRULE) + adapter `recurrence_utils.dart`
- Contacts: `ContactProps.fromProperties` (`core/utils/contact_props.dart`)
- Images: `ImageUtils` (`core/utils/image_utils.dart`) — avatarProvider/ResizeImage, fileThumb/cacheWidth
- DB: `SuperNoteHelper` facade + repositories, `dbProvider`
- UI: `DetailScreenMixin`, `FolderAutoSelectMixin`, `handleArchive` (+`ItemLabelX.fromType`), `ConfirmDialog`, `EmptyState`, `ItemTypeIcon`, `PriorityBadge`, `TagChip`, `ViewModeToggle`, `ContentFieldWidget`, `SheetHandle` (grabber 40×4, `margin?/color?`, radius `Spacing.xxs`), `ItemActionsSheet` (long-press sheets, προαιρετικά actions, pop με sheet-ctx), `FolderFormDialog` (create/edit φακέλου, `kFolderIcons/kFolderColors`, `FolderFormResult`, pop με dialog-ctx, validation `AppStringUtils.clean`)
- Notifications: `NotificationService` (IANA via `flutter_timezone`) + `ReminderScheduler`
- Backup/Migration: `BackupService` (File.copy, atomic restore), `MigrationService` (schemaVersion, safety backup, batch 50)

## Κανόνες
- R1 <500γρ (non-generated, χωρίς `*.g.dart/*.bak`, `backups/**` excluded από analyzer)
- R2 Resize: καμία raw εικόνα (camera 1024/85, gallery guard, thumbnail προτίμηση, display ResizeImage/cacheWidth)
- R3 Καμία νέα helper αν καλύπτεται από SPoT
- R4 Μόνο `DebugConfig.*` (error/warning πάντα ON), Ελληνικά user μηνύματα via mixin/handleArchive
- R5 Barrel exports για κάθε νέο util/service
- R6 Performance: `.select()`, `const`, `autoDispose` σε family

## Αλλαγές Session 50
- Dep: `flutter_timezone ^4.1.1` (4.x: v1-embedding fix, `Future<String>` API — όχι 5.x `TimezoneInfo`)
- Νέα: `image_utils.dart`, `contact_props.dart`
- Exports: `migration_service`, `image_utils`, `contact_props` + `backups/**` exclude
- Timezone: IANA init, silent fallback τέλος
- Backup: `exportToDevice` χωρίς `readAsBytes`
- Split <500: εκκρεμεί (Φ4)

## Αλλαγές Session 51-52 (reminder semantics)
- Κανόνας: κάθε προγραμματισμένη εμφάνιση = one-shot (`rrule:null`, `parent=null` για ανεξάρτητα). Roots (`rrule!=null`, `parent==null`) μόνο ως anchors για `refreshRecurringReminders`.
- Habits: `_scheduleReminders` δημιουργεί one-shots (recurrence ζει στα props) — επιβιώνουν `cancelAll/scheduleAll`, καθαρίζονται από `cleanupOldPending`.
- Snooze: status μένει `pending` (`snoozeUntil`=ιστορικό, `triggerAt`=οδηγός)· OS reschedule στο provider (`cancelReminder`+`scheduleReminder`), όχι στο repository (κύκλος imports)· roots εξαιρούνται (anchor)· snoozed children εξαιρούνται από wrong-time cleanup.
- `ReminderRepository.getById` (getter, ίδιο pattern)· `Reminder.isActive` = pending-only.
- Follow-up (με Φ4): repair παλιών habit rows, 60-day habit top-up, ReminderSection dialog-hiding σε habits, snooze button UI, `isActive`/`dismissed` τακτοποίηση.
- Session 53: `permanentDelete` (κάδος) κάνει `deleteAllRemindersForItem` πριν το `hardDelete` — καμία ορφανή OS ειδοποίηση· σειρά υποχρεωτική (τα ids χάνονται μετά τη DB διαγραφή).
- Session 58: vibration toggle → `syncChannel` (delete+recreate ίδιο id, μόνο στο toggle)· ήχος via `silent`· iOS per-notification.
- Session 54: week-math SPoT (`isValidWeeklyDay`, `epochMonday`) — weekly/monthly/yearly με `interval>1` σέβονται το διάστημα (scheduler anchor=root, habit anchor=epoch)· `interval==1` identical· tests `test/recurrence_weekly_test.dart`.

## Αλλαγές Session 59 (share intent IN — λήψη κοινοποιήσεων)
- Dep: `receive_sharing_intent ^1.9.0` (`SharedMediaType`: image/video/text/file/url· `getInitialMedia/getMediaStream/reset/setMockValues`) — το `share_plus` μένει outbound μόνο.
- Νέα: `SharedIntentService` (singleton, stream `incoming`, dedup 2s, `saveAsNote/saveAsEvent`, `onSaved` callback αντί import providers — κύκλος imports) + `SharedIntentListener/_ShareSheet` (dialog με `ItemTypePicker[note,event]` + `showReminderPicker` reuse).
- Android: 7 `SEND`/`SEND_MULTIPLE` filters (text/image/video/`*/*`), `singleTop` κρατιέται· καμία νέα runtime permission (temp cache paths).
- EventDetail: +πεδίο `notes` (`ContentFieldWidget`, pattern TaskDetail) — τα events αποκτούν ορατό σώμα.
- Κανόνας: share δημιουργεί Items (note: text block + attachments + 📎· event: `start_time/end_time/all_day/notes`) — ΠΟΤΕ Reminder rows· υπενθυμίσεις μόνο από καμπάνα.
- Γνωστό: backup καλύπτει μόνο `.isar`, όχι `attachments/` (follow-up Φάση Β).

## Αλλαγές Session 61 (habit native ownership)
- Κανόνας: habits έχουν δικό τους scheduling (ώρες `reminder_time(s)` → one-shots 60d) — η καμπάνα (generic `ReminderSection`) απενεργοποιήθηκε σε detail+list· `refreshRecurringReminders` εξακολουθεί να σκιπάρει habits.
- `HabitService`: `generatedTitle` (διαχωρισμός από bell τίτλο `'Υπενθύμιση'`)· `syncScheduleWithRecurrence` (UI wiring)· προσθετικό `topUpHabitReminders` (10min guard, opt-in μόνο, postFrame πριν `scheduleAll` + resume)· idempotent `repairLegacyHabitRows` (προ-51 ψευδο-roots → sync)· επιλεκτικό wipe (μόνο habit τίτλος, bell rows grandfather + reschedule).
- Tests: `test/habit_topup_test.dart` (pure `planTopUp`/`parseHabitTime`).

## Αλλαγές Session 63 (backup zip με attachments)
- Dep `archive ^4.3.0`· νέο `backup_archive.dart` (streaming export, memory-bound import → 500MB guard)· exports/imports/share με `.zip`, import και παλιού `.isar`· atomic restore βάσης + φακέλου (safety/rollback αμφότερα) + rebase `localPath`· κοινές consts + `AttachmentRepository.getAll()`· tests `backup_archive_test`.

## Αλλαγές Session 62 (habit ώρες σε weekly/monthly)
- `Recurrence.weekly/monthly` δέχονται `times` (κοινή ώρα ειδοποίησης)· `fromProperties`/`describe` καλύπτουν weekly/monthly (yearly εκτός)· UI: time picker μετά τα days (prefill δωρεάν)· `sync` για `type != yearly`· stats/streak ανέγγιχτα (ώρες = μόνο ειδοποιήσεις).

## Αλλαγές Session 64 (Φ4a βήμα 1: SheetHandle SPoT)
- Νέο `shared/widgets/sheet_handle.dart` + barrel export· 21 αντικαταστάσεις (pixel-identical, `margin`/`Center` στον caller)· εξαιρέσεις: progress/quote-bar/40×40 pickers/drag icons· tests `test/sheet_handle_test.dart` (3/3)· analyze clean.

## Αλλαγές Session 65 (Φ4a βήμα 2: ItemActionsSheet SPoT)
- Νέο `shared/widgets/item_actions_sheet.dart` (προαγωγή 2 private + 6 inline, προαιρετικά actions, `editIcon/editLabel`, `showTitle/titleStyle/showPriority`, pop με sheet-ctx = fix blind-pop)· `ItemLabelX.fromType` (διαγραφή 2 maps)· tests `test/item_actions_sheet_test.dart` (5/5)· analyze clean.

## Αλλαγές Session 66 (Φ4a βήμα 3: FolderFormDialog SPoT)
- Νέο `shared/widgets/folder_form_dialog.dart` (ενοποίηση 3 dialogs home/browser, `FolderFormResult`, validation `clean` + inline error + disabled OK, dispose-fix)· 5× hex → `parseHex ?? fallback`· micro-fix `FolderRepository.update` (+`updatedAt/localVersion/isDirty`)· tests `test/folder_form_dialog_test.dart` (4/4)· analyze clean.
