# Φ4 — Οδηγός διόρθωσης ποιότητας σελίδων (τελικός, δεσμευτικός)

> Σκοπός: διόρθωση κακογραμμένων/πρόχειρων σελίδων. Κανένα αρχείο >500 γραμμές.
> Μέθοδος: ένα βήμα τη φορά, backup πριν κάθε edit, OK χρήστη πριν το επόμενο (AGENTS.md 2-4).
> Βάση: πλήρη αρχεία τελευταίας έκδοσης (όχι αποσπάσματα) + grep επαλήθευση σε όλο `lib/`.

## 0. Σύγκριση προτάσεων (γιατί αυτή είναι η τελική)

| Θέμα | v1 | v2 | v3 | Τελική Φ4 (αυτή) |
|---|---|---|---|---|
| SheetHandle 11 αντίγραφα | νέο | extract | extract | extract από `confirm_dialog:230` |
| ItemActions διπλό private | νέο | προαγωγή | προαγωγή | προαγωγή (`item_list:302`≡`embedded:469`) |
| Weekdays 4 ορισμοί | νέο αρχείο | extension | extension | extension `AppDateUtils` |
| SafeParse | νέα κλάση | κατάργηση | κατάργηση | κατάργηση — υπάρχουν `parseHex/tryParse/safeDay` |
| Labels 3 πηγές | — | `labelFor` | `labelFor` | SPoT=`ItemTypeIcon.labelFor:72-88`, delegate το `AppStringUtils`, διαγραφή `item_list:_labelForType:116` |
| ViewMode διπλό | — | reuse | reuse | reuse `ViewModeToggle:1-88`, `red/amber/green→cError/cWarning/cSuccess` |
| Skeleton custom | — | reuse | reuse | reuse `ItemCardSkeleton:596-641` |
| Tags custom journal | — | shared | shared | διαγραφή journal custom ~100γρ, `showTagPickerSheet` |
| Diagnostics sort | bug | bug | κρατάμε | κρατάμε (null πρώτα = ανάδειξη starved) + label |
| Phones σχήμα | reuse παντού | reuse παντού | compat πρώτα | compat πρώτα: `contact_detail:135 List<String>` vs `share:218 p['number']` — fix share να δέχεται και τα 2, μετά `ContactProps` |
| Folder state διπλό | — | — | — | ΝΕΟ v4: `selectedFolderId:folder_provider:41` vs `homeSelectedFolder:ui_provider:6` → ενοποίηση |
| Notification route | — | — | — | ΝΕΟ v4: `main:76-85` ίδιο bug με search — κοινός `AppRoutes.forType` |
| SharedIntent loop | — | — | — | ΝΕΟ v4: `saveAsNote:277-298`≡`saveAsEvent:389-414` → `_saveAttachments` (το `_resolveFolder` μένει duplicate σκόπιμα, headless) |
| Import N+1 | — | — | — | ΝΕΟ v4: `contact_import:218-236` → batch |
| Debounce | magics | magics | magics | τυποποίηση: `AppDuration.debounceSearch 300ms/content 500ms/title 800ms` |
| Reminder fields | — | — | — | ΝΕΟ v4: `reminder_section:493,580 TextFormField` → `ContentFieldWidget` |
| ItemCard icons | — | reuse | reuse | διαγραφή `_ItemTypeIcon:546-590` → `ItemTypeIcon.iconDataFor`, `_PriorityChip._icon:419` → `PriorityBadge.iconFor` |

Διορθωμένες παρανοήσεις: `ReorderHandle`≠sheet handle· `StreamProvider counts→FutureProvider`· `select((v)=>v)` no-op διαγραφή· `helper:393 NOT cancel` παλιό σχόλιο (το `item_provider:227-230` ήδη κάνει cancel)· νέο compressor dep απορρίπτεται (αρκεί `1024/85+ResizeImage`).

## 1. Κανόνες Φ4 (δεσμευτικοί για κάθε βήμα)

- **R0 αρχιτεκτονική:** barrels (`core/services/widgets/providers`), `go_router+AppTransitions` (όχι `MaterialPageRoute`), `DetailScreenMixin`, soft-delete + cascade via `ReminderScheduler.deleteAllRemindersForItem`, καμία DB στο UI.
- **R1 <500:** χάρτης §2. Extract widget/file, ίδια ονόματα providers/methods.
- **R2 resize:** μόνο `ImageUtils.avatarProvider/fileThumb/checkMaxBytes` (256/80/2MB). Gallery+camera `maxWidth:1024/quality:85`. Όχι raw `MemoryImage/Image.file` σε λίστες.
- **R3 reuse πρώτα:** `ItemColorHelper.parseHex`, `ContactProps.fromProperties`, `AppStringUtils.*`, `AppDateUtils.*`, `Recurrence.safeDay/safeMonthDay/epochMonday/isValidWeeklyDay`, `BackupArchive.rebasePath/isBackupZip`, `ConfirmDialog/ArchiveHelper/showTagPickerSheet/ReminderSection/showReminderPicker`, `LinkList.extractUrls/LinkLauncher`, `ItemTypeIcon/PriorityBadge/ItemCard/Skeleton/TagChipList/EmptyState/ContentField/BlockEditor/ResponsiveItemList/ReorderableItemList/ItemCardBuilder/DraggableWrapper`, `sanitizeFileName`, `findDuplicate`, `getByItems/getAllForItems/getCollectionIds`, `planTopUp/parseHabitTime/sync/repair`, `cancelAllForItem`, `syncChannel`, `SearchService.search`, `ShareService.shareItem`, `AttachmentService.*`, `MigrationService`, `AppLockService.hash/verify/auth`, `Spacing/AppRadius/Duration/IconSize/Breakpoints/ColorsUI/context.c*`. Νέα μόνο 8: `SheetHandle`, `ItemActionsSheet` (προαγωγή), `FolderFormDialog`, `SearchClearButton` (με `ValueListenableBuilder`), `AppErrors`, weekdays extension, `AppRoutes.forType`, `_saveAttachments` + debounce consts.
- **R4 errors/debug:** `AppErrors` ελληνικά (εισάγει strings mixin). `DebugConfig.error/warning` πάντα. Απαγόρευση `catch(_){}/debugPrint/print/PII/log-in-build`. Κάθε catch → `error + SnackBar/EmptyState.error retry`.
- **Debug:** `nav` σε open/create (όχι build), `db` 1 count/λίστα (όχι ανά κάρτα), `warning` σε hex/date/photo, `error+e/stack` παντού.

## 2. Χάρτης splits <500

`settings 2816→6` (screen/tiles/dialogs/import/pin/colors)· `habit_detail 1874→5`· `entries 1776→list/detail/fields`· `contact_detail 1480→3`· `task_detail 1303→3`· `home 1253→3`· `event 916→2`· `journal_detail 914→2`· `appointment_detail 942→2`· `calendar 798→2`· `collection_detail 860→2`· `collections 673→2`· `search 695→2`· `folder_browser 768→2`· `trash 501→2` (οριακό)· `embedded 545→2`· `home_folder_view 570→2`.

## 3. Κατάλογος bugs — ΕΠΑΛΗΘΕΥΜΕΝΟΣ (audit εναντίον τρέχοντος κώδικα)

> **Audit (read-only):** grep σε όλο το `lib/` + file-level verifications + spot-checks.
> Το παλιό §3 ήταν snapshot **πριν** τη Φ3 → ~50% έχει κλείσει. Παρακάτω ο καθαρός τρέχων κατάλογος.
> Τα `file:line` είναι του **τρέχοντος** κώδικα· κατηγορίες 3.1–3.6 αντιστοιχούν στα βήματα Φ4c (41–46).

### 3.0 ✅ Επιβεβαιωμένα κλεισμένα (μην τα ξανακυνηγάτε)
`trash deletedAt!` → 0· raw `int.parse` (appointment→`parseHabitTime`, collection_detail→`tryParse`· μένει μόνο `parseHex` `item_color_helper:51`)· `tags.first orElse` (contact/entries/journal)· `habit _isEditingTitle→false` (`habit_detail:75`)· `block_editor` postFrame delete `mounted`+`try` (`:39-48`)· `event cancel→save` (PopScope)· `onDeleteEmpty` wired (`task:573`,`event:709`,`journal:477`,appointment)· `journal _pendingContent` clear (`journal_detail:103`)· **contact notes loss S98** (`_saveNotesDirect`+`onNotesSaved`+setState)· contact favorite dirty· appointment notes save· **search/main misroute** → `AppRoutes.forType` (`main:76`,`app_router:76`)· calendar months → `AppDateUtils.monthFullNames` (`calendar:145`)· habit dead bell· item_list blind pops (`canPop:!isDragging`)· collection_detail raw `int.parse`· leftover `debugPrint`.

### 3.1 Crash guards (Φ4c-41)
- Βασικά κλεισμένα (βλ. 3.0).
- `item_color_helper:51` — `int.parse` hex· επιβεβαίωση try/catch + range fallback.

### 3.2 Flush / dirty / απώλεια (Φ4c-42)
- ✅ (S141) `collection_detail:146` — back-cascade αφαιρέθηκε: empty+existing → SnackBar + κρατάει τον προηγούμενο τίτλο (καμία διαγραφή· D2)· device ✅ 09/10/2026 (`run_log_d1d2.txt`).
- 🟠 `event_detail:195` — save-on-pop χάνει location edits σε άτιτλο υπάρχον event.
- 🟠 `habit_detail:68` — `_saveTitle` early-return πριν το `_isEditingTitle=false` (`:75`).
- 🟡 `collection_detail:197,202,207` — `_hasChanges` εκτός `setState`.

### 3.3 Routing (Φ4c-43)
- 🟠 `calendar:384` — «Γενέθλια» → `pop(_EventCreationType.event)`· **κανένα `🎂` path** (το «Ειδική ημέρα» κάνει `_createEventWithIcon(...,'⭐')` `:406`).
- 🟡 `MaterialPageRoute` αντί `AppTransitions` (×8): `item_list_screen:59,65`· `settings:1904,1909`· `habit_list:41,47`· `contact_list:35,43`.
- 🟡 `app_router:207` — log τυπώνει literal `\$isNew`.

### 3.4 Λίστες / queries (Φ4c-44)
- 🟡 **N+1**: `calendar:25`· `collection_entries:497`· `journal_list:128`· `item_list_embedded:197,214`.
- ✅ (S148) reorder σε φιλτραρισμένο υποσύνολο — SPoT `ReorderUtils.moveAndMerge` (subset → full merge) σε 8 sites (entries/item_list/embedded/habit/task/browser/collections/folder_view)· **device-verified 10/10/2026** (acceptance `[1,2,3]→[1,3,2]`, pipeline 1:1, 0 ERR/WRN).
- ✅ (S141) `collections:69-72` — cascade κεντρικοποιήθηκε: `ItemNotifier.deleteItem` (type-aware· `project` → soft-delete εγγραφών πρώτα, μετά το root)· device ✅ 09/10/2026 (`run_log_d1d2.txt`, grid + Folder Browser).
- ✅ (S142) `item_provider` — συμμετρικό lifecycle κάδου (F1): `_cascadeCollectionEntries` έγινε action-based και καλείται **και** από `restoreItem`/`permanentDelete` (`includeDeleted:true`) → restore συλλογής επαναφέρει τις εγγραφές της· permanent τις διαγράφει + καθαρίζει attachments. 1 αρχείο (497→498), 0 νέα public API· `analyze` clean + `test` 138/138· device ✅ 09/10/2026 (`run_log_f1.txt` — delete/restore/permanent με εγγραφές + `deleted file` attachment cleanup).
- ✅ (S143) `item_provider` split (R1 <500): pinned/favorites streams → νέο `providers/pinned_provider.dart` (+ barrel export)· **498→442**· 0 νέα public API. Behavior (Fix #2): αρχειοθετημένα items = σίγαση OS reminders (`toggleArchive` cancel/reschedule · guard `_scheduleOne` · skip archived roots `refreshRecurringReminders` · Settings restore/delete → SPoT `ItemNotifier`)· `analyze` clean + `test` 138/138· device ✅ 09/10/2026 (`run_log_f2.txt` — ARCHIVED/SKIP, unarchive reschedule, delete cascade, 0 ERR).
- 🟠 `journal_list:106` — retry σε λάθος provider· `:129` Future ανά build.
- 🟡 `collection_entries:166,169` — stale AppBar (widget αντί watched).
- 🟡 `ValueKey` compound: `collection_detail:746`· `collection_entries:290`.

### 3.5 Providers / lifecycle (Φ4c-45)
- 🔴 `contact:509,555,565` — `ref.read(itemTagsProvider)` σε build → tags μη-reactive (δεν refresh μετά add/remove).
- 🟡 `ref.watch` σε `when`/itemBuilder: `journal_list:113`· `task_list:181`· `contact:499`· `collection_entries:497`· `item_list:157`· `contact_list:167`· `habit_list:184`.
- 🟠 `collection_entries:1451` — `addListener` χωρίς `removeListener` (leak).
- 🟠 `contact:249,267` — gallery photo χωρίς downscale (base64· μόνο 2MB guard· camera OK).
- 🟡 controllers χωρίς `dispose`: `collection_detail:220-228`· `settings:802,1280,1928,1929,2013`.
- 🟡 raw `Navigator.pop` αντί `safePop` (~8 detail screens).
- 🟡 `settings:538-539,1701` — per-row `FutureBuilder` + `SuperNoteHelper.instance` άμεσα.
- 🟡 `lock_screen:29,45,82,60,159` — triple-fetch, race pinLength/biometric, `_pinCtrl.text+=`, no try-catch, biometric μόνο μετά αποτυχία.
- 🟡 `collection_entries:430` — postFrame callback κάθε build.

### 3.6 Theming / tokens / a11y (Φ4c-46)
- 🟡 Hardcoded `Colors.*`: `event:663-673` (green box)· `calendar:372-389` (indigo/pink/amber)· `main:375,416`· `reminder_diagnostics:232,264,272`.
- 🟡 `event:432,830` — διπλό AppBar / 6 actions (overflow risk).
- 🟡 `calendar:410,441` — διπλό `_createEvent`/`_createEventWithIcon`· `:441` error swallow χωρίς SnackBar· `:637-656` νεκρό branch (identical render).
- 🟡 Ετυμολογία: `calendar:214`·`journal_list:195` «συμπιεσμένων»→«αρχειοθετημένων».
- 🟡 mojibake comments: `collection_detail:97-121`·`collection_entries:719-751`·`contact:202,209`.
- 🟡 `const`: `journal_list:419`·`habit_list:450`.
- ⏳ **a11y (48px/Semantics)** — ξεχωριστό device pass.

### 3.7 🆕 Νέα ευρήματα (audit)
- `calendar:441` error swallow · `calendar:637-656` dead branch (βλ. 3.6).
- `contact:_syncPropsFromDB` (`:692`) — full sync κάθε rebuild όταν email κενό.
- `habit_detail:253` — νεκρό `Text('')` στον spinner.
- `appointment:226` — time unpadded `9:5`.
- `collection_entries` — διπλό watch (`:143`+`:344`).

### 3.8 Παλιό §3 — Ποιότητα (ΔΕΝ επανελέγχθηκε σε αυτό το audit)
> Διατηρείται για να μη χαθεί· επανέλεγχος πριν από Φ4c-46.
`if(!mounted)return` χωρίς κενό· `use_build_context_synchronously`· `select((v)=>v)` no-op· `✓` αντί Icon· `day/month/year` χειροκίνητα αντί intl· `DateTime.now()` σε build· `O(n²) block_editor:105`· `BlockTileWidget Stateful χωρίς state:165`· delete πάντα ορατό· `autofocus` σε inline editor· `showArchived` χωρίς φίλτρο (`item_list:211`)· `archivedItems/pastReminders` providers σε UI (`settings:28,39`)→μεταφορά· `FutureBuilder per-row (settings:548)`→batch· `ValueKey entries accentColor (274)`· `_ToggleButton` διπλό· `types` arrays τριπλά με ίδιο emoji `📅`· `take(10)` magic· stats αγνοούν journal/appointment· `_green 0xFF4CAF50 ×2`· `Colors.white/black` hardcoded· main init/web hardcoded `0xFF1E1E2E`· `trash:250` error χωρίς retry· touch 16-22px.

## 4. Βήματα υλοποίησης (αριθμημένα, για εύκολη αναίρεση)

### Φ4a — SPoT + συμβατότητα (πριν τα splits)
1. Backup `backups/phi4a/` (7+ αρχεία). `analyze` + `test` baseline.
2. `SheetHandle` extract από `confirm:229-235` → αντικατάσταση 11 σημείων.
3. Προαγωγή `ItemActionsSheet` (ένα public) → διαγραφή 2 private + 5 `_showActions` duplicates (journal/contacts/habits/collections/folder_browser).
4. `FolderFormDialog` → αντικατάσταση 3 dialogs (home create/edit, folder_browser).
5. `SearchClearButton` (ValueListenableBuilder) → 5 σημεία (trash/entries/embedded/task/tagpicker).
6. `AppErrors` (από mixin strings) → `executeSave/showSnackBar` + share/backup/import μηνύματα.
7. `AppDateUtils.weekdayNames/Initials/monthNames` → αντικατάσταση 4 ορισμών + diagnostics/weekdays + recurrence describe (κράτα `describe` API).
8. `ItemTypeIcon.labelFor` SPoT → delegate `AppStringUtils`, διαγραφή `item_list:_labelForType`, διόρθωση `Ραντεβου→Ραντεβού`, `project/knowledge` απόφαση: `Συλλογή` (UI) — σημείωσε στο supernote.
9. `ItemCard` → `ItemTypeIcon.iconDataFor` + `PriorityBadge.iconFor` (διαγραφή 2 private).
10. `ViewModeToggle` κεντρικό → διαγραφή 2 `_ToggleButton` + colors→tokens.
11. `3× _colorFromHex→parseHex` (folder_selector/draggable/settings) + 2× `int.parse→tryParse+range` (appointment/collection_detail).
12. `ContactProps` ×4 (list/detail/share/import-dedup) ΜΕΤΑ phones-compat fix στο share (δέχεται `List<String>` και `[{number}]`).
13. `ImageUtils` ×3 (gallery guard+resize, avatar provider, fileThumb) — camera ήδη σωστό, gallery ευθυγράμμιση.
14. Journal → `showTagPickerSheet` (διαγραφή custom) · appointment raw `AlertDialog:375` → `ConfirmDialog` · collections → `ItemCardSkeleton`.
15. `AppRoutes.forType` (κοινός για `main` + `search`) — καλύπτει note/task/habit/event/appointment/journal/contact/collection/entry, null μόνο για goal/finance/bookmark.
16. `SharedIntent._saveAttachments` extract (2 loops) · `ContactImport` N+1→batch (`getAllForItems`) · `autoBackup` απόφαση: zip (όπως export) ή τεκμηριωμένη εξαίρεση.
17. `selectedFolderId ⊕ homeSelectedFolder` → ένα (κρατάμε `selectedFolderId` + mixin, διαγραφή `homeSelectedFolder`, `Home tap` reset το ίδιο).
18. `settings` providers → `providers/` (2 FutureProviders) · `collection counts Stream single-yield→FutureProvider` · διαγραφή `select((v)=>v)`.
19. `AppDuration.debounceSearch/content/title` + ευθυγράμμιση (300/500/800ms) · `reminder_section TextFormField→ContentFieldWidget` · birthday constants `kBirthdayFirst 1900/kPickerLast +5y`.
20. `analyze` + `test` + νέα tests (props/image/weekday/errors/parse/router). Device: `created 0/SUCCESS/0 ERR`.

### Φ4b — Splits (ένα αρχείο ανά βήμα, backup `phi4b/`)
21-40. Κάθε god-file: extract widgets → extract dialogs/sheets → extract sections → verify `analyze` + στοχευμένο `test` + OK χρήστη πριν επόμενο.

### Φ4c — Συμπεριφορά/a11y (backup `phi4c/`)
41. Crash guards (6). 42. Flush/dirty (5). 43. Routing (search+main+calendar birthday). 44. Lists (N+1→batch, Future-in-build, archived φίλτρο, filtered-reorder full-list, ValueKey). 45. Providers/lifecycle (`watch` hoist, `safePop`, `mounted+try`, `autoDispose` search/tag, dispose ctrls). 46. Theming/tokens/a11y (green→cSuccess, 2 AppBars→1+menu, 48px+Semantics, const, ορολογία, mojibake, empty/retry).

### Φ4d — Docs
47. `supernote.md` sync: zip backup (όχι `.isar`), `app_info/app_lock` providers, lock/share-intent/link/image/contact-props/image-utils/migration-v2/ habit top-up/pending-370/resume-cleanup/vibration-channel/calendar-dayfilter. 48. `oldsessions.md` 1 κεφάλαιο Φ4 (<500γρ). 49. Τελικό `analyze` + full `test` + device matrix (back<debounce, pop-mid-save, rotation, dark, tablet 600/1024, 0/1000 items, corrupt hex/phones/date, DST).

## 5. Testing/συμβατότητα/edge

Tests: υπάρχοντα 40/40 + `safe_parse/contact_props/image_utils/app_errors/weekday_labels/router_for_type` (pure, χωρίς Isar). Device logcat: `created 0`, `scheduleAll SUCCESS`, 0 ERR, `day filter shown`, `SharedIntent initialized`. Συμβατότητα: timezone IANA, pending 370d, resume cleanup, vibration channel, habit repair/topUp (main:159-160,330 + resume:330), weekly anchor, yearly guard, zip rebase localPath-only, share intent, dayfilter — αμετακίνητα, ίδια ονόματα. Edge §3 + lifecycle (dispose/mounted/postFrame/pop-mid-save/orientation/dark/large lists/Isar races/midnight/DST).

## 6. Αποφάσεις (προτάσεις)

Extract-files (όχι folders)· ελληνικά μόνο· `_debug=false` με error/warning on· counts→Future· phones-compat πριν reuse· autoBackup→zip· folder state→`selectedFolderId`· labels→`labelFor` (`Ραντεβού`, `Συλλογή` για project/knowledge στο UI).

## 7. Εκκρεμότητες — διορθώνονται αμέσως μετά το refactor (από device testing)

1. `note_detail_screen.dart:227` — AppBar `Row` overflow 21px σε στενά κινητά (6 actions). Fix Φ4c: ενοποιημένο DetailAppBar + overflow menu.
2. `habit_detail_screen` — `ListTile ... ink splashes may be invisible` assertion (ListTiles μέσα σε DecoratedBox με bg + radius 16). Fix Φ4c: Material wrapper ή αφαίρεση bg.
3. (συμπληρώνεται με κάθε νέο εύρημα από device logs)
