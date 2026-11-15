# error_list.md — Η ΜΟΝΑΔΙΚΗ λίστα εκκρεμοτήτων (2 ανοιχτά)

> **Επαναδημιουργήθηκε 15/11/2026 (S317)** λόγω νέου ευρήματος μετά το S305 (**0 ανοιχτά** τότε).
> Βάση: `backups/s305_e50_20261113_142733/error_list.md.final` (κανόνες 6/9 `AGENTS.md`).
> **Ιστορικό/πρόοδος:** `oldsessions.md` (ενημερώνεται **μόνο** στο οριστικό κλείσιμο). **Αρχιτεκτονική:** `supernote.md`.
> **Παράλληλες λίστες εκκρεμοτήτων απαγορεύονται.**

**SOP (σύντομο):** κάρτα + όλος ο σχετικός κώδικας + side effects → πρόταση με εναλλακτικές/ρίσκα → **OK χρήστη** → backup στο `backups/s<session>_<id>/` → **ένα βήμα τη φορά** → `flutter analyze` (+ `flutter test` στο τέλος) → device test (κανόνας 12) → ενημέρωση λίστας **μόνο** στο οριστικό κλείσιμο (αφαίρεση ID, κάρτα → CLOSED, 1 bullet) → commit + push με το ID.

**Προτεραιότητα:** ① **P1 = σφάλματα** που επιφέρουν μεγάλα λάθη στην εφαρμογή · ② **P2 = βελτιώσεις λειτουργιών** που ήδη υπάρχουν · ③ **P3 = μελλοντικές προσθήκες/αναβαθμίσεις** + δομική καθαριότητα.

---

## 0. Baseline (15/11/2026, μετά το S317 — S-21 Φ2)

| Μέτρηση | Τιμή |
|---|---|
| Git HEAD | `11f6787` (S317 docs: W3/W6 evidence + περιστατικό PIN, pushed στο `main`) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **717/717 PASS** |
| Device pass | **S317 Windows 11 25H2** (W2–W7, W9, W10/W11 — `device-test/s317_windows/summary.md`) · **S317 Android regression** (POCO X3 `9593c01e`, `device-test/s317_android/summary.md`) |

---

## 1. Ιεράρχηση — 3 κατηγορίες

### 🔴 P1 — Σφάλματα (0)

> Κανένα ανοιχτό.

### 🟠 P2 — Βελτιώσεις λειτουργιών (2)

| ID | Τίτλος |
|---|---|
| **E51** | Ενεργοποίηση κλειδώματος με υπάρχον `appLockPinHash` **δεν** ζητά νέο PIN (παραπλανητικό· ο χρήστης νομίζει ότι όρισε νέο) |
| **E52** | Windows S-21: αναφορά χρήστη ότι το **Alt+Tab / Task View thumbnail** δείχνει περιεχόμενο με lock ON (**προς επιβεβαίωση** — δεν αναπαράχθηκε εργαλειακά) |

### 🔵 P3 — Μελλοντικές προσθήκες / αναβαθμίσεις + καθαριότητα (0)

> Κανένα ανοιχτό.

**P4 — By-design / αποδεκτά (καμία ενέργεια)**
- **Χρώμα συλλογής στην αρχική / λίστα φακέλου** = χρώμα **τύπου** (`home_screen.dart:862-863`, `home_folder_view.dart:451-452`), όχι το custom `item.color` της καρτέλας Συλλογές (`collections_screen.dart:294`). Αποδεκτό προσωρινά (απόφαση χρήστη S294).
- **Rotation max 5 αυτόματων αντιγράφων** σβήνει τα παλαιότερα (`BackupRotation`, `BackupService.maxAutoBackups`) — by design (ένα συνολικό όριο).
- iOS parked ×2 · `custom:184` stale σημείωση · contact-dialog chrome 7.3px (debug-only) · stale write-only Isar slots στο `item.g.dart`.
- **E50-B** (SAF/εξωτερικός προορισμός auto backups) · **E50-C** (iOS path) — χωρίς ID.
- **macOS/Linux προστασία περιεχομένου = no-op** (`MissingPlugin`) — ακολουθείται ως **S-318** στο `security_v2.md`, όχι ως κάρτα εδώ.
- **W8 Reminder:** η εγγραφή S-21 στα docs αναφέρει «φίλτρα, όχι DRM» — in-process hooks/drivers παρακάμπτουν.

---

## 2. Κάρτες εκκρεμοτήτων (στοιχεία + απόδειξη + αποδοχή)

### E51 — Enable app-lock με υπάρχον PIN hash δεν ζητά νέο PIN

- **Απόδειξη (S317, Windows, 15/11/2026):** ο χρήστης ενεργοποίησε το κλείδωμα και έδωσε νέο PIN (`150962`), αλλά η εφαρμογή απέρριπτε το νέο PIN· στη βάση βρέθηκαν `appLockEnabled=true`, `appLockPinHash != null` (6ψήφιο από παλιότερη συνεδρία), `appLockFailedAttempts=3`. Επαναφορά έγινε χειροκίνητα (backup `backups/s317_lockreset_20261115_203731/`) — βλ. `oldsessions.md` S317 «Περιστατικό PIN».
- **Αιτία:** `lib/features/settings/settings_app_lock_section.dart:87` → dialog ορίσμου PIN **μόνο** όταν `appLockPinHash == null`· αλλιώς κρατά το παλιό hash. Το ίδιο μοτίβο στο `:120` («Αλλαγή PIN» υπάρχει, αλλά δεν προτείνεται στο enable).
- **Πρόταση (καμία αλλαγή κώδικα ακόμη):** στο enable, αν `pinHash != null` → dialog με ρητή επιλογή **«Όρισε νέο PIN» / «Χρήση υπάρχοντος»** (default: νέο)· εναλλακτικά πάντα dialog ορίσμου. **Side effects προς έλεγχο:** `appLockPinLength`, `appLockFailedAttempts`/lockout reset, `LockGateController.applySettings` (S-17), βιομετρικό path, tests του `settings_app_lock_section`.
- **Κατάσταση:** ⏳ ανοιχτό (απόφαση χρήστη S317: καταγραφή).

### E52 — Alt+Tab / Task View thumbnail με lock ON (Windows)

- **Απόδειξη (S317, χειροκίνητη παρατήρηση χρήστη):** με lock ενεργό, το thumbnail του SuperNote στο Alt+Tab / Task View έδειχνε **περιεχόμενο**. Δεν αναπαράχθηκε εργαλειακά· τα εργαλειακά probes έδειξαν `0x11` σταθερό, PrintWindow κενό και πραγματικό screen capture χωρίς την εφαρμογή (W3).
- **Γιατί μετράει:** η τεκμηρίωση `SetWindowDisplayAffinity` λέει για `WDA_EXCLUDEFROMCAPTURE` «The window is displayed only on a monitor. Everywhere else, the window does not appear at all» — άρα thumbnail με περιεχόμενο θα ήταν **διαρροή** του app-lock περιεχομένου.
- **Πιθανές αιτίες προς έλεγχο:** (α) η δοκιμή έγινε με lock **OFF** (η εφαρμογή έμεινε ανοιχτή μετά το W6) · (β) η εφαρμογή ήταν η **παλιά εγκατεστημένη** έκδοση (χωρίς S317) · (γ) όντως το DWM thumbnail δεν εφαρμόζει την affinity σε αυτό το build (26100).
- **Επόμενο βήμα (προτεινόμενο):** επανέλεγχος με καθαρή ακολουθία (lock ON → Alt+Tab) και capture της οθόνης κατά την ώρα που ο switcher είναι ανοιχτός· αν επιβεβαιωθεί → νέα πρόταση (πιθανές κατευθύνσεις: `WDA_MONITOR`, έλεγχος DWM, τεκμηρίωση περιορισμού).
- **Κατάσταση:** ⏳ ανοιχτό (προς επιβεβαίωση).

---

## 3. Κλειστά & επαληθευμένα

> **Ιστορικό:** `oldsessions.md` + `backups/s293_e06_close/error_list.md.final` (E01–E47) + `backups/e48_filtered_empty_20261105_180802/error_list.md.final` (E48) + `backups/s305_e50_20261113_142733/error_list.md.final` (E49, E50).
> **S304/S305:** `E49` ✅ CLOSED · `E50` ✅ CLOSED & DEVICE-VERIFIED.
> **S317 (χωρίς E-ID, security):** S-21 Φ2 **Windows ✅ CLOSED** — `WDA_EXCLUDEFROMCAPTURE` fail-closed + live toggle ON/OFF, device-verified (W3/W6/W9)· Android regression OK· macOS/Linux = **S-318**. Διορθώθηκε bug parsing του `{'secure': bool}` (commit `18b2d7c`).

---

## 6. Ομάδες υλοποίησης (1 ομάδα = 1 πρόταση + 1 fix)

| Ομάδα | Η μία πρόταση | Το ένα fix | Απορροφά |
|---|---|---|---|
| **Ο13 — App-lock setup UX** (⏳ ανοιχτή) | enable ⇒ ρητή επιλογή «νέο PIN» / «υπάρχον» | `settings_app_lock_section.dart` + dialog | **E51** |
| **Ο14 — Windows capture parity** (⏳ προς επιβεβαίωση) | επανέλεγχος Alt+Tab/Task View με lock ON | (αν επιβεβαιωθεί) στρατηγική affinity | **E52** |
