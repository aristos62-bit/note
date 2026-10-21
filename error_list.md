# error_list.md — Η ΜΟΝΑΔΙΚΗ λίστα εκκρεμοτήτων & προόδου

> **Κανονιστικό (ισχύει μέχρι να διαγραφεί αυτό το αρχείο):**
> - Το `error_list.md` είναι η **μοναδική πηγή** για εκκρεμότητες, προτεραιότητα και πρόοδο.
> - **Απαγορεύεται** να συντηρούνται παράλληλες λίστες σε άλλα `.md`. Ό,τι λέει το `code_refactor.md` §3/§7/§8/§9, το `supernote.md` (status/error-handling/performance) ή το `oldsessions.md` για *ανοιχτά* θέματα **δεν είναι έγκυρο** — έγκυρο είναι μόνο ό,τι λέει αυτό το αρχείο.
> - `supernote.md` = μόνο αρχιτεκτονική (κανόνας 8, αμετάβλητο). `oldsessions.md` = ιστορικό (δεν ενημερώνεται όσο τρέχει αυτή η λίστα).
> - Στο **τέλος** (όταν κλείσουν όλα): διαγραφή `error_list.md` → ένα κεφάλαιο στο `oldsessions.md` + ενημέρωση/καθάρισμα `code_refactor.md` + `supernote.md`.
>
> **📌 ΠΡΙΝ ΑΠΟ ΚΑΘΕ ΕΝΗΜΕΡΩΣΗ: το πρώτο που διαβάζω είναι αυτό το SOP.**
> **SOP ενημέρωσης (η ροή του E15 = πρότυπο για κάθε fix):**
>
> **Α. Πριν από κάθε edit**
> 1. Διαβάζω την κάρτα + **όλο** τον σχετικό κώδικα· ελέγχω side effects σε άλλες λειτουργίες.
> 2. Προτείνω λύση με εναλλακτικές/απορρίψεις + ρίσκα· **δεν αγγίζω τίποτα χωρίς OK**.
> 3. Backup σε `backups/s<session>_<id>/` (ό,τι θα αγγίξω + `BASE_HEAD.txt`).
>
> **Β. Υλοποίηση — ένα βήμα τη φορά (στάση μετά από κάθε βήμα)**
> 4. Κάθε βήμα: **πλήρες παλιό block + πλήρες νέο** + ακριβές σημείο (`αρχείο:γραμμές`) + τι κάνει.
> 5. Ο κώδικας εφαρμόζεται από τον χρήστη (ή από εμένα με edit-tool όταν το ζητήσει) → `flutter analyze` → στάση.
> 6. Στο τελευταίο βήμα: `flutter analyze` + `flutter test` (baseline π.χ. 259/259).
>
> **Γ. Device test (πριν γραφτεί οτιδήποτε στη λίστα)**
> 7. **Πρώτα** ρητή λίστα δεδομένων από τον χρήστη (κανόνας 12)· ποτέ δεδομένα μέσω adb.
> 8. Ένα σενάριο τη φορά (T1…Tn) με προσδοκία· μέτρηση από **2 ανεξάρτητες πηγές** όπου γίνεται (app log + `dumpsys alarm`/`notification`).
>
> **Δ. Ενημέρωση λίστας — μόνο στο τέλος, όχι σε κάθε βήμα**
> 9. Backup του `error_list.md` στο ίδιο `backups/s<session>_<id>/`.
> 10. **§1:** αφαιρώ το κλειστό ID (count −1)· νέα ευρήματα με το επόμενο ελεύθερο `E<n>` (ποτέ reuse) και count +1· σειρά = σοβαρότητα· renumber 1..N.
> 11. **§2:** κλειστό → `### E<n> — ✅ CLOSED <ημ/νία>` + 1 γραμμή (υλοποίηση + device)· νέες κάρτες σε αύξουσα σειρά **πριν την `E26`**· πεδία: `Πού` · `Απόδειξη` · `Γιατί Px` · `Κόστος/Ρίσκο` · `Fix/Acceptance`.
> 12. **§3:** 1 bullet με την απόδειξη κλεισίματος (τι άλλαξε + πώς επαληθεύτηκε σε device).
> 13. **§4:** 1 γραμμή ανά βήμα (υλοποίηση · device · νέα ευρήματα) με πραγματικά line refs/logs — όχι «ίσως/κάποτε».
> 14. **§0:** αλλάζει **μόνο** αν άλλαξε μέτρηση (analyze/tests/HEAD/αρχεία >500), με ημερομηνία.
> 15. `flutter analyze` (docs-only αλλαγή: προαιρετικό αλλά γίνεται) → **commit + push** με το ID στο message.
>
> **Παράδειγμα αναφοράς — E15 (21/10/2026):** §1 `(6)`→`(7)` (E15 έξω, E29+E30 μέσα) · §2 E15→`✅ CLOSED` + E29/E30 πριν την E26 · §3 1 bullet · §4 3 γραμμές · commit `9bb4567`.
> **Απαγορεύεται:** παράλληλες λίστες · ενημέρωση `supernote.md`/`oldsessions.md` όσο ζει αυτό το αρχείο · κλείσιμο χωρίς απόδειξη · commit χωρίς push.
> **Κανόνας 12:** πριν από κάθε device test ζητάω από τον χρήστη ρητή λίστα δεδομένων. Ποτέ δεδομένα μέσω adb.
> **Κανόνας προτεραιότητας (21/10/2026):** ① **P1 = σφάλματα** που επιφέρουν μεγάλα λάθη στην εφαρμογή · ② **P2 = βελτιώσεις λειτουργιών** που ήδη υπάρχουν · ③ **P3 = μελλοντικές προσθήκες/αναβαθμίσεις** (+ δομική καθαριότητα). Κάθε νέο εύρημα μπαίνει υποχρεωτικά στην παραπάνω κατηγορία.

---

## 0. Baseline (μετρημένο στον κώδικα — 21/10/2026)

| Μέτρηση | Τιμή | Πηγή |
|---|---|---|
| Git HEAD | `71cef63` (S262-b) | `git log` |
| `flutter analyze` | **No issues found** | run 21/10/2026 |
| `flutter test` | **259/259** (46 αρχεία test) | run 21/10/2026 |
| Γραμμές `lib/` (χωρίς `*.g.dart`) | 38.028 | μετρήθηκε |
| Αρχεία >500 γραμμές (R1) | **18** | βλ. E06 |
| `Semantics(` | **3** (2 `Semantics` + 1 `ExcludeSemantics`) | grep |
| `tooltip:` | **89** | grep |
| `autoDispose` providers | **6** (όχι 7 — το 7ο hit είναι σχόλιο) | grep |
| `catch (_) {}` | **21** (R4 παράβαση) | grep |
| `debugPrint`/`print` εκτός `DebugConfig` | 0 | grep |

⚠️ **Γνωστό doc-drift:** `supernote.md:17` γράφει 245/245, πραγματικό **259/259**. Δεν διορθώνεται τώρα (status ≠ αρχιτεκτονική) — θα διορθωθεί στο τελικό sync (E26).

### 0.1 Δεύτερος έλεγχος (21/10/2026) — τι διορθώθηκε στη λίστα
1. **`E24` «grid-mode guard gap» → ακυρώθηκε ως bug.** Έλεγξα το SDK (`reorderable_list.dart:82-83,129-131`: το `onReorderItem` διορθώνει το `newIndex`) **και** το package (`reorderable_grid.dart:652-663,573-577`: δίνει index κελιού-στόχου). Και τα δύο ταιριάζουν με το `removeAt+insert` του `moveAndMerge` ⇒ **όχι off-by-one**. Μένει μόνο προαιρετικό device spot-check.
2. **`E22` έγινε μετρημένο, όχι «κληρονομημένο»:** επιβεβαιώθηκαν `O(n²)` (`block_editor_widget.dart:110-113`), πάντα-ορατό delete (`:265-284`), `DateTime.now()` σε build (`task_list_screen.dart:302`), χειροκίνητο `d/m/yyyy` (4 σημεία). Τα υπόλοιπα σημειώνονται per-case.
3. **Νέο `E27`:** grid reorder `autoScroll: false` (`reorderable_item_list.dart:137`). **Νέο `E28`:** 12 raw `showModalBottomSheet` χωρίς `SafeSheet` (SPoT bypass, όχι αποδεδειγμένο bug).
4. **Διορθώθηκαν line refs** που ήταν stale: `_details`/`_onTap`/`_onBackgroundTap` = `notification_service.dart:396-414/416-425/428-433` (όχι `:325-343`)· `supernote.md` Error Handling `:891-905`, Performance `:908-919`.
5. **Νέα ιεράρχηση (εντολή χρήστη):** τα σοβαρότερα = **σφάλματα** που επιφέρουν μεγάλα λάθη, μετά **βελτιώσεις λειτουργιών**, μετά **μελλοντικές προσθήκες/αναβαθμίσεις** — βλ. §1. Καταργήθηκε η παλιά μίξη P3/P4.

---

## 1. Ιεράρχηση — 3 κατηγορίες (κανόνας χρήστη, 21/10/2026)

> **P1 = ΣΦΑΛΜΑΤΑ** → μεγάλα λάθη/αστάθεια/λάθος δεδομένα. **Πρώτα αυτά.**
> **P2 = ΒΕΛΤΙΩΣΕΙΣ ΛΕΙΤΟΥΡΓΙΩΝ** → κάτι υπάρχει αλλά είναι αργό/άβολο/με ρίσκο.
> **P3 = ΜΕΛΛΟΝΤΙΚΕΣ ΠΡΟΣΘΗΚΕΣ – ΑΝΑΒΑΘΜΙΣΕΙΣ** → νέα features + δομική καθαριότητα.
> **P4 = By-design/αποδεκτά** → καμία ενέργεια. *Κανένα επιβεβαιωμένο crash ή απώλεια δεδομένων.*

### 🔴 P1 — Σφάλματα (6)

| # | ID | Θέμα | Γιατί είναι P1 (απόδειξη) |
|---|---|---|---|
| 1 | `E29` | **Wipe χωρίς `cancelAll()`** | Μετά το «διαγραφή όλων» μένουν OS alarms/tray με παλιό περιεχόμενο (`settings_backup.dart:161-291`) |
| 2 | `E17` | **F4** — `rescheduleForItem` ×5 χωρίς `timeout` | Awaited UI flows: πάγωμα/κόλλημα σε αργό OS/DB (`item_provider.dart:203,214,275,341,360`) |
| 3 | `E16` | **F3** — `main` χωρίς `timeout` | Το startup μπορεί να μπλοκάρει (`settings.get` / `requestPermission`) |
| 4 | `E18` | **`catch (_) {}` ×21** (R4) | Κρύβει σφάλματα (backup/attachments/habits) → αόρατες αποτυχίες |
| 5 | `E04` | **Outer-context theme lookup** (κλάση S129/S133) | Crash-class: debug assertion, ρίσκο σε release/reassemble |
| 6 | `E10` | **B2.3** — title/body χωρίς σύγκριση πριν το rebake | Ειδοποίηση με παλιό/λάθος κείμενο μέχρι το επόμενο rebake |

### 🟠 P2 — Βελτιώσεις λειτουργιών (10)

| # | ID | Θέμα | Τι βελτιώνει |
|---|---|---|---|
| 7 | `E05` | **F13b** — bulk-delete perf (`permanentDeleteMany`) | Πάγωμα ~7s σε μαζική διαγραφή (N× invalidate + passes) |
| 8 | `E08` | **Notification-permission status + persistent OFF hint** | Χάνονται ειδοποιήσεις χωρίς ορατή εξήγηση στον χρήστη |
| 9 | `E02` | **Calendar AppBar title @140%** | Κόβεται το «Οκτώβριος 2026» — θέλει σχεδιαστική απόφαση |
| 10 | `E27` | **Grid reorder χωρίς autoScroll** | Δεν φτάνεις μακρινούς στόχους σε μεγάλο grid |
| 11 | `E22` | **Υπόλοιπα §3.8** (μετρημένα) | `O(n²)` block editor · πάντα-ορατό delete · `d/m/yyyy` · `DateTime.now()` σε build |
| 12 | `E28` | **12× raw `showModalBottomSheet`** (SPoT bypass) | Θωράκιση landscape/keyboard (όχι αποδεδειγμένο bug) |
| 13 | `E19` | **`take(10)` ×2 + διπλότυπη λογική φίλτρου** | Λάθος/διπλά αποτελέσματα σε άκρες |
| 14 | `E20` | **`firstDate: DateTime(2000)` ×3** | Αποκλείει παλιές ημερομηνίες (birthdays/αρχεία) |
| 15 | `E01` | ⏸️ **PARKED** — a11y pass (Semantics / 48dp / PII) | Προσβασιμότητα υπάρχουσας λειτουργίας |
| 16 | `E03` | **Device re-verify grid auto-height** | Επαλήθευση ότι δεν υπάρχει regression (100%/140%, portrait/landscape) |

### 🔵 P3 — Μελλοντικές προσθήκες / αναβαθμίσεις + καθαριότητα (10)

| # | ID | Θέμα | Τύπος |
|---|---|---|---|
| 17 | `E07` | **Snooze UI + notification actions** | Νέα λειτουργία (θέλει spec) |
| 18 | `E09` | **Attachments add-button + badge στην κάρτα** | Νέα λειτουργία (θέλει απόφαση) |
| 19 | `E11` | **Ενοποιημένο `DetailAppBar`** | Αναβάθμιση/consistency |
| 20 | `E12` | **8× «Εμφάνιση/Απόκρυψη αρχειοθετημένων»** → shared widget | Καθαριότητα |
| 21 | `E06` | **R1: 18 αρχεία >500 γραμμές** | Δομική αναβάθμιση (splits ή χαλάρωση κανόνα) |
| 22 | `E13` | **B-Π2b** — κρύψιμο label «Φάκελοι» σε κοντό viewport | Προσθήκη *(μόνο αν φανεί στο E03)* |
| 23 | `E14` | **F19** — dead providers (`pendingReminders*`) | Καθαριότητα |
| 24 | `E21` | **Stale TODOs ×7** (`models/`) | Καθαριότητα |
| 25 | `E23` | **G-track (S120)** — ρητό κλείσιμο | Απόφαση |
| 26 | `E25` | **Doc-drift παλιών docs** | Συντήρηση (κλείνει με E26) |

**P4 — By-design / αποδεκτά (καμία ενέργεια)**
- iOS parked ×2 · 6-actions overflow `note_detail` · zombie-overlap residual (S245) · αρχαίες S~92 σημειώσεις · display-inDays DST cosmetic · `custom:184` σημείωση (stale) · contact-dialog chrome 7.3px (debug-only, αποδεκτό).

**Κλειστό κατά τον 2ο έλεγχο**
- `E24` «grid-mode guard gap» → **stale / όχι bug** (SDK + package source)· βλ. §3.

**Τελικό βήμα**
- `E26` **Κλείσιμο**: διαγραφή `error_list.md` + sync `oldsessions.md`/`code_refactor.md`/`supernote.md`.

---

## 2. Κάρτες εκκρεμοτήτων (στοιχεία + απόδειξη + αποδοχή)

### E01 — a11y pass ⏸️ PARKED
- **Κατάσταση:** PARKED 19/10/2026 (απόφαση χρήστη: μελλοντική υλοποίηση). Δεν αφαιρείται/αναριθμείται.
- **Απόδειξη (μετρήθηκε):** `Semantics(` = **3** συνολικά (`habit_detail_screen.dart:1080,1764` · `collection_detail_screen.dart:594` = `ExcludeSemantics`) · `tooltip:` = 89.
- **Λείπει:** TalkBack pass, 48dp hit-targets, no-PII semantics, flicker, touch 16–22px.
- **Πριν την υλοποίηση:** refresh protocol `a11y.md` §0.1 (baseline, diff από `bd6f82a`, device audit C1–C22, επανεξέταση D1–D6).
- **Αποδοχή:** device pass (κανόνας 12 — ρητή λίστα δεδομένων) + μηδέν PII στα semantics + 48dp στα βασικά actions.

### E02 — Calendar AppBar title @140%
- **Πού:** `calendar_screen.dart:198-209` — `title: Text('${months[focusedMonth.month - 1]} ${focusedMonth.year}', style: context.titleLg)` χωρίς `maxLines`/ellipsis/`Flexible`.
- **Σύμπτωμα (device S262-b):** «Οκτώβριος» → «Οκτώβρ…» @140%.
- **Επιλογές:** (α) σύντομο format «Οκτ ’26» · (β) 2 γραμμές · (γ) μικρότερο `titleLg`/κουμπιά. **Απαιτείται απόφαση χρήστη.**
- **Αποδοχή:** πλήρες/κόσμιο label σε 100% & 140%, portrait/landscape, 0 overflow.

### E03 — Device re-verify grid auto-height (#2)
- **Κατάσταση:** κώδικας ✅ S261 · ευρήματα A/B ✅ διορθώθηκαν S262 + S262-b · **εκκρεμεί re-verify**.
- **Τι ελέγχεται:** journal, contacts, trash, search, home, collections, tasks, entries, habits — 100%/140%, portrait/landscape, chips πλήρη, 0 `RenderFlex overflow`.
- **Κανόνας 12:** πριν το test ζητείται ρητή λίστα δεδομένων.
- **Αποδοχή:** 0 overflow/κοψίματα + screenshots.

### E04 — Outer-context Theme lookup hardening (S129/S133 class)
- **Πού (επαληθευμένο στον κώδικα):**
  - `task_detail_screen.dart:785,789,790,795` (status) & `:847,852,853` (priority) — το `SafeSheet` builder διαβάζει το **outer** `context.*`.
  - `settings_tiles.dart:195,199` (size picker) · `:282,286,288,291` (folder picker + outer `Navigator.pop`).
  - `collection_detail_screen.dart:802,812,818` (icon picker — `builder: (_)` + outer `context`).
  - `settings_colors.dart:101-102` (outer `context` μέσα σε `onSelected`).
- **Τι:** debug assertion (release-safe) αν το route της detail-οθόνης αποενεργοποιηθεί/reassemble με ανοιχτό sheet.
- **Fix:** `context.` → `sheetCtx.`/`ctx.` (0 layout αλλαγή). **Κόστος:** 1 μικρό session. **Ρίσκο:** χαμηλό· θέλει device reassemble test ανά sheet.
- **Αποδοχή:** reassemble με ανοιχτό sheet → 0 assertions.

### E05 — F13b: bulk-delete perf
- **Πού:** `trash_screen.dart:90-103` — loop `await notifier.permanentDelete(id)`.
- **Κόστος ανά item:** `item_provider.dart:285-310` → `_cascadeCollectionEntries` + `getForItem` + `deleteAllRemindersForItem`/`deleteHabitReminders` + `hardDelete` + `invalidateSelf()` (N×).
- **Πρόταση:** `ItemNotifier.permanentDeleteMany(List<int> ids)` — ίδια σειρά/εγγυήσεις: habit = wipe + hardDelete **στο ίδιο pass** (S250), NEVER-THROW, `finally` 1× invalidate, attachments cleanup, cascade entries.
- **Ρίσκο:** **υψηλό** (S250 race + S142 lifecycle + attachments). Θέλει ισοδυναμία: ίδιο τελικό state με N×.
- **Αποδοχή:** `analyze` clean + tests + device bulk delete (ρητή λίστα δεδομένων) με 0 ERR.

### E06 — R1: 18 αρχεία >500 γραμμές
Επιβεβαιωμένο μέτρημα (`lib/`, χωρίς `*.g.dart`):

| Αρχείο | Γραμμές |
|---|---|
| `features/habits/habit_detail_screen.dart` | 1719 |
| `features/collections/collection_entries_screen.dart` | 1691 |
| `features/contacts/contact_detail_screen.dart` | 1389 |
| `helpers/super_note_helper.dart` | 1322 |
| `features/tasks/task_detail_screen.dart` | 1207 |
| `services/habit_service.dart` | 1098 |
| `features/appointments/appointment_detail_screen.dart` | 882 |
| `features/home/home_screen.dart` | 826 |
| `features/calendar/calendar_screen.dart` | 809 |
| `services/reminder_scheduler.dart` | 808 |
| `core/router/app_router.dart` | 806 |
| `features/calendar/event_detail_screen.dart` | 804 |
| `features/collections/collection_detail_screen.dart` | 781 |
| `features/journal/journal_detail_screen.dart` | 726 |
| `features/tasks/task_list_screen.dart` | 711 |
| `services/backup_service.dart` | 630 |
| `features/search/search_screen.dart` | 545 |
| `shared/widgets/item_card.dart` | 541 |

- **Σημείωση:** από τα σχέδια του `code_refactor.md` §2 εκτελέστηκε μόνο το `settings` split (S253). Τα υπόλοιπα (Φ4b-21…40) **δεν έγιναν**.
- **Απαιτείται απόφαση:** (α) σταδιακά splits ένα αρχείο/session (κατά R1) ή (β) ρητή χαλάρωση του R1 για services/screens.
- **Αποδοχή (αν (α)):** <500 + analyze/test clean ανά βήμα, 0 αλλαγή συμπεριφοράς.

### E07 — Snooze UI + notification actions
- **Έτοιμο μηχανικό:** `ReminderNotifier.snooze` (`reminder_provider.dart:68-88`) · repo `snooze` (`super_note_helper.dart:1158-1168`) · OS reschedule semantics S52.
- **Λείπει (επαληθευμένο 21/10/2026):** **0 UI callers** (grep) · `markSent` 0 callers (σκόπιμα κρατείται) · `_details()` (`notification_service.dart:396-414`) χωρίς Android `actions`/iOS category · `_onTap` (`:416-425`) αγνοεί `actionId` · `_onBackgroundTap` (`:428-433`) no-op.
- **Θέλει spec πρώτα** (κουμπί/actions/background-tap χωρίς Isar). **Κόστος:** μεγάλο.

### E08 — Notification-permission status + persistent OFF hint
- **Απόδειξη:** grep `areNotificationsEnabled|checkPermissions|permissionStatus` = **0** hits. `notification_service` έχει μόνο `requestPermission`.
- **Πού:** `reminder_section.dart:202-210` ελέγχει μόνο `settings.notificationsEnabled` + SnackBar στο save.
- **Θέλει:** (α) query OS permission API, (β) μόνιμη γραμμή-hint. **Κόστος:** μικρό-μεσαίο.

### E09 — Attachments: add-button + card badge
- **Απόδειξη:** `attachments_strip.dart:5` — ρητά «ΜΟΝΟ προβολή/άνοιγμα/διαγραφή — το add ζει στα collection entries» · `item_card.dart` = 0 badge.
- **Θέλει απόφαση** (feature gap, μπορεί να μείνει σκόπιμα εκτός).

### E10 — B2.3: title/body σύγκριση πριν το rebake
- **Απόδειξη:** το incremental `keepIds` βασίζεται **μόνο σε ids** που υπάρχουν στο OS (`reminder_scheduler.dart:62-76` → `:769-773`). Δεν συγκρίνεται title/body ⇒ κρατιέται παλιό κείμενο μέχρι το επόμενο rebake.
- **Καθαρό optimization** (self-heal καλύπτει). **Κόστος:** μικρό-μεσαίο.

### E11 — Ενοποιημένο DetailAppBar
- **Απόδειξη:** δεν υπάρχει κοινό `DetailAppBar` (grep). Μόνο private `_EventDetailAppBar` (`event_detail_screen.dart:805`). Τα detail screens χτίζουν hand-rolled `_buildAppBar`.
- **Κόστος:** μεσαίο. **Καθαρά hygiene**, 0 λειτουργικός αντίκτυπος.

### E12 — 8× label «Εμφάνιση/Απόκρυψη αρχειοθετημένων»
- **Σημεία (8, όχι 7 — το calendar έλειπε από το doc):** `item_list_screen.dart:150` · `habit_list_screen.dart:190` · `task_list_screen.dart:270` · `contact_list_screen.dart:160` · `collection_entries_screen.dart:254` · `collections_screen.dart:117` · `journal_list_screen.dart:200` · `calendar_screen.dart:269`.
- **Πρόταση:** 1 shared widget (label+icon+onPressed). **Κόστος:** μικρό.

### E13 — B-Π2b (υπό συνθήκη)
- Κρύψιμο του label «Φάκελοι» σε κοντό viewport **μόνο αν** φανεί ανάγκη στο E03.

### E14 — F19: dead providers
- **Απόδειξη:** `pendingRemindersProvider` (`reminder_provider.dart:13`) = **0 readers**· μόνο 5 invalidates (`:60,:84,:94,:104` + `reminder_section.dart:114`). `pendingRemindersStreamProvider` (`:18`) = **0 references**.
- **Προσοχή:** πρέπει να φύγουν **και τα 5 invalidates** αλλιώς analyze error. Αγγίζει `supernote.md:597-598` ⇒ απόφαση.

### E15 — ✅ CLOSED 21/10/2026 (F2: OFF path) — βλ. §3
- **Υλοποίηση:** A (`settings_provider.dart:81-91`) · B/B3 + C + C3 (`reminder_scheduler.dart`) · device-verified (βλ. §3 + Progress log).

### E16 — F3: `main` χωρίς timeout
- **Πού:** `main.dart:210` (`settings.get()`) · `:224` (`requestPermission()`). Υπάρχει `.timeout` pattern αλλού στο `main` (π.χ. `:376/:402`).

### E17 — F4: `rescheduleForItem` χωρίς timeout — **×5**
- **Ακριβή σημεία:** `item_provider.dart:203, 214, 275, 341, 360` (τα `:199/:234/:337` είναι `cancelAllForItem`). Το παλιό doc έλεγε ×6 — λάθος.

### E18 — `catch (_) {}` ×21 (R4)
- **Απόδειξη (δείγμα):** `attachment_service.dart:126` · `backup_archive.dart:63` · `backup_service.dart:145,154,196,203,387,420,467,501,541,562,637,641,669` · `habit_service.dart:122,720` · `recurrence.dart:89,110,122`.
- **Κανόνας R4:** απαγορεύεται. Ανά site: `DebugConfig.warning` (ή τεκμηριωμένη σκόπιμη σίγαση best-effort).
- **Αποδοχή:** 0 `catch (_) {}` χωρίς σχόλιο/λόγο.

### E19 — `take(10)` ×2 + διπλότυπη λογική
- **Σημεία:** `items_query_provider.dart:64` · `home_folder_view.dart:171` (το doc έλεγε `:143` — drift). Ίδιο φίλτρο `deletedAt == null && !archived` + magic 10 ⇒ SPoT helper/const.

### E20 — `firstDate: DateTime(2000)` ×3
- **Σημεία:** `reminder_section.dart:237` · `appointment_detail_screen.dart:463` · `journal_detail_screen.dart:561`. Αποκλείει ημερομηνίες <2000.
- **Αποδοχή:** απόφαση ορίου (π.χ. 1900) + tests αν αλλάξει.

### E21 — Stale TODOs ×7
- `models/{attachment,device,app_settings,item_tag,tag,user,workspace}.dart:2` → `// TODO: Σελίδα προς Ανάπτυξη`. Απόφαση: **διαγραφή** (κατά πλειοψηφία) ή υλοποίηση.

### E22 — Υπόλοιπα §3.8 (spot-verified & μετρημένα 21/10/2026)
**Επιβεβαιωμένα υπαρκτά:**
- `Text('✓')` → `habit_detail_screen.dart:731`.
- `📅` ×2 → `folder_create_sheet.dart:28,33`.
- `BlockTileWidget` Stateful → `block_editor_widget.dart:146` (state `:170`).
- **Delete πάντα ορατό** → `block_editor_widget.dart:265-284` (22×22 κόκκινο ✕ σε **κάθε** block, χωρίς hover/focus) — UX.
- **`O(n²)` block editor** → `block_editor_widget.dart:110-113`: `widget.blocks.sublist(0, i).where((b) => b.type == BlockType.numbered).length` **ανά γραμμή** μέσα στο `SliverChildBuilderDelegate`.
- **`DateTime.now()` σε build** → αποδειγμένο: `task_list_screen.dart:302` μέσα σε `_TaskListBody.build` (25+ hits συνολικά, per-case).
- **`day/month/year` αντί intl (χειροκίνητο `d/m/yyyy`)** → `journal_detail_screen.dart:551,739` · `shared_intent_service.dart:150` · `reminder_diagnostics_screen.dart:187`.
**Χαμηλής αξίας / per-case (όχι wholesale):** `if(!mounted)return` style · `Colors.white/black` (κυρίως σωστά ως on-color σε χρωματιστές επιφάνειες).

### E23 — G-track (S120): απόφαση κλεισίματος
- «tokens/copy/limits, ξεχωριστά». Tokens ✅ S169· limits υπάρχουν (`maxAttachmentSizeMB`). Πιθανόν **obsolete** — θέλει ρητό κλείσιμο για να μη στοιχειώνει.

### E25 — Doc-drift / ασυνέπειες παλιών docs
- `supernote.md`: **Error Handling** (`:891-905`): «Unprotected attachment_service» / «User-facing messages: None» = **αναληθή** (υπάρχουν try/catch + `AppErrors`). **Performance** (`:908-919`): «No autoDispose» = **6 autoDispose**. Λείπει `dayTickProvider` (`habit_provider.dart:16`) από τη λίστα Habit Providers. `:17` γράφει 245/245 = **259/259**.
- `code_refactor.md`: `:188` (F9 ανοιχτό) vs `:192` (✅ CLOSED) · F4 ×6 vs ×5 · `§3.8:110` λάθος path (`item_provider:443` → `items_query_provider:64` / `home_folder_view:171`) · §8 αρίθμηση 4→10.
- **Κλείνει μαζί με το E26** (δεν διορθώνονται ένα-ένα τώρα).

### E27 — Grid reorder χωρίς autoScroll
- **Πού:** `reorderable_item_list.dart:137` — `autoScroll: false` στο `SliverReorderableGrid`.
- **Συνέπεια:** σε grid (tablet/desktop) με λίστα μεγαλύτερη από την οθόνη, το drag δεν κυλάει αυτόματα → δύσκολη μετακίνηση σε απόσταση.
- **Κόστος:** μικρό (1 flag + device test). **Ρίσκο:** χαμηλό (autoScroll του package είναι 14ms steps).

### E28 — 12× raw `showModalBottomSheet` (SPoT bypass)
- **Πού (επαληθευμένα, χωρίς `SafeSheet` στο builder):** `appointment_detail:537` · `task_detail:170` · `tag_picker_sheet:114` *(isScrollControlled)* · `settings_tiles:264` (folder picker) · `settings_colors:88` · `note_detail:120` · `contact_detail:436,1041` · `collection_detail:212` *(isScrollControlled)* `,787` · `journal_detail:176` · `event_detail:308`.
- **Γιατί μετράει:** το S109 SPoT (`showSafeSheet`/`SafeSheet`) υπάρχει για scroll/keyboard/landscape ασφάλεια (κλάση S103–S108). **Δεν** αποδείχθηκε overflow σε αυτά τα 12 — είναι **SPoT bypass** προς έλεγχο, όχι επιβεβαιωμένο bug.
- **Κόστος:** μικρό-μεσαίο (1 site/session + device landscape). **Ρίσκο:** χαμηλό (οπτική ισοδυναμία).

### E29 — Wipe χωρίς `cancelAll()` (νέο, 21/10/2026)
- **Πού:** `settings_backup.dart:161-291` (`clearAllData`). Διαγράφει/κλείνει τη βάση και σβήνει αρχεία, αλλά **δεν** καλεί `NotificationService.instance.cancelAll()`.
- **Αποτέλεσμα:** μετά το «διαγραφή όλων», τα ήδη προγραμματισμένα OS alarms και το tray μένουν → ειδοποιήσεις με παλιό τίτλο/περιεχόμενο.
- **Γιατί P1:** ορατά λάθος συμπεριφορά (όχι data loss).
- **Fix (χωριστό βήμα):** `await NotificationService.instance.cancelAll();` πριν/μετά το κλείσιμο της DB + `DebugConfig.notif` με `os=` για επιβεβαίωση.

### E30 — ✅ CLOSED 21/10/2026 (grid extent guards) — βλ. §3
- **Υλοποίηση:** guard `!hasBoundedWidth || maxWidth <= spacing*(n-1)` σε 3 σημεία: `home_screen.dart:694` (grid), `:767` (skeleton), `collections_screen.dart:236`· device-verified (βλ. §3 + Progress log).

### E26 — Τελικό κλείσιμο
1. `oldsessions.md`: 1 κεφάλαιο «Φ5 — error_list sweep» (τι έκλεισε, ημερομηνίες, hashes, device tests).
2. `code_refactor.md`: διαγραφή/αντικατάσταση §3/§7/§8/§9 με παραπομπή στο κεφάλαιο του `oldsessions.md` (καμία διπλή λίστα).
3. `supernote.md`: μόνο αρχιτεκτονικές αλλαγές (π.χ. νέα APIs) + test counter.
4. Διαγραφή `error_list.md`.

---

## 3. Κλειστά & επαληθευμένα (μην τα ξανακυνηγάτε)

> Επαληθευμένα στον κώδικα ή/και σε device. Λεπτομέρειες: `oldsessions.md` S141–S262-b.

- **Cascades/lifecycle:** S141 (collections cascade), S142 (κάδος συμμετρικός), S143 (archive = σίγαση), S148 (reorder subset→full), S213 (κάδος restore).
- **Routing/theming:** S156 (birthday), S169 (tokens), S172 (`AppTransitions`), S178 (mojibake), S180 (`safePop`), S183 (event 1 AppBar), S176 (`$isNew`).
- **Providers/lifecycle:** S170, S171, S179, S181 (`getByIds`), S182 (PIN state), S187, S189, S191.
- **Scheduler:** S194 (done/cancelled σίγαση), S196 (DTSTART/DST), S198, S199, S201, S206, S212, S215, S244–S246 (`SerialPassQueue`), S248, S250 race, S252 (postFrame δίχτυα).
- **`E15` — CLOSED 21/10/2026 (device-verified, F2 OFF path):** OFF πλέον μόνο μέσω `_bakeQueue` (A: `toggleNotifications` = 1 κλήση `scheduleAll()` για ON/OFF)· OFF branch = `cancelAll()` + `_osWindowTruncated=false` + `os=` log + warning (B/B3)· `_scheduleOne` λύνει mode **πριν** το fresh enabled guard (C)· φραγή κάθε 20 alarms (C3). Device (POCO X3, 101 reminders): ON `os=45`/`dumpsys=45` → OFF `os=0`/`dumpsys=0` (132ms) → reboot 0 → ON `os=46` → **race**: `queued id=14` μέσα σε ενεργό bake + `WRN OFF mid-loop at 100/101` + `cancelAll` μετά → `dumpsys=0` → ήχος/δόνηση ×4 bakes `os=46` → πραγματική ειδοποίηση χτύπησε + tap → `NoteDetail 415`.
- **`E30` — CLOSED 21/10/2026 (device-verified, grid extents):** `cellWidth` αρνητικό σε warm-up frame (`maxWidth≈0`) → `mainAxisExtent<0`. Guard `!hasBoundedWidth || maxWidth <= spacing*(n-1)` → `SizedBox.shrink()` σε **3** σημεία: `home_screen.dart:694` (grid), `:767` (skeleton), `collections_screen.dart:236`. Device (POCO X3, `flutter run`-attached cold start 14:01:59, pid 14755): κανένα `mainAxisExtent`/`EXCEPTION`/`E/flutter` στο logcat της ίδιας διεργασίας — όπου φαίνονται κανονικά τα app `debugPrint` (`STARTUP +5795ms`, `HabitService.topUp: os=45`). analyze clean · test **259/259**.
- **Settings:** S253 (9 guards + split 9 αρχεία), S254 (`selection_list_dialog`), S255 (F13 `unarchiveMany`), S256 (F9 pop), S257 (F18 fresh list), S258 (F9c dead members), S259 (F17 slider), S260 (F18 tests), S262-b (popup overflow ×7, chip minWidth, `_PropRow`, «Όλοι» drag flag).
- **Grid:** S261 (auto-height) + S262/S262-b fixes → μένει μόνο **E03 re-verify**.
- **`E24` «grid-mode guard gap» — CLOSED 21/10/2026 (stale, όχι bug):** `onReorderItem` του SDK διορθώνει ήδη το `newIndex` (`reorderable_list.dart:82-83,129-131`) · το `SliverReorderableGrid` δίνει index κελιού-στόχου (`reorderable_grid.dart:573-577,652-663`) · και τα δύο ταιριάζουν με `removeAt+insert` του `moveAndMerge` (`reorder_utils.dart:26-29`) ⇒ κανένα off-by-one. (Προαιρετικό device spot-check σε tablet grid.)
- **Crash guards:** `parseHex` try/catch, `int.parse` → `tryParse` (appointment/collection_detail), `trash deletedAt`, postFrame `mounted` guards.

---

## 4. Progress log (μία γραμμή ανά βήμα)

| Ημ/νία | ID | Τι έγινε | Απόδειξη |
|---|---|---|---|
| 21/10/2026 | — | **Audit κώδικα + δημιουργία λίστας** (μοναδική πηγή). Επιβεβαιώθηκαν **26** ανοιχτά στοιχεία + 5 by-design + τελικό βήμα. | analyze clean · test **259/259** · 18 αρχεία >500 · 21 `catch(_){}` · 3 Semantics/89 tooltips · HEAD `71cef63` |
| 21/10/2026 | E24 | **2ος έλεγχος:** ακύρωση ως bug (SDK + package source) — stale σημείωση S148. | `reorderable_list.dart:82-83` · `reorderable_grid.dart:573-577,652-663` · `reorder_utils.dart:26-29` |
| 21/10/2026 | E22, E07, E25 | **2ος έλεγχος:** μετρήθηκαν/διορθώθηκαν line refs + νέα **E27** (grid autoScroll) & **E28** (12× raw bottom sheets). | `block_editor_widget.dart:110-113,265-284` · `task_list_screen.dart:302` · `notification_service.dart:396-433` |
| 21/10/2026 | — | **Docs:** κανόνας «εκκρεμότητες μόνο εδώ» σε `supernote.md` / `oldsessions.md` / `code_refactor.md` + `AGENTS.md` (6/9/10). | backups `backups/s263_error_list_sync/` |
| 21/10/2026 | — | **Αναταξινόμηση προτεραιοτήτων** (εντολή χρήστη): P1 σφάλματα (6) → P2 βελτιώσεις λειτουργιών (10) → P3 προσθήκες/αναβαθμίσεις (10). `E24` μεταφέρθηκε στα κλειστά. | §1 νέοι πίνακες · `E24` CLOSED |
| 21/10/2026 | E15 | **Υλοποίηση A+B+B3+C+C3** σε 4 βήματα (backup `backups/s264_e15_f2/`): A = ένα μονοπάτι ON/OFF μέσω `_bakeQueue`· B = durable `cancelAll` + `_osWindowTruncated=false`· B3 = `os=` log + warning· C = mode πριν το fresh enabled guard· C3 = φραγή κάθε 20 alarms. | `settings_provider.dart:81-91` · `reminder_scheduler.dart:52-72, 139-153` · `_scheduleOne` · analyze clean · test **259/259** |
| 21/10/2026 | E15 | **Device T1–T7 (POCO X3, 101 reminders):** ON `os=45`=`dumpsys` → OFF `os=0`=`dumpsys` (132ms) → νέα υπενθύμιση με OFF = κανένα alarm → reboot 0 → ON `os=46` → **race**: `queued id=14` μέσα σε ενεργό bake + `WRN OFF mid-loop at 100/101` + cancelAll μετά → `dumpsys=0` → ήχος/δόνηση ×4 `os=46` → ειδοποίηση χτύπησε & tap → `NoteDetail 415`. | logcat 13:04–13:33 · `dumpsys alarm` |
| 21/10/2026 | E29, E30 | **Νέα ευρήματα:** (E29) `clearAllData` χωρίς `cancelAll` → παλιά alarms μετά το wipe· (E30) `mainAxisExtent<0` στο `_LoadingSkeleton` (debug assertion σε warm-up frame, `home_screen.dart:762-779`). | `settings_backup.dart:161-291` · `home_screen.dart:762-779,698` |
| 21/10/2026 | — | **SOP ενημέρωσης** στο `error_list.md` (η ροή του E15 ως πρότυπο: Α πριν το edit · Β ένα βήμα · Γ device 2 πηγές · Δ §1/§2/§3/§4/§0) + «πρώτο που διαβάζω». | `error_list.md:9-36` · backup `backups/s265_sop_error_list/` |
| 21/10/2026 | E30 | **Fix (3 βήματα):** guard `mainAxisExtent` σε `home_screen.dart:694,767` + `collections_screen.dart:236` → `SizedBox.shrink()` όταν `!hasBoundedWidth || maxWidth <= spacing*(n-1)`· backup `backups/s266_e30_grid_extent/`. **Device:** cold start μέσω ενεργού `flutter run` (pid 14755, 14:01:59) — κανένα assertion στο logcat της ίδιας διεργασίας. | analyze clean · test **259/259** · logcat 14:01–14:02 · `error_list.md` §1 `(7)`→`(6)` |

---

## 5. Χάρτης παλιών docs → νέο καθεστώς

| Αρχείο | Πριν | Τώρα |
|---|---|---|
| `code_refactor.md` §3/§7/§8/§9 | λίστες/status | **παγώνουν** (δεν συντηρούνται) — μόνο ιστορικό· καθαρίζονται στο E26 |
| `supernote.md` | αρχιτεκτονική + status | **μόνο αρχιτεκτονική** (κανόνας 8) |
| `oldsessions.md` | ιστορικό + «επόμενο session» | **μόνο ιστορικό**· νέο κεφάλαιο στο E26 |
| `error_list.md` | — | **η μοναδική πηγή** μέχρι το E26, μετά διαγράφεται |
| `AGENTS.md` | κανόνες 6/9/10 | ✅ **ενημερώθηκε 21/10/2026**: 6 = διάβασε `error_list.md` + ιστορικό · 9 = πρόοδος/εκκρεμότητες **ΜΟΝΟ** στο `error_list.md` · 10 = το 1-κεφάλαιο-ανά-φάση ισχύει για το τελικό sync |
