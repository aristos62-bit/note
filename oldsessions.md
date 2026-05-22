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

## Session 2 — 22-05-2026

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

**Reorder bugs (collections + entries):**
- Τα pinned+favorite items ΔΕΝ πρέπει να μετακινούνται — αλλάζουν θέση όταν drag-άρονται άλλα items δίπλα/μπροστά τους
- Λύση: αφαίρεση drag handle από pinned/favorite items, να μένουν πάντα στην αρχή της λίστας
- Check: `_canDrag` ήδη υπάρχει, αλλά χρειάζεται να μπλοκάρει και τη μετακίνηση ΑΛΛΩΝ items μπροστά τους

**Home screen folder reorder:**
- Προσθήκη drag-and-drop reorder και στα items μέσα στους φακέλους της αρχικής (HomeFolderView)

**Appointment favorite bug fix (έγινε σήμερα):**
- `item_provider.dart:155` — `ref.invalidate(itemByIdProvider(id))` μετά από `updateItem`
- `appointment_detail_screen.dart` — `_toggleFav` με άμεσο provider call + `item.favorite` από stream

**Notification tap cold start fix (έγινε σήμερα):**
- `NotificationService.getLaunchPayload()` — `getNotificationAppLaunchDetails()` πριν το `init()`
- stub→real handler pattern + επεξεργασία pending payload

**Εκκρεμότητες γενικά:**
- Αφαίρεση debug logs πριν το release
- Έλεγχος collections/entries reorder persistence
