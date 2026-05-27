# SuperNote — Old Sessions Log

## Session 1 — 21-05-2026

### Στόχος
Διόρθωση προβλημάτων στο `main.dart` βάσει αξιολόγησης.

### Τρέχουσα κατάσταση
- `main.dart`: 257 γραμμές
- `super_note_helper.dart`: προστέθηκε `isInitialized` getter (γραμμή 44)

### Αλλαγές που έγιναν

**Βήμα 1 — Error handling στην init**
- `main.dart:17-31`: try-catch γύρω από `Future.wait` για `SuperNoteHelper.init()` + `NotificationService.instance.init()`
- `main.dart:34-38`: έλεγχος `SuperNoteHelper.isInitialized` — αν false, δείχνει `_InitErrorApp` και κάνει return
- `super_note_helper.dart:44`: νέο static getter `isInitialized => _instance != null`
- `main.dart:155-192`: νέο widget `_InitErrorApp` (fallback error screen)

**Βήμα 2 — Memory leak `_AppLifecycleObserver`**
- `main.dart:134`: προστέθηκε `WidgetsBinding.instance.removeObserver(this)` πριν το `container.dispose()`

**Βήμα 3 — Post-frame callbacks με try-catch**
- `main.dart:57-85`: κάθε await στο `addPostFrameCallback` μπήκε σε ξεχωριστό try-catch (requestPermission, scheduleAll, refreshRecurringReminders)

**Βήμα 4 — Web platform check**
- `main.dart:1`: προστέθηκε `import 'package:flutter/foundation.dart';`
- `main.dart:15-18`: `kIsWeb` check — αν true, δείχνει `_WebNotSupportedApp` και κάνει return
- `main.dart:208-248`: νέο widget `_WebNotSupportedApp`

**Βήμα 5 — Dynamic locale**
- `main.dart:21`: `initializeDateFormatting()` χωρίς όρισμα (όλες οι γλώσσες)
- `main.dart:97`: locale διαβάζεται από `_localeFromLanguage(settings.value?.language ?? AppLanguage.auto)`
- `main.dart:127`: `locale: locale` αντί `locale: const Locale('el')`
- `main.dart:142-148`: νέα συνάρτηση `Locale? _localeFromLanguage(AppLanguage lang)` — greek→el, english→en, auto→null

### Επόμενα βήματα (δεν πρόλαβαν)
- Διερεύνηση άλλων θεμάτων (π.χ. SearchScreen route που λείπει από app_router, ή άλλα προβλήματα)

---

## Session 10 — 27-05-2026

### Στόχος
Διόρθωση προβολής χρωματιστών κουκκίδων (ροζ/χρυσό/μπλε) στο ημερολόγιο για την επιλεγμένη ημέρα.

### Πρόβλημα
Στην `CalendarScreen`, όταν μια ημέρα είναι selected (συμπεριλαμβανομένης της today που είναι εξ ορισμού selected), οι κουκκίδες τύπου συμβάντος (birthday→ροζ, specialDay→χρυσό, event→primary) εμφανίζονταν ως **1 λευκή κουκκίδα** αντί για όλες με τα κανονικά τους χρώματα. Ο λόγος ήταν ότι ο κώδικας στο `isSelected` branch έδειχνε μόνο `[markers.first]` με `forceColor: Colors.white`.

### Αλλαγές

**`lib/features/calendar/calendar_screen.dart`:**

| Γραμμές | Περιγραφή |
|---------|-----------|
| 597-606 | `isSelected` branch: `markers: [markers.first]` → `markers: markers`, αφαίρεση `forceColor: Colors.white` και `isToday` |
| 587-594 | `!isSelected` branch: αφαίρεση `isToday:` (ίδιο, απλά καθαρισμός) |
| 627-634 | `_DayMarkerRow`: αφαίρεση unused `isToday` + `forceColor` params |
| 636-637 | `_colorFor`: αφαίρεση `if (forceColor != null)` dead code |

**Αποτέλεσμα:** Και για selected και για non-selected ημέρες, όλες οι κουκκίδες εμφανίζονται με τα κανονικά τους χρώματα (ροζ `#EC4899`, χρυσό `#F59E0B`, primary).

---
### Στόχος
Διόρθωση compile errors από προσθήκη `RecurrenceType.yearly` + UI fixes στο recurrence picker.

### Πρόβλημα
Το `RecurrenceType.yearly` προστέθηκε στο enum (`recurrence.dart:4`) αλλά 3 switch statements δεν το χειρίζονταν:

1. `habit_service.dart:646` — `_isPeriodComplete`: έλειπε case yearly
2. `habit_service.dart:729` — `_prevPeriodStart`: έλειπε case yearly
3. `reminder_section.dart:16` — `recurrenceToRRULE`: έλειπε case yearly
4. `reminder_section.dart:69` — `rruleToRecurrence`: το `freq='YEARLY'` πήγαινε σε `default` → `RecurrenceType.daily`

Επίσης δεν γινόταν parse το `BYMONTH` από το RRULE, οπότε το yearly reminder εμφανιζόταν ως "Καθημερινά".

### Διορθώσεις (από χρήστη με οδηγίες)

| Βήμα | Περιγραφή | Αρχείο |
|------|-----------|--------|
| 1 | Προσθήκη `case RecurrenceType.yearly` στο `_isPeriodComplete` (έλεγχος αν η συγκεκριμένη μέρα-μήνα είναι completed) | `habit_service.dart` ~690 |
| 2 | Προσθήκη `case RecurrenceType.yearly` στο `_prevPeriodStart` (αφαίρεση interval ετών) | `habit_service.dart` ~743 |
| 3 | Προσθήκη `case RecurrenceType.yearly` στο `recurrenceToRRULE` (BYMONTH+BYMONTHDAY) | `reminder_section.dart` ~38 |
| 4 | Προσθήκη `case 'YEARLY'` στο `rruleToRecurrence` + parse `BYMONTH` | `reminder_section.dart` ~69-73 |
| 5 | Αλλαγή type selector από `Row` με `Expanded` σε `ListView` horizontal scroll + label 'Κάθε Χρόνο' για yearly | `reminder_section.dart` ~439-469 |

### Αρχεία που άλλαξαν
- `lib/services/habit_service.dart`
- `lib/shared/widgets/reminder_section.dart`

---
### Στόχος 1
Προσθήκη drag-and-drop reorder στις custom list screens (collections + collection entries).

### Αλλαγές

**Collections reorder** (`collections_screen.dart`):
- Αντικατάσταση `_CollectionsGrid` (`GridView.builder`) με `_CollectionsReorderableGrid`
- Χρήση `SliverReorderableGrid` + `ReorderableGridDragStartListener` (immediate drag, όχι long-press)
- ReorderHandle redesign: bottom-right corner, 48×48 transparent, `RotatedBox(quarterTurns:1)` + `Icons.drag_handle_rounded` + `cText2.withValues(alpha:0.5)`
- `_canDrag(Item item) => !item.pinned && !item.favorite`

**Entries reorder** (`collection_entries_screen.dart`):
- Αντικατάσταση `ListView.separated` με shared `ReorderableItemList` (list mode)

**Bug fixes:**
- Αφαίρεση alphabetical `collections.sort()` (γραμμή 382) που αναιρούσε το reorder
- Αφαίρεση `-1` adjustment στο `_onReorder` για `SliverReorderableGrid`

**ReorderHandle consistency** (`reorder_handle.dart`):
- Εναρμόνιση style: `RotatedBox` + `drag_handle_rounded` + `cText2`

### Στόχος 2
Διόρθωση 6 προβλημάτων reminders/notifications.

| Fix | Περιγραφή | Αρχεία |
|-----|-----------|--------|
| 1 | `pastPendingRemindersProvider`: `getPending()` φιλτράρει triggerAt∈[now, now+7d] → νέα `getPastPending()` χωρίς upper bound | `super_note_helper.dart` |
| 2 | Recurring update: `_saveReminder` άλλαζε μόνο root χωρίς να καθαρίζει παιδιά → `deleteReminderThread` + recreate + `refreshRecurringReminders` | `reminder_section.dart`, `reminder_scheduler.dart` |
| 3 | Habits double-scheduling: `refreshRecurringReminders` δημιουργούσε child reminders για habit roots → filtering habits | `reminder_scheduler.dart` |
| 4 | Notification tap: `_onTap` ήταν TODO → static callback `onNotificationTap` + navigation στο `main.dart` | `notification_service.dart`, `main.dart` |
| 5 | Timezone: hardcoded `Europe/Athens` → system `timeZoneName` με fallback `UTC` | `notification_service.dart` |
| 6 | Status check: `scheduleReminder` δεν έλεγχε `reminder.status` → skip αν status≠pending | `reminder_scheduler.dart` |

### Στόχος 3
Διόρθωση notification tap navigation — δεν πήγαινε στο σωστό item.

**Fix notification tap** (`main.dart`, `app_router.dart`):
- Μετακίνηση `onNotificationTap` assignment πριν το `runApp` (όχι σε postFrameCallback)
- Επέκταση `switch` για όλα τα `ItemType`: note, task, habit, event, appointment, journal, contact
- Προσθήκη missing route builders: `AppRoutes.event()`, `AppRoutes.appointment()`
- Cold start fix: `getNotificationAppLaunchDetails()` ΠΡΙΝ το `init()` για να πιάσει notification taps σε cold start (το `onDidReceiveNotificationResponse` ΔΕΝ πυροδοτείται πάντα σε cold start)
- Stub `onNotificationTap` πριν το `init()` ως fallback για warm start
- Νέα μέθοδος `NotificationService.getLaunchPayload()` (`notification_service.dart`)

### Εκκρεμότητες — Επόμενα βήματα

**Reorder bugs (collections + entries):** ✅ Fixed
- Τα pinned+favorite items ΔΕΝ μετακινούνται πλέον όταν drag-άρονται άλλα items

**Home screen folder reorder:** ✅ Fixed
- Drag-and-drop reorder προστέθηκε και στα items μέσα στους φακέλους της αρχικής (HomeFolderView)

**Appointment favorite bug fix (έγινε σήμερα):**
- `item_provider.dart:155` — `ref.invalidate(itemByIdProvider(id))` μετά από `updateItem`
- `appointment_detail_screen.dart` — `_toggleFav` με άμεσο provider call + `item.favorite` από stream

**Notification tap cold start fix (έγινε σήμερα):**
- `NotificationService.getLaunchPayload()` — `getNotificationAppLaunchDetails()` πριν το `init()`
- stub→real handler pattern + επεξεργασία pending payload

**Εκκρεμότητες γενικά:**
- Αφαίρεση debug logs πριν το release
- Έλεγχος collections/entries reorder persistence

---

## Session 3 — 23-05-2026

### Στόχος
Αξιολόγηση project για λάθη και βελτιστοποιήσεις.

### Τι έγινε

**Read-only ανάλυση ολόκληρου του codebase:**
- Διάβασμα όλων των providers, models, services, core, helpers, shared widgets, features
- Εντοπίστηκαν αρχικά 15+ issues

**Διορθώσεις που έγιναν (μετά από έγκριση):**

| # | Περιγραφή | Αρχείο | Status |
|---|-----------|--------|--------|
| 4 | `delete(int)` στο AttachmentService: αφαίρεση dead code, προσθήκη disk delete | `attachment_service.dart` + `super_note_helper.dart` | ✅ Fixed |
| 5 | Λάθος φιλτράρισμα items με null/empty title στο `itemsStreamProvider` | `item_provider.dart` | ✅ Fixed |
| 6 | Backup import: try-catch ώστε η DB να ξανανοίγει αν αποτύχει το file copy | `backup_service.dart` | ✅ Fixed |

**Θέματα που συζητήθηκαν και κρατήθηκαν (χωρίς αλλαγή):**
- #3: `task_provider.dart` υπάρχει κανονικά στο barrel providers.dart
- #7: `habitStatsProvider` — το `ref.listen` δεν έχει performance issue γιατί `watchById` δεν πυροδοτείται από writes σε ItemProperty
- #8: `_scheduleReminders` maxPerTime — συζητήθηκε αλλά δεν εφαρμόστηκε

**Νέο κρίσιμο εύρημα:**
- Circular import: `task_provider.dart` → `import 'providers.dart'` και `providers.dart` → `export 'task_provider.dart'`
- Προκαλούσε 16+ compile errors στο `flutter analyze`
- Λύση: αλλαγή import στο `task_provider.dart` από barrel σε απευθείας imports (επιδιορθώθηκε από χρήστη)

### Εκκρεμότητες
- Ολοκλήρωση αξιολόγησης εμφάνισης και λειτουργικότητας
- Reorder bugs (pinned/favorite items) — ✅ Fixed (session 6)
- Home screen folder reorder — ✅ Fixed (session 6)
- `value` deprecated στο collection_entries_screen.dart
- Αφαίρεση debug logs

---

## Session 6 — 24-05-2026

### Στόχος 1
Διόρθωση bugs σε επαναλαμβανόμενες υπενθυμίσεις (duplicate notifications + λάθος μέρα).

### Προβλήματα από logs
1. **Item 124 (ημερήσιο)**: Root id=133 και child id=134 είχαν ίδιο `triggerAt` → 2 notifications
2. **Item 209 (εβδομαδιαίο Δευ+Παρ)**: Root id=139 είχε trigger=Σάββατο (BYDAY=MO,FR) → χτύπησε και Σάββατο και Παρασκευή

### Διορθώσεις (έκανε ο χρήστης με οδηγίες)

| Fix | Περιγραφή | Αρχείο | Γραμμές |
|-----|-----------|--------|---------|
| A | `refreshRecurringReminders`: αφαίρεση `todayAtTriggerTime - interval` που προκαλούσε child με ίδια ώρα με root | `reminder_scheduler.dart` | 177-178 |
| B1 | `_saveReminder` recurring UPDATE: αφαίρεση `scheduleReminder(root)` — το root (με συγκεκριμένη ημερομηνία) δεν πρέπει να προγραμματίζεται | `reminder_section.dart` | 177 |
| B2 | `_saveReminder` recurring CREATE: `refreshRecurringReminders()` αντί για `scheduleReminder(newReminder)` | `reminder_section.dart` | 212-217 |
| C | `scheduleAll()`: φιλτράρισμα roots με rrule ώστε να μην προγραμματίζονται στο startup | `reminder_scheduler.dart` | 34-43 |

### Αρχεία που άλλαξαν
- **`lib/services/reminder_scheduler.dart`**: Fix A (start χωρίς interval subtraction) + Fix C (filter roots in scheduleAll)
- **`lib/shared/widgets/reminder_section.dart`**: Fix B1 (update path) + Fix B2 (create path για recurring)

### Backup
- `backups/reminder_scheduler.dart.backup.20260524`
- `backups/reminder_section.dart.backup.20260524`

### Επόμενο βήμα — Session 7
**Νέο feature: Import επαφών από κινητό στις Ρυθμίσεις**

Ο χρήστης θα μπορεί:
- Να επιλέγει στις Ρυθμίσεις αν θέλει να εισαγάγει επαφές από το τηλέφωνο
- Να επιλέγει ποια πεδία θα μεταφερθούν (όνομα, τηλέφωνο, email, εταιρεία, website, διεύθυνση, γενέθλια, φωτογραφία)
- Αποφυγή duplicates (match με όνομα/τηλέφωνο)
- Progress indicator για πολλές επαφές

Απαιτεί:
- Package `flutter_contacts` (προτείνεται) ή `contacts_service` στο pubspec.yaml
- Runtime permission (pattern από NotificationService.requestPermission)
- UI επιλογής πεδίων στη SettingsScreen
- Mapping phone contact fields → Item(contact) + ItemProperty
- Φωτογραφία: αποθήκευση ως base64 σε ItemProperty ή attachment

---

## Session 4 — 23-05-2026

### Στόχος
Refactor Home Screen — καλύτερη απόδοση, ασφάλεια (stale state), λιγότερα rebuilds.

### Τι έγινε

**1. Επέκταση folder icons + colors**
- `home_screen.dart` + `folder_browser_screen.dart`: 20+ νέα icons (πρόσωπα👦👧👴👵👨👩👶🧑👪, εργαλεία🛠️⚙️🔧🧰📐💻📱, οικογένεια, κλπ)
- `_kFolderColors`: από 12 σε 24 χρώματα (12 original + 12 light variants)

**2. FolderBrowserScreen — staleness fix**
- Αφαίρεση `initState` + `setState` για `_folder`
- Νέος `folderByIdProvider` (StreamProvider.family) με `isar.folders.watchObject(id, fireImmediately: true)`
- `_folder` συγχρονίζεται από stream στην αρχή του `build()`
- Διόρθωση `LateInitializationError` — μεταφορά `_folder` πριν από `DebugConfig.provider` που διάβαζε `_folder.id`

**3. Combined FolderView provider — μείωση rebuilds 5→1**
- `item_provider.dart`: νέο `FolderViewData` class + `folderViewDataProvider` (StreamProvider.family)
- `home_folder_view.dart`: 1 `ref.watch` αντί για 5 (stats, pinned, favorites, recent, itemsByFolder)
- `_buildContent` απλοποιήθηκε από ~65 γραμμές σε ~20
- Backups σε `backups/*.backup`

## Session 5 — 23-05-2026 (continuation)

### Στόχος
Ολοκλήρωση εκκρεμοτήτων από session 4.

### Αλλαγές

**1. try-catch σε color hex parsing**
- `home_screen.dart:444-450` και `folder_browser_screen.dart:147-153`: προσθήκη try-catch στα edit dialogs (έλειπαν σε σχέση με τα υπόλοιπα 2 σημεία που ήδη είχαν)
- Consistency: και τα 4 σημεία hex parsing στο home έχουν πλέον try-catch

**2. Loading skeleton**
- `home_screen.dart:881`: `SizedBox.shrink()` → `_LoadingSkeleton()`
- Νέο widget `_LoadingSkeleton` (γραμμές 1091-1137): grid 2 rows × 3/4 columns με placeholder containers + title placeholder
- Χρώμα: `surfaceContainerHighest` από theme (dark mode compatible)

**3. Duplicate icons — skipped** (user δεν τον ενοχλούν)
**4. DebugConfig.print — θα κλείσει ο χρήστης μετά την ανάπτυξη**

### Εκκρεμότητες
- Αφαίρεση duplicate icons (🧠🛠️⚙️🔧🧰📐💻📱🔑🚀🎉) — cancelled by user (δεν τον ενοχλούν) (δεν τον ενοχλούν)
- Προσθήκη try-catch σε color hex parsing — ✅ Fixed (session 5)
- DebugConfig.print calls — θα κλείσει ο χρήστης συνολικά μετά την ανάπτυξη
- Loading skeleton αντί για SizedBox.shrink() — ✅ Fixed (session 5)
- Διερεύνηση compile errors που βλέπει ο χρήστης στην Home Folder View (αν υπάρχουν)

---

## Session 7 — 24-05-2026 (συνέχεια 25-05-2026)

### Στόχος
Import επαφών από κινητό — Πλήρης υλοποίηση.

### Αλλαγές που έγιναν

**Βήμα 1 — Package `flutter_contacts`**
- `pubspec.yaml`: προστέθηκε `flutter_contacts: ^2.1.0`
- `flutter pub get`

**Βήμα 2 — Permissions στα manifest**
- `AndroidManifest.xml:11`: `<uses-permission android:name="android.permission.READ_CONTACTS"/>`
- `Info.plist:27-28`: `NSContactsUsageDescription` (ελληνικό string)

**Βήμα 3 — Νέο service `ContactImportService`**
- `lib/services/contact_import_service.dart`: singleton (24 γρ.)
- `requestPermission()` + `fetchContacts()`
- `services.dart` barrel: export (γρ. 14)

**Βήμα 4 — UI tile στις Ρυθμίσεις**
- `settings_screen.dart:148-153`: `_ActionTile` "Εισαγωγή επαφών"
- stub `_importContacts()`

**Βήμα 5 — Πλήρης επέκταση (25-05-2026)**

`lib/services/contact_import_service.dart` — 357 γραμμές:
- `ContactField` enum: name, phones, email, company, website, address, birthday, notes, photo
- `ImportProgress` class: current, total, contactName, status, fraction
- `ImportResult` class: imported, skipped, errors, errorDetails
- `importContacts()`: fetch → dedup → map → save (με progress callback)
- `_existsInDb()`: duplicate check — ίδιο όνομα (case insensitive) Ή ίδιο τηλέφωνο (μέσω JSON)
- `_mapContactToItem()`: mapping όλων των πεδίων με `Future.wait` (παράλληλη αποθήκευση)

Mapping:
| flutter_contacts | Isar |
|---|---|
| `displayName` | `Item.title` |
| `phones[].number` | `ItemProperty("phones", jsonEncode[...])` |
| `emails[].address` | `ItemProperty("email")` |
| `organizations[].name` | `ItemProperty("company")` |
| `websites[].url` | `ItemProperty("website")` |
| `addresses[].street+city+...` | `ItemProperty("address")` |
| `events[].year+month+day` | `ItemProperty("birthday", date)` |
| `notes[].note` | `ItemProperty("notes")` |
| `photo.fullSize/thumbnail` | `ItemProperty("photo", base64)` |

`lib/features/settings/settings_screen.dart` — 3 νέοι διάλογοι:
- `_showFieldSelectionDialog()` — checkbox list πεδίων (προ-επιλεγμένα όλα)
- `_ImportProgressDialog` — `LinearProgressIndicator` + όνομα επαφής + αριθμός
- `_showImportSummary()` — εισήχθησαν / παραλείφθηκαν / σφάλματα

Backups:
- `backups/contact_import_service.dart.backup.20260524`
- `backups/settings_screen.dart.backup.20260524`

**Βήμα 6 — Επιλογή επαφών + Διαχείριση εισαγμένων (25-05-2026)**

`lib/features/settings/settings_screen.dart`:
- **`_showContactSelectionDialog()`** — dialog με search + checkboxes, "Επιλογή όλων" / "Αποεπιλογή"
- **`_showImportedContactsDialog()`** — dialog στο group Βάση για διαγραφή εισαγμένων επαφών (μία-μία ή όλες)
- Ροή import: permission → fetch → **contact selection** → field selection → import → summary
- `_ImportProgressDialog` δέχεται πλέον `List<Contact>` (όχι fetch internally)

`lib/services/contact_import_service.dart`:
- `importContacts()` δέχεται `List<Contact>` αντί να κάνει fetch internally
- `_mapContactToItem()`: προστέθηκε marker `ItemProperty("_imported", "true", isVisible: false)`
- Νέο `getImportedContactIds()` — query για όλες τις import-marked επαφές
- Νέο `deleteImported(Set<int>)` — soft delete επιλεγμένων

### Εκκρεμότητες
- ✅ Επιλογή πεδίων
- ✅ Mapping Contact → Item + ItemProperty
- ✅ Progress indicator
- ✅ Αποφυγή duplicates
- ✅ Φωτογραφία ως base64
- ✅ Επιλογή επαφών (όλες ή επιλεγμένες)
- ✅ Διαχείριση/διαγραφή εισαγμένων (μία-μία ή όλες)
- ❌ Δοκιμή σε πραγματική συσκευή

---

## Session 8 — 24-05-2026

### Στόχος
Διόρθωση permission denied + επιλογή φακέλου στη ροή import επαφών.

### Προβλήματα

**1. Permission πάντα `granted=false`**
- Αιτία: το manifest είχε μόνο `READ_CONTACTS` αλλά το `request()` ζητούσε `PermissionType.readWrite` (θέλει και `WRITE_CONTACTS`)
- Δεν εμφανιζόταν καν dialog άδειας

**2. Imported contact δεν εμφανιζόταν στο `/contacts`**
- Το `folderId` ερχόταν από `settings.preferredFolderId` που ήταν `null`
- Η επαφή δημιουργόταν χωρίς folder → αόρατη στο φιλτραρισμένο contact list

### Αλλαγές

**`android/app/src/main/AndroidManifest.xml` (γρ. 11):**
- Προστέθηκε `<uses-permission android:name="android.permission.WRITE_CONTACTS"/>`

**`lib/services/contact_import_service.dart` (γρ. ~24-36):**
- `requestPermission()`: πρώτα `check(PermissionType.read)`, μετά `request(PermissionType.read)` αντί για `readWrite`

**`lib/features/settings/settings_screen.dart`:**
- Νέος διάλογος `_showFolderPickerDialog()` — λίστα όλων των folders του workspace με εικονίδια, προ-επιλογή από `preferredFolderId`
- `_importContacts()`: η ροή έγινε permission → fetch → **contact selection** → **field selection** → **🔹 folder picker** → import → summary
- Αν ο χρήστης πατήσει Ακύρωση στο folder picker, το import σταματάει

### Backup
- `backups/settings_screen.dart.backup.20260524.2`

### Session 8b (same day) — Crash fix + duplicate detection fix

**Πρόβλημα 1 — Crash στο folder picker**
- `int.parse(folder.icon!)` κρασάρε όταν το εικονίδιο είναι emoji (π.χ. `"🏠"`)
- **Fix**: αντικατάσταση `Icon(IconData(int.parse(...)))` με `Text(folder.icon ?? '📁')`

**Πρόβλημα 2 — Duplicate detection έβρισκε soft-deleted items**
- `_existsInDb()` δεν φιλτράριζε `deletedAt` → orphaned items εμπόδιζαν re-import
- **Fixes στο `contact_import_service.dart`:**
  - Name check: `.deletedAtIsNull()`
  - Phone check: `parent.deletedAt != null` → skip
  - `deleteImported()`: διαγραφή `ItemProperty` του deleted item

### Τελική κατάσταση (από logs)
- Permission ✅, folder picker ✅, import ✅, detail ✅, delete ✅
- 123 contacts fetched, 0 duplicates (μετά το fix)
- `deleteImported` καθαρίζει ItemProperties → δεν μένουν orphaned

---

## Session 10 — 27-05-2026

### Στόχος
Διόρθωση προβολής χρωματιστών κουκκίδων (ροζ/χρυσό/μπλε) στο ημερολόγιο για την επιλεγμένη ημέρα.

### Πρόβλημα
Στην `CalendarScreen`, όταν μια ημέρα είναι selected (συμπεριλαμβανομένης της today που είναι εξ ορισμού selected), οι κουκκίδες τύπου συμβάντος (birthday→ροζ, specialDay→χρυσό, event→primary) εμφανίζονταν ως **1 λευκή κουκκίδα** αντί για όλες με τα κανονικά τους χρώματα. Ο λόγος ήταν ότι ο κώδικας στο `isSelected` branch έδειχνε μόνο `[markers.first]` με `forceColor: Colors.white`.

### Αλλαγές

**`lib/features/calendar/calendar_screen.dart`:**

| Γραμμές | Περιγραφή |
|---------|-----------|
| 597-606 | `isSelected` branch: `markers: [markers.first]` → `markers: markers`, αφαίρεση `forceColor: Colors.white` και `isToday` |
| 587-594 | `!isSelected` branch: αφαίρεση `isToday:` (ίδιο, απλά καθαρισμός) |
| 627-634 | `_DayMarkerRow`: αφαίρεση unused `isToday` + `forceColor` params |
| 636-637 | `_colorFor`: αφαίρεση `if (forceColor != null)` dead code |

**Αποτέλεσμα:** Και για selected και για non-selected ημέρες, όλες οι κουκκίδες εμφανίζονται με τα κανονικά τους χρώματα (ροζ `#EC4899`, χρυσό `#F59E0B`, primary).

---

