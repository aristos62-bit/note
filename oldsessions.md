# SuperNote — Development History

## Session 1 — 21-05-2026 (App initialization hardening)
- try-catch + `_InitErrorApp` fallback screen αν αποτύχει η DB init
- Memory leak fix: `removeObserver` + `container.dispose()` στο detached
- Dynamic locale: Greek/English/auto (από `initializeDateFormatting`)
- Web platform check: `_WebNotSupportedApp` αν `kIsWeb`

## Sessions 3-6 — 23-24/05/2026 (Early bug fixes + Reorder)
- Διόρθωση: circular import `task_provider.dart` → `providers.dart` → compile errors
- Drag-and-drop reorder για collections (grid) + entries (list)
- Recurring reminder dedup + λάθος μέρα fix (root με rrule δεν πρέπει να προγραμματίζεται)
- Home screen refactor: 24 folder icons + loading skeleton
- Favorite toggle στον Appointment Detail

## Sessions 7-8 — 24-25/05/2026 (Contact Import)
- Πλήρες feature: permission → fetch → select contacts → pick fields → pick folder → import
- Mapping: `flutter_contacts` → `Item` + `ItemProperty` (phones, email, company, website, address, birthday, notes, photo)
- Duplicate detection (όνομα ή τηλέφωνο), progress indicator, delete imported
- Bug fix: permission denied (έλειπε `WRITE_CONTACTS`), folder picker crash (emoji σε icon)

## Sessions 10-11 — 27-28/05/2026 (Calendar + Yearly recurrence)
- Yearly recurrence type (`RecurrenceType.yearly`): `_isPeriodComplete`, `_prevPeriodStart`, RRULE generate/parse
- Birthday/special day: date picker from 1900 (αντί `now.year - 1`)
- Yearly reminder auto-update όταν αλλάζει η ημερομηνία
- Build warnings fixed (Kotlin, Java source/target, deprecated API)
- EventDetailScreen: archive button

## Session 12 — 28/05/2026 (Archive unification + Provider cleanup)
- `archive_helper.dart`: κεντρική `handleArchive()` — consistent behavior σε 9 detail screens (ConfirmDialog + SnackBar + pop)
- Αφαίρεση 7 dead providers (‑111 γρ.)
- Task providers: independent Isar watch (δεν ανανεώνονται όταν αλλάζει note/journal/habit)

## Session 14 — 28/05/2026 (Birthday reminders from contacts)
- Ένα tap στην τούρτα → δημιουργία ετήσιας υπενθύμισης (9AM, yearly rrule)
- Προστασία από duplicate reminders (αν υπάρχει ήδη yearly root, προσφέρει αντικατάσταση)

## Session 15 — 28/05/2026 (Notification toggle fix)
- OFF → `cancelAll()`, ON → `scheduleAll()` (πριν: άλλαζε setting χωρίς effect)

## Sessions 16-17 — 31/05/2026 (Shared widgets: ContentField + BlockEditor)
- `ContentFieldWidget`: shared auto-save TextField (debounce, auto-delete empty on focus loss)
- `BlockEditorWidget`: extracted from NoteDetailScreen (shared blocks: heading, checklist, bullet, numbered, quote, code)
- Εφαρμογή σε: note, task, journal, appointment, contact detail screens

## Sessions 18-21 — 31/05/2026 (Share Feature)
- `share_plus` integration (`SharePlus.instance.share`)
- `share_service.dart`: `_format()` per-type formatters (notes, tasks, appointments, contacts, events, journals, habits)
- Share icon σε όλες τις κάρτες: ItemCard (trailing), habits/contacts (in-card), collections (action sheet), entries (in-card), journal (action sheet), home (in-card)

## Sessions 22-26 — 06/06/2026 (Empty title + Archive UX + DetailScreenMixin)

**Empty title protection:** Dispose safety net σε 7 detail screens — αν isNew && title.isEmpty → softDelete. GoRouter `isNew` propagation fixed (6 routes + HomeFolderView).

**DetailScreenMixin (Layer 1):** `detail_screen_mixin.dart` — παρέχει `initScreen`, `disposeScreen`, `executeSave`, `executeSaveOrDelete`, `safePop` — migrated 9/9 screens.

**Archive UX:** Archived items εμφανίζονται με opacity 0.5 + "Αρχείο" chip. SnackBar hint "Πατήστε παρατεταμένα για επαναφορά". Long-press context menu → unarchive.

## Session 27 — 07/06/2026 (Per-type card color customization)
- Settings → color picker (60 presets) per ItemType (note, task, event, contact, habit, journal, appointment)
- `itemTypeCardColorOverrideProvider` family by type
- 7 card locations ενημερώθηκαν (ItemCard, habits, contacts, journal, home, folder browser)

## Session 28 — 07/06/2026 (DB write optimization — _hasChanges)
- Appointment + Contact detail: dirty tracking (`_hasChanges` flag) — αποτρέπει περιττά `ItemRepository.update` όταν ο χρήστης απλά βλέπει και φεύγει

## Session 29 — 09/06/2026 (Remove local search from lists)
- Αφαίρεση search bar + tag filters από 6 list screens (notes, habits, journal, contacts, collections, folder browser). Η αναζήτηση γίνεται μόνο από την Αρχική.

## Sessions 30-34 — 10-11/06/2026 (try-catch protection + Recurring gap fix)

**Services (Layer 3):** try-catch σε: `share_service`, `notification_service` (7 methods), `reminder_scheduler` (8 methods), `habit_service` (10 methods) — με fallback `_emptyStats()` αντί rethrow.

**Providers (Layer 2):** try-catch σε 10 provider files — χάθηκαν από backup restore, επαναφέρθηκαν σε Sessions 32-33: `item_provider` (11 methods), `property_provider` (4), `block_provider` (5), `settings_provider` (3 + fix silent catches), `folder_provider` (4), `tag_provider` (3), `reminder_provider` (4), `attachment_provider` (2), `workspace_provider` (1), `task_provider` (2 silent → DebugConfig.error).

**Subtask race condition:** Atomic `writeTxn` στο `ItemNotifier.create()` — item + properties γράφονται μαζί, αποφεύγοντας Isar watcher που βλέπει ημιτελή δεδομένα.

**Reorder bugs:** Αφαίρεση `newIndex - 1` adjustment (reorderable_grid v1.0.13 δίνει modified-list index). Category sorting: Pinned → Favorites → Others by sortOrder. HomeFolderView reorder στην πλήρη λίστα (όχι filtered subset).

**Recurring reminder gap fix:** Αν `todayAtTriggerTime` είναι μετά το now, προστίθεται στο batch — καλύπτει την περίπτωση που το reminder τρέχει πριν την ώρα του.

## Sessions 35-36 — 11/06/2026 (Backup redesign)
- **Export:** `File.copy()` αντί `readAsBytes()` (0 OOM risk). Επιλογή: αποθήκευση στη συσκευή ή system share sheet.
- **Import:** Deep validation (temp Isar instance) → atomic `rename()` + safety net rollback
- **Fix:** Isar instance name collision (validation χρησιμοποιούσε ίδιο `name` με live DB)

## Session 37 — 11/06/2026 (Schema migration system)
- `MigrationService`: version tracking σε `AppSettings.schemaVersion`, safety backup (rotate 3), batch pagination (50 records), idempotent by design
- Integration: 1 γραμμή στο `SuperNoteHelper.init()` (μετά το Isar.open, πριν το _ensureDefaults)

## Session 38 — 11/06/2026 (Encryption analysis)
- Ανάλυση 3 προσεγγίσεων: Full DB ❌ (Isar v3 χωρίς encryption), Field-level 🔴 (σπάει 18+ σημεία), App Lock 🟢 (πρακτική λύση)
- Σύσταση: App Lock PIN/biometric πρώτα, μετά file encryption, μετά backup encryption

## Session 39 — 11/06/2026 (App Lock + Migration bug fix)
- **App Lock:** PIN (SHA-256) + biometric (`local_auth`). Lock screen overlay (όχι GoRouter redirect — προστατεύει file picker από route destruction). Settings: enable, PIN set/change, biometric toggle, timeout dropdown. Lifecycle auto-lock (startup + pause). GoRouter redirect guard.
- **Migration fix:** Invalid/negative schema version guard (αν <0 ή >target, γράφει targetVersion αντί για loop/crash)

## Sessions 40-42 — 12/06/2026 (Collections Attachments — Πλήρες feature)
- **Attachment field type:** Upload file per entry field, image thumbnail/file icon, multiple files per field
- **Dedup:** Global (ίδιο fileName + fileSize) + per-field (ίδιο attachment ID)
- **Type restriction:** Per-field allowed extensions (presets: Εικόνες, Έγγραφα)
- **maxFiles:** Strict 1-10 per field
- **Filename sanitization:** Reserved chars `<>:"/\|?*` → `_`, control chars removed, trailing dots/spaces trim, Windows reserved names protected
- **Cascade delete:** Hard delete → DB records + disk files
- **Preview:** Image → fullscreen `InteractiveViewer` dialog, other → `OpenFilex.open()` system app
- **Save to disk:** `FilePicker.platform.saveFile()` with bytes
- **Layout:** X button εκτός κάρτας, save button εντός, tap = preview

## Session 43 — 12/06/2026 (Auto-lock timeout + Collection entry share)
- **Auto-lock fix:** `appLockTimeoutSeconds` αγνοούνταν — hardcoded 2s → διάβασε από settings
- **Collection share:** Πλέον συμπεριλαμβάνει όλα τα πεδία + attachment files (`ShareParams(files: ...)`). Απέφυγε circular dependency (JSON parsing αντί για import `FieldDef`/`FieldType`).

## Session 44 — 12/06/2026 (Batch DB optimization — 3 N+1 fixes)
- **Νέα μέθοδος `PropertyRepository.getCollectionIds()`** — lightweight Isar query με `anyOf` + `keyEqualTo('collection_id')`, επιστρέφει `Map<int, String>` σε 1 DB call
- **Collections screen fix:** `collectionEntriesCountProvider` — αντικατάσταση N `itemPropertiesProvider` calls με ένα `getCollectionIds()` (32→1)
- **Collection entries screen fix:** `_FilteredEntriesList` — νέο `_batchColIdProvider` `FutureProvider.autoDispose`, φιλτράρισμα `collection_id` με 1 batch query αντί για N
- **Contacts screen fix:** `_ContactListScreen` — νέο `_contactBatchPropsProvider` `FutureProvider.autoDispose`, batch `getAllForItems` αντί για per-contact loop (7→1)
- **Συνολική μείωση:** ~71 DB calls → 3 batch queries

## Session 45 — 12/06/2026 (Contact photo display + picker + real-time sync)
- **Phase 1 — Photo display:** `_ContactAvatar` + `_ContactDetailAvatar` με `CircleAvatar` + `MemoryImage(base64Decode(...))` ή letter fallback. Σύνδεση `_extractContactProps` → `photo` field, περασμένο σε mobile list + grid + detail screen
- **Phase 2 — Photo picker:** Bottom sheet (Camera / Gallery / Delete) στο avatar edit button. `image_picker` + `file_picker` για λήψη/επιλογή, base64Encode → `setText('photo', ...)`. Camera button overlay (24px, primary color)
- **Real-time sync fix:** `propertyWriteVersionProvider` (`StateProvider<int>`) αυξάνεται ΜΟΝΟ από contact photo write (όχι από tasks/notes). `_contactBatchPropsProvider` τον βλέπει με `ref.watch()` και ξανα-τρέχει batch `getAllForItems`. Debug logs παντού
- **Dependencies:** Προσθήκη `image_picker: ^1.1.2`
