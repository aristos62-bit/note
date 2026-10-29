# error_list.md — Η ΜΟΝΑΔΙΚΗ λίστα εκκρεμοτήτων & προόδου

> **Κανονιστικό (ισχύει μέχρι να διαγραφεί αυτό το αρχείο):**
> - Το `error_list.md` είναι η **μοναδική πηγή** για εκκρεμότητες και προτεραιότητα. Η **πρόοδος** καταγράφεται στο `oldsessions.md` (βλ. παρακάτω).
> - **Απαγορεύεται** να συντηρούνται παράλληλες λίστες σε άλλα `.md`. Ό,τι λέει το `code_refactor.md` §3/§7/§8/§9, το `supernote.md` (status/error-handling/performance) ή το `oldsessions.md` για *ανοιχτά* θέματα **δεν είναι έγκυρο** — έγκυρο είναι μόνο ό,τι λέει αυτό το αρχείο.
> - `supernote.md` = μόνο αρχιτεκτονική (κανόνας 8). `oldsessions.md` = ιστορικό + **πρόοδος** — ενημερώνεται **μόνο στο οριστικό κλείσιμο** κάθε εκκρεμότητας.
> - Σε **κάθε οριστικό κλείσιμο**: κεφάλαιο/ενότητα στο `oldsessions.md` (+ `supernote.md` **μόνο** αν άλλαξε αρχιτεκτονική). Στο **τέλος όλων**: διαγραφή του `error_list.md` + καθάρισμα `code_refactor.md`.
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
> 13. **§4 (παγωμένο ιστορικό):** δεν προστίθενται νέες γραμμές. Η πρόοδος γράφεται στο **`oldsessions.md`** όταν η εκκρεμότητα κλείσει **οριστικά** (+ `supernote.md` μόνο αν άλλαξε αρχιτεκτονική).
> 14. **§0:** αλλάζει **μόνο** αν άλλαξε μέτρηση (analyze/tests/HEAD/αρχεία >500), με ημερομηνία.
> 15. `flutter analyze` (docs-only αλλαγή: προαιρετικό αλλά γίνεται) → **commit + push** με το ID στο message.
> 16. **Νέα ευρήματα από fix:** πρώτα εξετάζεται αν εντάσσονται σε **υπάρχουσα ομάδα** της §6 (1 ομάδα = 1 πρόταση + 1 fix)· μόνο αν δεν ταιριάζουν, ανοίγει **νέο ID** `E<n>` (επόμενο ελεύθερο, ποτέ reuse) με κατηγορία + κάρτα — πάντα με OK χρήστη.
>
> **Παράδειγμα αναφοράς — E15 (21/10/2026):** §1 `(6)`→`(7)` (E15 έξω, E29+E30 μέσα) · §2 E15→`✅ CLOSED` + E29/E30 πριν την E26 · §3 1 bullet · §4 3 γραμμές · commit `9bb4567`.
> **Απαγορεύεται:** παράλληλες λίστες εκκρεμοτήτων · πρόοδος εκτός `oldsessions.md` (ή `supernote.md` για αρχιτεκτονική) · κλείσιμο χωρίς απόδειξη · commit χωρίς push.
> **Κανόνας 12:** πριν από κάθε device test ζητάω από τον χρήστη ρητή λίστα δεδομένων. Ποτέ δεδομένα μέσω adb.
> **Κανόνας προτεραιότητας (21/10/2026):** ① **P1 = σφάλματα** που επιφέρουν μεγάλα λάθη στην εφαρμογή · ② **P2 = βελτιώσεις λειτουργιών** που ήδη υπάρχουν · ③ **P3 = μελλοντικές προσθήκες/αναβαθμίσεις** (+ δομική καθαριότητα). Κάθε νέο εύρημα μπαίνει υποχρεωτικά στην παραπάνω κατηγορία.

---

## 0. Baseline (μετρημένο στον κώδικα — 29/10/2026, μετά το S279/Ο7)

| Μέτρηση | Τιμή | Πηγή |
|---|---|---|
| Git HEAD | `fd54697` κώδικας Ο7 · `5f8a297` docs κλεισίματος (S279) | `git log` |
| `flutter analyze` | **No issues found** | run 29/10/2026 (S279) |
| `flutter test` | **370/370** (59 αρχεία test) | run 29/10/2026 (S279) |
| Γραμμές `lib/` (χωρίς `*.g.dart`) | 43.537 (158 αρχεία) | μετρήθηκε 29/10/2026 (S279) |
| Αρχεία >500 γραμμές (R1) | **20** (`main.dart` 519 · `home_screen.dart` 921) | βλ. E06 |
| `Semantics(` | **3** (2 `Semantics` + 1 `ExcludeSemantics`) | grep |
| `tooltip:` | **89** | grep |
| `autoDispose` providers | **6** (όχι 7 — το 7ο hit είναι σχόλιο) | grep |
| `catch (_) {}` | **0** (E18 CLOSED 24/10/2026) | grep |
| `debugPrint`/`print` εκτός `DebugConfig` | 0 | grep |

✅ **Device pass S279/Ο7 (POCO X3, 29/10/2026):** E20+E22 **T1–T8 PASS** (0 exceptions, 0 `ERR` στο logcat · 6.9 MB log + screenshots `backups/s279_o7_device/`). Λεπτομέρειες: §2 κάρτες E20/E22 + §3 + `oldsessions.md` S279.

✅ **Doc-drift διορθώθηκε (24/10/2026, S273 docs sync):** `supernote.md` → test counter **294/294**, Error Handling/Performance αληθή, tree **+4 αρχεία** (`lock_screen`, `reminder_diagnostics_screen`, `app_info_provider`, `app_lock_provider`), `dayTickProvider` + ShareService (pointer στο E39). Βλ. §4.

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

### 🔴 P1 — Σφάλματα (0)

> Κανένα ανοιχτό. Το `E18` έκλεισε 24/10/2026 (`catch (_) {}` = **0**) — βλ. §2/§3.

### 🟠 P2 — Βελτιώσεις λειτουργιών (3)

| # | ID | Θέμα | Τι βελτιώνει |
|---|---|---|---|
| 1 | `E08` | **Notification-permission status + persistent OFF hint** | Χάνονται ειδοποιήσεις χωρίς ορατή εξήγηση στον χρήστη |
| 2 | `E45` | **Habit topUp: σειριακό OS scheduling** — 🔧 κώδικας ✅ (S280/S281: Φ0+Φ1+Α OS-horizon), device ⏳ | 120 alarms ≈ 9.2s (restore/cold start/resume) |
| 3 | `E01` | ⏸️ **PARKED** — a11y pass (Semantics / 48dp / PII) | Προσβασιμότητα υπάρχουσας λειτουργίας |

### 🔵 P3 — Μελλοντικές προσθήκες / αναβαθμίσεις + καθαριότητα (6)

| # | ID | Θέμα | Τύπος |
|---|---|---|---|
| 6 | `E07` | **Snooze UI + notification actions** | Νέα λειτουργία (θέλει spec) |
| 7 | `E09` | **Attachments add-button + badge στην κάρτα** | Νέα λειτουργία (θέλει απόφαση) |
| 8 | `E11` | **Ενοποιημένο `DetailAppBar`** | Αναβάθμιση/consistency |
| 9 | `E06` | **R1: 20 αρχεία >500 γραμμές** | Δομική αναβάθμιση (splits ή χαλάρωση κανόνα) |
| 10 | `E13` | **B-Π2b** — κρύψιμο label «Φάκελοι» σε κοντό viewport | Προσθήκη *(δεν εμφανίστηκε στο device pass του E03 — 26/10/2026)* |
| 11 | `E39` | **Ενιαία κοινοποίηση (τίτλος+πεδία+συνημμένα) σε όλα τα items** | Νέα λειτουργία/αναβάθμιση (θέλει spec) |

**P4 — By-design / αποδεκτά (καμία ενέργεια)**
- iOS parked ×2 · 6-actions overflow `note_detail` · zombie-overlap residual (S245 — ισχύει και για τις ουρές του E17 (`_bakeQueue`): fail-open 60s by design, καμία νέα κάρτα) · αρχαίες S~92 σημειώσεις · display-inDays DST cosmetic · `custom:184` σημείωση (stale) · contact-dialog chrome 7.3px (debug-only, αποδεκτό) · **stale write-only Isar slots 8/10** (`isDeleted`/`isVisible` getters) στο `item.g.dart` — **0 reads**, κλείνει μόνο με επόμενο codegen (**όχι** `build_runner` τώρα).

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

### E02 — ✅ CLOSED 22/10/2026 (device-verified)
- **Πού:** `calendar_screen.dart:198-209` — `title: Text('${months[focusedMonth.month - 1]} ${focusedMonth.year}', style: context.titleLg)` χωρίς `maxLines`/ellipsis/`Flexible`.
- **Σύμπτωμα (device S262-b):** «Οκτώβριος» → «Οκτώβρ…» @140%.
- **Υλοποίηση (22/10/2026, `92fdcc6`):** επιλέχθηκε το (α) — `AppDateUtils.formatMonth(..., compact: true)` → «Οκτ ’26» + `maxLines: 1`/ellipsis στο calendar AppBar· unit test στο `weekday_labels_test.dart`.
- **Device (22/10/2026, POCO X3):** 100% & 140%, portrait + landscape → «Οκτ ’26» πλήρες, archive toggle ορατό, **0 overflow/assertions**. Screenshots: `backups/o4_sheets_2026-10-22/device_logs/sn_*calendar*`.
- **Αποδοχή:** πλήρες/κόσμιο label σε 100% & 140%, portrait/landscape, 0 overflow.

### E03 — ✅ CLOSED 26/10/2026 (device-verified, S276 — 0 κώδικας)
- **Υλοποίηση:** καμία νέα αλλαγή — ο κώδικας του S261 (`autoGridItemExtent`) + S262/S262-b επιβεβαιώθηκε ως έχει.
- **Device (POCO X3, 26/10/2026):** **140%** portrait (journal, contacts, trash, search, home, collections, tasks, entries, habits) **και** 140% landscape (grid 2 στηλών: notes 100→108, folder view 100→104, collections →102, home grid →144) → **0** `RenderFlex overflow`, **0** `❌`, `chipH=66.0 scale=1.40` σε κάθε build· επαναφορά 100% → `chipH=58.0 scale=1.00`. Απόδειξη: logcat με φίλτρο `overflowed|RenderFlex|DraggableFolderSelector` (χωρίς αποθηκευμένα screenshots).
- **Αποδοχή:** ✅ 0 overflow/κοψίματα σε 100%/140%, portrait/landscape.

### E04 — ✅ CLOSED 22/10/2026 (device-verified, sheet reassemble)
- **Πού (επαληθευμένο στον κώδικα):**
  - `task_detail_screen.dart:785,789,790,795` (status) & `:847,852,853` (priority) — το `SafeSheet` builder διαβάζει το **outer** `context.*`.
  - `settings_tiles.dart:195,199` (size picker) · `:282,286,288,291` (folder picker + outer `Navigator.pop`).
  - `collection_detail_screen.dart:802,812,818` (icon picker — `builder: (_)` + outer `context`).
  - `settings_colors.dart:101-102` (outer `context` μέσα σε `onSelected`).
- **Τι:** debug assertion (release-safe) αν το route της detail-οθόνης αποενεργοποιηθεί/reassemble με ανοιχτό sheet.
- **Fix:** `context.` → `sheetCtx.`/`ctx.` (0 layout αλλαγή). **Κόστος:** 1 μικρό session. **Ρίσκο:** χαμηλό· θέλει device reassemble test ανά sheet.
- **Υλοποίηση (22/10/2026, `92fdcc6`):** `sheetCtx`/`innerCtx` σε task status/priority, settings size/folder, collection field/icon, settings colors, contact photo, calendar creation, habit text editor· όλα τα `Navigator.pop` με sheet context.
- **Κατάσταση:** κώδικας ✅ · **device ✅ 22/10/2026:** status sheet ανοιχτό → `ext.flutter.reassemble` μέσω VM service (app pid 30972) → το sheet **παρέμεινε ανοιχτό**, **0 Flutter assertions/overflow**. Επιπλέον status/priority/reminder/folder/size/contact photo ανοίγουν/κλείνουν χωρίς overflow. Απόδειξη: `backups/o4_sheets_2026-10-22/device_logs/e04_reassemble_pass.png`, `e04_reassemble.log`, `e04_reassemble_errors.txt`.
- **Αποδοχή:** reassemble με ανοιχτό sheet → 0 assertions. ✅

### E05 — F13b: bulk-delete perf — ✅ CLOSED 27/10/2026 (S277, device-verified)
- **Πού:** `trash_screen.dart:99` (selected) + `:182` (empty trash) — ήταν loops `await notifier.permanentDelete(id)`.
- **Κόστος ανά item (πριν):** `_cascadeCollectionEntries` + `getForItem` + `deleteAllRemindersForItem`/`deleteHabitReminders` + `hardDelete` + `invalidateSelf()` (N×).
- **Λύση:** `ItemNotifier.permanentDeleteMany(List<int> ids)` + 3 batch APIs (`hardDeleteMany`, `deleteAllRemindersForItems`, `deleteHabitRemindersMany`)· 1 OS snapshot + 1 txn + 1 invalidate. Τα singles (`permanentDelete`, `hardDelete`, `deleteHabitReminders`, `deleteAllRemindersForItem`) = wrappers (log parity n=1).
- **Απόδειξη:** `analyze` clean · **339/339** · device T1–T7: T1 `n=3 → total=7 entries=4` (entries πρώτα, 1 txn, `took=293ms`) · T2 habit branch `deleteHabitRemindersMany n=7` + `hardDeleteMany` μέσα στο pass (`took=193ms`) · T5 `deleted file "…jpg"` · T7 single parity · **0 ERR**. Λεπτομέρειες: `oldsessions.md` S277.
- **Residuals:** R-E05-1 all-or-nothing txn · R-E05-4 O(N) OS cancels (plugin: μόνο `cancel(id)`/`cancelAll()`) · R-E05-7 habit+maintenance (μη προσπελάσιμο).

### E06 — R1: 20 αρχεία >500 γραμμές
> Επανμέτρηση 24/10/2026 (S273): **20** αρχεία >500, `main.dart` 519. Ο παρακάτω πίνακας είναι το μέτρημα της 22/10 (stale per-file νούμερα — refresh στο E25/E26).
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

### E12 — ✅ CLOSED 22/10/2026 (device-verified, user-confirmed 140%/landscape)
- **Σημεία (8, όχι 7 — το calendar έλειπε από το doc):** `item_list_screen.dart:150` · `habit_list_screen.dart:190` · `task_list_screen.dart:270` · `contact_list_screen.dart:160` · `collection_entries_screen.dart:254` · `collections_screen.dart:117` · `journal_list_screen.dart:200` · `calendar_screen.dart:269`.
- **Πρόταση:** 1 shared widget (label+icon+onPressed). **Κόστος:** μικρό.
- **Υλοποίηση (22/10/2026, `92fdcc6`):** `ArchivedMenuButton` για τα 7 AppBar menus + `ArchivedInlineButton` (`Align`, όχι `Row+Spacer`) για το calendar· flexible label για 140% στα menus.
- **Κατάσταση:** κώδικας ✅ · **device ✅ 22/10/2026 (χειροκίνητος έλεγχος χρήστη):** 7 AppBar menus + calendar inline toggle σε **140% / landscape**, χωρίς κόψιμο label ή overflow· δεν καταγράφηκαν Flutter errors. Screenshots: `backups/o4_sheets_2026-10-22/device_logs/`.

### E13 — B-Π2b (υπό συνθήκη)
- Κρύψιμο του label «Φάκελοι» σε κοντό viewport **μόνο αν** φανεί ανάγκη στο E03.

### E14 — ✅ CLOSED 26/10/2026 (S275)
- **Υλοποίηση:** διαγράφηκαν `pendingRemindersProvider` + `pendingRemindersStreamProvider` (`reminder_provider.dart:12-21`), **5 invalidates** (`:60,:84,:95,:105` + `reminder_section.dart:115`) και 2 γραμμές docs (`supernote.md:636-637`). Το repo API `watchPending` μένει (τεκμηριωμένο, `supernote.md:424`).
- **Αποδοχή:** `flutter analyze` clean · **322/322** · `grep pendingReminders` = **0** στο `lib/`.

### E15 — ✅ CLOSED 21/10/2026 (F2: OFF path) — βλ. §3
- **Υλοποίηση:** A (`settings_provider.dart:81-91`) · B/B3 + C + C3 (`reminder_scheduler.dart`) · device-verified (βλ. §3 + Progress log).

### E16 — ✅ CLOSED 22/10/2026 (F3: startup timeouts)
- **Υλοποίηση:** `main.dart:29` launch payload 3s · `:129` pre-runApp `settings.get()` 5s · `:217` postFrame `settings.get()` 5s · `:232` `requestPermission()` 5s. **Device/test:** cold start/restore logs χωρίς block· analyze clean · 286/286 (βλ. §4).

### E17 — ✅ CLOSED 21/10/2026 (F4: κοινό `_bakeQueue`) — βλ. §3
- **Υλοποίηση:** `rescheduleForItem` → `_bakeQueue.run(() => _rescheduleForItemImpl(itemId))` — ίδια ουρά με `scheduleAll` (καμία 6η) + `resolveScheduleMode()` 1×/pass (`reminder_scheduler.dart:689-725`). **Device (POCO X3):** 5/5 call sites (`item_provider.dart:203,214,275,341,360`) `rebaked=1`, cold-start race bake `id=1→2`, counts σταθερά 168→171, test 259/259.

### E18 — ✅ CLOSED 24/10/2026 (R4: 0 άδεια catch)
- **Υλοποίηση (S273):** 7 sites → ορατό log: `recurrence.dart:91,115,130` (`warning` ×3) · `attachment_service.dart:127` (`error`+stack) · `share_service.dart:433` (`warning`) · `habit_service.dart:124,155,766` (`warning` ×3).
- **Διόρθωση topUp (`habit_service.dart:754-767`):** guard `reminder_times.isNotEmpty` πριν το `jsonDecode` — απέφευγε `FormatException` σε **κάθε** habit με 1 ώρα (`setReminderTime` διαγράφει το `reminder_times`).
- **Αμετάβλητα (σκόπιμα):** monthly legacy `catch (_)` (`recurrence.dart:102`, fallback `int.tryParse`) · non-empty `catch (_)` (share bullet/numbered) — δεν ήταν E18.
- **Αποδοχή:** `catch (_) {}` = **0** · analyze clean · test **294/294** (βλ. §4).
- **Device pass (POCO X3, debug — 24/10/2026):** cold start `topUp: done scanned=4 needTopUp=0 created=0 scheduledBatch=275` · `OS pending=315` · 151ms · **0** `parse failed` / **0** `ERR`. T1 ειδοποίηση ✅ · T2 `x/3 ώρες` + persistence ✅ · T5 share entry σε Yahoo Mail (τίτλος+πεδία+📎) ✅ · T6 add/open/delete ✅. Τα `WRN RACE RISK` είναι προϋπάρχοντα (S50, `main.dart:349-353`), όχι E18.

### E19 — ✅ CLOSED 26/10/2026 (S275)
- **Υλοποίηση:** (α) `_recentLimit = 10` στο `home_folder_view.dart` · (β) τα 3 φίλτρα χρησιμοποιούν το **υπάρχον** `Item.isVisible` (`item.dart:141`, 0 χρήσεις πριν) — απόδειξη ότι ήταν περιττά: το `watchByFolder` φιλτράρει **στη DB** `deletedAtIsNull + archivedEqualTo(false)` (`super_note_helper.dart:574-583`) · (γ) διαγράφηκε ο 2ος υπολογισμός `take(10)` μαζί με `FolderViewData` + `folderViewDataProvider` (`items_query_provider.dart:34-75`).
- **Αποδοχή:** analyze clean · **322/322** · ίδια items/stats (behavior-neutral).
- **Υπόλοιπο → `E44`:** «Πρόσφατα» ταξινομούνται με `sortOrder`, όχι `updatedAt` (semantic bug) + drag policy σε recency-sorted λίστα.

### E20 — ✅ CLOSED 29/10/2026 (device-verified T1/T2/T3/T5/T7, S279)
- **Σημεία (πριν):** `reminder_section.dart:237` · `appointment_detail_screen.dart:463` · `journal_detail_screen.dart:548` (refs refresh 27/10/2026/S277). Αποκλείει ημερομηνίες <2000.
- **Υλοποίηση:** `AppDateUtils.earliestYear = 1900` (rename του `birthdayFirstYear` — ενημερώθηκαν 3 callers: `contact_detail`, `event_detail`, `appointment_detail`) + `AppDateUtils.clampToRange(value, first, last)` (E41 pattern) σε **5** pickers:
  - journal entry: `1900 … now`
  - reminder trigger: `1900 … now.year + pickerLastYears` (το `initialTime` κρατά την ώρα του `raw`, όχι του clamp)
  - appointment date: `1900 … 2100` (επιτρέπει πια παλιά ραντεβού, π.χ. 1995)
  - appointment birthday / contact birthday: `1900 … now`
- **Tests:** `test/picker_bounds_test.dart` (2× AssertionError του SDK χωρίς clamp + 2× επιτυχία με clamp) · `date_utils_numeric_test` (clamp edges) · `reminder_occurrences_test` (daily από 1900 → κενό walk-cap · yearly γενέθλια 1950 → γεμίζει).
- **Γνωστός περιορισμός (όχι νέος):** `planOccurrences` `maxWalk=6000` → daily >~16,4 έτη και weekly >~57–115 έτη πίσω χτυπούν cap· κρατούν το thread + `DebugConfig.warning`, **δεν** διαγράφουν. Monthly/yearly ασφαλή.
- **Device pass (POCO X3, debug, 29/10/2026 — `backups/s279_o7_device/`):**
  - **T1 γενέθλια 1950:** άνοιγμα «Γεννεθλια 1950» → `28 Οκτ 1950, 09:00` · picker ανοίγει **Οκτώβριος 1950** χωρίς assert · Διάγνωση: «Επόμενη 28/10/2027 09:00 · **5 στη σειρά** · μέχρι 28/10/2031» ⇒ το yearly fill δουλεύει από 1950. *(Το item είναι συμβάν γενεθλίων· η επαφή χρησιμοποιεί τον ίδιο `earliestYear` + clamp.)*
  - **T2 ραντεβού 1995:** `12/06/1995` στο chip · picker **Ιούνιος 1995** χωρίς assert (πριν αδύνατο λόγω `DateTime(2000)`).
  - **T3 journal 12/04/1998:** chip `12/04/1998` (dd/MM/yyyy) · picker **Απρίλιος 1998** · η λίστα ετών ξεκινά **1900**.
  - **T5 υπενθύμιση 1990 + daily** (σκόπιμα παλαιότερο του 1999): `ReminderSection._pickDateTime: selected dt=1990-10-29 11:58` → `rrule=FREQ=DAILY;INTERVAL=1` → `created new root id=3223` · `scheduleReminders: rows=85 desired=85 baked=0 kept=85 failed=0 skipped=0 truncated=false` · `refreshRecurringReminders: created 0 new child reminders total` · **0 ERR**. Επιβεβαιώθηκε και **by-design guard**: one-shot με παρελθοντική ώρα → snack «Η ώρα έχει περάσει…» + log `past one-shot, blocked` (γι' αυτό απαιτείται πρώτα recurrence).
  - **T7 διάγνωση:** ημερομηνίες/ομάδες σε **dd/MM/yyyy** («29/10/2026 17:30», «μέχρι 10/11/2026 17:30»).
  - **Αποδοχή:** analyze clean · **370/370** · T1/T2/T3/T5/T7 ✅ + T6/T8 (E22) ✅.

### E21 — ✅ CLOSED 26/10/2026 (S275)
- **Υλοποίηση:** διαγράφηκε το `// TODO: Σελίδα προς Ανάπτυξη` από `models/{attachment,app_settings,item_tag,tag,workspace}.dart:2` (χρησιμοποιούνται κανονικά → το TODO ήταν ψευδές). Σε `user.dart`/`device.dart` αντικαταστάθηκε με: `// Collection στο Isar — καμία λειτουργία δεν τη χρησιμοποιεί ακόμη.` (0 χρήσεις, κανένα auth/sync feature).
- **Αποδοχή:** analyze clean · **322/322** · `grep "Σελίδα προς Ανάπτυξη"` = **0**.

### E22 — ✅ CLOSED 29/10/2026 (device-verified T4/T6/T8 + regression T7, S279)
**Επιβεβαιωμένα υπαρκτά (21/10/2026 · refs 27/10/2026/S277) → τι έγινε:**
- `Text('✓')` (`habit_detail_screen.dart:731`) → **αφαιρέθηκε** (το `Spacer` έμεινε, καμία μετατόπιση).
- `📅` ×2 (`folder_create_sheet.dart:28,33`) → `kFolderCreateTypes` **2-tuple** `(type, label)` + `ItemTypeIcon` (SPoT χρώμα/icon ανά τύπο). Το `folder_create_parity_test` παραμένει πράσινο (`t.$1` + `length`).
- `BlockTileWidget` Stateful (`:146`, state `:170`) → **παραμένει Stateful**, τώρα με πραγματικό state (`_hovered`/`_focused`).
- Delete πάντα ορατό (`:265-284`) → ✕ **μόνο σε hover/focus**, hit area **48×48** (`kMinInteractiveDimension`), `Visibility(maintainSize/maintainAnimation/maintainState: true, maintainInteractivity: false)` → καμία μεταβολή πλάτους/ύψους, κανένα tap όταν κρυφό, `key: ValueKey('block_delete')`. Focus ανίχνευση με ancestor `Focus(canRequestFocus:false, skipTraversal:true)`.
- `O(n²)` αρίθμηση (`:110-113`) → `numberedIndexesFor(blocks)` top-level, **O(n)** (ίδια semantics: συνεχής αρίθμηση σε όλη τη σημείωση).
- `DateTime.now()` σε build (`task_list_screen.dart:268,475`) → `ref.watch(dayTickProvider)` (μετακόμιση provider σε `ui_provider.dart` — SPoT) · `today` περνά σε `_TaskCard`/`_TaskProgressBar` · `dueDate.startOfDay`.
- Χειροκίνητο `d/m/yyyy` (`journal_detail:538,726` · `shared_intent_service:150` · `reminder_diagnostics:187`) → `AppDateUtils.formatNumeric` / `formatNumericDateTime` / `formatTime` (**intl-free** τα numeric).
- **Tests:** `date_utils_numeric_test` · `picker_bounds_test` · `block_numbering_test` · `block_tile_delete_test` · `folder_create_icons_test` + επεκτάσεις `shared_intent_mapper_test` (regex `^\d{2}/\d{2}/\d{4}$`) & `reminder_occurrences_test`.
- **Device pass (POCO X3, debug, 29/10/2026 — `backups/s279_o7_device/`):**
  - **T4 block editor:** σημείωση `T4` — το ✕ **δεν** φαίνεται default· μόλις εστιαστεί block εμφανίζεται **48×48** δεξιά (χωρίς μεταβολή ύψους γραμμής)· αρίθμηση συνεχής **4→11** (10+ numbered, O(n))· **140%** και **landscape** → δύο στήλες, **0 overflow/assertions** (screenshots `t4_focus`, `t4_font140`, `t4_landscape140`).
  - **T6 create menu:** «Νέο στοιχείο σε “Γενικά”» → **8** τύποι με **ItemTypeIcon** (χρώμα/icon ανά τύπο), **0 emoji**.
  - **T8 habit:** κεφαλίδα «E40 single» → `0 / 2 ώρες` χωρίς `✓` (Spacer έμεινε).
  - **T7 (regression):** `formatNumeric*` στο diagnostics χωρίς intl crash.
  - **Αποδοχή:** analyze clean · **370/370** · T4/T6/T8 ✅ + T1/T2/T3/T5/T7 (E20) ✅.
**Χαμηλής αξίας / per-case (όχι wholesale):** `if(!mounted)return` style · `Colors.white/black` (κυρίως σωστά ως on-color σε χρωματισμένες επιφάνειες).

### E23 — ✅ CLOSED 26/10/2026 (S275, απόφαση — 0 κώδικας)
- **Κείμενο κλεισίματος (ακριβές):** Tokens canonical (S169). Limits canonical **ανά τομέα** (`osAlarmLimit`, `maxAttachmentSizeMB`, `pickerLastYears`, `maxResults`, `ImageUtils.*`). **Δεν** υπάρχει ενιαίο registry και **δεν** προστίθεται: το μόνο πραγματικό διπλότυπο (370-ήμερο, `super_note_helper.dart:1143,1155`) μένει σκόπιμα (2 sites, ίδιο αρχείο, σχολιασμένα). **Δεν** διεκδικείται «όλα canonical».
- **Αποδοχή:** analyze clean · **322/322** (docs-only).

### E25 — ✅ CLOSED 24/10/2026 (S273, docs sync όπως στο τελικό κλείσιμο)
- `supernote.md`: test counter **294/294**, Error Handling/Performance **αληθή**, tree **+4 αρχεία**, `dayTickProvider`, ShareService (E39 pointer) · `code_refactor.md`: §3/§7/§8/§9 → **παραπομπή** (κανόνας 9), πλήρες αντίγραφο `backups/s273_docs_sync/` · `oldsessions.md`: κεφάλαιο **S273** · `a11y.md`/`README.md` ευθυγραμμισμένα. Λεπτομέρειες: §3/§4 + `oldsessions.md` S273.

### E27 — ✅ CLOSED 26/10/2026 (device-verified, S276)
- **Πού ήταν:** `reorderable_item_list.dart:137` — `autoScroll: false` στο `SliverReorderableGrid`.
- **Υλοποίηση:** `autoScroll: physics is! NeverScrollableScrollPhysics` (ο **γραπτός κανόνας του package**, `reorderable_grid.dart:338-339`) · `collections_screen.dart:228` → ρητό `autoScroll: true`. Στο 1-column path (`ReorderableListView`) το auto-scroll είναι native — δεν άλλαξε.
- **Device (POCO X3, 26/10/2026, grid 2 στηλών):** κρατώντας το handle στην άκρη της λίστας, το περιεχόμενο **κυλάει μόνο του** και αποκαλύπτει τα επόμενα items (μία χειρονομία 13 θέσεων: `move full=179 filtered=13 0→12`) · 0 exceptions. **PASS.**

### E28 — ✅ CLOSED 22/10/2026 (device-verified, user-confirmed 140%/landscape)
- **Πού (αρχικός έλεγχος 12, τελικά 15 μετά τον έλεγχο των settings/calendar/contact):** `appointment_detail:537` · `task_detail:170` · `tag_picker_sheet:114` *(isScrollControlled)* · `settings_tiles:176,264` (size/folder picker) · `settings_colors:88` · `note_detail:120` · `contact_detail:436,1041` · `collection_detail:212` *(isScrollControlled)* `,787` · `journal_detail:176` · `event_detail:308` · `calendar_screen:375`.
- **Γιατί μετράει:** το S109 SPoT (`showSafeSheet`/`SafeSheet`) υπάρχει για scroll/keyboard/landscape ασφάλεια (κλάση S103–S108). **Δεν** αποδείχθηκε overflow σε αυτά τα 12 — είναι **SPoT bypass** προς έλεγχο, όχι επιβεβαιωμένο bug.
- **Κόστος:** μικρό-μεσαίο (1 site/session + device landscape). **Ρίσκο:** χαμηλό (οπτική ισοδυναμία).
- **Υλοποίηση (22/10/2026, `92fdcc6`):** 15 sites σε `SafeSheet`/`showSafeSheet` (6 reminder sheets + FolderCreate + TagPicker + settings size/folder/colors + collection field/icon + contact photo + calendar creation). Απομένουν **3** σκόπιμα raw: `safe_sheet.dart:50` (ο canonical wrapper), `confirm_dialog.dart:129`, `appointment_detail_screen.dart:391` (item picker).
- **Κατάσταση:** κώδικας ✅ · `grep showModalBottomSheet` = 3 exceptions · **device ✅ 22/10/2026 (χειροκίνητος έλεγχος χρήστη):** όλα τα 15 sites σε **140% / landscape**, χωρίς overflow/assertions· screenshots spot checks `backups/o4_sheets_2026-10-22/device_logs/`.

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

### E38 — ✅ CLOSED 23/10/2026 (analyze+tests, S272)
- **Πού:** `selectedFolderIdProvider` (`folder_provider.dart`) · Home + 7 λίστες + Ημερολόγιο · `shared/widgets/folder_picker_dialog.dart` · `main.dart` · `settings_tiles/settings_screen/settings_provider` · `shared_intent_service.dart`.
- **Πρόβλημα:** διπλό state (`homeSelectedFolderProvider` + `selectedFolderIdProvider`) + `FolderAutoSelectMixin` + startup seed + `preferredFolderId` ⇒ απρόβλεπτη προεπιλογή· FAB κρυφό σε «Όλοι»· picker μόνο στην εισαγωγή επαφών.
- **Υλοποίηση:** ένα state (null = «Όλοι», εκκίνηση πάντα «Όλοι»), κεντρικό deselect στο `FolderNotifier.delete`, κοινό `showFolderPickerDialog` + `resolveFolderForNewItem` (δεν αλλάζει την κοινή επιλογή), FAB πάντα ορατό (Home/7 λίστες/Ημερολόγιο — type-first), φίλτρο μήνα σε events + γενέθλια επαφών, αφαίρεση mixin/seed/preferred UI+provider+μέθοδος+share branch.
- **Απόδειξη:** analyze clean · **290/290** (50 files, +3 `test/folder_picker_resolve_test.dart`) · backup `backups/s272_e38_folder_picker/` (24 αρχεία · BASE_HEAD `82cdc77`).

### E39 — Ενιαία κοινοποίηση: τίτλος + πεδία + συνημμένα σε ΟΛΑ τα items
- **Απόφαση χρήστη (24/10/2026):** όχι μόνο για συλλογές — **κοινή συμπεριφορά** για notes/tasks/events/contacts/appointments/journal/habits/collections κ.λπ., όπου υπάρχει κοινοποίηση.
- **Σημερινή κατάσταση (μετρημένη):**
  - `shareItem` (`share_service.dart:12`): ειδική διαδρομή **μόνο** για `ItemType.knowledge` (entry: schema + πεδία + αρχεία). Όλα τα άλλα → `_format` (`:71-101`).
  - `_format`: note/task/appointment/contact/event/journal/habit έχουν δικό τους formatter· **collection (`ItemType.project`), goal, finance, bookmark, checklist → μόνο τίτλος** (`default: :96-97`).
  - Συνημμένα συλλέγονται **μόνο** από πεδία collection entry (`:346-374`). Item-level `AttachmentsStrip` (`note_detail_widgets.dart:138`, `event_detail_screen.dart:665`) **δεν** κοινοποιείται ποτέ.
  - Κοινοποίηση **συλλογής** = σκέτος τίτλος (δεν διαβάζει entries) — επιβεβαιωμένο σε device 24/10/2026.
  - Προορισμοί που αγνοούν `EXTRA_TEXT` όταν υπάρχει αρχείο → χάνεται όλο το κείμενο (Yahoo Mail ✅· άλλος προορισμός ❌) — `share_plus 12.0.2`, `Share.kt:108-113`.
- **Στόχος:** ένα ενιαίο pipeline `ShareContentBuilder` → `{subject, text, files}` με σταθερή σειρά: **τίτλος → σύνοψη συνημμένων → πεδία → σώμα**. Κάθε τύπος δηλώνει μόνο τα δικά του sections (task: προτεραιότητα/προθεσμία/υποεργασίες · event/appointment: ώρα/τοποθεσία · contact: τηλέφωνα/email · habit: recurrence · collection: entries).
- **Συνημμένα:** από (α) item attachments και (β) collection field ids· **dedupe by id**, skip missing αρχείο (log), όρια πλήθους/μεγέθους + σύνοψη `📎 n συνημμένα` **αμέσως μετά τον τίτλο** (ανθεκτικό σε truncation).
- **Συλλογή:** «με περιεχόμενο» = λίστα entries (τίτλος + πεδία + 📎), χωρίς archived/deleted· ρητή επιλογή αν στέλνονται και τα αρχεία τους.
- **Συμβατότητα προορισμών:** επιλογή **«Κείμενο»** / **«Κείμενο + αρχεία»** (ή `.md` fallback) ώστε να μη χάνεται ποτέ το κείμενο. *(Απορροφά την άτυπη ιδέα «κείμενο/κείμενο+αρχεία» — **δεν** παίρνει δικό της ID· το `E40` χρησιμοποιείται για το restore pipeline, βλ. κάρτα E40.)*
- **Side effects:** `share_service.dart` (refactor formatters σε builder) + 1 σημείο UI (item actions/entry card) + tests· **καμία** αλλαγή DB/schema/notifications.
- **Αποδοχή:** για κάθε shareable τύπο → τίτλος + πεδία + συνημμένα παρόντα· 0 χαμένα/διπλά αρχεία· analyze/test clean· device spot-check (Yahoo Mail + app που αγνοεί `EXTRA_TEXT`).
- **Κατάσταση:** **OPEN — θέλει spec/απόφαση πριν από κώδικα** (δεν έχει υλοποιηθεί τίποτα).

### E40 — ✅ CLOSED 27/10/2026 (device-verified T1–T9, S278 `e96cbc9`)
- **Πού (πριν):** `trash_screen.dart:74-88` — `_restoreSelected()` έκανε `for (final id in _selectedIds.toList()) await notifier.restoreItem(id)` ⇒ **N×** cascade query-set + `items.restore` (N txns) + `refreshRecurringReminders()` (global pass) + `rescheduleForItem(id)` + `topUpHabitReminders(force:true)` (global pass) + `invalidateSelf()`.
- **Υλοποίηση (3 αρχεία, 2 νέες μέθοδοι, 0 νέοι providers/tests/schema):** `super_note_helper.dart` → `restoreMany(ids)`: `isEmpty` → `!isOpen` → `getByIds` → φίλτρο `deletedAt != null` → `deletedAt=null`+`isDirty=true` → **1** `writeTxn`/`putAll`· `restore(id)` = wrapper. Χωρίς `updatedAt`/`localVersion` (E44 recency). `item_provider.dart` → `restoreMany(ids)`: dedupe → **1** `_collectionEntryIds(includeDeleted:true)` → entries+parents dedupe (entries πρώτα) → **1** repo call → **1** refresh → `rescheduleForItem`/id → **1** `topUp(force)` → `invalidateSelf` σε `finally`· `restoreItem(id)` = wrapper (log parity n=1). `trash_screen.dart` → snapshot ids πριν το confirm + flag `_restoring` + `mounted` → **1** κλήση. `_restoreSingle` αμετάβλητο.
- **Device pass (27/10/2026, `e40_device.log` 5.213 γρ., pid `32101` σταθερό, 0 `ERR`/exception, 0 `truncated`):** T1 batch 3 `n=3 → total=10 restored=10` (1 txn/1 refresh/1 topUp, 511ms) · T2 συνήθεια (`needTopUp=1 created=120`) · T3 recurring (`rebaked=14 skipped=1`) · T4 single parity (`restoreItem: id=… → rescheduled`) · T5 διπλό tap (1 κλήση) · T6 συλλογή+entries (dedupe: `total=8` αντί 11) · T7 ήδη restored (`restored=1` από 8, 0 επανεγγραφές) · T8 10 επιλεγμένα · T9 archived+deleted → επιστροφή στο **αρχείο** (`reschedule skipped=5`, `skipping archived root id=2191`). T5/T8: επιβεβαιώθηκαν από τον χρήστη (δεν κατεγράφησαν στο log — τα markers είχαν άλλο tag). **PASS.**
- **Αποδοχή:** analyze clean · **339/339** · R1 (`trash_screen` 496 · `item_provider` 482 · `super_note_helper` 1623 = ήδη >500, E06) · backups `backups/s278_e40/` + `backups/s278_e40_close/`.
- **Κατάσταση:** **CLOSED**.

### E41 — ✅ CLOSED 26/10/2026 (device-verified, S274: πολυήμερα συμβάντα)
- **Υλοποίηση:** `span_utils.dart` (εύρος, 1 lane, hatch overlays, sort, halo, ≥3.0:1) · `event_properties_panel.dart` (Λήξη/Χρώμα) · `calendar_screen.dart` (`_MonthData`, batch properties, `_SpanBarPainter`, markers) · `event_detail_screen.dart` (`_pickEndDate`/`_pickSpanColor`, clamp) · `property_provider.dart` (`calendarDataVersionProvider`) · `property_keys.dart` · `search_service.dart` (blocklist) · `share_service.dart` (εύρος). `end_date` = EAV date-only inclusive · `span_color` = `#RRGGBB` · τελείες **πάνω** (`top: 0`) / γραμμή **κάτω** (`bottom: 0`).
- **Device pass (26/10/2026):** 3ήμερο συμπαγές · επικάλυψη → **45° hatch** στην κοινή ζώνη + συνεχής γραμμή σε όλο το 2ο εύρος · all-day εύρος · γενέθλια χωρίς γραμμή · χρώμα picker (και σε selected/today) · 100%/140% χωρίς overflow. **PASS.**
- **Αποδοχή:** analyze clean · **321/321** (51 files) · §3 + `oldsessions.md` S274 · backups `s274_e41/`, `s274_e41_hatch/`, `s274_e41_dots_top/`, `s274_e41_close/`.

### E44 — ✅ CLOSED 26/10/2026 (device-verified, S276)
- **Πού ήταν:** `home_folder_view.dart` (`FolderViewMode.recent` → `all.where(isVisible).take(_recentLimit)`) · `reorderable_item_list.dart:36` (`_canDrag = !pinned && !favorite`, hardcoded).
- **Απόδειξη (τότε):** το stream έρχεται `sortBySortOrder()` (`super_note_helper.dart:580`) → `_sortByCategory` για ίσο `sortOrder` επιστρέφει `0` (`:236`)· κάθε νέο item γράφεται `sortOrder = 0.0` ⇒ **ποια 10 φαίνονται δεν οριζόταν από τον κώδικα**.
- **Υλοποίηση:** top-level `selectRecentItems` (`home_folder_view.dart:64`) = `isVisible` + **`updatedAt ?? createdAt` desc** + tie-break `id desc` + `take(10)` (ντετερμινιστικό, 9 unit tests) · `ReorderableItemList.dragEnabled` (default **`true`** — 0 αλλαγές στα 7 άλλα sites) + `_isDraggable = dragEnabled && !pinned && !favorite` · Home «Πρόσφατα» → `dragEnabled: false` (A4) · `_sortByCategory` **PARK** (A6, 0 αλλαγές — το recency δεν εξαρτάται πλέον από αυτό).
- **Device (POCO X3, 26/10/2026):** `HomeFolderView recent 10/10 ids=[…]` σε κάθε build· 15 items → **10 νεότερα**· ενέργεια/μετακίνηση σε item → **1ο** (F11, by design μέσω `updatedAt`)· **καμία λαβή** στα «Πρόσφατα» · pinned/favorite **χωρίς** λαβή στα «Όλα» · drag σε «Πρόσφατα» **κλειδωμένο** · drag σε «Όλα» αποθηκεύει σειρά και **δεν** αγγίζει το `updatedAt` · 100%/140% 0 overflow. **PASS.**
- **Αποδοχή:** ✅ 12 items με διαφορετικά `updatedAt` → 10 νεότερα · edit → πρώτο · drag off στο recent · 0 handles σε pinned/favorite.

### E45 — Habit topUp: σειριακό OS scheduling (120 alarms ≈ 9.2s)
- **Πού (μετρημένο):** `habit_service.dart:725-848` (`_topUpHabitRemindersImpl`) — δημιουργεί **120 rows** (2 ώρες/ημέρα × `horizonDays = 60`, `:543`) με **σειριακό** `await helper.reminders.create(...)` ανά occurrence (`:816-826`)· μετά **1** batch `ReminderScheduler.scheduleReminders(pendingToSchedule)` (`:832`), που καταλήγει σε `_runBakePlan` (`reminder_scheduler.dart:220-239`): `for (final reminder in plan.schedule) await _scheduleOne(...)` ⇒ **1 `zonedSchedule` ανά alarm, σειριακά**.
- **Απόδειξη (S278, POCO X3, device):** restore συνήθειας (T2 του E40) → `HabitService.topUp: done scanned=4 needTopUp=1 created=120 scheduledBatch=338` · **120×** `_scheduleOne … SUCCESS` · `PERF#9 topUp: … took=8962ms` (**74,7 ms/alarm** = 8962/120, άνω φράγμα — το παλιό «55ms/alarm» δεν προκύπτει από τα ίδια νούμερα) → συνολικό `E40 restoreMany took=9186ms` · `OS pending` 291→**411** (budget 450, 0 `truncated`).
- **Γιατί P2:** κανένα λάθος state (τα alarms είναι σωστά) — το κόστος είναι **χρόνος/UX**: `await` μέσα στο restore, και χτυπά **και** cold start / resume / `scheduleAll` γιατί όλα περνούν από το ίδιο `_runBakePlan`.
- **Επιλογές (να επιλεγεί πριν από κώδικα):**
  1. **Bounded concurrency** στο `_runBakePlan` (chunks 4–8 με `Future.wait`) — το budget cut γίνεται **πριν** την εκτέλεση (`plan.schedule` ήδη κομμένο, `:135`/`:912`), άρα η σειρά εκτέλεσης **δεν** αλλάζει ποια alarms κρατιούνται· ρίσκο: παράλληλα `zonedSchedule` στο ίδιο method channel → θέλει μέτρηση, όχι υπόθεση.
  2. **1 `putAll` αντί 120 `create`** για τις rows (μικρό αλλά καθαρό κέρδος, ίδιο πρότυπο με `restoreMany`/`hardDeleteMany`).
  3. **`horizonDays` 60 → 30/14** (product απόφαση): 120 → 60/28 alarms, αλλά «αδειάζει» νωρίτερα (πιο συχνό topUp)· το σχόλιο H3 (`:837-838`) το προτείνει ρητά ως μοχλό.
- **Όχι επιλογή:** batch API του FLN — **δεν υπάρχει** στο 17.2.4 (μόνο `zonedSchedule` / `cancel(id)` / `cancelAll()`).
- **Θεμέλιο (S280 — από SDK + config, όχι υπόθεση):**
  - FLN 17.2.4 `zonedSchedule` → `zonedScheduleNotification` (`:1605`→`:573`): `setupAlarm` (`:591`) **πριν** το `saveScheduledNotification` (`:593-595`) = `loadScheduledNotifications` (**Gson parse ΟΛΗΣ** της λίστας, `:501-512`) + `saveScheduledNotifications` (**serialize ΟΛΗΣ** + `apply()`, `:514-522`). Δηλαδή **O(n) persistence σε κάθε κλήση**, στο platform (main) thread (`setMethodCallHandler`, `:1370-1373`).
  - Το ίδιο ισχύει για **κάθε `cancel`** (`removeNotificationFromCache`, `:524-534` ← `cancelNotification`, `:1769-1781`) και για κάθε `pendingNotificationRequests` (πλήρες parse, `:1532-1546`).
  - Επειδή `setupAlarm` προηγείται του save, ένα revoke exact-alarm **δεν** αφήνει ghost cache· το Dart κάνει 1× retry `inexact` (`notification_service.dart:293-312`). Το boot rearm (`:219-236`) καλεί με `updateScheduledNotificationsCache=false` → **καμία εγγραφή**.
  - Isar 3.1.0+1: `putAll` = `getTxn(true)` (reuse ενεργού txn, `isar_common.dart:88-101`) + `schema.attach` ανά object (`isar_collection_impl.dart:304-326`) → **τα ids γράφονται πίσω**· `putAll([])` → `alloc(0)` → `ArgumentError` (`txn.dart:56-62`, `ffi-2.2.0/allocation.dart:57-71`) ⇒ guard `isEmpty`.
  - **Συνέπεια:** το **concurrency δεν επιταχύνει το native** (είναι σειριακό). Μοχλοί = λιγότερες κλήσεις · λιγότερα commits · μικρότερη persisted λίστα · Dart/log overhead.
- **Υλοποίηση S280:**
  1. **Φ1** `ReminderRepository.createMany` (1 `writeTxn` + `putAll`, guards `isEmpty`/`!isOpen`, ids πίσω) → `topUp` (120 txns → **1**) + `_scheduleRemindersImpl` (2ος loop). Το `create` μένει για τους 3 UI callers.
  2. **Φ0** μετρήσεις (0 behavior change): `PERF#9b topUp` (`rowsMs`, `osReadMs`, `schedMs`, `otherMs`) · `PERF#9b scheduleReminders` (`readMs`, `planMs`, `modeMs`, `cancelMs`, `schedMs`, `nativeMs`, `dartMs`) · `_BakeExecutionResult` + μετρητής μόνο του `zonedSchedule` στο `_scheduleOne`.
  3. **Φ3** `avg=` → `avgSched=` (διαιρεί με `result.baked`, όχι με όλες τις DB rows — το «8.7ms/alarm» του S225 ήταν **ms/row**) + `RUNWAY` log στο topUp.
  4. **Γ7** `_lastTopUp = null` στο catch → ένα αποτυχημένο pass δεν μπλοκάρει retry για 10 λεπτά.
- **Υλοποίηση S281 (2α → **A: OS-horizon για habits**):** μετά τη μέτρηση (`native 92,8%`, O(n²) συνολικά ⇒ λιγότερες κλήσεις = ο μόνος μοχλός), το OS κρατά **μόνο 14 ημέρες** από τα habit-generated alarms — η DB κρατά 60 και το topUp/resume ξαναγεμίζει.
  1. `reminder_bake_plan.dart`: `habitOsHorizonDays = 14` (**= A5**: `refreshRecurringReminders` batchSize 14 για daily, «με 5 σταματούσε μετά 5 μέρες»)· `habitMinOsAlarmsPerItem = 5` (**= A5** weekly/monthly/yearly)· pure **`habitDeferredIds`** (SPoT του κανόνα, το καλεί **και** το Diagnostics)· `ReminderBakePlan.deferredCount`· `required bool habitOsWindow` (compiler-enforced: 3 prod + 7 tests) · cutoff `DateTime(y, m, d + 14)` (τοπικό μεσάνυχτο, **DST-safe**, αποκλειστικό)· predicate `title == habitGeneratedTitle` (ίδιο με `_clearHabitGenerated`, **0 νέο marker**).
  2. `reminder_scheduler.dart`: `habitOsWindow: true` στα 3 call sites (`scheduleAll` `:147`, `scheduleReminders` `:940`, `rescheduleForItem` `:1032`) + `deferred=` στα `PERF#9`/`PERF#9b`.
  3. `reminder_diagnostics_screen.dart`: `_PendingRow.deferred` → «⏳ εκτός ορίζοντα 14ημ. (στη DB)» αντί για ψευδές κόκκινο «ΛΕΙΠΕΙ ΑΠΟ ΤΟ OS!» (θα έβγαινε για ~690 rows) + γραμμή «Αναβολή: N» στην κάρτα.
  - **Reuse (0 νέα μηχανισμός):** scoped `cancelableOsIds` καθαρίζει τυχόν OS habit alarms εκτός πολιτικής · `topUp`/resume/cold start = refill · `rescheduleForItem` (`forceSchedule`) ξαναψήνει 14ημ. αντί έως 225 · `_scheduleRemindersImpl` (αλλαγή ωρών) κόβεται αυτόματα από το plan · `repairLegacyHabitRows` → `syncScheduleWithRecurrence` καλύπτεται · `rebakeIfTruncatedAndDayChanged` **σωστά** no-op (`truncated=false`: το παράθυρο δεν «χάνει» κάλυψη, μόνο μικραίνει).
  - **Αναμενόμενο (ίδια δεδομένα):** `desired 956 → ~266`, `deferred ~690`, `cut 506 → 0`, `truncated false`, cold start `21,7s → ~7-8s`.
  - **Δεν άλλαξαν:** `horizonDays` (DB 60), `planTopUp`, `_computeOccurrences`, `createMany`, models, providers, UI (εκτός Diagnostics), schema. Το `_clearHabitGenerated` mass-cancel μένει **ανοιχτό** (ξεχωριστό βήμα).
- **Εκτός / μετά τη μέτρηση:** concurrency N=4 (2β — **απορρίφθηκε** με μέτρηση: native 92,8% σειριακό) · `horizonDays` 60→30 (2γ — παραμένει product απόφαση) · log trimming (μόνο αν μετρηθεί) · «μην περιμένει το restore» (δεν λύνει το main-thread jank) · `refreshRecurringReminders` child loop (άλλο feature) · `_clearHabitGenerated` mass-cancel (ξηρό ρίσκο, μετά το device pass).
- **Acceptance:** analyze clean · **377/377** · device: T1 πρώτη αποθήκευση H1 · T2 restore H2 (vs `9186ms`) · T3 cold start (`desired≈266`, `deferred≈690`, `truncated=false`, `loop≈7-8s`) · T5 αλλαγή ωρών (2ος loop → `createMany`) · T6 archive/unarchive · T7 OFF→ON · **T8** Diagnostics: 0 κόκκινα «ΛΕΙΠΕΙ», ⏳ στα deferred · **T9** monthly habit → ≥5 alarms στη Διάγνωση — 0 `ERR`.
- **Κατάσταση:** 🔧 **κώδικας ✅ 29/10/2026 (S280 Φ0/Φ1/Φ3/Γ7 + S281 Α)** · analyze clean · **377/377** · **device pass ⏳** · backups `backups/o10_e45_p0/`, `backups/o10_e45_oswindow/`.

### E26 — Τελικό κλείσιμο
> **Κατάσταση 24/10/2026:** τα βήματα **1–3 έγιναν** στο S273 (docs sync «σαν τελικό κλείσιμο»)· μένει το **4**, όταν αδειάσουν P2/P3.
1. ✅ `oldsessions.md`: κεφάλαιο **S273** (Φ5 partial: E18, device pass, E39, docs, commits).
2. ✅ `code_refactor.md`: §3/§7/§8/§9 → παραπομπή (κανόνας 9 — καμία διπλή λίστα).
3. ✅ `supernote.md`: μόνο αληθή/αρχιτεκτονικά + test counter **294/294**.
4. ⏳ Διαγραφή `error_list.md` — **μόνο** όταν κλείσουν P2/P3 (+ τελικό sync του S273 κεφαλαίου).

---

## 3. Κλειστά & επαληθευμένα (μην τα ξανακυνηγάτε)

> Επαληθευμένα στον κώδικα ή/και σε device. Λεπτομέρειες: `oldsessions.md` S141–S277.

- **`O7` (E20 + E22) — CLOSED 29/10/2026 (S279, device-verified T1–T8):** `AppDateUtils.earliestYear=1900` + `clampToRange` σε **5** pickers (journal `1900…now` · reminder `1900…now+5` · appointment `1900…2100` · appointment/contact birthday `1900…now`) · `formatNumeric`/`formatNumericDateTime` (intl-free dd/MM/yyyy) · `numberedIndexesFor` **O(n)** · ✕ **μόνο σε hover/focus** με 48×48 + `Visibility(maintain*)` · `dayTickProvider` στο `ui_provider` (0 `DateTime.now()` σε build) · `kFolderCreateTypes` 2-tuple + `ItemTypeIcon` · αφαίρεση `✓`/emoji. Device (POCO X3, 29/10/2026): T1 1950 (picker + yearly 5/5) · T2 1995 · T3 1998 (+ έτη από **1900**) · T4 focus-✕/αρίθμηση 4→11/140%/landscape · T5 **1990 + daily** root id=3223, `rows=85 desired=85 kept=85 truncated=false`, 0 `ERR` (one-shot παρελθόν → `past one-shot, blocked` by design) · T6 8 icons/0 emoji · T7 dd/MM/yyyy · T8 habit χωρίς ✓. analyze clean · **370/370**.

- **`E05` (Ο3) — CLOSED 27/10/2026 (S277, device-verified):** mass-delete pipeline = **1** κύκλος αντί N. `ItemNotifier.permanentDeleteMany` (`trash_screen` 2 loops → 2 κλήσεις) + `hardDeleteMany` (1 query reminders + 1 query attachments + **1** writeTxn για όλα τα ids) + `deleteAllRemindersForItems` (**1** OS snapshot) + `deleteHabitRemindersMany` (**1** pass `_passQueue`: wipe + `afterRows` αδιαίρετα, S250). Singles = wrappers με **log parity n=1**. Device T1–T7: T1 `n=3 → total=7 entries=4` `took=293ms` · T2 habit branch `n=7` `took=193ms` · T5 `deleted file "…jpg"` (disk cleanup) · T7 single parity · **0 ERR**. Hard rules: ποτέ `anyOf([])`/`deleteAll([])`. analyze clean · 339/339.

- **`E40` (Ο9) — CLOSED 27/10/2026 (S278, device-verified T1–T9):** restore pipeline = **1** κύκλος αντί N. `ItemRepository.restoreMany(ids)` (guards `isEmpty`→`!isOpen` → `getByIds` → φίλτρο `deletedAt != null` → **1** `writeTxn`/`putAll`) + `ItemNotifier.restoreMany(ids)` (**1** cascade query-set, **1** txn, **1** `refreshRecurringReminders`, `rescheduleForItem`/id, **1** `topUpHabitReminders(force)`, `invalidateSelf` σε `finally`) + `_restoreSelected` 1 κλήση (snapshot ids, flag επανεισόδου, `mounted`). Singles = wrappers με **log parity n=1** (`restoreItem: id=… → rescheduled`). Device: T1 `n=3 → total=10 restored=10` 511ms · T2 habit `created=120` · T3 `rebaked=14 skipped=1` · T6 dedupe `total=8` · T7 `restored=1` από 8 · T9 archived+deleted → αρχείο (`skipped=5`) · **0 ERR**, 0 `truncated`. Hard rules: ποτέ κενή λίστα σε `putAll` (`alloc(0)` → ArgumentError) · ποτέ `restoreMany` μέσα σε `writeTxn` · `!isOpen` **πριν** το read. analyze clean · 339/339.

- **`O6` (E19, E14, E21, E23) — CLOSED 26/10/2026 (S275, analyze+tests):** `FolderViewData` + `folderViewDataProvider` **διαγράφηκαν** (2η συνδρομή στο ίδιο stream + `error: (_, __) async* {}` που παραβίαζε `supernote.md:950` → αιώνιο skeleton)· stats in-memory από το `itemsByFolderStreamProvider` (`_countVisibleByType`, `Item.isVisible`)· `_recentLimit=10` αντί magic number· **9 dead providers** + **7 invalidates** + docs (11 γραμμές) έφυγαν· **7 stale TODOs** (5 διαγραφές + 2 αληθή σχόλια)· E23 ρητό κλείσιμο. analyze clean · **322/322** · νέο test: stream error → `statsSkeleton` = `findsNothing`.
- **`E42` — CLOSED 26/10/2026 (S275, μαζί με O6):** `home_screen.dart` fingerprint + `updatedAt` **μόνο** για `pinnedOrder == null` (εκεί το sort το χρησιμοποιεί, `:551-552`) → η σειρά στο `ViewMode.both` ανανεώνεται μετά από edit χωρίς churn στα ordered items. Επαλήθευση στο device pass του **O5** (ίδια οθόνη).

- **`O5` (E27 + E03 + E44) — CLOSED 26/10/2026 (device-verified, S276):** grid reorder **autoScroll** από το physics αντί hardcoded `false` (`reorderable_item_list.dart:145` · rule του package `reorderable_grid.dart:338-339`) + ρητό `true` στις συλλογές · «Πρόσφατα» = `updatedAt ?? createdAt` desc + tie-break `id desc` + `take(10)` (`selectRecentItems`, 9 tests) · `dragEnabled` στο κοινό widget (`_isDraggable = dragEnabled && !pinned && !favorite`, default `true`, off μόνο στο «Πρόσφατα»). Device (POCO X3): auto-scroll ✅ σε grid 2 στηλών · 10/10 πραγματικά πρόσφατα · 0 handles εκεί · pinned/favorite χωρίς handle · regression drag σε tasks/habits/collections/entries/folder_view/browser ✅ · **339/339**, analyze clean.

- **`E41` — CLOSED 26/10/2026 (device-verified, S274: πολυήμερα συμβάντα):** `end_date` (EAV, date-only inclusive) + `span_color` → **συνεχής** γραμμή στο κάτω μέρος του κελιού (τελείες τύπου πάνω, `top: 0`), **45° hatch overlay** στις επικαλύψεις (`SpanDay.overlays`), 1 lane / 5px (3px + 1px halo), render-time αντίθεση ≥3.0:1 · `calendarDataVersionProvider` (F25) · blocklist αναζήτησης · share εύρος. Device (26/10/2026): 26 συμπαγές → 27–28 hatch → 29 συμπαγές 2ου · all-day 22–24 · γενέθλια χωρίς γραμμή · χρώμα picker σε selected/today · 100%/140% χωρίς overflow. analyze clean · **321/321**.

- **`E25` — CLOSED 24/10/2026 (S273, docs sync):** `supernote.md` (294/294, Error Handling/Performance αληθή, tree +4 αρχεία, `dayTickProvider`, ShareService) · `code_refactor.md` §3/§7/§8/§9 → παραπομπή (κανόνας 9) · `oldsessions.md` κεφάλαιο S273 · `a11y.md`/`README.md` ευθυγραμμισμένα. Backup `backups/s273_docs_sync/`.

- **`E38` — CLOSED 23/10/2026 (analyze+tests, S272):** μία καθολική επιλογή φακέλου (`selectedFolderIdProvider`, null = «Όλοι») σε Home + 7 λίστες + Ημερολόγιο· κοινός picker νέων items (`folder_picker_dialog.dart`)· κεντρικό deselect στη διαγραφή· αφαίρεση auto-select mixin/seed/preferred folder. analyze clean · test **290/290**.

- **`E18` — CLOSED 24/10/2026 (device/test-verified, S273):** τα 7 τελευταία άδεια `catch (_) {}` → `DebugConfig.warning`/`error` (+ guard στο `topUp`); `catch (_) {}` = **0** συνολικά. analyze clean · test **294/294** · device (POCO X3) `scanned=4` + 275 alarms, 0 warnings.

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
- **`E02` — CLOSED 22/10/2026 (device-verified, calendar compact title):** «Οκτ ’26» σε 100%/140%, portrait/landscape, 0 overflow/assertions· screenshots `backups/o4_sheets_2026-10-22/device_logs/sn_*calendar*`.
- **`E04` — CLOSED 22/10/2026 (device-verified, sheet reassemble):** `ext.flutter.reassemble` με ανοιχτό status sheet → 0 Flutter assertions/overflow· `e04_reassemble_pass.png` + `e04_reassemble.log`.
- **`E28` — CLOSED 22/10/2026 (device-verified, user-confirmed):** 15 SafeSheet sites σε 140%/landscape, χωρίς overflow/assertions· screenshots `backups/o4_sheets_2026-10-22/device_logs/`.
- **`E12` — CLOSED 22/10/2026 (device-verified, user-confirmed):** 7 archive menus + calendar inline σε 140%/landscape, χωρίς κόψιμο/overflow· screenshots `backups/o4_sheets_2026-10-22/device_logs/`.
- **Settings:** S253 (9 guards + split 9 αρχεία), S254 (`selection_list_dialog`), S255 (F13 `unarchiveMany`), S256 (F9 pop), S257 (F18 fresh list), S258 (F9c dead members), S259 (F17 slider), S260 (F18 tests), S262-b (popup overflow ×7, chip minWidth, `_PropRow`, «Όλοι» drag flag).
- **Grid:** S261 (auto-height) + S262/S262-b fixes → ✅ **E03 CLOSED 26/10/2026** (device 100%/140%, portrait/landscape, 0 overflow — S276).
- **`E24` «grid-mode guard gap» — CLOSED 21/10/2026 (stale, όχι bug):** `onReorderItem` του SDK διορθώνει ήδη το `newIndex` (`reorderable_list.dart:82-83,129-131`) · το `SliverReorderableGrid` δίνει index κελιού-στόχου (`reorderable_grid.dart:573-577,652-663`) · και τα δύο ταιριάζουν με `removeAt+insert` του `moveAndMerge` (`reorder_utils.dart:26-29`) ⇒ κανένα off-by-one. (Προαιρετικό device spot-check σε tablet grid.)
- **Crash guards:** `parseHex` try/catch, `int.parse` → `tryParse` (appointment/collection_detail), `trash deletedAt`, postFrame `mounted` guards.

---

## 4. Progress log — ιστορικό έως 26/10/2026 (νέα πρόοδος → `oldsessions.md` στο οριστικό κλείσιμο)

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
| 22/10/2026 | E04, E28, E12, E02 | **Ο4 υλοποίηση (S271, commit `92fdcc6`):** 15 raw sheets → `SafeSheet`/`showSafeSheet`· E04 sheet-context hardening (task status/priority, settings, collection, contact, calendar, habit)· E12 `ArchivedMenuButton`/`ArchivedInlineButton` (7 menus + calendar)· E02 compact «Οκτ ’26» + unit test. **Device verification εκκρεμεί (E02/E04).** | analyze clean · test **287/287** (49 files, +1) · `showModalBottomSheet` = 3 exceptions · `settings_tiles.dart` 452 γραμμές · backup `backups/o4_sheets_2026-10-22/` |
| 22/10/2026 | E02, E04, E28, E12 | **Ο4 device pass (POCO X3, debug):** E02 ✅ 100%/140%, portrait/landscape, 0 overflow· E28 spot: status/priority/reminder/folder/size/contact photo portrait 100% χωρίς overflow· E12: archive menu + calendar inline ορατά· **E04: τα sheets ανοίγουν/κλείνουν, αλλά reassemble με ανοιχτό sheet ΔΕΝ επιβεβαιώθηκε** (hot-reload attempt χωρίς reload). | screenshots/logs `backups/o4_sheets_2026-10-22/device_logs/` · `flutter_run_o4.log` · logcat |
| 22/10/2026 | E04 | **Reassemble verified (POCO X3, debug):** status sheet ανοιχτό → `ext.flutter.reassemble` μέσω VM service (pid 30972) → sheet παρέμεινε ανοιχτό, **0 Flutter assertions/overflow**· μόνο MIUI theme-config noise. | `e04_reassemble_pass.png` · `e04_reassemble.log` · `e04_reassemble_errors.txt` |
| 22/10/2026 | E28, E12 | **Full 140%/landscape pass (user-confirmed):** 15 SafeSheet sites + 7 archive menus/calendar inline toggle, χωρίς overflow/κόψιμο· κανένα Flutter error. | χειροκίνητος έλεγχος χρήστη · screenshots `backups/o4_sheets_2026-10-22/device_logs/` |
| 23/10/2026 | E38 | **S272 υλοποίηση:** ενοποίηση επιλογής φακέλου σε `selectedFolderIdProvider` (null = «Όλοι», εκκίνηση πάντα «Όλοι»), αφαίρεση `homeSelectedFolderProvider`/`FolderAutoSelectMixin`/startup seed/`preferredFolderId` UI, κεντρικό deselect, κοινό `folder_picker_dialog`, FAB unconditional σε Home + 7 λίστες + Ημερολόγιο, type-first + φίλτρο μήνα (events + γενέθλια) στο Ημερολόγιο. | backup `backups/s272_e38_folder_picker/` · analyze clean |
| 23/10/2026 | E38 | **Verify:** πλήρες `flutter test -j 1` **290/290** (50 files) · νέο `test/folder_picker_resolve_test.dart` (έγκυρη επιλογή / picker σε «Όλοι» / stale επιλογή). | run 23/10/2026 |
| 24/10/2026 | E18 | **S273 υλοποίηση:** 7 άδεια `catch (_) {}` → ορατό log (`warning` ×6 + `error`+stack ×1)· guard `isNotEmpty` στο `topUp` (αποφυγή per-pass `FormatException`). | `recurrence.dart:91,115,130` · `attachment_service.dart:127` · `share_service.dart:433` · `habit_service.dart:124,155,766` · backup `backups/s273_e18_catch/` |
| 24/10/2026 | E18 | **Verify:** `catch (_) {}` = **0** · analyze clean · test **294/294** (+4 tolerant-parsing tests). | run 24/10/2026 · `test/habit_topup_test.dart` |
| 24/10/2026 | E18 | **Device pass (POCO X3, debug):** cold start `topUp: done scanned=4 … scheduledBatch=275` · `OS pending=315` · 151ms · **0** `parse failed` / **0** `ERR`. T1 ειδοποίηση · T2 progress+persistence · T5 share entry (Yahoo Mail: τίτλος+πεδία+📎) · T6 add/open/delete — όλα OK. | logcat 18:26–18:41 (`scanned=4`) · Yahoo Mail |
| 24/10/2026 | E39 | **Καταγραφή (απόφαση χρήστη):** ενιαία κοινοποίηση τίτλου+πεδίων+συνημμένων για **όλα** τα items (όχι μόνο συλλογές) — θέλει spec πριν από κώδικα. | `share_service.dart:12,71-101,346-374` · device spot (Yahoo ✅ / άλλος ❌) |
| 24/10/2026 | docs | **Sync όλων των `.md` με τον κώδικα (S273):** `supernote.md` → 294/294, Error Handling/Performance αληθή, tree +4 αρχεία, `dayTickProvider`/`appInfo`/`appLock`, ShareService+E39· `oldsessions.md` → banner «ιστορικό έως S272, ενεργά στο error_list»· `a11y.md` → pointer σε error_list· `README.md` → πραγματική περιγραφή· `code_refactor.md` → έτοιμο banner «ΠΑΓΩΜΕΝΟ» (χωρίς άλλη αλλαγή). | analyze clean · test **294/294** · grep `catch (_) {}`=0 · 42.653 γραμμές lib/155 αρχεία (χωρίς g.dart) |
| 24/10/2026 | E25 | **CLOSED (E26 βήματα 1–3 «σαν τελικό κλείσιμο»):** `oldsessions.md` κεφάλαιο **S273** (E18 + device + E39 + docs) · `code_refactor.md` §3/§7/§8/§9 → **παραπομπή** (αρχειοθετήθηκαν, αντίγραφο σε `backups/s273_docs_sync/`) · `supernote.md` αληθή + test counter · `a11y.md`/`README.md` sync. | P3 10→9 · E26: 1–3 ✅, 4 ⏳ (μετά P2/P3) |
| 24/10/2026 | docs | **Κενό ιστορικού P1 → έκλεισε:** τα **E15/E16/E17/E29/E30/E33** δεν είχαν κεφάλαιο (S263–S269) — γράφτηκε **αναδρομικό κεφάλαιο** στο `oldsessions.md` (21–22/10, από §3/§4 + backups). `a11y.md`: τα §3.6/§8 του `code_refactor.md` → σημείωση αρχειοθέτησης. | `oldsessions.md` S263–S269 · `a11y.md:13` |
| 25/10/2026 | E41 | **S274 υλοποίηση (όλη η πρόταση + Δ1/Δ2/Δ3):** `end_date`/`span_color` ως EAV (χωρίς schema)· `span_utils.dart` (εύρος, 1 lane all-or-nothing, sort, halo, ≥3.0:1)· `event_properties_panel.dart` (εξαγωγή + Λήξη/Χρώμα)· `_MonthData` + batch `getAllForItems` (όχι N+1)· `calendarDataVersionProvider` (F25 bump μόνο σε 4 calendar keys)· blocklist αναζήτησης· share εύρος· clamp `initialDate`. | `span_utils.dart:1-232` · `event_properties_panel.dart:1-190` · `calendar_screen.dart` `_MonthData`/`_SpanBar` · `property_provider.dart` · backup `backups/s274_e41/` |
| 25/10/2026 | E41 | **Verify:** analyze **No issues found** · **318/318** (51 files, +24 `test/span_utils_test.dart` — εύρος/DST/clipping/επικάλυψη/ντετερμινισμός/αντίθεση/keys). | run 25/10/2026 |
| 25/10/2026 | E41 | **Docs:** `supernote.md` → 318/318, tree **+3 αρχεία** (`property_keys`, `span_utils`, `event_properties_panel`), calendar/EAV/provider σημειώσεις· `oldsessions.md` → κεφάλαιο **S274** (κατ' εξαίρεση, εντολή χρήστη). **Εκκρεμεί device test** (T1–T7, κανόνας 12). | analyze clean · test **318/318** |
| 25/10/2026 | E41 | **Αναθεώρηση (device feedback):** καταργήθηκε το all-or-nothing → `SpanDay.overlays` + `buildSpanBars` δίνουν **συνεχή** γραμμή σε κάθε εύρος (βάση = 1ο, υπόλοιπα = **45° hatch**, 1px ανά 3px)· `_SpanBarPainter` + `spanOverlapSurface` (ίδια χρώματα → φόντο = επιφάνεια)· markers εξαιρούν base+overlays. **Ίδιο ύψος 5px / κελί 44px.** | `span_utils.dart` (`SpanDay`/`SpanOverlay`/`buildSpanBars`) · `calendar_screen.dart` (`_SpanBarPainter`, `_markersFor`) · test **321/321** (+3) · backup `backups/s274_e41_hatch/` |
| 26/10/2026 | E41 | **Εναλλαγή θέσεων (υλοποίηση χρήστη + έλεγχος):** τελείες τύπου **πάνω** (`top: 0`, τελικό — 3px από το ink) · γραμμή πολυήμερου **κάτω** (`bottom: 0`). Docs sync (πάνω→κάτω, μέτρηση 43.306) + **νέο καθεστώς docs** (εκκρεμότητες εδώ, πρόοδος `oldsessions.md`). | `calendar_screen.dart` (`_MonthGrid` dots/bar) · analyze clean · test **321/321** · backups `backups/s274_e41_dots_top/`, `backups/s274_rule_sync/` |

---

## 5. Χάρτης παλιών docs → νέο καθεστώς

| Αρχείο | Πριν | Τώρα |
|---|---|---|
| `code_refactor.md` §3/§7/§8/§9 | λίστες/status | ✅ **αρχειοθετήθηκαν 24/10/2026 (S273)** — παραπομπή σε `oldsessions.md`/`error_list.md` (κανόνας 9) |
| `supernote.md` | αρχιτεκτονική + status | ✅ **μόνο αρχιτεκτονική** (κανόνας 8) — αληθή facts 24/10/2026 |
| `oldsessions.md` | ιστορικό + «επόμενο session» | ✅ **ιστορικό + πρόοδος** — κεφάλαιο **S277** (27/10/2026, Ο3: E05 CLOSED, device-verified)· εκκρεμότητες μόνο στο `error_list.md`, πρόοδος εδώ στο οριστικό κλείσιμο |
| `error_list.md` | — | **η μοναδική πηγή εκκρεμοτήτων** μέχρι το E26, μετά διαγράφεται |
| `AGENTS.md` | κανόνες 6/9/10 | ✅ **ενημερώθηκε 26/10/2026**: 6 = `error_list.md` (εκκρεμότητες) + `oldsessions.md` (ιστορικό/πρόοδος) · 9 = εκκρεμότητες μόνο στο `error_list.md`, **πρόοδος στο `oldsessions.md` στο οριστικό κλείσιμο** · 10 = 1 κεφάλαιο/φάση |

---

## 6. Ομάδες υλοποίησης (1 ομάδα = 1 πρόταση + 1 fix)

> Κάθε ομάδα δουλεύεται με **μία ενιαία πρόταση** (συνεκτικό σχέδιο, αριθμημένα βήματα) και **ένα fix** — δεν ξανανοίγει σκόρπια. Νέα ευρήματα από fix: πρώτα εξέταση ένταξης σε υπάρχουσα ομάδα, αλλιώς νέο `E<n>` (SOP §Δ16).
> Προτεινόμενη σειρά: **Ο1 ✅ → Ο2 ✅ → Ο4 ✅ → Ο8 ✅ → Ο6 ✅ → Ο5 ✅ → Ο3 ✅ → Ο9 ✅ → Ο7 ✅ (device T1–T8) → Ο10** (+ E07/E09/E06 όποτε αποφασιστούν · E01 parked · E25 κλείνει με E26).

| Ομάδα | Η μία πρόταση | Το ένα fix | Απορροφά |
|---|---|---|---|
| **Ο1 — Scheduler correctness** ✅ CLOSED 21/10/2026 (S270 `c2dc8f2` + device/test) | E10 + E34 + E35 + E36 + E37 (προαιρ. E08, E14) | `reminder_scheduler.dart` + `reminder_text.dart` + `reminder_bake_plan.dart` + `habit_service.dart` + providers/settings + 16 tests | E35–E37 από E10/E34 |
| **Ο2 — Lifecycle (startup/resume/restore)** ✅ CLOSED 22/10/2026 (device-verified) | E16 + E33 + E18-μέρος | `main.dart` + debounce `reminder_scheduler` + `backup_service` + `super_note_helper` + `backup_archive` + cold-start/restore tests | E18: 14/21 sites (υπόλοιπα 7 → Ο6) |
| **Ο3 — Mass-delete pipeline** ✅ CLOSED 27/10/2026 (S277 `a5a40a6` + device T1–T7) | E05 (solo — υψηλό ρίσκο, εξαρτάται από Ο1) | `trash_screen` + `item_provider` + `habit_service` + `super_note_helper` + `reminder_scheduler` (4 batch APIs, 0 νέοι providers/tests) | — |
| **Ο4 — UI consolidation/hardening** ✅ CLOSED 22/10/2026 (S271 `92fdcc6` + device) | E04 + E28 + E12 + E02 (προαιρ. E13, E11) | Sheets + οθόνες (ίδια αρχεία, ένα πέρασμα) + landscape/140% checks | E28/E12/E02 από E04 |
| **Ο8 — Καθολική επιλογή φακέλου** ✅ CLOSED 23/10/2026 (S272, analyze+test) | E38 (solo) | `selectedFolderIdProvider` + Home/7 λίστες/Ημερολόγιο + `folder_picker_dialog` + settings/share cleanup + 3 tests | — |
| **Ο5 — Grid + verify** ✅ CLOSED 26/10/2026 (device-verified, S276) | E27 + E03 + **E44** | `reorderable_item_list` (autoScroll + dragEnabled) + `selectRecentItems` recency + μαζικό device pass (100%/140°) | E03 από E27 · E44 από E19 |
| **Ο6 — Cleanup & visibility sweep** ✅ CLOSED 26/10/2026 (S275, analyze+tests) | E19 + E21 + E14 + E23 | Μηχανικά/αποφάσεις, χωρίς device (+E42 επιτόπου) | E19/E21/E14/E23 από E18 |
| **Ο9 — Restore pipeline** ✅ CLOSED 27/10/2026 (S278 `e96cbc9` + device T1–T9) | E40 (solo — αδελφό του Ο3, ίδια αρχεία) | `trash_screen` + `item_provider` (`restoreMany`) + 1 refresh/topUp/invalidate για όλο το batch | E40 από E05/Ο3 (Α4) |
| **Ο7 — Dates/editor mini-pass** ✅ CLOSED 29/10/2026 (S279 `c16f90d` + device T1–T8) | E22 + E20 | 14 production αρχεία (12 + `ui_provider`/`habit_provider` για `dayTick`) + 5 νέα tests + 2 επεκτάσεις | E20 από E22 |
| **Ο10 — Habit topUp perf** 🔧 κώδικας ✅ 29/10/2026 (S280 + S281/A) · device ⏳ | E45 (solo — `habit_service` + `reminder_scheduler` + `super_note_helper` + `reminder_bake_plan` + Diagnostics) | 1 πρόταση: Φ0 μετρήσεις → Φ1 `createMany` (1 txn) → Φ3 `avgSched`/RUNWAY → Γ7 guard reset → **A: OS-horizon 14ημ. για habits** (`deferredCount`), concurrency **απορρίφθηκε** με μέτρηση | — |

**Ξεχωριστά:** E07 & E09 (features — spec/απόφαση πρώτα) · **E39** (ενιαία κοινοποίηση — spec πρώτα) · E06 (απόφαση splits/χαλάρωση R1) · E01 (parked) · E25 (κλείνει με E26).
