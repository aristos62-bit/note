# SuperNote — Έκθεση Ασφάλειας (v2.3)

**Έκδοση:** v2.4 · 14/11/2026 · **v2.3:** 08/11/2026 · **v2.2:** 06/11/2026 · **v2.1:** 06/11/2026 · **v2:** 05/11/2026 (S294) · **v1:** 05/11/2026
**Βάση ελέγχου:** `2cf7df6` (main), επαληθευμένη ξανά στο `b1bb623` (S295). Η v1 ελέγχθηκε στο `7f4f6f5`· τα commits `6da3ba7`/`e3c9ab3`/`a14a3e6`/`2cf7df6` είναι κώδικας E39 + docs και **δεν** αλλάζουν ευρήματα· από το `2cf7df6` έως το `b1bb623` άλλαξαν μόνο UI/docs (S294/S295) — κανένα security finding δεν άλλαξε.
**Μέθοδος:** ανάγνωση κώδικα, manifest, gradle, installer, git history **και πηγής πακέτων** (`open_filex 4.7.0`, `share_plus 12.0.2`, `archive 4.3.0`). **Καμία** εκτέλεση σε συσκευή σε αυτόν τον κύκλο.

## Σύνοψη

Η SuperNote **δεν έχει απομακρυσμένη επιφάνεια επίθεσης** (καμία άδεια `INTERNET` στο release, κανένας κώδικας δικτύου στο `lib/`), αλλά τα δεδομένα της **δεν είναι κρυπτογραφημένα** και το PIN προστατεύει **μόνο την οθόνη**. Βρέθηκαν **25 ευρήματα: 0 κρίσιμα · 4 υψηλής · 13 μεσαίας · 8 χαμηλής** σοβαρότητας.

Οι πέντε ενέργειες με το μεγαλύτερο όφελος ανά κόστος:

1. **Ασφαλής άνοιγμα αρχείων** (S-16, S-18, S-23, S-25): το `open_filex` στο Windows περνά **unquoted** path σε `cmd /c start` και ο FileProvider του Android δηλώνει `root-path="."`. Μαζί με μη επικυρωμένο `Attachment.localPath` δίνουν **εκτέλεση εντολών (Windows)** και **αυθαίρετη ανάγνωση/διαγραφή/αποστολή** αρχείου. Επιπλέον το `ShellExecuteW` **εκτελεί** `.exe/.bat/.cmd/...` (S-25). Φθηνή διόρθωση, μεγάλο κέρδος.
2. **Fail-closed κλείδωμα** (S-17): ✅ **S300** — gate με cold/resume/retry timeouts· `null`/σφάλμα/timeout ⇒ locked + `FLAG_SECURE(true)`· inline setup όταν `enabled && pinHash == null`.
3. **Μόνιμος μετρητής PIN + μονοτονικός χρόνος** (S-03): ✅ **S302** — persisted `AppLockAttemptsStore`, monotonic `elapsedRealtime` + wall fallback, min-6/όχι τετριμμένο νέο PIN (4-5 μόνο legacy verify), tiers lockout έως 1 ώρα.
4. **Επανάληψη PIN σε κρίσιμες ενέργειες + κρυφές ειδοποιήσεις** (S-04 ✅ **S302** — `confirmSensitiveAction` σε export/import/wipe/disable· S-06), και **μπλοκάρισμα της ζωντανής UI** κάτω από το lock (S-05 ✅ μηχανισμός S300).
5. **Κρυπτογράφηση backup + αφαίρεση hash PIN** (S-02) — είναι το αρχείο που φεύγει από τη συσκευή.

Η κρυπτογράφηση της ίδιας της βάσης (S-01) παραμένει το πιο ουσιαστικό αλλά και το πιο ακριβό μέτρο· περιγράφεται με επιλογές και κόστος.

## Τι άλλαξε σε σχέση με τη v1

| # | Αλλαγή | Λόγος |
|---|---|---|
| 1 | **S-07 διορθώθηκε**: το restore από **zip κάνει rebase** των `localPath` (`p.basename` → `attachments/`, `backup_service.dart:822-833`)· το κενό αφορά **μόνο το raw `.isar`** | Η v1 έλεγε γενικά «δεν γίνεται rebase» — ίσχυε μόνο για μη-zip |
| 2 | **Αφαιρέθηκε το «κανένα προσωρινό αντίγραφο»** από τα θετικά του E39 | Το `share_plus 12.0.2` **αντιγράφει** σε `cache/share_plus/` (`Share.kt:181,239-245`) → νέο S-19 |
| 3 | **Προστέθηκαν 8 ευρήματα**: S-16…S-23 | Δεύτερο πέρασμα σε πηγή πακέτων, merged permissions, fail-open paths, `.gitignore`, Android 12+ |
| 4 | Διορθώθηκαν γραμμές: S-12 `:11→:12` · S-13 `:60-69→:54-88` (υπάρχουν και `text/*`, `image/*`, `video/*`) · gradle `:25,36-40→:24,37` | Line drift |
| 5 | Καταγράφεται ότι `open_filex` είναι **4.7.0** (pubspec `^4.5.0`) και το `share_plus` **12.0.2** | Στοιχεία για S-16/S-19/S-23 |
| 6 | Επιβεβαιώθηκαν ως **καθαρά**: no clipboard usage, no raw `print`, PII redaction σε search/collection/folder logs, zip traversal guard | Να μη θεωρηθούν ανοιχτά |

### Διορθώσεις v2.1 (06/11/2026)

| # | Διόρθωση | Λόγος |
|---|---|---|
| 1 | **S-18**: πλήρης λίστα call sites — προστέθηκαν `super_note_helper.dart:553` (`hardDeleteMany`), `attachments_strip.dart:123,256`, `collection_entries_screen.dart:920,965-971,1630`· διορθώθηκε το `:946 → :951` | Το `hardDeleteMany` σβήνει αρχείο εκτός `attachments/` με μόνο shared-ref έλεγχο — το πιο επικίνδυνο σημείο |
| 2 | **S-19**: διορθώθηκε η διατύπωση — το `clearShareCacheFolder()` **υπάρχει** και στο tag `12.0.2` (`Share.kt:60`) | Το κενό είναι μόνο το **τελευταίο** share (μαζί με backup zip) μέχρι το επόμενο share ή το Wipe |
| 3 | **S-02.4**: ρητή σειρά — **decrypt + GCM tag verify πριν από οποιοδήποτε `Isar.open`**· το legacy plaintext παραμένει αναπόφευκτα unauthenticated | Σήμερα το `_checkIsarInDir` ανοίγει το εξωτερικό αρχείο πριν από κάθε έλεγχο αυθεντικότητας |
| 4 | **P0 βήμα 1** χωρίστηκε σε **1α** (`AttachmentPathGuard`) και **1β** (Windows opener + sanitize) | Το 1α είναι βέβαιο/φθηνό· το 1β επιβεβαιώθηκε πλέον στην πηγή του `open_filex 4.7.0` |

### Διορθώσεις v2.2 (06/11/2026)

| # | Διόρθωση | Λόγος |
|---|---|---|
| 1 | **S-02.3 — auto backup**: αντικαταστάθηκε το «`getApplicationSupportDirectory()/backups`» με πλήρη επανασχεδιασμό: **φάκελος επιλογής χρήστη** (SAF / `Documents/SuperNote`) + **έλεγχος και prompt επαναφοράς στην πρώτη εκκίνηση** (`hasSeenRestorePrompt`, μέσω `importBackup(..., fromPath:)`) | Το `getApplicationSupportDirectory()` **δεν** επιβιώνει από uninstall (το `allowBackup="false"` κλείνει και το cloud restore) — κάλυπτε μόνο το clear-cache· ο χρήστης δεν είχε τρόπο να μάθει ότι υπάρχει αντίγραφο |
| 2 | **P2 βήμα 9**: «auto backup εκτός cache» → «auto backup σε **φάκελο χρήστη** + **first-run prompt**» | Ευθυγράμμιση του πλάνου με το S-02.3 |

### Διορθώσεις v2.3 (08/11/2026)

| # | Διόρθωση | Λόγος |
|---|---|---|
| 1 | **S-25** — νέο εύρημα μεσαίας σοβαρότητας: το άνοιγμα στο Windows περνά στο `ShellExecuteW`, που **εκτελεί** εκτελέσιμους τύπους | Ο S-16/1β αφαίρεσε το `cmd` (injection) αλλά **όχι** την εκτέλεση: `.bat`/`.exe` από backup zip ή share intent εκτελούνταν με ένα tap |
| 2 | **P0 βήμα 1γ** — `isRiskyToLaunch` στον `AttachmentPathGuard` + `ConfirmDialog` + fail-safe `allowRisky` | Ίδιο SPoT με S-18 (μηδέν νέο αρχείο), ρητή επιβεβαίωση αντί σιωπηλής εκτέλεσης |

### Επαληθεύσεις v2.1 (06/11/2026)

- **S-22/S-23** επαληθεύτηκαν στην πηγή `open_filex 4.7.0` (pub cache): permissions στο `android/src/main/AndroidManifest.xml`, `filepaths.xml` με **`root-path="."`** + `external-*`, και `OpenFilePlugin.java:232` (`FileProvider.getUriForFile` χωρίς containment). Το plugin **ζητά** τα permissions runtime (`:142-150`) όταν το path είναι έξω από `dataDir`/`externalFilesDir` (`pathRequiresPermission()`, `:189-203`).
- **S-21** επαληθεύτηκε στα official Android docs: με `targetSdk ≥ 31`, το `allowBackup="false"` **δεν εγγυάται** απενεργοποίηση D2D σε όλα τα OEM· απαιτείται ρητό `<device-transfer>` με excludes (αν **λείπει** το section, το D2D είναι *fully enabled*).
- **targetSdk/compileSdk = 36** (Flutter 3.47.8 defaults), άρα ισχύει το Android 12+ μοντέλο.

## Εύρος και threat model

| Απειλή | Τι μπορεί να κάνει | Σχετικά ευρήματα |
|---|---|---|
| Εσωτερική, από απροσεξία | Χάνει/μοιράζεται backup, αφήνει το app ξεκλείδωτο, πατά «Διαγραφή όλων» | S-02, S-04, S-06, S-19 |
| Εσωτερική, κακόβουλη (γνωστός με φυσική πρόσβαση) | Μαντεύει το PIN, χρησιμοποιεί ξεκλείδωτο τηλέφωνο, διαβάζει ειδοποιήσεις | S-03, S-04, S-05, S-06, S-17 |
| Εξωτερική, τοπική (άλλη εφαρμογή ή κακόβουλο αρχείο) | Στέλνει αρχεία μέσω share, δίνει κατεστραμμένο/κακόβουλο backup, εκμεταλλεύεται όνομα αρχείου, εκτελεί `.exe/.bat` μέσω ShellExecute | S-07, S-08, S-13, S-16, S-18, S-22, S-23, S-25 |
| Εξωτερική, κλοπή ή ανάκτηση συσκευής/δίσκου | Διαβάζει βάση, συνημμένα, backups, cache | S-01, S-02, S-19 |
| Εξωτερική, supply chain (εγκαταστάτης, υπογραφή, repo) | Αντικαθιστά APK/exe, εκμεταλλεύεται δικαιώματα φακέλων, βρίσκει keystore | S-09, S-10, S-14, S-20 |

**Δεν υπάρχει κώδικας δικτύου** (`lib/`: 0 hits σε `HttpClient`/`dio`/`WebView`/`Socket`) και η `INTERNET` υπάρχει **μόνο** στα debug/profile manifests (`android/app/src/{debug,profile}/AndroidManifest.xml`). Άρα απομακρυσμένη εκμετάλλευση δεν είναι εφικτή στο release. Η σοβαρότητα κρίνεται για **προσωπική, μη εμπορική** χρήση· αν το APK ή ο εγκαταστάτης μοιράζεται σε τρίτους, τα S-09/S-10/S-16/S-18 ανεβαίνουν.

---

# Ευρήματα υψηλής σοβαρότητας (4)

## S-01 — Τα δεδομένα δεν είναι κρυπτογραφημένα· το κλείδωμα είναι μόνο οθόνη
- **Πού:** `lib/helpers/super_note_helper.dart:74` (`getApplicationDocumentsDirectory`), `:90-100` (`Isar.open` χωρίς κλειδί) · `lib/main.dart:286-299` (LockScreen ως overlay πάνω στο `child!`).
- **Σενάριο:** όποιος διαβάσει `super_note_db.isar` + `attachments/` βλέπει τα πάντα, με ή χωρίς PIN. Android: sandbox + `allowBackup=false` ⇒ ρίσκο κυρίως root/forensics. **Windows:** η βάση ζει στα **Documents** του χρήστη — την διαβάζει **οποιαδήποτε** διεργασία του ίδιου λογαριασμού (και το `users-full` του S-10 χειροτερεύει).
- **Επιπλέον:** το `appLockPinHash` είναι **μέσα στην ίδια, απλή βάση** (`app_settings.dart:55`) ⇒ offline brute force χωρίς καν backup.
- **Διόρθωση (φθηνή → ακριβή):**
  1. **Windows:** μετακίνηση βάσης/συνημμένων σε `getApplicationSupportDirectory()` (`%APPDATA%`), με migration στο `MigrationService`.
  2. Κλειδί σε `flutter_secure_storage` (Keystore/DPAPI) + κρυπτογράφηση ευαίσθητων πεδίων (χάνεται search/indexes).
  3. Drift + SQLCipher (πλήρης αλλαγή, δεν συνιστάται τώρα).
  4. Αν μείνει προσωπική: **τεκμηρίωση** στο `supernote.md` ότι το PIN = κλείδωμα οθόνης, όχι κρυπτογράφηση.

## S-02 — Backups χωρίς κρυπτογράφηση, με το hash του PIN μέσα
- **Πού:** `backup_archive.dart:40-97` (όλη η βάση + όλα τα συνημμένα σε απλό zip) · `backup_service.dart:194-263` (export σε τοποθεσία επιλογής), `:279-331` (share), `:523-530` (**auto backup σε cache**), `:613-661` (validation μόνο με compressed size).
- **Σενάριο:** το zip φεύγει από το sandbox (Downloads, Drive, email, messenger). Περιέχει `appLockPinHash`, `biometricEnabled`, όλο το περιεχόμενο. Με 4–6 ψηφία και 100.000 iterated SHA-256, το PIN σπάει σε ώρες (CPU) / λιγότερο (GPU). Το auto backup κρατά **5** αντίγραφα σε cache.
- **Διόρθωση:**
  1. **AES-256-GCM** με κωδικό χρήστη: κλειδί από PBKDF2-HMAC-SHA256 (≥210.000) ή Argon2id, salt+IV στο header, magic `SNB2` + version. **Legacy read** για παλιά zip.
  2. **Strip lock fields** από το snapshot πριν το zip: `appLockPinHash=null`, `appLockEnabled=false`, `biometricEnabled=false` (άνοιγμα του snapshot με Isar, ενημέρωση AppSettings(1), close).
  3. **Auto backup — επανασχεδιασμός** (η σημερινή μορφή **δεν** καλύπτει το σενάριο «επανεγκατάσταση»): γράφει σε `getTemporaryDirectory()/SuperNoteBackups` (`:523-530`, retention 5, default **OFF**) ⇒ χάνεται σε uninstall / clear-cache / αλλαγή συσκευής, και **κανείς δεν ελέγχει** για υπάρχοντα αντίγραφα στην πρώτη εκκίνηση· το `lastAutoBackupAt` ζει μέσα στην Isar, άρα μετά από reinstall το UI δείχνει «Ποτέ». Το `onboardingCompleteProvider` (`settings_provider.dart:167`) υπάρχει αλλά **δεν χρησιμοποιείται** και το `completeOnboarding()` (`:101`) **δεν καλείται πουθενά**. **Πρόταση:**
     a. **Φάκελος επιλογής χρήστη** ως προορισμός: SAF `ACTION_OPEN_DOCUMENT_TREE` (Android — **καμία νέα άδεια**, μόνο persisted URI) / `Documents/SuperNote` (Windows)· retention 5 και εκεί. Το `getApplicationSupportDirectory()` **δεν αρκεί**: ούτε αυτό επιβιώνει από uninstall (`allowBackup="false"`, S-21, κλείνει και το cloud restore) — καλύπτει μόνο το clear-cache.
     b. **Έλεγχος στην πρώτη εκκίνηση**: scan του φακέλου για `*.zip`, λίστα με ημερομηνίες, prompt «Βρέθηκαν αντίγραφα ασφαλείας — θέλεις επαναφορά;» (Επαναφορά / Όχι τώρα / Ποτέ), μέσω του υπάρχοντος `importBackup(..., fromPath:)` (η deep validation υπάρχει ήδη).
     c. **Νέο flag** π.χ. `hasSeenRestorePrompt` (Isar + `MigrationService` bump)· **όχι** το `hasCompletedOnboarding` — είναι νεκρό (δεν γίνεται ποτέ `true`) και θα προκαλούσε prompt σε **κάθε** launch.
     d. **Προϋπόθεση:** ο φάκελος είναι δημόσιος, άρα το βήμα (1) AES-GCM πρέπει να έχει προηγηθεί (ή ρητή συγκατάθεση) — αλλιώς βγάζουμε ακρυπτογράφητο zip **με το hash του PIN** (βλ. Σενάριο) σε κοινόχρηστο χώρο.
     e. **Επιπτώσεις:** διπλό I/O + διπλός χώρος (5 × μέγεθος), νέα εξάρτηση για SAF, και τα persisted URI permissions **χάνονται στο uninstall** ⇒ ο χρήστης ξαναδιαλέγει φάκελο μία φορά.
  4. (Με το 1) το GCM δίνει και **integrity** — σήμερα δεν υπάρχει κανένα MAC/υπογραφή. **Υποχρεωτική σειρά:** decrypt + **tag verify** πριν από **οποιοδήποτε** `Isar.open` (σήμερα το `_checkIsarInDir`, `:550-600`, ανοίγει το εξωτερικό αρχείο πριν από κάθε έλεγχο)· το legacy plaintext παραμένει αναπόφευκτα unauthenticated — ρητή προειδοποίηση/επιβεβαίωση ή κατάργηση· το `restoreBackup()` (`:362`) να μην δέχεται μη επικυρωμένο αρχείο.

## S-03 — Το PIN αντέχει ελάχιστα σε brute force ✅ **ΥΛΟΠΟΙΗΘΗΚΕ S302**
- **Πού:** `lock_screen.dart:21-22` (`_failedAttempts`, `_lockoutUntil` = widget state), `:118-122` (`DateTime.now()`), `:150-157` · `app_lock_service.dart:15-20` (cap 300s), `:23-27` (`DateTime` diff) · PIN 4-6 ψηφία: `lock_screen.dart:41`, `settings_pin_dialogs.dart:13-17`.
- **Σενάριο:** kill από recents → άνοιγμα → **4 δωρεάν προσπάθειες** → lockout 30s· επανάληψη. Αλλαγή ώρας συστήματος παρακάμπτει lockout **και** auto-lock timeout. Το ελάχιστο 4 ψηφία δίνει 10⁴ συνδυασμούς.
- **Διόρθωση (S302):**
  1. Νέα πεδία `AppSettings`: `appLockFailedAttempts`, `appLockLockoutUntilEpochMs`, `appLockLockoutDurationSeconds`, `appLockLockoutMonoMs`, `appLockLastSeenWallMs` + schema **v4** (`_v3ToV4` sanitize-only) — Isar auto-migration (additive).
  2. **Μονοτονικός χρόνος:** `elapsedRealtimeMs()` μέσω του υπάρχοντος `super_note/security` channel + anchor `appLockLockoutMonoMs`· wall fallback· `now < lastSeenWallMs` (ρολόι πίσω) ⇒ fail-closed (πλήρης διάρκεια).
  3. Ελάχιστο **6** ψηφία για νέο PIN + μπλοκάρισμα τετριμμένων (`isWeakPin`: all-same, διαδοχικά, επαναλαμβανόμενο block). 4-5 μόνο legacy verify.
  4. Μετά από 10 αποτυχίες: **όχι** μόνιμος αποκλεισμός — μεγάλο lockout (tiers έως 1 ώρα) + βιομετρική διαφυγή (bypass + reset).
- **Κατάσταση:** `AppLockAttemptsStore` (`appLockAttemptsStoreProvider`) = μία πύλη `snapshot`/`verify`/`finishSuccess`· `LockScreen` δουλεύει από persisted snapshot (επιβιώνει kill/unlock)· unlock-first + best-effort reset/hash-upgrade. Tests: `lock_security_test`, `lockout_store_test`, `lock_screen_test` (**613/613** τότε — σήμερα **620/620**). **Device-verified 08/11/2026 (POCO X3):** lockout 30s μετά 5 αποτυχίες + επιβίωση μετά `force-stop`/relaunch (30→22s), FLAG_SECURE + 0-byte screencap, min-6/weak/mismatch, legacy 4ψήφιο verify.
- **Αποδοχή:** kill+reopen δεν μηδενίζει το lockout· αλλαγή ρολογιού δεν το λύνει· tests για `nextLockoutSeconds` + persistence.

## S-16 — Πιθανή εκτέλεση εντολών στο Windows μέσω `open_filex` **(ΝΕΟ v2)**
- **Πού:** `open_filex-4.7.0/lib/src/platform/open_filex.dart:23` → `Process.start('cmd', ['/c', 'start', '', filePath])` **χωρίς quotes**· `string_utils.dart:221-238` (`sanitizeFileName` **δεν** αφαιρεί `& % ^ ! ( )`)· κλήση: `attachment_service.dart:197` (`open` — **μοναδικό** σημείο ανοίγματος μετά το R5).
- **Σενάριο:** αρχείο με `&` στο όνομα (π.χ. `a&calc.exe`) → `cmd` κόβει στο `&` και εκτελεί το δεύτερο τμήμα. Ο χρήστης αρκεί να πατήσει «άνοιγμα» σε συνημμένο. Το ίδιο μονοπάτι δέχεται και `localPath` από κακόβουλο raw `.isar` (S-18).
- **Διόρθωση (ΥΛΟΠΟΙΗΘΗΚΕ — 1β, S298):** στο `lib/` (όχι patch του πακέτου): `AttachmentService.open()` — `if (Platform.isWindows) launchUrl(Uri.file(safePath), mode: LaunchMode.externalApplication)` (Windows plugin → `ShellExecuteW`, **χωρίς** command line), αλλιώς `OpenFilex.open`· πάντα μετά από `AttachmentPathGuard` (S-18). **Η απαίτηση sanitize (`& % ^ ! ( ) ' " ; ,`) αφαιρέθηκε ως περιττή:** το `cmd` δεν καλείται πλέον· το `Uri.file` κάνει percent-encoding (space, `%`, `#`, ελληνικά) και το plugin κάνει `UrlUnescapeA` πριν το `ShellExecuteW`.
- **Αποδοχή:** `test/attachment_open_test.dart` (guard/λείπει/φάκελος → `attachNotFound`, χωρίς platform call) + 2 widget tests στο `attachments_strip_test.dart`· Windows manual test με `&`/`%`/space/ελληνικά στο όνομα· `grep` για `cmd`/`Process.` → 0.

---

# Ευρήματα μεσαίας σοβαρότητας (13)

| ID | Εύρημα | Πού (HEAD) | Διόρθωση |
|---|---|---|---|
| S-04 | Κρίσιμες ενέργειες χωρίς PIN: **απενεργοποίηση lock**, export/share backup, restore, «Διαγραφή όλων» (η αλλαγή PIN ζητά) | `settings_screen.dart:242-246` · `settings_backup.dart:14-80, 87-206, 238-420` | ✅ **ΥΛΟΠΟΙΗΘΗΚΕ S302** (+ **Device-verified 08/11/2026** POCO X3: export gate πριν το dialog, disable gate): `confirmSensitiveAction` (βιομετρικό → PIN, bypass lockout)· gate **πριν** από dialogs/file picker σε export/import/wipe (`settings_backup.dart`) και disable (`settings_app_lock_section.dart`)· fail-closed σε αδυναμία ανάγνωσης· PIN με inline lockout (`AppLockAttemptsStore`) |
| S-05 | Η UI «ζει» κάτω από το lock: accessibility service και hardware keyboard φτάνουν στο περιεχόμενο | `main.dart:286-299` | ✅ **Μηχανισμός S300**: `IgnorePointer` + `ExcludeSemantics` + `ExcludeFocus` γύρω από το `child!` όταν `appContentBlockedProvider` (διατήρηση state). Device-verified 07/11/2026 (POCO X3) |
| S-06 | Ειδοποιήσεις δείχνουν τίτλο στην κλειδωμένη οθόνη (κανένα `visibility`)· το payload είναι σωστά μόνο id | `notification_service.dart:451-469` | ✅ **ΥΛΟΠΟΙΗΘΗΚΕ S309** (+ **Device-verified 14/11/2026** POCO X3 — dumpsys `--noredact`: `android.title=(Υπενθύμιση)`, `android.text=(Σημείωση)`· με OFF `android.text=(<πραγματικός τίτλος>)`): **masking στο OS** — `hideNotificationContent` (default ON, schema v6) ⇒ `discreet` ⇒ title «Υπενθύμιση» + body `ItemTypeX.labelGr`· η DB κρατά πάντα πραγματικό κείμενο· `visibility: private` παραμένει ως 2ο επίπεδο (`publicVersion` **δεν** υπάρχει στο plugin 17.2.4, και με `lock_screen_allow_private_notifications=1` το `private` **δεν** αρκεί) |
| S-07 | Επαναφορά = πλήρης αντικατάσταση: **PIN/lock από το backup**, χωρίς authenticity. **Διόρθωση v1:** το zip **κάνει** rebase· το κενό αφορά **raw `.isar`** | `backup_service.dart:582-596` (μόνο `AppSettings(1)`), `:822-833` (rebase zip), `:836-838` (**χωρίς** rebase raw isar), `:752-838` (atomic restore) | Διατήρηση **τοπικών** lock ρυθμίσεων μετά το restore· απόρριψη `localPath` εκτός `attachmentsDir`· προαιρετικά MAC (βλ. S-02.4) |
| S-08 | Zip bomb / μνήμη: `archive 4.3.0`, `readAsBytes` + `decodeBytes`, guard **μόνο** συμπιεσμένου μεγέθους (500 MB)· το traversal/symlink **είναι** καλυμμένο (`extract_archive_to_disk.dart:108-125`) | `pubspec.lock:20-27` · `backup_archive.dart:100-142` · `backup_service.dart:80, 613-661` | `archive ≥4.5` + όρια εξόδου (έλεγχος API πριν το edit), allowlist entries (`super_note_db.isar`, `attachments/*`), per-entry & total output limit, μείωση `maxRestoreBytes` |
| S-09 | Release APK με **debug key** και `applicationId=com.example.super_note` | `android/app/build.gradle.kts:24, 33-38` | Release keystore εκτός repo + `key.properties` (S-20), σταθερό δικό σας `applicationId` (νέα εγκατάσταση + μεταφορά με backup) |
| S-10 | Εγκαταστάτης Windows: `users-full` σε app/data, χωρίς code signing, `vc_redist.x64.exe` + `SuperNoteSetup.exe` **committed** | `note_eco_new.iss:54-56` · `Dependencies/`, `InstallerOutput/` | Αφαίρεση `users-full`, SignTool, hash ελέγχου, binaries σε Releases (όχι git) |
| S-17 | **Fail-open κλείδωμα**: αν το `settings.get()` πετά/timeout (5s) στο startup ή στο resume, συνεχίζει **ξεκλείδωτο** και **χωρίς** `FLAG_SECURE` **(ΝΕΟ v2)** | `main.dart:125-129` (pre-runApp), `:393-410` (resume) — **πριν** το S300 | ✅ **ΥΛΟΠΟΙΗΘΗΚΕ S300**: `LockGateController`/`lockGateProvider` (`app_lock_provider.dart`) + `lock_gate_screen.dart`· `getOrNull()` (ποτέ default `AppSettings()`)· cold 5s / resume 2s / retry 5s· `setSecure(true)` σε unknown/failure· retry + inline setup PIN. Device-verified 07/11/2026 (POCO X3) |
| S-18 | **Μη επικυρωμένο `Attachment.localPath`**: ανάγνωση (thumbnail/fullscreen/save), **διαγραφή** αρχείου, αποστολή μέσω share — πέρα από το άνοιγμα **(ΝΕΟ v2)** | **Διαγραφή:** `super_note_helper.dart:553` (**`hardDeleteMany`** — μόνο shared-ref guard), `attachment_service.dart:159` · **Ανάγνωση/projection:** `attachments_strip.dart:158,245`, `collection_entries_screen.dart:1558-1579`, `image_utils.dart:39` (`Image.file`) · **Save:** `collection_entries_screen.dart:907-919` (`readAsBytes`) · **Share:** `services/share/share_attachments.dart:47` (`collect`, χωρίς `isWithin`) · **Άνοιγμα:** `attachment_service.dart:181` (`open` — μοναδικό σημείο) | **Ένας** helper `AttachmentPathGuard.resolve(a)` → path μόνο αν `p.isWithin(attachmentsDir, p.normalize(path))`· χρήση σε **όλα** τα παραπάνω (αλλιώς placeholder/άρνηση)· cached sync root για τα widgets (το `getApplicationDocumentsDirectory` είναι async)· προαιρετικά `resolveSymbolicLinks()` για symlink/junction (το `isWithin` είναι lexical — case-insensitive στο Windows) |
| S-25 | **Εκτελέσιμο συνημμένο εκτελείται με ένα tap (Windows)**: το `open` περνά κάθε path στο `ShellExecuteW` (verb `open` → `run` για `.exe/.bat/.cmd/.ps1/.lnk/...`), ακόμη κι αν προήλθε από backup zip ή share intent **(ΝΕΟ v2.3)** | `attachment_service.dart:188-191` (risky check), `:197-206` (Windows `launchUrl` → ShellExecuteW) · `url_launcher_windows-3.1.5/windows/url_launcher_plugin.cpp:117` → `system_apis.cpp:31-34` (`::ShellExecuteW`) · `attachments_strip.dart:128-165` (μοναδικό UI entry `openAttachment`) · `backup_service.dart:816` (restore: κάθε αρχείο του zip στο `attachments/`) | ✅ **S303:** `AttachmentPathGuard.isRiskyToLaunch()` — pure, denylist `launchRiskExtensions`, μόνο basename, κόβει ADS (`evil.exe::$DATA`) + τελικές τελείες/κενά, Windows-only · `ConfirmDialog` (`AppErrors.attachRisky*`) στο `openAttachment` + fail-safe `allowRisky: true` στο `open()` · tests 7 (5 guard + 1 service + 1 widget). Όρια: macOS/Linux extensions, Office macros, denylist όχι πλήρης |
| S-19 | **Απομεινάρια cache**: το `share_plus` αντιγράφει κάθε αρχείο σε `cache/share_plus/`· **καθαρίζει στην αρχή** κάθε share (`12.0.2 Share.kt:60`, main `13.x Share.kt:119`), άρα μένει μόνο το **τελευταίο** share — μαζί με ολόκληρο backup zip — μέχρι το επόμενο share ή το Wipe· pickers/intent αφήνουν temp αντίγραφα **(ΝΕΟ v2, διόρθωση v2.1)** | `share_plus-12.0.2/.../Share.kt:60,181,239-245` · `share_service.dart:96-101` (χωρίς cleanup) · `backup_service.dart:307-317` (καθαρίζει μόνο τον temp φάκελο) | **Delayed** cleanup των συγκεκριμένων αρχείων μετά το share (όχι άμεσο `finally` — ο παραλήπτης μπορεί να τα διαβάζει ακόμη, βλ. 10s του backup temp)· καθαρισμός temp των pickers μετά το `saveFile`· (το Wipe ήδη σβήνει όλο το cache — `settings_backup.dart:492-503`) |
| S-22 | **Υπερ-δικαιώματα από merge**: το `open_filex 4.7.0` προσθέτει `READ_MEDIA_IMAGES/VIDEO/AUDIO` + `READ_EXTERNAL_STORAGE (≤32)` ενώ η εφαρμογή ανοίγει **μόνο** δικά της αρχεία **(ΝΕΟ v2, επιβεβαιωμένο v2.1)** | `open_filex-4.7.0/android/src/main/AndroidManifest.xml` (merged στο release — χωρίς `tools:node="remove"` στο app manifest) · `OpenFilePlugin.java:142-150` (τα **ζητά** runtime εκτός app dirs), `:189-203` (`pathRequiresPermission`) | `xmlns:tools` + `tools:node="remove"` για τα 4 permissions (**ΥΛΟΠΟΙΗΘΗΚΕ S299** — merged release: 0 `READ_MEDIA_*`/`READ_EXTERNAL_STORAGE`)· επαλήθευση merged manifest πριν το release· τα συνημμένα είναι εντός `dataDir` ⇒ δεν ενεργοποιείται το permission path |
| S-23 | **FileProvider `root-path="."`**: το `open_filex` μπορεί να δώσει `content://` για **οποιοδήποτε** readable path (και `external-*`), με grant σε εξωτερική εφαρμογή **(ΝΕΟ v2, επιβεβαιωμένο v2.1)** | `open_filex-4.7.0/android/src/main/res/xml/filepaths.xml` (`root-path`, `external-*`, `files`, `cache`) · `OpenFilePlugin.java:232` (`getUriForFile` χωρίς containment)· provider `exported=false` + `grantUriPermissions=true` · Android 11+ gate: `MANAGE_EXTERNAL_STORAGE` εκτός MediaStore paths (`:135-138,168-187`) — **δεν** δηλώνεται | Με τον S-18 guard δεν φτάνει ποτέ path εκτός `attachments/`· εναλλακτικά αντικατάσταση με δικό μας στενό FileProvider ή copy-to-cache + `share_plus`. Σε chain με S-18/S-22 (granted `READ_MEDIA_*`) καλύπτει και media εκτός app dirs |

**⚠️ Ενημέρωση v2.4 (S-307, 14/11/2026) — S-08:** ο πίνακας περιγράφει το snapshot `b1bb623` (πριν το S-307). Σήμερα το zip create/extract είναι **streaming** (`ZipFileEncoder` / `ZipDecoder().decodeStream` + `ArchiveFile.writeContent`) με **allowlist** entries και **μηδέν όρια μεγέθους** — Δ3: αφαιρέθηκαν `maxRestoreBytes`/`maxDialogBytes`/`defaultMaxPlaintextBytes` (βλ. `supernote.md` §BackupService). Άρα: (α) `readAsBytes`/`decodeBytes` **δεν** υπάρχουν πλέον, (β) το «guard 500 MB» και η σύσταση «μείωση `maxRestoreBytes`» **δεν ισχύουν**, (γ) `archive` παραμένει **4.3.0** — η αναβάθμιση ≥4.5 μένει **προαιρετική**. Υπολειπόμενος κίνδυνος: πλήρωση **δίσκου** (όχι RAM) από κακόβουλο zip — μετριάζεται μερικώς από τον έλεγχο free space της εξαγωγής.

---

# Ευρήματα χαμηλής σοβαρότητας (8)

| ID | Εύρημα | Πού | Διόρθωση |
|---|---|---|---|
| S-11 | `DebugConfig.error`/`warning` γράφουν **πάντα** σε release (paths, exceptions, stack traces)· το `link_text` λογάρει **raw URL**· σχόλιο `_debug` παραπλανητικό | `debug_config.dart:26, 101-109` · `link_text.dart:43` | `if (!kDebugMode) return;` σε error/warning· redact URL· διόρθωση σχολίου. *(Τα titles/queries είναι ήδη redacted — επιβεβαιώθηκε.)* |
| S-12 | Δηλώνεται `WRITE_CONTACTS`, ο κώδικας ζητά **μόνο** `PermissionType.read` **(ΥΛΟΠΟΙΗΘΗΚΕ S299)** | `android/app/src/main/AndroidManifest.xml:12` · `contact_import_service.dart:70-77` | Αφαίρεση της άδειας + έλεγχος merged manifest |
| S-13 | Το share intent δέχεται `*/*` και με `maxAttachmentSizeMB ≤ 0` **δεν** υπάρχει όριο· ίδιο σε collection entries· το shared κείμενο δεν έχει όριο | `AndroidManifest.xml:54-88` · `shared_intent_service.dart:298-300, 386-388` · `collection_entries_screen.dart:863` | Σκληρό cap (π.χ. 50 MB) ακόμη και στο 0· όριο κειμένου· ονόματα ήδη sanitized |
| S-14 | PII/artifacts στο δημόσιο repo: **148** tracked αρχεία `backups/`, `Dependencies/VC_redist.x64.exe`, `InstallerOutput/SuperNoteSetup.exe`, `.bat`/`.iss` με τοπικά paths, placeholder `AppPublisherURL` | `git ls-files`, `note_eco_new.iss:10`, `build_and_setup_new 2.bat` | ✅ **ΥΛΟΠΟΙΗΘΗΚΕ S310** (δεδομένα: repo **public** επιβεβαιωμένο μέσω GitHub API): `git rm --cached` σε **151** αρχεία (148 snapshots κώδικα — **καμία** βάση/συνημμένο/αρχείο χρήστη — + 2 binaries + 1 build artifact) ⇒ tracked **596 → 445**· νέοι κανόνες `/backups/`, `/InstallerOutput/`, `/Dependencies/`, `/android/build/` (τα αρχεία **μένουν** τοπικά)· paths: `%~dp0` στο `.bat` + `{#SourcePath}` στο `.iss` (ISCC compile **exit 0**)· URLs → GitHub repo/issues/releases, αφαίρεση ψευδούς `AppContact`· 0 εμφανίσεις ονόματος χρήστη/προσωπικών δεδομένων σε tracked αρχεία. **Υπολειπόμενο:** τα blobs ζουν σε παλιά commits (history **δεν** ξαναγράφηκε — απόφαση χρήστη: προαιρετικό `filter-repo` + force-push, repo 122 MB → ~40 MB) |
| S-15 | PIN KDF: iterated SHA-256 (100k), legacy **unsalted** SHA-256 αποδεκτό· το iteration count διαβάζεται από το hash | `app_lock_service.dart:12, 36-60, 63-71` | PBKDF2-HMAC-SHA256 ≥210k ή Argon2id, νέο prefix `v2$`, διατήρηση `v1$`/legacy verify, σταδιακή αφαίρεση legacy |
| S-20 | `.gitignore` **δεν** καλύπτει `key.properties`, `*.jks`, `*.keystore`, `*.p12`, `.env` **(ΝΕΟ v2)** | `.gitignore` | ✅ **ΥΛΟΠΟΙΗΘΗΚΕ S310**: προστέθηκαν `key.properties`, `*.jks`, `*.keystore`, `*.p12`, `.env`, `.env.*` (κατηγορία «μυστικά/κλειδιά») — **πριν** το S-09, ώστε να μη commitαριστεί ποτέ keystore. Επιβεβαίωση: κανένα από αυτά δεν είναι tracked |
| S-21 | Λείπει `android:dataExtractionRules`/`fullBackupContent` (Android 12+ D2D)· το `allowBackup="false"` καλύπτει το **cloud**, αλλά σε ορισμένα OEM **δεν** απενεργοποιεί το D2D· `FLAG_SECURE` **μόνο Android** (Windows/macOS screenshots & taskbar previews ακάλυπτα) **(ΝΕΟ v2, επιβεβαιωμένο v2.1)** | `AndroidManifest.xml:18` (μόνο `allowBackup=false`) · `security_service.dart` (no-op εκτός Android) · official docs: autobackup + Android 12 behavior changes | `dataExtractionRules` με **ρηστό** `<device-transfer><exclude domain="root" path="."/></device-transfer>` (αν λείπει το section → fully enabled)· τεκμηρίωση limitation· προαιρετικά `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` στα Windows |
| S-24 | **Μη-ατομικό toggle lock** **(ΥΛΟΠΟΙΗΘΗΚΕ S301)**: το `SecurityService.setSecure(v)` + `AppLockService.lock()` εκτελούνται ακόμη κι αν το write των settings αποτύχει· το `SettingsNotifier.updateSettings` **καταπίνει** το σφάλμα | `settings_screen.dart:233-251` · `settings_provider.dart:61-68` | ✅ **S301:** `SettingsRepository.update` = atomic read-modify-write μέσα σε ένα `writeTxn` και επιστρέφει το **committed** snapshot· `SettingsNotifier.updateSettings` → `Future<AppSettings?>` (`null` = αποτυχία, `invalidateSelf` μόνο σε επιτυχία)· νέο `SettingsAppLockSection` (`settings_app_lock_section.dart`) με busy-guard + maintenance pre-check· security effects **μόνο** μετά από επιτυχές commit μέσω `LockGateController.applySettings(snapshot)` (χωρίς 2η ανάγνωση DB, χωρίς `resolving` flash)· αποτυχία ⇒ snackbar + αναλλοίωτη κατάσταση. Tests: `test/settings_app_lock_section_test.dart` (7) |

---

# Πλάνο υλοποίησης (ιεραρχημένο: πρώτα τα πιο σοβαρά)

Κάθε βήμα γίνεται με τους κανόνες του `AGENTS.md`: **backup στο `backups/`**, πλήρες παλιό/νέο block, **ένα βήμα τη φορά**, `flutter analyze` + tests, device όπου απαιτείται.

| Φάση | # | Ενέργεια | Ευρήματα | Κόστος | Ρίσκο παλινδρόμησης |
|---|---|---|---|---|---|
| **P0 — Άμεσα** | **1α** | **AttachmentPathGuard**: `isWithin` σε open/share/delete/save/thumb — **μαζί** με `hardDeleteMany` (`super_note_helper.dart:553`) | S-18, S-23 (μερικώς) | Μικρό (1 helper + 9 call sites) | Χαμηλό· tests για path εντός/εκτός, `..`, case, symlink |
| | **1β** | **Windows opener χωρίς `cmd`** (`launchUrl(Uri.file)` → `ShellExecuteW`) — ✅ S298· **χωρίς** αλλαγή `sanitizeFileName` (περιττή: δεν υπάρχει πλέον `cmd`) | S-16 | Μικρό | Χαμηλό· Windows test με `&`/`^`/space |
| | **1γ** | **Εκτελέσιμοι τύποι (Windows)**: `isRiskyToLaunch` (denylist, ADS-aware) + `ConfirmDialog` + fail-safe `allowRisky` στο `open()` — ✅ S303 | S-25 | Μικρό | Πολύ χαμηλό· μόνο Windows, dialog πριν το launch |
| | 2 | **Fail-closed lock**: gate μέχρι να διαβαστούν ρυθμίσεις· `setSecure(true)` σε άγνωστη κατάσταση· retry — ✅ S300 | S-17 | Μικρό | Χαμηλό (startup UX) |
| | 3 | **Permissions**: αφαίρεση `READ_MEDIA_*`, `READ_EXTERNAL_STORAGE`, `WRITE_CONTACTS` + merged-manifest check — ✅ S299 | S-22, S-12 | Μικρό | Πολύ χαμηλό |
| **P1 — Κλείδωμα** | 4 | **PIN hardening**: persistent counter + monotonic + min 6 + trivial block + migration bump — ✅ S302 | S-03 | Μικρό-μέτριο | Χαμηλό· migration test |
| | 5 | **PIN gate** σε toggle-off/export/restore/wipe — ✅ S302 | S-04 | Μικρό | Χαμηλό |
| | 6 | **Lock UI**: `IgnorePointer`+`ExcludeSemantics`+`ExcludeFocus` όταν locked — ✅ S300 | S-05 | Μικρό | Χαμηλό (focus/state) |
| | 7 | **Notifications**: masking OS κειμένου (title «Υπενθύμιση» + τύπος item) + toggle «Απόκρυψη περιεχομένου» + `visibility: private` — ✅ S309 | S-06 | Μικρό | Χαμηλό |
| | 8 | **Logs**: guard error/warning, redact URL | S-11 | Πολύ μικρό | Πολύ χαμηλό |
| **P2 — Δεδομένα που φεύγουν** | 9 | **Backup encryption** (AES-256-GCM + PBKDF2) + legacy read + strip lock fields + **auto backup σε φάκελο χρήστη + first-run prompt** + **tag verify πριν το `Isar.open`** | S-02 | Μέτριο | Μέτριο· tests παλιών zip + restore· SAF/permissions ανά πλατφόρμα |
| | 10 | **Cache cleanup** μετά το share (**delayed**) + picker temp | S-19 | Μικρό | Χαμηλό |
| | 11 | **Archive ≥4.5** + output limits + entry allowlist + χαμηλότερο `maxRestoreBytes` *(v2.4: δεν ισχύει — S-307 streaming/allowlist, μηδέν caps)* | S-08 | Μικρό-μέτριο | Μέτριο (restore E33) |
| **P3 — Release & repo** | 12 | **Keystore + applicationId** + `.gitignore` (**`.gitignore` ✅ S310/S-20**· keystore/applicationId = S-09 ανοιχτό) | S-09, S-20 | Μέτριο (διαδικαστικό) | Νέα εγκατάσταση + μεταφορά |
| | 13 | **Installer**: ACL, SignTool, hashes, binaries εκτός git | S-10 | Μέτριο | Χαμηλό |
| | 14 | **Repo cleanup**: untrack `backups/`, `Dependencies/`, `InstallerOutput/`, παραμετροποίηση paths — ✅ S310 | S-14 | Μικρό | Χαμηλό (history παραμένει) |
| | 15 | **Share limits** (hard cap + text cap) | S-13 | Μικρό | Χαμηλό |
| | 16 | **KDF v2** (PBKDF2/Argon2) + κλιμάκωση | S-15 | Μικρό | Χαμηλό (legacy verify) |
| | 17 | **Android 12+ extraction rules** + τεκμηρίωση FLAG_SECURE scope | S-21 | Μικρό | Πολύ χαμηλό |
| **P4 — Απόφαση** | 18 | **Κρυπτογράφηση βάσης**: (1) Windows path, (2) field encryption, (3) SQLCipher, ή (4) τεκμηρίωση limitation | S-01 | Μικρό → πολύ μεγάλο | Υψηλό για (2)/(3) |

**Κατάσταση υλοποίησης:** έχουν υλοποιηθεί τα P0 βήματα **1α**, **1β** (S298), **1γ/S-25** (S303), **2/S-17** (S300) και **3/S-22/S-12** (S299), τα P1 βήματα **4/S-03** + **5/S-04** (S302), **6/S-05** (S300) και **7/S-06** (S309, masking OS κειμένου + toggle «Απόκρυψη περιεχομένου»), καθώς και το **S-24** (S301, ατομικό toggle lock) και τα **S-14/S-20** (S310, repo hygiene: untrack 151 αρχείων + relative paths εγκαταστάτη + `.gitignore` για keystore). Το παρόν παραμένει η έκθεση v2.3 + πλάνο για τα υπόλοιπα.

---

# Τι ήδη λειτουργεί σωστά (επιβεβαιωμένο)

- **Καμία απομακρυσμένη επιφάνεια:** χωρίς `INTERNET` στο release, χωρίς κώδικα δικτύου· `allowBackup=false`· receivers `exported=false`· `MainActivity` exported μόνο για LAUNCHER/SEND.
- **`FLAG_SECURE`** όταν υπάρχει κλείδωμα (`MainActivity.kt:14-27`, `security_service.dart`) — recents/screenshots κενά (Android).
- **PIN:** salt 16B, iterated SHA-256, **constant-time** compare, αλλαγή PIN ζητά το τρέχον· legacy hash αναβαθμίζεται μόνο μετά από επιτυχές verify.
- **Pre-runApp lock:** ✅ S300 — το πρώτο καρέ είναι ήδη gate/LockScreen (`main.dart:125-129`)· καμία διαδρομή δεν αφήνει περιεχόμενο ορατό σε fail path (gate failure UI + `FLAG_SECURE(true)`).
- **Zip ασφάλεια:** path traversal/symlink φιλτράρονται (`archive 4.3.0`, `_isWithinOutputPath`)· allowlist de facto (db + attachments)· atomic restore με safety copy + rollback.
- **PII redaction:** titles/queries/ονόματα/διαδρομές περνούν από `AppStringUtils.redact` (search, collection, folder, contacts, attachments)· **κανένα** raw `print(`· **καμία** χρήση clipboard.
- **Share (E39):** όρια 20 αρχείων/100 MB/100.000 χαρ., re-entrancy guard, `context.mounted` μετά από await, text-only fallback, μόνο http/https links.
- **Ειδοποιήσεις:** payload = **μόνο** ακέραιο id, ελέγχεται (`main.dart:63-98`)· το κείμενο προς το OS είναι masked («Υπενθύμιση» + τύπος item) όσο είναι ON το «Απόκρυψη περιεχομένου» (S309).
- **Συνημμένα:** `sanitizeFileName` + timestamp prefix· dedupe ανά item· DB-first διαγραφή.
- **Wipe:** διαγράφει βάση, συνημμένα, restore leftovers, migration snapshots **και όλο το cache** (άρα και auto backups + share copies).
- **Δεν βρέθηκαν** κλειδιά, κωδικοί ή tokens στο repo.

# Περιορισμοί & εκκρεμείς επαληθεύσεις

- Η έκθεση βασίζεται σε **ανάγνωση** κώδικα/πακέτων, όχι δυναμικό έλεγχο.
- **S-16** χρειάζεται επιβεβαίωση σε Windows build (εκτέλεση με δοκιμαστικό `&`).
- **S-19** επιβεβαιώθηκε από την πηγή του πακέτου (και στο tag `12.0.2`): το `cache/share_plus/` καθαρίζεται στην **αρχή** κάθε share· μένει μόνο το τελευταίο. Χρειάζεται device test μόνο για το αν αρκεί το επόμενο share/Wipe ως cleanup.
- **S-18/S-23** χρειάζονται device test: restore raw `.isar` με `localPath` εκτός `attachments/` και απόπειρα open/share/delete/save/thumb.
- **S-09/S-10:** αν το APK/exe διανεμηθεί σε τρίτους, η σοβαρότητα ανεβαίνει.
- **S-21** είναι OEM-dependent (D2D): το cloud καλύπτεται από `allowBackup=false`· το D2D χρειάζεται test σε πραγματική μεταφορά (π.χ. Pixel/Samsung) μετά την προσθήκη `dataExtractionRules`.
- **iOS:** υπάρχουν `NSContactsUsageDescription` + `NSFaceIDUsageDescription`, αλλά **λείπουν** `NSPhotoLibraryUsageDescription`/`NSCameraUsageDescription` για `image_picker` (crash, όχι κενό ασφάλειας)· iOS παραμένει parked.
- **Backups:** 148 tracked αρχεία στο repo (S-14) περιέχουν παλιό κώδικα/docs — όχι δεδομένα χρήστη, αλλά παραμένουν δημόσια.
