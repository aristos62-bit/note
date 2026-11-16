# `receive_sharing_intent` — SuperNote fork (S321 / E53)

Vendored αντίγραφο του `receive_sharing_intent` **1.9.0** (τελευταία έκδοση στο
pub.dev) με διορθώσεις για το εισερχόμενο share. Δεν είναι ανεξάρτητο πακέτο
προς δημοσίευση: φορτώνεται με `dependency_overrides` από το root `pubspec.yaml`.

```
dependency_overrides:
  receive_sharing_intent:
    path: packages/receive_sharing_intent
```

## Γιατί fork

Το upstream `content://` μονοπάτι είχε τρεις κατηγορίες προβλημάτων:

1. **Crash στο main thread** — `FileDirectory.kt` καλούσε `openInputStream`
   χωρίς `try/catch`: `content://` χωρίς grant → `SecurityException` → crash
   της εφαρμογής (αναπαράχθηκε σε POCO X3, S320).
2. **Σιωπηλή απώλεια αρχείων** — για `ExternalStorageProvider` επέστρεφε την
   εξωτερική διαδρομή **χωρίς αντίγραφο**· η εφαρμογή δεν έχει storage
   permissions (by design) → το path δεν διαβαζόταν ποτέ. Επίσης
   `path ?: text` πετούσε το `EXTRA_TEXT` όταν υπήρχε και stream, και ένα
   `path: null` προκαλούσε `TypeError` στο Dart (`fromMap`).
3. **Χωρίς όρια / χωρίς καθαρισμό** — `File(cacheDir, displayName)` χωρίς
   sanitize (path traversal, crash με `/`), μηδέν όριο μεγέθους, orphan
   thumbnail `.png` από `MediaMetadataRetriever` (χωρίς `release()`).

## Τι άλλαξε (πλήρης λίστα)

### `android/.../FileDirectory.kt` (ουσιαστικά re-written)

- **Πάντα** copy των `content://` μέσω `ContentResolver` σε
  `<cacheDir>/intake_<timestamp>_<n>/<sanitized name>` (per-intent φάκελος).
- `file://` = passthrough **μόνο** αν το αρχείο υπάρχει, αλλιώς `unreadable`.
- `CopyBudget` ανά intent: `SEND_MULTIPLE` μοιράζεται ένα budget.
- Όρια: `MAX_FILE_BYTES = 100 MB` / `MAX_TOTAL_BYTES = 100 MB` (streaming,
  διακοπή μόλις ξεπεραστούν — δεν γεμίζει ο δίσκος).
- Sanitize ονόματος (mirror του `AppStringUtils.sanitizeFileName`): αφαίρεση
  διαχωριστικών/μη-έγκυρων χαρακτήρων, όχι control chars, όχι τελείες/κενά στο
  τέλος, cap 100 χαρακτήρες με διατήρηση επέκτασης.
- Fallback όνομα από mime type (`IMG_<ts>.<ext>` / `VID_…` / `FILE_…`).
- Σε κάθε αποτυχία: διαγραφή partial αρχείου/φακέλου, επιστροφή error code.
- **Καμία εξαίρεση δεν βγαίνει** από το `getAbsolutePath` (try/catch παντού).

### `android/.../ReceiveSharingIntentPlugin.kt`

- Το record περιέχει πλέον `"error": "unreadable" | "tooLarge"` όταν η εγγραφή
  απορρίφθηκε (με `path = ""`), ώστε το Dart να εξηγεί στον χρήστη τι χάθηκε.
- `EXTRA_TEXT` → `"message"` όταν συνυπάρχει stream (δεν χάνεται πια).
- Αφαίρεση thumbnail/duration (`MediaMetadataRetriever`): η εφαρμογή δεν τα
  χρησιμοποιεί ποτέ, κόστιζαν main-thread χρόνο και άφηναν orphan PNG.
- `handleIntent` σε `try/catch` (upstream crash path).
- `parcelable()` / `parcelableArrayList()` tolerant: λάθος τύπος extra → `null`
  αντί για crash.
- Pure text (χωρίς stream) κρατά την upstream σημασιολογία (`path = text`,
  `type = text`) — το `isDuplicate` key `type:path` δεν αλλάζει.

### `lib/src/data/shared_media_file.dart`

- Νέο `SharedMediaIntakeError { unreadable, tooLarge }` + πεδίο `intakeError`.
- `fromMap` tolerant: `path` null → `''`, άγνωστο `type` → `file`
  (upstream: `TypeError` / `StateError`).
- `toMap` γράφει `error` μόνο όταν υπάρχει.

### `android/.../IntakeLog.kt` (νέο)

- Το μοναδικό native logging gate: γράφει **μόνο** σε `FLAG_DEBUGGABLE` builds
  και **ποτέ** paths/ονόματα αρχείων (S-11 parity).

## Σταθερές που ΠΡΕΠΕΙ να μένουν συγχρονισμένες

| Kotlin (fork) | Dart (εφαρμογή) |
|---|---|
| `FileDirectory.MAX_FILE_BYTES` (100 MB) | `AppSettings.maxAttachmentCeilingMB` |
| `FileDirectory.MAX_TOTAL_BYTES` (100 MB) | `ShareLimits.maxTotalBytes` |
| `FileDirectory.INTAKE_DIR_PREFIX = "intake_"` | `InboundShare.intakeDirPrefix` |
| `INTAKE_ERROR_UNREADABLE` / `INTAKE_ERROR_TOO_LARGE` | `SharedMediaIntakeError` |
| `MediaType` values | `SharedMediaType` |

## Τι **δεν** άλλαξε (σκόπιμα)

- `android/build.gradle` / Gradle plugin versions: το fork δηλώνει AGP 9.2.1
  στο buildscript αλλά το root project επιβάλλει 8.11.1 / Kotlin 2.2.20 /
  `compileSdk 36`. Μην τα «διορθώσεις» — σπάει το build της εφαρμογής.
- `ios/` και το Dart API surface (`ReceiveSharingIntent`, `getInitialMedia`,
  `getMediaStream`, `reset`) — καμία αλλαγή για τους consumers.
- `example/` δεν αντιγράφηκε (20 αρχεία / ~107 KB, δεν χρειάζεται).
- `test/` του plugin αντιγράφηκε ως έχει (2 tests: `toMap`/`fromMap`
  roundtrip + mock channels). Τρέχονται ξεχωριστά:
  `dart test packages/receive_sharing_intent` (δεν είναι στο app suite).

## Sync με upstream

1. `flutter pub upgrade receive_sharing_intent` σε καθαρό temp project ή κατέβασε
   το νέο tarball από pub.dev.
2. `diff -ru <upstream> packages/receive_sharing_intent` και **επανεφάρμοσε**
   τα patches των 3 αρχείων (`FileDirectory.kt`,
   `ReceiveSharingIntentPlugin.kt`, `shared_media_file.dart`) — μην κάνεις
   overwrite το fork.
3. Ενημέρωσε την έκδοση βάσης στον τίτλο αυτού του αρχείου + `CHANGELOG` του
   fork αν χρειάζεται.
4. `flutter pub get` → `dart analyze packages/receive_sharing_intent` →
   `flutter build apk --release` (το Kotlin ελέγχεται μόνο στο build).
5. Device test: `content://` χωρίς grant (ACTION_VIEW) = **κανένα crash** +
   μήνυμα «Δεν ήταν δυνατή η ανάγνωση του αρχείου».

## Αναφορά

- Upstream πηγή: `~/.pub-cache/hosted/pub.dev/receive_sharing_intent-1.9.0/`
- Εύρημα/απόδειξη: `error_list.md` → `E53` · `oldsessions.md` → Session 321.
- Backups πριν την αλλαγή: `backups/s321_plugin_fork_20261116/`.
