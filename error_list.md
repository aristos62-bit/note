# error_list.md — Η ΜΟΝΑΔΙΚΗ λίστα εκκρεμοτήτων (**1 ανοιχτό**)

> **Επαναδημιουργήθηκε 16/11/2026 (S321)** — νέο εύρημα `E53` (κανόνες 6/9 `AGENTS.md`).
> Βάση: `backups/s319_e51_20261115_214150/error_list.md.final` (0 ανοιχτά, 15/11/2026).
> **Ιστορικό/πρόοδος:** `oldsessions.md` (ενημερώνεται **μόνο** στο οριστικό κλείσιμο). **Αρχιτεκτονική:** `supernote.md`.
> **Παράλληλες λίστες εκκρεμοτήτων απαγορεύονται.**

**SOP (σύντομο):** κάρτα + όλος ο σχετικός κώδικας + side effects → πρόταση με εναλλακτικές/ρίσκα → **OK χρήστη** → backup στο `backups/s<session>_<id>/` → υλοποίηση → `flutter analyze` (+ `flutter test`) → device test (κανόνας 12) → ενημέρωση λίστας **μόνο** στο οριστικό κλείσιμο (αφαίρεση ID, κάρτα → CLOSED, 1 bullet) → commit + push με το ID.

**Προτεραιότητα:** ① **P1 = σφάλματα** που επιφέρουν μεγάλα λάθη στην εφαρμογή · ② **P2 = βελτιώσεις λειτουργιών** που ήδη υπάρχουν · ③ **P3 = μελλοντικές προσθήκες/αναβαθμίσεις** + δομική καθαριότητα.

---

## 0. Baseline (16/11/2026, μετά το S320 — S-13)

| Μέτρηση | Τιμή |
|---|---|
| Git HEAD | `3028eb7` (S-13) + `d4a8bc6` (`chore(release): bump 1.3.0+6`) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **736/736 PASS** |
| Device pass | **S320 Android** (POCO X3 `9593c01e`, `device-test/s320/`) — 6 σενάρια S-13/S-13b/S-13c |

---

## 1. Ιεράρχηση — 3 κατηγορίες

### 🔴 P1 — Σφάλματα (1)

- **`E53`** — `receive_sharing_intent` 1.9.0: native crash + σιωπηλές απώλειες στο εισερχόμενο share (βλ. κάρτα §2).

### 🟠 P2 — Βελτιώσεις λειτουργιών (0)

> Κανένα ανοιχτό.

### 🔵 P3 — Μελλοντικές προσθήκες / αναβαθμίσεις + καθαριότητα (0)

> Κανένα ανοιχτό.

**P4 — By-design / αποδεκτά (καμία ενέργεια)**
- **Χρώμα συλλογής στην αρχική / λίστα φακέλου** = χρώμα **τύπου**, όχι το custom `item.color` (απόφαση χρήστη S294).
- **Rotation max 5 αυτόματων αντιγράφων** σβήνει τα παλαιότερα (`BackupRotation`) — by design.
- iOS parked ×2 · `custom:184` stale σημείωση · contact-dialog chrome 7.3px (debug-only) · stale write-only Isar slots στο `item.g.dart`.
- **E50-B** (SAF/εξωτερικός προορισμός auto backups) · **E50-C** (iOS path) — χωρίς ID.
- **macOS/Linux προστασία περιεχομένου = no-op** (`MissingPlugin`) — **S-318** στο `security_v2.md`.
- **W8 Reminder:** η εγγραφή S-21 στα docs αναφέρει «φίλτρα, όχι DRM» — in-process hooks/drivers παρακάμπτουν.
- **Alt+Tab / Task View με lock ON:** το preview δείχνει ζωντανό περιεχόμενο **στην οθόνη** (DWM, όχι capture API)· τα capture APIs παραμένουν κλειστά (`E52`).
- **`shared_intent_service.dart` 588 γραμμές** (>500): προϋπάρχον· το split (pure helpers + cache cleanup) προγραμματίζεται ως ξεχωριστή φάση καθαριότητας, όχι μαζί με το `E53`.
- **`isDuplicate` με κενό `path`** (2ο unreadable share <2s): τεκμηριωμένος περιορισμός — το sheet του 1ου είναι ήδη ανοιχτό.
- **Orphan `cacheDir/intake_*`** αν σκοτωθεί η εφαρμογή πριν το save: bounded (100 MB)· age-based sweep = μελλοντική φάση (δεν μπαίνει στο `sweepStaleArtifacts`, που τρέχει **πριν** το `SharedIntentService.init()`).

---

## 2. Κάρτες εκκρεμοτήτων (στοιχεία + απόδειξη + αποδοχή)

### `E53` — `receive_sharing_intent`: crash στο main thread + σιωπηλή απώλεια αρχείων (P1)

| Πεδίο | Στοιχείο |
|---|---|
| **Πηγή** | `receive_sharing_intent-1.9.0` (τελευταία έκδοση στο pub) — 3 native/Dart ευπάθειες |
| **Απόδειξη** | `FileDirectory.kt:123` `openInputStream` χωρίς try/catch → `SecurityException` (content:// χωρίς grant) = crash· `:39-43` ExternalStorageProvider επιστρέφει εξωτερική διαδρομή **χωρίς copy** (η εφαρμογή δεν έχει storage permission) → path ως κείμενο/`missing`· `:104` `File(cacheDir, displayName)` χωρίς sanitize (path traversal + crash με `/`)· `:128` path ακόμη κι αν δεν γράφτηκε τίποτα· `ReceiveSharingIntentPlugin.kt:141-152` `path ?: text` (χάνει το `EXTRA_TEXT` με stream) + `path: null` → Dart `TypeError` (`shared_media_file.dart:34`)· `:155-169` `MediaMetadataRetriever` χωρίς try/catch/`release()` + orphan `.png` (κανείς δεν τα καθαρίζει)· μηδέν όριο μεγέθους (copy πριν τα όρια S-13) |
| **Απόδειξη (device)** | S320: crash αναπαράχθηκε με `content://` χωρίς grant· τα tests έγιναν με `file://` |
| **Λύση** | Vendored fork `packages/receive_sharing_intent/` + `dependency_overrides`: copy-through-resolver (πάντα, με per-intent φάκελο + sanitize + ceiling 100 MB/αρχείο + 100 MB/intent + διαγραφή partial), nullable record με `error` code, αφαίρεση thumbnail/duration, tolerant `fromMap`, `InboundContent.unreadable` + `AppErrors.shareIntakeUnreadable` + inline προειδοποίηση |
| **Αποδοχή** | `flutter analyze` No issues · tests πράσινα · device: **κανένα crash** με content:// χωρίς grant, μήνυμα «Δεν ήταν δυνατή η ανάγνωση του αρχείου», S-320 regression OK |
| **Κατάσταση** | **ΑΝΟΙΧΤΟ** |

---

## 3. Κλειστά & επαληθευμένα

> **Ιστορικό:** `oldsessions.md` + `backups/s293_e06_close/error_list.md.final` (E01–E47) + `backups/e48_filtered_empty_20261105_180802/error_list.md.final` (E48) + `backups/s305_e50_20261113_142733/error_list.md.final` (E49, E50) + `backups/s319_e51_20261115_214150/error_list.md.final` (E51, Ο13, E52).
> **S304/S305:** `E49` ✅ CLOSED · `E50` ✅ CLOSED & DEVICE-VERIFIED.
> **S317:** `E52` ✅ CLOSED (περιορισμός) · S-21 Φ2 Windows ✅ CLOSED.
> **S319:** `E51` ✅ CLOSED & DEVICE-VERIFIED · `Ο13` ✅ κλειστή · 721/721 · `1.2.1+5`.
> **S320:** **S-13** ✅ CLOSED & DEVICE-VERIFIED (όρια + clamp + S-13b/S-13c) · 736/736 · `1.3.0+6`.

---

## 6. Ομάδες υλοποίησης (1 ομάδα = 1 πρόταση + 1 fix)

| Ομάδα | Η μία πρόταση | Το ένα fix | Απορροφά |
|---|---|---|---|
| **Ο15 — Inbound share hardening** (S321) | fork του plugin + error contract + μήνυμα | `packages/receive_sharing_intent/` + `inbound_share.dart` + `shared_intent_service.dart` + `shared_intent_sheet.dart` | **E53** |
| **Ο16 — Split `shared_intent_service.dart`** (μελλοντικό) | εξαγωγή pure helpers + cache cleanup σε SPoTs | `lib/services/share/` | — |
