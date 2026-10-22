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
> 16. **Νέα ευρήματα από fix:** πρώτα εξετάζεται αν εντάσσονται σε **υπάρχουσα ομάδα** της §6 (1 ομάδα = 1 πρόταση + 1 fix)· μόνο αν δεν ταιριάζουν, ανοίγει **νέο ID** `E<n>` (επόμενο ελεύθερο, ποτέ reuse) με κατηγορία + κάρτα — πάντα με OK χρήστη.
>
> **Παράδειγμα αναφοράς — E15 (21/10/2026):** §1 `(6)`→`(7)` (E15 έξω, E29+E30 μέσα) · §2 E15→`✅ CLOSED` + E29/E30 πριν την E26 · §3 1 bullet · §4 3 γραμμές · commit `9bb4567`.
> **Απαγορεύεται:** παράλληλες λίστες · ενημέρωση `supernote.md`/`oldsessions.md` όσο ζει αυτό το αρχείο · κλείσιμο χωρίς απόδειξη · commit χωρίς push.
> **Κανόνας 12:** πριν από κάθε device test ζητάω από τον χρήστη ρητή λίστα δεδομένων. Ποτέ δεδομένα μέσω adb.
> **Κανόνας προτεραιότητας (21/10/2026):** ① **P1 = σφάλματα** που επιφέρουν μεγάλα λάθη στην εφαρμογή · ② **P2 = βελτιώσεις λειτουργιών** που ήδη υπάρχουν · ③ **P3 = μελλοντικές προσθήκες/αναβαθμίσεις** (+ δομική καθαριότητα). Κάθε νέο εύρημα μπαίνει υποχρεωτικά στην παραπάνω κατηγορία.

---

## 0. Baseline (μετρημένο στον κώδικα — 22/10/2026)

| Μέτρηση | Τιμή | Πηγή |
|---|---|---|
| Git HEAD | `a3216f2` (O2 — lifecycle) | `git log` |
| `flutter analyze` | **No issues found** | run 22/10/2026 |
| `flutter test` | **286/286** (49 αρχεία test) | run 22/10/2026 |
| Γραμμές `lib/` (χωρίς `*.g.dart`) | 39.371 | μετρήθηκε |
| Αρχεία >500 γραμμές (R1) | **19** (`main.dart` 511) | βλ. E06 |
| `Semantics(` | **3** (2 `Semantics` + 1 `ExcludeSemantics`) | grep |
| `tooltip:` | **89** | grep |
| `autoDispose` providers | **6** (όχι 7 — το 7ο hit είναι σχόλιο) | grep |
| `catch (_) {}` | **7** (14/21 έκλεισαν στην Ο2) | grep |
| `debugPrint`/`print` εκτός `DebugConfig` | 0 | grep |

⚠️ **Γνωστό doc-drift:** `supernote.md:19` γράφει 245/245, πραγματικό **286/286**. Δεν διορθώνεται τώρα (status ≠ αρχιτεκτονική) — θα διορθωθεί στο τελικό sync (E26).

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

### 🔴 P1 — Σφάλματα (2)

| # | ID | Θέμα | Γιατί είναι P1 (απόδειξη) |
|---|---|---|---|
| 1 | `E18` | **`catch (_) {}` ×7** (R4) | Κρύβει σφάλματα (attachments/habits/recurrence/share) → αόρατες αποτυχίες· τα 14/21 έκλεισαν στην Ο2 |
| 2 | `E04` | **Outer-context theme lookup** (κλάση S129/S133) | Crash-class: debug assertion, ρίσκο σε release/reassemble |

### 🟠 P2 — Βελτιώσεις λειτουργιών (10)

| # | ID | Θέμα | Τι βελτιώνει |
|---|---|---|---|
| 3 | `E05` | **F13b** — bulk-delete perf (`permanentDeleteMany`) | Πάγωμα ~7s σε μαζική διαγραφή (N× invalidate + passes) |
| 4 | `E08` | **Notification-permission status + persistent OFF hint** | Χάνονται ειδοποιήσεις χωρίς ορατή εξήγηση στον χρήστη |
| 5 | `E02` | **Calendar AppBar title @140%** | Κόβεται το «Οκτώβριος 2026» — θέλει σχεδιαστική απόφαση |
| 6 | `E27` | **Grid reorder χωρίς autoScroll** | Δεν φτάνεις μακρινούς στόχους σε μεγάλο grid |
| 7 | `E22` | **Υπόλοιπα §3.8** (μετρημένα) | `O(n²)` block editor · πάντα-ορατό delete · `d/m/yyyy` · `DateTime.now()` σε build |
| 8 | `E28` | **12× raw `showModalBottomSheet`** (SPoT bypass) | Θωράκιση landscape/keyboard (όχι αποδεδειγμένο bug) |
| 9 | `E19` | **`take(10)` ×2 + διπλότυπη λογική φίλτρου** | Λάθος/διπλά αποτελέσματα σε άκρες |
| 10 | `E20` | **`firstDate: DateTime(2000)` ×3** | Αποκλείει παλιές ημερομηνίες (birthdays/αρχεία) |
| 11 | `E01` | ⏸️ **PARKED** — a11y pass (Semantics / 48dp / PII) | Προσβασιμότητα υπάρχουσας λειτουργίας |
| 12 | `E03` | **Device re-verify grid auto-height** | Επαλήθευση ότι δεν υπάρχει regression (100%/140%, portrait/landscape) |

### 🔵 P3 — Μελλοντικές προσθήκες / αναβαθμίσεις + καθαριότητα (10)

| # | ID | Θέμα | Τύπος |
|---|---|---|---|
| 13 | `E07` | **Snooze UI + notification actions** | Νέα λειτουργία (θέλει spec) |
| 14 | `E09` | **Attachments add-button + badge στην κάρτα** | Νέα λειτουργία (θέλει απόφαση) |
| 15 | `E11` | **Ενοποιημένο `DetailAppBar`** | Αναβάθμιση/consistency |
| 16 | `E12` | **8× «Εμφάνιση/Απόκρυψη αρχειοθετημένων»** → shared widget | Καθαριότητα |
| 17 | `E06` | **R1: 19 αρχεία >500 γραμμές** | Δομική αναβάθμιση (splits ή χαλάρωση κανόνα) |
| 18 | `E13` | **B-Π2b** — κρύψιμο label «Φάκελοι» σε κοντό viewport | Προσθήκη *(μόνο αν φανεί στο E03)* |
| 19 | `E14` | **F19** — dead providers (`pendingReminders*`) | Καθαριότητα |
| 20 | `E21` | **Stale TODOs ×7** (`models/`) | Καθαριότητα |
| 21 | `E23` | **G-track (S120)** — ρητό κλείσιμο | Απόφαση |
| 22 | `E25` | **Doc-drift παλιών docs** | Συντήρηση (κλείνει με E26) |

**P4 — By-design / αποδεκτά (καμία ενέργεια)**
- iOS parked ×2 · 6-actions overflow `note_detail` · zombie-overlap residual (S245 — ισχύει και για τις ουρές του E17 (`_bakeQueue`): fail-open 60s by design, καμία νέα κάρτα) · αρχαίες S~92 σημειώσεις · display-inDays DST cosmetic · `custom:184` σημείωση (stale) · contact-dialog chrome 7.3px (debug-only, αποδεκτό).

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

### E06 — R1: 19 αρχεία >500 γραμμές
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
| `main.dart` | 511 |

- **Νέο (Ο2):** το `main.dart` πέρασε τις 500 (511) με τα startup timeouts/lifecycle guards (E16/B10/B11).
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

### E10 — ✅ CLOSED 21/10/2026 (device-verified, B2.3)
- **Device (POCO X3):** rename `E17 RENAME v3`→`v4` + future reminder 22:50 → `rescheduleForItem: rebaked=1 kept=0`· πραγματικό notification title «Υπενθύμιση», body `E17 RENAME v4`, σε OS. Logs/screenshot: `backups/O1_reminder_hardening_2026-10-21/device_logs/e10_*`.

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

### E16 — ✅ CLOSED 22/10/2026 (F3: startup timeouts)
- **Υλοποίηση:** `main.dart:29` launch payload 3s · `:129` pre-runApp `settings.get()` 5s · `:217` postFrame `settings.get()` 5s · `:232` `requestPermission()` 5s. **Device/test:** cold start/restore logs χωρίς block· analyze clean · 286/286 (βλ. §4).

### E17 — ✅ CLOSED 21/10/2026 (F4: κοινό `_bakeQueue`) — βλ. §3
- **Υλοποίηση:** `rescheduleForItem` → `_bakeQueue.run(() => _rescheduleForItemImpl(itemId))` — ίδια ουρά με `scheduleAll` (καμία 6η) + `resolveScheduleMode()` 1×/pass (`reminder_scheduler.dart:689-725`). **Device (POCO X3):** 5/5 call sites (`item_provider.dart:203,214,275,341,360`) `rebaked=1`, cold-start race bake `id=1→2`, counts σταθερά 168→171, test 259/259.

### E18 — `catch (_) {}` ×7 (R4) — μερικό κλείσιμο
- **Κατάσταση:** 14/21 CLOSED 22/10/2026 (Ο2): `backup_service` ×13 + `backup_archive` ×1 → `DebugConfig.warning`/σχόλιο.
- **Υπόλοιπα 7 → Ο6:** `recurrence.dart:89,110,122` · `attachment_service.dart:126` · `share_service.dart:432` · `habit_service.dart:123,758`.
- **Κανόνας R4:** απαγορεύεται. Ανά site: `DebugConfig.warning` (ή τεκμηριωμένη σκόπιμη σίγαση best-effort).
- **Αποδοχή (Ο6):** 0 `catch (_) {}` χωρίς σχόλιο/λόγο.

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
- `supernote.md`: **Error Handling** (`:891-905`): «Unprotected attachment_service» / «User-facing messages: None» = **αναληθή** (υπάρχουν try/catch + `AppErrors`). **Performance** (`:908-919`): «No autoDispose» = **6 autoDispose**. Λείπει `dayTickProvider` (`habit_provider.dart:16`) από τη λίστα Habit Providers. `:19` γράφει 245/245 = **275/275**.
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

### E29 — ✅ CLOSED 21/10/2026 (wipe cancelAll)
- **Υλοποίηση:** `settings_backup.dart:250-267` — `BackupService.dbFileName` + `await NotificationService.instance.cancelAll()` **μετά** το `close()`/delete της DB + `DebugConfig.notif('clearAllData: cancelAll done, osCache=…')`.
- **Device (POCO X3, 21/10/2026):** T1 wipe 45 alarms → `osCache=0`/`dumpsys=0`/tray 0· T2 reopen empty → 0· T3 restore → 45· T4 wipe → 0· **T4b** ενεργό tray (id=1, «E29 TRAY TEST 2») με ίδιο PID → tray 0/alarms 0/cache 0· final restore 100→45, DB 5 MB. Logs: `backups/s267_e29_wipe_cancel/`.

### E30 — ✅ CLOSED 21/10/2026 (grid extent guards) — βλ. §3
- **Υλοποίηση:** guard `!hasBoundedWidth || maxWidth <= spacing*(n-1)` σε 3 σημεία: `home_screen.dart:694` (grid), `:767` (skeleton), `collections_screen.dart:236`· device-verified (βλ. §3 + Progress log).

### E33 — ✅ CLOSED 22/10/2026 (restore race + full wipe)
- **Υλοποίηση:** maintenance gates (`SerialPassQueue.pauseForMaintenance/waitForIdle/resumeAfterMaintenance` · scheduler debounce deferred · habit pass+repair) · `BackupService.beginDbMaintenance()` pause+drain 65s + epoch guard + in-flight export/autoBackup · `_atomicRestoreDb()` safety `copyToFile` → close → replace DB/attachments → re-init (restartRequired) · barrier/restart dialogs + `exit(0)` (`settings_backup.dart:330-433`) · idempotent `SuperNoteHelper.close()`.
- **Findings B13 (fix1/fix2):** trial `Isar.open` δημιουργεί σιωπηλά κενή DB σε άκυρο αρχείο → απαιτείται `AppSettings(1)` (`backup_service.dart:589-599`)· το validation εξάγει **μόνο** το DB entry (`extractBackupZipDbOnly`, `backup_archive.dart:122-142`) → κανένα νέο `_backup_zipval_*`.
- **Findings B13 (fix3/fix5):** το wipe διαγράφει live `attachments/` (`settings_backup.dart:475-486`) + app cache (`:492-503`) + `.migration_safety` (`:506-516`)· το migration ξαναφτιάχνει 1 snapshot στο restart.
- **Device (POCO X3, 22/10/2026):** T1 restore `entries=8`/`moved=7`/`restartRequired=true`/`exit(0)` · T2 truncated zip `entries=0` → «δεν περιέχει βάση» · T2b bad DB → `λείπει AppSettings(1)` (reject) · T3 wipe `drain OK`/`osCache=0` · fix3 attachments absent · fix5 cache 0 entries/`.migration_safety`=1 · logs `backups/O2_lifecycle_2026-10-22/device_logs/`.

### E34 — ✅ CLOSED 21/10/2026 (device race, E17-residual)
- **Device (POCO X3):** archive κατά ενεργό 120-row bake (`rescheduleForItem`, ίδια `_bakeQueue`, `id=10`) → `bake queued id=11`· `ARCHIVED, SKIP` ×52· `rescheduleForItem: itemId=467 rebaked=68 skipped=52`· `cancelAllForItem cancelled=120`· τελικό `dumpsys` 76 alarms, **0 στις 08:20/10:20** (0 ghosts). Logs: `backups/O1_reminder_hardening_2026-10-21/device_logs/e34_*`.

### E35 — ✅ CLOSED 21/10/2026 (tests + Android counts, E17-residual)
- **Απόδειξη:** cold start `desired=166 baked=166 cut=0 os=166`· unit tests limit 2/3/60, oldest-first/no eviction· iOS/macOS runtime untested (platform-agnostic planner tests καλύπτουν το όριο 60). Tests: `test/reminder_bake_plan_test.dart:57-145`.

### E36 — ✅ CLOSED 21/10/2026 (device-verified rename, E17-residual)
- **Device (POCO X3):** rename `E17 HABIT`→`E17 HABIT 01` → `rescheduleForItem: itemId=467 rebaked=120 kept=0`· diagnostics `Υπενθύμιση: E17 HABIT 01` στις 08:20/10:20, σε OS. Logs: `backups/O1_reminder_hardening_2026-10-21/device_logs/e36_*`.

### E37 — ✅ CLOSED 21/10/2026 (test-verified, E17-residual)
- **Test:** `test/reminder_bake_plan_test.dart:147-167` — `archived/done/orphan rows are skipped`: 3 rows (incl. orphan `itemId=3` χωρίς item) → `skippedCount=3`, `schedule` κενό· δεν υπάρχει UI path για orphan. `flutter test` 275/275.

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
- **`E17` — CLOSED 21/10/2026 (device-verified, F4: κοινό `_bakeQueue`):** `rescheduleForItem` → **ίδια** `_bakeQueue` με `scheduleAll` (`reminder_scheduler.dart:691-692`) ⇒ ποτέ παράλληλα bake passes. Device (POCO X3, 168→171 alarms): rename/status/archive/restore `rebaked=1`· bulk ×2 FIFO `id=14→15` (1× refresh + 1× topUp 365ms)· cold start bake `id=1` (`baked=171 failed=0`) → rename bake `id=2`, `dumpsys` 171→171· logs `backups/s268_e17_reschedule_bake_queue/`.
- **`O1` (E10, E34–E37) — CLOSED 21/10/2026 (device/test-verified, S270 `c2dc8f2`):** text resolver + bake planner + queue-wrapped cancel/delete + fresh guards + habit live body + orphan guard. Device (POCO X3): E10 πραγματικό notification `E17 RENAME v4`· E36 `rebaked=120` + live body· E34 archive race (`bake queued id=11`, 52 skipped, `cancelled=120`, 0 habit alarms)· E35 cold start `166/450` + limit tests· E37 orphan test. Logs: `backups/O1_reminder_hardening_2026-10-21/device_logs/`.
- **`E30` — CLOSED 21/10/2026 (device-verified, grid extents):** `cellWidth` αρνητικό σε warm-up frame (`maxWidth≈0`) → `mainAxisExtent<0`. Guard `!hasBoundedWidth || maxWidth <= spacing*(n-1)` → `SizedBox.shrink()` σε **3** σημεία: `home_screen.dart:694` (grid), `:767` (skeleton), `collections_screen.dart:236`. Device (POCO X3, `flutter run`-attached cold start 14:01:59, pid 14755): κανένα `mainAxisExtent`/`EXCEPTION`/`E/flutter` στο logcat της ίδιας διεργασίας — όπου φαίνονται κανονικά τα app `debugPrint` (`STARTUP +5795ms`, `HabitService.topUp: os=45`). analyze clean · test **259/259**.
- **`E29` — CLOSED 21/10/2026 (device-verified, wipe cancelAll):** `settings_backup.dart:250-267` — `BackupService.dbFileName` + `cancelAll()` μετά το close/delete + `osCache=` log. Device: wipe 45 alarms + ενεργό tray → `osCache=0`/`dumpsys=0`/tray 0 (ίδιο PID, χωρίς cold start)· reopen empty 0· restore 45· final 45. Logs `backups/s267_e29_wipe_cancel/`.
- **`E16` — CLOSED 22/10/2026 (device/test-verified, startup timeouts):** `main.dart:29` (launch payload 3s) · `:129` (pre-runApp settings 5s) · `:217` (postFrame settings 5s) · `:232` (requestPermission 5s). Cold start/restore logs χωρίς timeout/block· analyze clean · **286/286**.
- **`E33` — CLOSED 22/10/2026 (device-verified, restore race + full wipe):** maintenance gates + drain 65s + epoch· `_atomicRestoreDb` (safety `copyToFile` → close → replace → re-init, restartRequired)· barrier/restart UX· validation `AppSettings(1)` + `extractBackupZipDbOnly`· wipe DB + attachments + leftovers + cache + `.migration_safety`. Device T1/T2/T2b/T3/fix3/fix5 (βλ. §4· logs `backups/O2_lifecycle_2026-10-22/device_logs/`).
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
| 21/10/2026 | E29 | **Fix:** `cancelAll()` μετά το close/delete της DB + `BackupService.dbFileName` + `osCache=` log· backup `backups/s267_e29_wipe_cancel/`. | analyze clean · test **259/259** · `settings_backup.dart:250-267` |
| 21/10/2026 | E29 | **Device T1–T4b:** wipe 45 alarms → `osCache=0`/`dumpsys=0`/tray 0· reopen empty → 0· restore → 45· **T4b** ενεργό tray (id=1) + ίδιο PID → tray 0· final restore 100→45, DB 5 MB. | logcat 14:40–15:35 · `dumpsys alarm`/`notification` · `backups/s267_e29_wipe_cancel/` |
| 21/10/2026 | — | **Νέο εύρημα (restore race):** file-picker resume → `debouncedRefreshRecurringReminders` (2s) overlap `_atomicRestoreZip: closing Isar` → `Isar instance already closed` + rollback `MdbxError (11)`· workaround 15s wait. **E33 (P2) — άνοιξε (έγκριση χρήστη).** | `run_log_e29_restore_fail1.txt` · `reminder_scheduler.dart:242-255` · `super_note_helper.dart:1175-1187` |
| 21/10/2026 | E33 | **Άνοιγμα κάρτας P2** (έγκριση χρήστη): restore race + rollback failure· §1 P2 **11**, §2 κάρτα E33. | `run_log_e29_restore_fail1.txt` · `backup_service.dart:568-671` |
| 21/10/2026 | E17 | **Υλοποίηση (κοινή `_bakeQueue`):** `rescheduleForItem` → `_bakeQueue.run(() => _rescheduleForItemImpl(itemId))` — ίδια ουρά με `scheduleAll`, batch `resolveScheduleMode()` 1×/pass· backup `backups/s268_e17_reschedule_bake_queue/`. | `reminder_scheduler.dart:689-725` · analyze clean · test **259/259** (`6a75a57`) |
| 21/10/2026 | E17 | **Device T1–T6 (POCO X3):** 5/5 call sites `rebaked=1` (rename/done→active/archive/unarchive/restore/delete)· bulk ×2 FIFO `id=14→15` + 1× refresh/topUp (365ms)· cold start `bake id=1` (`baked=171 failed=0 skipped=57`) → rename `bake id=2`, `dumpsys` 171→171, 0 parallel passes. | logcat 18:23–18:33 · `dumpsys alarm` · `backups/s268_e17_reschedule_bake_queue/device_logs/` |
| 21/10/2026 | E34–E37 | **Νέα ευρήματα από E17 residuals** (έγκριση χρήστη): E34 = cancel/delete εκτός ουράς (P1) · E35 = `osAlarmLimit` μόνο στο `scheduleAll` · E36 = habit snapshot title · E37 = orphan guard (`item == null`). **timeout zombie → P4** (S245 — καμία νέα κάρτα). Νέα **§6**: ομαδοποίηση Ο1–Ο7 (1 ομάδα = 1 πρόταση + 1 fix). §1: P1 **5** · P2 **14** · P3 **10** (renumber 1..29). | `reminder_scheduler.dart:595-618,738-749,137-143,770-782,765-805` · `notification_service.dart:81-89` · `serial_pass_queue.dart:18-20` · backup `backups/s269_e17_residuals_grouping/` |
| 21/10/2026 | E10, E34–E37 | **Ο1 υλοποίηση (S270, commit `c2dc8f2`):** pure text resolver + bake planner· global budget/oldest-first/replacements χωρίς slot· DB-first delete order + unconditional OS payload scan· cancel/delete APIs στην `_bakeQueue`· fresh row/item/settings guards· batch refresh + habit topUp (ένα OS read ανά pass)· habit live body/title· `cleanupOldPending` επιστρέφει IDs για OS cancel. **Device verification ολοκληρώθηκε 21/10/2026 — βλ. επόμενες γραμμές.** | analyze clean · test **275/275** (48 files, +16) · `reminder_text.dart:1-85` · `reminder_bake_plan.dart:1-151` · backup `backups/O1_reminder_hardening_2026-10-21/` |
| 21/10/2026 | E36 | **Device rename (POCO X3):** `E17 HABIT`→`E17 HABIT 01` → `rescheduleForItem: itemId=467 rebaked=120 kept=0`· diagnostics `Υπενθύμιση: E17 HABIT 01` στις 08:20/10:20, OS. | logcat 22:23 · diagnostics · `backups/O1_reminder_hardening_2026-10-21/device_logs/e36_*` |
| 21/10/2026 | E10 | **Device future reminder (POCO X3):** `E17 RENAME v3`→`v4` + 22:50 → `rebaked=1 kept=0`· πραγματικό notification «Υπενθύμιση»/`E17 RENAME v4`. | `e10_fire_notification.txt` · `e10_notification_shade.png` |
| 21/10/2026 | E34 | **Device race (POCO X3):** archive κατά ενεργό 120-row bake (`rescheduleForItem`, ίδια `_bakeQueue`, `id=10`) → `bake queued id=11`· `ARCHIVED, SKIP` ×52· `rebaked=68 skipped=52`· `cancelAllForItem cancelled=120`· final `dumpsys` 76, **0 alarms 08:20/10:20** (0 ghosts). | `e34_race_logcat.txt` · `e34_race_alarm.txt` · `e34_after.png` |
| 21/10/2026 | E35, E37 | **Verification:** E35 Android counts `166/450` χωρίς cut + limit/oldest-first/no-eviction tests· E37 `archived/done/orphan` test (incl. `itemId=3` χωρίς item) → `skippedCount=3`, 0 schedule (no UI path). | `test/reminder_bake_plan_test.dart:57-167` · test **275/275** · §1 P1 **3** / P2 **11** |
| 22/10/2026 | E16 | **Startup timeouts:** launch payload 3s · pre-runApp/postFrame `settings.get()` 5s · `requestPermission()` 5s. | `main.dart:29,129,217,232` · analyze clean · test **286/286** |
| 22/10/2026 | E33 | **Maintenance gates (B1–B3):** `SerialPassQueue.pauseForMaintenance/waitForIdle/resumeAfterMaintenance` + scheduler debounce deferred + habit pass/repair gates. | `serial_pass_queue.dart:52-108` · `reminder_scheduler.dart:779-820` · `habit_service.dart:913-949` · analyze clean |
| 22/10/2026 | E33 | **Backup orchestration (B5/B9):** pause+drain 65s + epoch guard + in-flight export/autoBackup· `_atomicRestoreDb` safety/close/replace/re-init. | `backup_service.dart:122-177,704-903` · analyze clean · test **286/286** |
| 22/10/2026 | E33 | **Restore/wipe UX (B7/B8):** barrier dialog + restart dialog + `exit(0)`· abort πριν το close → snackbar + resume. | `settings_backup.dart:330-433` · analyze clean |
| 22/10/2026 | E18 | **14/21 sites:** `backup_service` ×13 + `backup_archive` ×1 → `DebugConfig.warning`· grep `catch (_) {}` = **7**. | `grep` · analyze clean · test **286/286** |
| 22/10/2026 | E33 | **T1 restore SUCCESS:** `entries=8` · `moved=7` · `restartRequired=true` · `Process … exited cleanly (0)`. | `t1_success_logcat.txt` |
| 22/10/2026 | E33 | **T2 truncated zip:** `BackupArchive.extract: entries=0` → «δεν περιέχει βάση δεδομένων»· κανένα restore. | `t2_invalid_logcat.txt` |
| 22/10/2026 | E33 | **T2b bad DB + fix1:** pre-fix `entries=1` + `zip VALID` (restore κενής DB)· post-fix `λείπει AppSettings(1)` → reject. | `t2b_bad_db_logcat.txt` · `t2b_postfix_logcat.txt` |
| 22/10/2026 | E33 | **fix2:** `extractBackupZipDbOnly` — `entries=8` στο I2_BASE· κανένα νέο `_backup_zipval_*`. | `t2b_postfix2_logcat.txt` · `backup_archive.dart:122-142` |
| 22/10/2026 | E33 | **T3 wipe + finding:** `drain OK`/`osCache=0` αλλά 7 attachments έμειναν. | `t3_wipe_logcat.txt` |
| 22/10/2026 | E33 | **fix3:** `Wipe: deleted live attachments directory`· attachments absent· 0 alarms/notif. | `t3_retest_logcat.txt` · `settings_backup.dart:475-486` |
| 22/10/2026 | — | **fix4 ακυρώθηκε (απόφαση χρήστη):** rotation παραμένει **5**· το `step_B13_4_fix4` δεν εφαρμόστηκε. | `backup_service.dart:86` |
| 22/10/2026 | E33 | **fix5:** `Wipe: cache directory deleted` + `Wipe: deleted .migration_safety`· reopen cache **0** entries · `.migration_safety` **1** νέο· attachments/leftovers absent. | `t3_fix5_wipe_logcat.txt` · `settings_backup.dart:492-516` |
| 22/10/2026 | — | **Verification Ο2:** analyze clean · test **286/286** (49 files) · `catch (_) {}` **7**. | run 22/10/2026 |

---

## 5. Χάρτης παλιών docs → νέο καθεστώς

| Αρχείο | Πριν | Τώρα |
|---|---|---|
| `code_refactor.md` §3/§7/§8/§9 | λίστες/status | **παγώνουν** (δεν συντηρούνται) — μόνο ιστορικό· καθαρίζονται στο E26 |
| `supernote.md` | αρχιτεκτονική + status | **μόνο αρχιτεκτονική** (κανόνας 8) |
| `oldsessions.md` | ιστορικό + «επόμενο session» | **μόνο ιστορικό**· νέο κεφάλαιο στο E26 |
| `error_list.md` | — | **η μοναδική πηγή** μέχρι το E26, μετά διαγράφεται |
| `AGENTS.md` | κανόνες 6/9/10 | ✅ **ενημερώθηκε 21/10/2026**: 6 = διάβασε `error_list.md` + ιστορικό · 9 = πρόοδος/εκκρεμότητες **ΜΟΝΟ** στο `error_list.md` · 10 = το 1-κεφάλαιο-ανά-φάση ισχύει για το τελικό sync |

---

## 6. Ομάδες υλοποίησης (1 ομάδα = 1 πρόταση + 1 fix)

> Κάθε ομάδα δουλεύεται με **μία ενιαία πρόταση** (συνεκτικό σχέδιο, αριθμημένα βήματα) και **ένα fix** — δεν ξανανοίγει σκόρπια. Νέα ευρήματα από fix: πρώτα εξέταση ένταξης σε υπάρχουσα ομάδα, αλλιώς νέο `E<n>` (SOP §Δ16).
> Προτεινόμενη σειρά: **Ο1 ✅ → Ο2 ✅ → Ο4 → Ο6 → Ο5 → Ο3 → Ο7** (+ E07/E09/E06 όποτε αποφασιστούν · E01 parked · E25 κλείνει με E26).

| Ομάδα | Η μία πρόταση | Το ένα fix | Απορροφά |
|---|---|---|---|
| **Ο1 — Scheduler correctness** ✅ CLOSED 21/10/2026 (S270 `c2dc8f2` + device/test) | E10 + E34 + E35 + E36 + E37 (προαιρ. E08, E14) | `reminder_scheduler.dart` + `reminder_text.dart` + `reminder_bake_plan.dart` + `habit_service.dart` + providers/settings + 16 tests | E35–E37 από E10/E34 |
| **Ο2 — Lifecycle (startup/resume/restore)** ✅ CLOSED 22/10/2026 (device-verified) | E16 + E33 + E18-μέρος | `main.dart` + debounce `reminder_scheduler` + `backup_service` + `super_note_helper` + `backup_archive` + cold-start/restore tests | E18: 14/21 sites (υπόλοιπα 7 → Ο6) |
| **Ο3 — Mass-delete pipeline** | E05 (solo — υψηλό ρίσκο, εξαρτάται από Ο1) | `trash_screen` + `item_provider` + `habit_service` (+bulk reminder call αν χρειαστεί) | — |
| **Ο4 — UI consolidation/hardening** | E04 + E28 + E12 + E02 (προαιρ. E13, E11) | Sheets + οθόνες (ίδια αρχεία, ένα πέρασμα) + landscape/140% checks | E28/E12/E02 από E04 |
| **Ο5 — Grid + verify** | E27 + E03 | `reorderable_item_list` + μαζικό device pass (100%/140°) — το E03 κλείνει εδώ | E03 από E27 |
| **Ο6 — Cleanup & visibility sweep** | E18 (→0) + E19 + E21 + E14 + E23 | Μηχανικά/αποφάσεις, χωρίς device | E19/E21/E14/E23 από E18 |
| **Ο7 — Dates/editor mini-pass** | E22 + E20 | Μικρές στοχευμένες αλλαγές (`journal_detail` κ.λπ.) | E20 από E22 |

**Ξεχωριστά:** E07 & E09 (features — spec/απόφαση πρώτα) · E06 (απόφαση splits/χαλάρωση R1) · E01 (parked) · E25 (κλείνει με E26).
