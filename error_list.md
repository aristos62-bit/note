# error_list.md — Η ΜΟΝΑΔΙΚΗ λίστα εκκρεμοτήτων (2 ανοιχτά)

> **Επαναδημιουργήθηκε 13/11/2026 (S304)** λόγω 2 νέων ευρημάτων μετά το S-02 (κανόνες 6/9 `AGENTS.md`). Βάση: `backups/e48_filtered_empty_20261105_180802/error_list.md.final` (E01–E48, όλα CLOSED).
> **Ιστορικό/πρόοδος:** `oldsessions.md` (ενημερώνεται **μόνο** στο οριστικό κλείσιμο). **Αρχιτεκτονική:** `supernote.md`.
> **Παράλληλες λίστες εκκρεμοτήτων απαγορεύονται.**

**SOP (σύντομο):** κάρτα + όλος ο σχετικός κώδικας + side effects → πρόταση με εναλλακτικές/ρίσκα → **OK χρήστη** → backup στο `backups/s<session>_<id>/` → **ένα βήμα τη φορά** → `flutter analyze` (+ `flutter test` στο τέλος) → device test (κανόνας 12: πρώτα ρητή λίστα δεδομένων από τον χρήστη, **ποτέ** δεδομένα μέσω adb) → ενημέρωση λίστας **μόνο** στο οριστικό κλείσιμο (αφαίρεση ID, κάρτα → CLOSED, 1 bullet) → commit + push με το ID.

**Προτεραιότητα:** ① **P1 = σφάλματα** που επιφέρουν μεγάλα λάθη στην εφαρμογή · ② **P2 = βελτιώσεις λειτουργιών** που ήδη υπάρχουν · ③ **P3 = μελλοντικές προσθήκες/αναβαθμίσεις** + δομική καθαριότητα.

---

## 0. Baseline (13/11/2026, μετά το S-02 / S304)

| Μέτρηση | Τιμή |
|---|---|
| Git HEAD | `2092eab` (S-02 committed + pushed στο `main`) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **649/649 PASS** (620 + 29 νέα/ενημερωμένα του S-02 συνολικά στα 4 αρχεία backup) |
| Device pass | **S-02 OK** (POCO X3 `9593c01e`, release APK: export/import `.snb`, λάθος κωδικός, strip lock, round-trip συνημμένου, auto-backup + interval 24h, D8 gate) |

---

## 1. Ιεράρχηση — 3 κατηγορίες

### 🔴 P1 — Σφάλματα (0)

> Κανένα ανοιχτό.

### 🟠 P2 — Βελτιώσεις λειτουργιών (0)

> Κανένα ανοιχτό.

### 🔵 P3 — Μελλοντικές προσθήκες / αναβαθμίσεις + καθαριότητα (2)

> `E49` (stale «Τελευταίο:» στο tile auto-backup) · `E50` (auto-backups στο cache dir).

**P4 — By-design / αποδεκτά (καμία ενέργεια)**
- **Χρώμα συλλογής στην αρχική / λίστα φακέλου** = χρώμα **τύπου** (`home_screen.dart:862-863`, `home_folder_view.dart:451-452`), όχι το custom `item.color` που δείχνει η καρτέλα Συλλογές (`collections_screen.dart:294`). Αποδεκτό προσωρινά (απόφαση χρήστη S294).
- **Rotation max 5 αυτόματων αντιγράφων** σβήνει τα παλαιότερα (`BackupRotation`, `_maxAutoBackups`) — by design, αλλά σε συνδυασμό με το `E50` χρειάζεται προσοχή.
- iOS parked ×2 · `custom:184` stale σημείωση · contact-dialog chrome 7.3px (debug-only) · stale write-only Isar slots στο `item.g.dart` (κλείνει με επόμενο codegen).

---

## 2. Κάρτες εκκρεμοτήτων (στοιχεία + απόδειξη + αποδοχή)

### E49 — «Τελευταίο:» στο tile auto-backup μένει stale ως το restart — 🔵 **OPEN (P3)**

- **Απόδειξη (S304, POCO X3):** μετά από auto-backup στις 11:01 και 13:01 η λίστα έδειχνε τα νέα `auto_*.snb`, αλλά το subtitle έλεγε ακόμη «Τελευταίο: 8 Νοε 2026, 20:57»· μετά από `force-stop` + relaunch → «Τελευταίο: 13 Νοε 2026, 13:01». Άρα **η DB είναι σωστή**, μόνο το UI μένει πίσω.
- **Αιτία:** `BackupService.autoBackup()` γράφει απευθείας `SuperNoteHelper.instance.settings.update((s) => s.lastAutoBackupAt = DateTime.now())` (`backup_service.dart:545-547`), ενώ το `SettingsNotifier.build()` διαβάζει **μία φορά** (`settings_provider.dart:50` — `ref.watch(dbProvider).settings.get()`, χωρίς stream/invalidate). Προϋπάρχον (υπήρχε και με τα `.zip`), **όχι** regression του S-02.
- **Πρόταση (προς έγκριση):** στο `main.dart:407` αλυσίδωση `unawaited(BackupService.instance.autoBackup().then((_) => container.invalidate(settingsNotifierProvider)))` — μία επιπλέον ανάγνωση settings ανά pause. Εναλλακτικές: invalidate στο `resumed` (πιο συχνό) ή `SettingsNotifier` να ακούει stream από τη DB (μεγαλύτερη αλλαγή).
- **Side effects ελέγχθηκαν:** `container` υπάρχει ήδη στο `main.dart`· το invalidate δεν αγγίζει DB/αρχεία· κανένα άλλο σημείο δεν διαβάζει `lastAutoBackupAt`.

### E50 — Τα auto-backups ζουν στο cache dir (μπορεί να σβηστούν από OS/«Εκκαθάριση cache») — 🔵 **OPEN (P3)**

- **Απόδειξη (S304):** `_getAutoBackupDir()` = `getTemporaryDirectory()/SuperNoteBackups` (`backup_service.dart:572-579`) → `/data/user/0/com.example.super_note/cache/...`. Μη προσβάσιμο από `adb` (release non-debuggable, χωρίς root) ⇒ δεν μπόρεσα να διαγράψω το test `auto_*.snb`· ο χρήστης μπορεί να χάσει **όλα** τα αυτόματα αντίγραφα με «Εκκαθάριση cache» ή purge υπό πίεση χώρου.
- **Αιτία/ιστορικό:** προϋπάρχουσα επιλογή τοποθεσίας (πριν το S-02)· το S-02 διατήρησε τον ίδιο φάκελο για συμβατότητα με τα legacy `.zip`.
- **Πρόταση (προς έγκριση):** `getApplicationSupportDirectory()` για τα **νέα** `.snb` + ανάγνωση/εμφάνιση και του παλιού cache dir για 1 έκδοση (D4 pattern), ώστε να μη χαθούν τα υπάρχοντα· μετά sweep. Εναλλακτική: ρητή προειδοποίηση στο UI.
- **Side effects ελέγχθηκαν:** `BackupRotation.list` δέχεται dir parameter· `_getAutoBackupDir` χρησιμοποιείται σε auto-backup + rotation + λίστα· τα temp artifacts (export/restore) **παραμένουν** στο cache (σωστό).

---

## 3. Κλειστά & επαληθευμένα

> **Ιστορικό:** `oldsessions.md` + `backups/s293_e06_close/error_list.md.final` (E01–E47) + `backups/e48_filtered_empty_20261105_180802/error_list.md.final` (E48).
> **S295:** `E48` **CLOSED & DEVICE-VERIFIED** — filter-aware empty states σε 8 λίστες + λίστα φακέλου + compact calendar panel· 6 νέα tests.
> **S303/S-25 & S-02 (S304):** χωρίς ID — εγκρίθηκαν ως features/fixes από τον χρήστη· S-02 **device-verified** (βλ. `oldsessions.md` «Session 304 — S-02», ενότητα Device tests).

---

## 6. Ομάδες υλοποίησης (1 ομάδα = 1 πρόταση + 1 fix)

| Ομάδα | Η μία πρόταση | Το ένα fix | Απορροφά |
|---|---|---|---|
| **Ο11 — Φίλτρο λιστών** (✅ έκλεισε S295 με το E48) | απόφαση scope → **filter-aware empties** (χωρίς αλλαγή state) | `empty_state.dart` (`EmptyState.filtered` + `FilterAwareEmptyState`) + τα 8 screens + λίστα φακέλου + compact panel | **E48** (solo) |
| **Ο12 — Auto-backup hardening** (ανοιχτή) | E50: `getApplicationSupportDirectory()` + ανάγνωση παλιού cache dir για 1 έκδοση | E49: invalidate `settingsNotifierProvider` μετά το `autoBackup()` | **E49 + E50** |
