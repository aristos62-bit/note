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

`settings 2947→9` ✅ (screen / tiles / colors / backup / pin-dialogs / reminders-dialog / archived-dialog / contacts-dialogs / contacts-flow — S253, public symbols + direct imports, 0 `part`· max 484 γρ.)· `habit_detail 1874→5`· `entries 1776→list/detail/fields`· `contact_detail 1480→3`· `task_detail 1303→3`· `home 1253→3`· `event 916→2`· `journal_detail 914→2`· `appointment_detail 942→2`· `calendar 798→2`· `collection_detail 860→2`· `collections 673→2`· `search 695→2`· `folder_browser 768→2`· `trash 498` ✅ <500 (S251 — 0 ανάγκη split)· `embedded 545→2`· `home_folder_view 570→2`.

## 3. Κατάλογος bugs — ΕΠΑΛΗΘΕΥΜΕΝΟΣ (audit εναντίον τρέχοντος κώδικα)

> **Audit (read-only):** grep σε όλο το `lib/` + file-level verifications + spot-checks.
> Το παλιό §3 ήταν snapshot **πριν** τη Φ3 → ~50% έχει κλείσει. Παρακάτω ο καθαρός τρέχων κατάλογος.
> Τα `file:line` είναι του **τρέχοντος** κώδικα· κατηγορίες 3.1–3.6 αντιστοιχούν στα βήματα Φ4c (41–46).

### 3.0 ✅ Επιβεβαιωμένα κλεισμένα (μην τα ξανακυνηγάτε)
`trash deletedAt!` → 0· raw `int.parse` (appointment→`parseHabitTime`, collection_detail→`tryParse`· μένει μόνο `parseHex` `item_color_helper:51`)· `tags.first orElse` (contact/entries/journal)· `habit _isEditingTitle→false` (`habit_detail:75`)· `block_editor` postFrame delete `mounted`+`try` (`:39-48`)· `event cancel→save` (PopScope)· `onDeleteEmpty` wired (`task:573`,`event:709`,`journal:477`,appointment)· `journal _pendingContent` clear (`journal_detail:103`)· **contact notes loss S98** (`_saveNotesDirect`+`onNotesSaved`+setState)· contact favorite dirty· appointment notes save· **search/main misroute** → `AppRoutes.forType` (`main:76`,`app_router:76`)· calendar months → `AppDateUtils.monthFullNames` (`calendar:145`)· habit dead bell· item_list blind pops (`canPop:!isDragging`)· collection_detail raw `int.parse`· leftover `debugPrint`.

- ✅ CLOSED 13/10/2026 (code-audit, μην τα ξανακυνηγάτε): MaterialPageRoute→AppTransitions S172· dark-hardcoded→tokens S169· event-double-AppBar→1 S183· raw-pops→safePop S180· mojibake-comments S178· contact-birthdays-calendar S177· contact-reactive-tags S170· _SelectField-listener S171· settings-batch S181· lock-PIN-state S182· appointment-HH:MM S184· habit-flag S185· collection-flags-reviewed S186· dispose-no-ref S187· habit-create-flash S188· entries-ValueKey-stable S189· gallery-downscale S179· router-$isNew S176· §7 S173· allowBackup=false S174· habit-Text('')-gone· calendar-old-dead-branch-gone· collection_detail-ValueKey-legit(:719)· entries-double-watch/postFrame-reviewed-no-change· syncProps-guarded· settings-disposes-accepted(S131).

### 3.1 Crash guards (Φ4c-41)
- Βασικά κλεισμένα (βλ. 3.0).
- ✅ CLOSED 13/10/2026 — `item_color_helper:51` (`parseHex` try/catch + warning + null-fallback, επαληθευμένο `:84-93`).

### 3.2 Flush / dirty / απώλεια (Φ4c-42)
- ✅ (S141) `collection_detail:146` — back-cascade αφαιρέθηκε: empty+existing → SnackBar + κρατάει τον προηγούμενο τίτλο (καμία διαγραφή· D2)· device ✅ 09/10/2026 (`run_log_d1d2.txt`).
- ✅ CLOSED 13/10/2026 — `event_detail:195`: `_flushSaves` (`:152-161`) + `_saveData` σε save ΚΑΙ pop (`:182-199`), location δεν χάνεται.
- ✅ CLOSED 13/10/2026 — `habit_detail:68`: reset `_isEditingTitle=false` στο early-return (revert-πριν-debounce).
- 🟡 `collection_detail:197,202,207` — `_hasChanges` εκτός `setState` → REVIEWED 13/10/2026: no-change (διαβάζεται μόνο στο pop-gate `:140`, 0 UI — setState θα ήταν regression).

### 3.3 Routing (Φ4c-43)
- ✅ CLOSED 13/10/2026 (S156) — calendar birthday path: επιλογή → `_createBirthdayEvent` (`:435,472`) με 🎂 + yearly reminder· ειδική με ✅ (`:437`).
- ✅ CLOSED 13/10/2026 (S172) — `MaterialPageRoute`→`AppTransitions` (×8 + trash-slideUp + diagnostics-fade)· device ✅.
- ✅ CLOSED 13/10/2026 — `app_router` EventDetail nav-log: `\$isNew` → `$isNew` (8/8 ομοιόμορφα).

### 3.4 Λίστες / queries (Φ4c-44)
- ✅ CLOSED 13/10/2026 (S191) — journal batch (1 bulk + signal) · calendar batch (S177) · ✅ CLOSED 14/10/2026 (S216+S217, device ✅) — P1 N+1 τέλος: entries props-batch + embedded tags-batch (contacts-batch προϋπήρχε).
- ✅ (S148) reorder σε φιλτραρισμένο υποσύνολο — SPoT `ReorderUtils.moveAndMerge` (subset → full merge) σε 8 sites (entries/item_list/embedded/habit/task/browser/collections/folder_view)· **device-verified 10/10/2026** (acceptance `[1,2,3]→[1,3,2]`, pipeline 1:1, 0 ERR/WRN).
- ✅ (S141) `collections:69-72` — cascade κεντρικοποιήθηκε: `ItemNotifier.deleteItem` (type-aware· `project` → soft-delete εγγραφών πρώτα, μετά το root)· device ✅ 09/10/2026 (`run_log_d1d2.txt`, grid + Folder Browser).
- ✅ (S142) `item_provider` — συμμετρικό lifecycle κάδου (F1): `_cascadeCollectionEntries` έγινε action-based και καλείται **και** από `restoreItem`/`permanentDelete` (`includeDeleted:true`) → restore συλλογής επαναφέρει τις εγγραφές της· permanent τις διαγράφει + καθαρίζει attachments. 1 αρχείο (497→498), 0 νέα public API· `analyze` clean + `test` 138/138· device ✅ 09/10/2026 (`run_log_f1.txt` — delete/restore/permanent με εγγραφές + `deleted file` attachment cleanup).
- ✅ (S143) `item_provider` split (R1 <500): pinned/favorites streams → νέο `providers/pinned_provider.dart` (+ barrel export)· **498→442**· 0 νέα public API. Behavior (Fix #2): αρχειοθετημένα items = σίγαση OS reminders (`toggleArchive` cancel/reschedule · guard `_scheduleOne` · skip archived roots `refreshRecurringReminders` · Settings restore/delete → SPoT `ItemNotifier`)· `analyze` clean + `test` 138/138· device ✅ 09/10/2026 (`run_log_f2.txt` — ARCHIVED/SKIP, unarchive reschedule, delete cascade, 0 ERR).
- ✅ CLOSED 13/10/2026 — `journal_list:106` retry → `itemsStreamProvider` (1γρ.) · `:128-129` Future-per-build → batch-map (S191).
- ✅ CLOSED 14/10/2026 (S219+S220, device ✅) — τίτλος → live Item, icon → props-αλυσίδα + dual-write `Item.icon` για το grid.
- ✅ CLOSED 13/10/2026 — entries stable key (S189)· `collection_detail:719` = legit field-key (όχι accent-compound).

### 3.5 Providers / lifecycle (Φ4c-45)
- ✅ CLOSED 13/10/2026 (S170) — 3× read→watch· device ✅.
- ✅ REVIEWED 14/10/2026 — watches μέσα σε `data:` κάνουν subscribe κανονικά (όχι bug όπως το embedded `ref.read`)· hoist δεν αλλάζει συμπεριφορά → no-change.
- ✅ CLOSED 13/10/2026 (S171) — named + dispose + didUpdateWidget· device ✅.
- ✅ CLOSED 13/10/2026 (S179) — κοινό `_storePickedPhoto` (1024/85)· **device ✅ (13/10/2026):** PASS, 0 ERR.
- 🟡 controllers χωρίς `dispose`: settings ✅ accepted (S131 docs ×4, S120)· `collection_detail:191-199` dialog-ctrls → doc-parity (OPEN micro, 0 κώδικα).
- ✅ CLOSED 13/10/2026 (S180) — 7 screens → `safePop`· έμεινε 1 νόμιμο guarded (`appointment:574`, dialog-ctx)· device ✅.
- ✅ CLOSED 13/10/2026 (S181) — `getByIds` batch + dbProvider· device ✅.
- ✅ CLOSED 13/10/2026 (S182) — single-load+cache, `String _pin`, try/catch· device ✅.
- ✅ REVIEWED 13/10/2026 — postFrames guarded (setEquals `:454`, one-shot flag `:212`, reset `:95`)· no-change.

### 3.6 Theming / tokens / a11y (Φ4c-46)
- ✅ CLOSED 13/10/2026 (S169) — tokens + shared consts· `main` parked (const, χωρίς context)· **device ✅ (13/10/2026):** eyeball PASS, 0 ERR.
- 🟡 `event:432,830` — ✅ CLOSED 13/10/2026 (S183: 1 widget, device tablet PASS) · 6 actions (overflow risk — αν σκάσει, overflow-menu follow-up).
- ✅ `calendar:476,554` — ✅ CLOSED 13/10/2026: error SnackBar και στα 3 (parity `_createEventWithIcon:575-581`) · παλιό dead branch `:637-656` ✅ GONE (restructured S156/S177)· νέο identical-pair `:753-772` ✅ MERGED 14/10/2026 (S218, −11γρ., device ✅).
- ✅ CLOSED 14/10/2026 (S221, device ✅) — 8 αρχεία → «αρχειοθετημένων», grep `συμπιεσμένων` = 0 σε `lib/`.
- ✅ CLOSED 13/10/2026 (S178) — ξαναγραφή από context· grep `�` = 0.
- ✅ CLOSED 14/10/2026 (S222, Επιλογή Β, device ✅) — const `_LoadingList` ×5 αρχεία + key-cleanup (`unused_element_parameter`).
- ⏳ **a11y (48px/Semantics)** — ξεχωριστό device pass.

### 3.7 🆕 Νέα ευρήματα (audit)
- ✅ `_createEventWithIcon` catch ΧΩΡΙΣ SnackBar (OPEN parity, βλ. 3.6)· παλιό dead branch GONE· identical-pair ✅ MERGED (S218, βλ. 3.6).
- ✅ REVIEWED 13/10/2026 — guarded (`isEmpty`/`_lastEmail`/one-shot flag)· μένει micro-cost in-memory (όχι DB)· no-change ή 2γρ. flag.
- ✅ CLOSED 13/10/2026 — εξαφανισμένο (grep 0).
- ✅ CLOSED 13/10/2026 (S184) — padLeft· device ✅.
- ✅ REVIEWED 13/10/2026 — shared stream watches (0 extra queries)· no-change.

### 3.8 Παλιό §3 — Ποιότητα (ανανεώθηκε 17/10/2026 — έλεγχος parked)
> Ο παλιός κατάλογος «ΔΕΝ επανελέγχθηκε»· ο έλεγχος 17/10/2026 (grep στον τρέχοντα κώδικα) έκλεισε ό,τι υλοποιήθηκε στο μεταξύ — παραμένουν μόνο τα μη επιβεβαιωμένα.
**✅ CLOSED 17/10/2026 (spot-verified):** `select((v)=>v)` no-op (0 hits)· `_green 0xFF4CAF50` ×2 (0 hits — tokens S169)· `_ToggleButton` → κοινό `ViewModeToggle` (Φ4a-10)· `autofocus` inline editor → focusNode (`task_detail:1098`)· `showArchived` φίλτρο (`includeArchived: showArchived` — `item_provider:37,104`, `task_provider:32`)· providers μεταφορά (`archivedItemsProvider` → `item_provider:403`· `pastRemindersProvider` 0 hits)· `FutureBuilder per-row` → batch 1 query (`settings:460`)· `trash:250` retry (`EmptyState.error` `:245-250`)· `use_build_context_synchronously` (analyze clean)· `ValueKey entries` (S189).
**🟡 Ανοιχτά/χωρίς επαλήθευση:** `take(10)` magic (`item_provider:443`)· `if(!mounted)return` χωρίς κενό· `✓` αντί Icon· `day/month/year` αντί intl· `DateTime.now()` σε build· `O(n²) block_editor`· `BlockTileWidget Stateful` (`block_editor_widget:146-170`)· delete πάντα ορατό· `types` arrays με ίδιο `📅` (`folder_create_sheet:28,33`)· stats journal/appointment (δεν βρέθηκε ενεργό stats screen)· `Colors.white/black`· main `0xFF1E1E2E` ×2 (ρητά accepted — §3.6:92)· touch 16-22px (→ ⏳ a11y pass §3.6:98).

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

1. ✅ CLOSED 13/10/2026 (device OK) — `note_detail_screen.dart` AppBar 6 actions: compact density + 20px + `titleSpacing: 0`, κανένα overflow στη συσκευή· ενοποιημένο DetailAppBar parked.
2. ✅ CLOSED 13/10/2026 (fixed S99 + device OK) — `habit_detail_screen`: `Container` → `Material` (ίδια χρώματα/radius/border).
3. 🔜 Snooze UI + notification actions (μελλοντική ανάπτυξη, απόφαση 14/10/2026) — το `ReminderNotifier.snooze` δουλεύει (S52: pending + OS reschedule) αλλά δεν έχει κουμπί/μενού πουθενά· το `markSent` επίσης 0 callers (σκόπιμα κρατείται για μελλοντικό OS fire-callback — μην το σβήσεις). Εύρημα 14/10/2026: οι ειδοποιήσεις δεν έχουν action buttons (Αναβολή 10′ / Έγινε) — το `_details()` (`notification_service.dart:325-343`) δεν ορίζει Android `actions` ούτε iOS category, το `_onTap` αγνοεί `actionId`, το `_onBackgroundTap` είναι no-op. Θέλει spec (κουμπί σε ReminderSection; actions; iOS categories) + σχεδίαση background-tap (εκεί δεν υπάρχει Isar) + λειτουργικό τεστ + device matrix.

4. S234 findings (device 15/10/2026 — προϋπάρχοντα, όχι S234· πηγή oldsessions S234): ✅ CLOSED 17/10/2026 (S250 — κώδικας + device ✅): race delete-χρήστη ↔ topUp → μερική διαγραφή (218/22) — σειριοποίηση wipe+soft/hard delete στο ίδιο pass της `_passQueue` + deleted-guard `_scheduleRemindersImpl` + routing `permanentDelete`· ✅ CLOSED 17/10/2026 (S251 — κώδικας + device ✅): `_TrashScreenState` setState-after-dispose crash (κλάση S85/S187) — βλ. §8 P1#2.
5. ✅ CLOSED 18/10/2026 (S253 — κώδικας ✅· analyze clean + test 223/223 + build apk ✅): `settings_screen.dart` **9** (όχι 8) ίδια κλάση crash (setState-after-await χωρίς `mounted` guard), όλα `setModal`: reminders (`:501,:520`) · archived (`:1005,:1018,:1035,:1051`) · contacts (`:1757,:1769`) · PIN (`:2110`). Fix: `if (!ctx.mounted) return;` **πριν** το `setModal`, τα `ref.invalidate` μένουν μετά (S251 parity — καμία μετακίνηση, για να μη ρισκάρουμε disposed `ref`). Bonus: A10 λάθος log label (`:970` archived έγραφε «past reminders»), A11 F11 (loading dialog: `loadingOpen` flag + `navigator` captured πριν το await — το back δεν κλείνει πλέον το Settings), A12 σχόλιο γιατί per-row delete (ΟΧΙ `deleteReminderThread` — θα έσβηνε το root rrule). Split 2947→9 αρχεία (<500, max 484). Βλ. §8 P2#5. Device ✅ B1-B4 (back mid-await: didPop εν μέσω delete/restore → 0 crash).
6. ✅ CLOSED 17/10/2026 (S252 — κώδικας ✅· analyze clean + test 223/223 + device ✅ T1-T5) — postFrame δίχτυα: `purgeKnowledgeReminders` (`main:239`) + `scheduleAll` (`main:246`) → SPoT `SerialPassQueue` per-concern instances (`ReminderScheduler.bake`, `ReminderScheduler.purge`, fail-open 60s, NEVER-THROW)· 0 αλλαγές `main`· βλ. §8 P1#3.
7. 🟡 Grid auto-height (παλιό «parked Φ4c, για όλα μαζί») — αραιές κάρτες με fixed extents· πλήρης ανοσία μόνο με auto-height (πηγές oldsessions ~`:938,998,1246`).

8. ⚪ Micros (P4, docs-only — S252 re-check): **F2** `settings_provider:87` — OFF path `cancelAll()` bypass την ουρά (προϋπάρχον race, self-heal)· **F3** `main:210` `settings.get()` + `main:224` `requestPermission()` — awaited postFrame χωρίς δίχτυ (πρότυπο `.timeout(5s)` υπάρχει ήδη: `main:376/402`)· **F4** `item_provider` `rescheduleForItem` ×6 (`:199/203/214/275/337/341`) — awaited UI flows χωρίς timeout (S234 residual). **F9c (S256):** `ImportProgress.status` (set 3×, ποτέ rendered) + `ImportResult.totalProcessed` (0 callers) — νεκρά placeholders (θα απαιτούσαν UI αλλαγή στο progress dialog). **✅ CLOSED 19/10/2026 (S258 — αφαίρεση):** 0 readers ⇒ **behavior-neutral** (ίδιο rendered UI)· `contact_import_service.dart` 401→**395** · `settings_contacts_dialogs.dart` 402→**400**· analyze clean + test **230/230**· commit `c2d4893`.

## 8. Κατάταξη ανοιχτών εκκρεμοτήτων (17/10/2026 — έλεγχος parked)

> Πλήρης ιεραρχημένη λίστα όλων των ανοιχτών (P1→P5) — συγκεντρώνει §3.x/§7, supernote.md και oldsessions S229-S248. Δεν περιλαμβάνει ό,τι έκλεισε στον έλεγχο 17/10/2026 (9593c01e· day-rollover S229/S236).
> Σύνολο 16→14 (P1#3 ✅ CLOSED 17/10/2026 — S252· P2#5 ✅ CLOSED 18/10/2026 — S253): 0 κρίσιμες · 2 σημαντικές · 3 βελτιώσεις · 4 micro-groups · 5 by-design/ασαφή.

### 🔴 P1 — Κρίσιμες για σωστή λειτουργία (δικό τους session)
1. ✅ CLOSED 17/10/2026 (S250 — κώδικας + device ✅) — **Race: delete-χρήστη ↔ topUp → μερική διαγραφή** (§7.4 · S234): σειριοποίηση wipe+item-delete στο ίδιο pass της `_passQueue` + deleted-guard `_scheduleRemindersImpl` + routing `permanentDelete`· analyze clean + test 223/223· device matrix T1-T5+T3 OK (race αναπαράχθηκε & κλείνει με FIFO — oldsessions S250) · καταγραφή: oldsessions S250.
2. ✅ CLOSED 17/10/2026 (S251 — κώδικας + device ✅) — **`_TrashScreenState` setState-after-dispose crash** (§7.4 · S234): 5/5 ακάλυπτες async ουρές → guarded tail `_clearSelectionAndRefresh()` (`if (!mounted) return;`) + capture `notifier` πριν το πρώτο await (4 σημεία) + tear-offs/αφαίρεση άχρηστων `allItems`· 1 αρχείο (`trash_screen.dart` 497→498, <500)· analyze clean + test 223/223· device **before-repro ✅** (`run_log_s251_t0c_pre.txt`: `setState() called after dispose(): _TrashScreenState` — `_clearSelection:62` ← `_restoreSingle:104`) → **after ✅ 0 crash** (`run_log_s251_t3c_post.txt`: pop 2.3s μετά την έναρξη, tail ~4.9s μετά το pop — 0 ERR/WRN). Καταγραφή: oldsessions S251.
3. ✅ CLOSED 17/10/2026 (S252 — κώδικας ✅ + analyze/test ✅) — **postFrame δίχτυα: `purge` (`main:239`) + `scheduleAll` (`main:246`)** (§7.6): 2 SPoT instances (`ReminderScheduler.bake`/`.purge`, fail-open 60s, NEVER-THROW, per-pass — ΠΟΤΕ κοινή ουρά)· 1 αρχείο (`reminder_scheduler.dart` 862→883), 0 αλλαγές `main`/APIs/imports/tests· bonus: καλύπτει και τα `cancelAll()`/`pendingNotificationRequests()` της ίδιας μεθόδου (supernote §Error Handling, S252). Micros F2/F3/F4 → §7.8. Device ✅ T1-T5 (M2007J20CG/Android 12 — oldsessions S252).

### 🟠 P2 — Σημαντικές (ποιότητα/αξιοπιστία)
4. **a11y device pass** (§3.6:98 ⏳ · oldsessions ~`:882-892`) — ο κώδικας Semantics/48px γράφτηκε, επαλήθευση συσκευής ποτέ (TalkBack/48px/no-PII/flicker + touch 16-22px). Κόστος: 1 device pass (0 κώδικα εκτός ευρημάτων).
5. ✅ CLOSED 18/10/2026 (S253 — κώδικας ✅· analyze clean + test 223/223 + build apk ✅ + **device ✅ B1-B4**) — **Settings ×9 setState-after-await χωρίς guard** (§7.5 · S251): 9 guards `if (!ctx.mounted) return;` πριν κάθε `setModal` (reminders ×2 · archived ×4 · contacts ×2 · PIN ×1)· F6 λάθος log label ✅· F11 loading-dialog ✅· split 2947→9 (<500 γρ.)· device: back **εν μέσω** delete/restore (didPop `51.234`/`29.787`/`58.172`/`45.500`) → **0 crash**, Settings παρέμεινε· PIN λάθος → σωστό error· cold start 0 ERR (βλ. oldsessions S253).
6. **Grid auto-height (αντοχή max fontScale)** (§7.7 · πηγές ~`:938,998,1246`) — με max fontScale + 3 πεδία (~153px) τα fixed κελιά οριακά → περικοπές/whitespace· λύση «για όλα τα grids μαζί». Κόστος: 1 session.

### 🟡 P3 — Feature/βελτιώσεις (αποφασισμένες «μελλοντικές»)
7. **Snooze UI + notification actions** (§7.3 🔜) — μηχανισμός έτοιμος, χωρίς κουμπί/actions (απόφαση 14/10)· θέλει spec πρώτα. Κόστος: μεγάλο.
8. **Β2.3 title/body σύγκριση** (S242) — καθαρά optimization (μειώνει rebakes)· self-heal καλύπτει. Κόστος: μικρό-μεσαίο.
9. **Ενοποιημένο DetailAppBar** (§7.1) — hygiene, μηδενικός λειτουργικός αντίκτυπος. Κόστος: μεσαίο.

### ⚪ P4 — Micros/καθαριότητα (batch, μη λειτουργικά)
> S252 (re-check): νέα micros → §7.8 — F2 (OFF `cancelAll` bypass ουράς) · F3 (`main:210/224` χωρίς δίχτυ) · F4 (`rescheduleForItem` ×6 χωρίς timeout).
> S253 (re-check, defer): **F9 ✅ CLOSED S256** (18/10/2026) microtask-pop μέσα σε `build` (`settings_contacts_dialogs.dart` `SettingsImportProgressDialogState.build`) · **F13** `restoreSelected` καλεί N× `toggleArchive` → N× `topUpHabitReminders(force:true)` (S250: `took=6930ms` με 180 created· μετά το F16 = **1 σημείο**, το bulk-restore loop του archived wrapper) · **F17 ✅ CLOSED S259** (19/10/2026) «Μέγεθος γραμματοσειράς» σπάει σε «γραμματοσειρά / ς» (Slider στενεύει τη στήλη — cosmetic, προϋπάρχον, 100%+140%).
> S254 (F16 ✅ CLOSED 18/10/2026): ενοποίηση 3 list dialogs → **`selection_list_dialog.dart`** (`SelectionListDialog<T>` + `SelectionListController<T>` + `showSelectionListDialog<T>`): 8 guards → **1** (`remove`)· analyze clean + test **229/229** (223 + 6 νέα)· 3 wrappers 265/292/339→152/156/229 · device pass εκκρεμεί (T1-T11). **F16b ✅**: 5 delete-confirms `.show` → `.delete` (reminders ×2 · archived ×1 · imported ×2 — μοναδικές εξαιρέσεις στην app· restore μένει `.show`)· κείμενο byte-identical, μόνο icon/χρώμα. **F10 ✅ ΚΡΑΤΗΘΗΚΕ + ΔΙΟΡΘΩΣΗ**: το `archivedItemsProvider` είναι **`FutureProvider`** (cached, `item_provider:420`) και το `deleteItem` **δεν** το invalidates → το `ref.invalidate` είναι **αναγκαίο** (όχι «stale-cache ρίσκο»· η σημείωση «οι λίστες είναι streams» ήταν ανακριβής).
> S254 (device pass ✅ 18/10/2026 + **F18 νέο**): device pass F16/T1-T11 ✅ **και στα 3 dialogs** (select-all/per-row/bulk/auto-pop/invalidate · F16b ✅ ×3 · cold start 0 ERR) → κλείνει η εκκρεμότητα «device pass» της ίδιας S254. **F18 (νέο, defer)**: `pastPendingRemindersProvider` (`reminder_provider.dart:30`, non-autoDispose `FutureProvider`) κρατά cached τιμή → ληγμένη υπενθύμιση **δεν** εμφανίζεται στο dialog εντός session (μόνο cold start· `batch 1/1` μετά από restart). Fix: `ref.invalidate` στο άνοιγμα ή `autoDispose`. Σειρά S255 (σοβαρότερο πρώτο): **F13 → F9 → F18 → F17**.
> S255 (F13 ✅ CLOSED 18/10/2026): **bulk-restore perf** — νέα `ItemNotifier.unarchiveMany(List<int> ids)` (SPoT orchestration **υπαρχουσών** κλήσεων: loop `updateItem(archived:false)` + `rescheduleForItem` → **1×** `refreshRecurringReminders` → **1×** `topUpHabitReminders(force:true)` → `finally` 1× invalidate· NEVER-THROW): N×3 → **3** global/heavy κλήσεις ανά bulk restore (S250: `created=180 took=6930ms`). Call-site: bulk-restore loop του `settings_archived_dialog` (1 σημείο). **Split S2 (cycle-free):** read/derived providers (`itemsByFolderStream`, `trashedItemsStream`, `FolderViewData`, `folderViewData`, `collectionEntriesCount`) → νέο **`lib/providers/items_query_provider.dart`** (ο `archivedItemsProvider` μένει στο `item_provider` — το invalidate-άρει ο `toggleArchive`/`unarchiveMany`· μονόδρομο import, 0 κύκλοι)· barrel +1 export ⇒ 0 αλλαγές σε features. Γρ.: `item_provider` 499→**432**· `items_query_provider` 103 (ΝΕΟ)· `settings_archived_dialog` 162→160. analyze clean + test **229/229** (0 tests άγγιζαν τα μετακινούμενα σύμβολα)· device test εκκρεμεί. **F13b (νέο, defer):** αντίστοιχο bulk-delete (το `_cascadeCollectionEntries` είναι private ⇒ μεγαλύτερο scope).
> S256 (F9 ✅ CLOSED 18/10/2026): **pop εκτός `build`** — `SettingsImportProgressDialogState` (`settings_contacts_dialogs.dart` 377→**402**): `build` **pure**· νέο `_popOnce(ImportResult?)` (S254 parity: `_popped` + `route.isCurrent` + root pop) από το `_startImport` **μετά** το await. + error net (`try/catch` → `DebugConfig.error` + **νέο** `AppErrors.contactsImportFailed` (`app_errors.dart` 96→97) + SnackBar **χωρίς** `backgroundColor` — parity με τα 5 sibling της ροής) + `SafeDialogBody` (S109 SPoT· `dialog.dart:916-922` απόδειξη: `scrollable:false` ⇒ content σε σκέτο `Flexible`· 0 padding ⇒ μηδενική οπτική αλλαγή). Απορρίφθηκαν: `addPostFrameCallback`+flag · `PopScope`/`isDraggingProvider` (back-blocking) · `DetailScreenMixin.safePop()` (λάθος base class + χωρίς `isCurrent`) · `ctx.mounted`-only (S253 PIN) · `AlertDialog(scrollable:true)` (όχι parity αρχείου). analyze clean + test **230/230** (229 + 1 νέο pure widget test `settings_import_progress_dialog_test.dart`: «ακριβώς ένα pop» μέσω `NavigatorObserver`· **contract/guard**, όχι red-on-old — βλ. oldsessions S256 «Ειλικρινή όρια»· **S258 (επιβεβαίωση με στοιχεία):** 4 triggers (2ο `pumpWidget` ίδιου δέντρου / theme / `MediaQuery` / `HeroControllerScope.controller` — ο Navigator εξαρτάται από αυτό: `navigator.dart:3959`) **δεν** ξανα-έτρεξαν τη σελίδα του route (`pageBuilds=1`, `stateBuilds=2`, 1 pop) ⇒ red-on-old **μη εφικτό** στο widget test· απόδειξη: `backups/s258_f9c_deadcode/f9_before_repro_diag{,2}_test.dart`). **Device test T1 ✅** (18/10/2026 — debug build που περιέχει το F9· ροή Ρυθμίσεις → Εισαγωγή επαφών με 3 νέες επαφές: **1×** `Settings: import done imported=3 skipped=0 errors=0`, **1×** pop, σύνοψη 3/0/0, **οι Ρυθμίσεις μένουν πίσω** (όχι Αρχική), **0** ERR/exceptions σε όλο το session· **T2 παραλείφθηκε** — παράθυρο import 313 ms, μη αξιόπιστο για adb· βλ. oldsessions S256 «Device test T1»). **F9c (νέο micro)** → §7.8.
> S257 (F18 ✅ CLOSED 19/10/2026): **φρέσκια λίστα «Παρελθουσών»** — `showPastRemindersDialog` (`settings_reminders_dialog.dart` 162→**167**): `ref.invalidate(pastPendingRemindersProvider)` **πριν** το `ref.read(...future)`. Reuse-first: ο μηχανισμός **υπάρχει ήδη** στο ίδιο αρχείο (`_deleteReminders` → `onApplied` invalidate, γρ. 29) — έλειπε **ένα trigger** (το άνοιγμα)· η λίστα είναι χρονικά εξαρτημένη (`getPastPending` = pending + `triggerAt < now` + `rruleIsNull`) **χωρίς DB write** (το `markSent` έχει **0 callers** — FLN χωρίς fire-callback) ⇒ cached non-autoDispose `FutureProvider` έμενε stale εντός session (μόνο cold start· `batch 1/1` μετά από restart, S254). Απορρίφθηκαν: `autoDispose` (κόντρα στη σύμβαση «no autoDispose»· εύθραυστο lifecycle με `ref.read` χωρίς listener· ακυρώνει το `:29`) · `pendingRemindersStreamProvider` (άλλο σύνολο: μελλοντικό `now..now+370d`· δεν εκπέμπει σε πέρασμα χρόνου χωρίς write) · απευθείας `getPastPending()` στο UI (R0 «καμία DB στο UI») · `dayTickProvider` (ημερήσια κοκκώδηση) · invalidate μέσα στο `refreshRecurringReminders`/`cleanupOldPending` (δεν καλύπτει «άνοιγμα→λήξη→άνοιγμα»). Idiom check: το codebase χρησιμοποιεί **μόνο** `ref.invalidate` (0× `ref.refresh`). analyze clean + test **230/230** (0 νέα tests — καμία υποδομή provider+Isar στο `test/`). **Device test ✅ PASS** (19/10/2026 — debug build του `0f289d9`· **1** process pid 15084· 1ο άνοιγμα dialog «(8)»/provider **10** → 2ο άνοιγμα «(9)»/provider **11**, μετά τη λήξη (11:01:00) της νέας id=2200 και +38s ⇒ **ξανα-εκτέλεση** του query· αποκλείστηκαν refresh/cleanup (μόνο διαβάζει/διαγράφει, `created 0`) και restart· 0 ERR· βλ. oldsessions S257 «Device test S257»). **F19 (νέο, defer):** `pendingRemindersProvider` (`reminder_provider.dart:13`) = **0 readers** (invalidate-άρεται ×5) και `pendingRemindersStreamProvider` (`:18`) = **0 readers, 0 invalidates** → dead providers· η αφαίρεση αγγίζει τη λίστα providers στο `supernote.md:597-598` (κανόνας #8) ⇒ θέλει ρητή εντολή.

> S258 (F9c ✅ CLOSED 19/10/2026): **αφαίρεση 2 νεκρών μελών** — `ImportProgress.status` (`contact_import_service.dart:39,45` + set 2× `:151,177` + dialog init `:221`) + `ImportResult.totalProcessed` (`:64`, 0 callers): 3 κατασκευές `ImportProgress` (2 service + 1 dialog) ⇒ `contact_import_service.dart` 401→**395** · `settings_contacts_dialogs.dart` 402→**400** · **0 αλλαγές** σε barrels/Isar (plain κλάσεις ⇒ 0 codegen)/tests. **micro:** διπλότυπο `// Fetch` ×2 (`settings_contacts_flow.dart:30-31`) → 1 (`247→246`). **Δ1b ΑΠΟΡΡΙΦΘΗΚΕ (τεκμηριωμένα):** απόπειρα αναβάθμισης του F9 test σε **red-on-old** — 4 triggers δεν ξανα-έτρεξαν τη σελίδα του route (`pageBuilds=1`, 1 pop) ⇒ μη εφικτό στο widget test· το test μένει **contract/guard** (η σημείωση S256 είναι **ακριβής**). analyze clean + test **230/230** (0 νέα tests). Commit `c2d4893`.

> S259 (F17 ✅ CLOSED 19/10/2026): **Slider σε δική του γραμμή** — `SettingsFontScaleTile` (`settings_tiles.dart:330-346`, 484→**479** γρ.): `Row[Expanded(Column[τίτλος,%]), Slider]` → `Column(start)[τίτλος, %, SizedBox(sm), Slider]` ⇒ ο τίτλος παίρνει **όλο** το πλάτος του tile (**296.7 dp**, 1 γραμμή σε 100% **και** 140%) αντί **104.7 dp** (portrait) / **136.3 dp** (landscape). **Αιτία (SDK):** σε `Row` το Slider παίρνει **μη φραγμένο** πλάτος ⇒ `computeDryLayout` = `_minPreferredTrackWidth` **144** (`slider.dart:1229`) + 2×**24** inset (`slider_parts.dart:243-249`) = **192 dp**· σε `Column` = πλήρες πλάτος, ύψος φυσικό 48 dp (όχι άπειρο — `flex.dart:881-897`). **0 νέα** widgets/αρχεία/tokens/strings (reuse μοτίβου ×3: `SettingsThemeTile:104-110` / `SettingsLockTimeoutTile:375-381`· **1** Slider σε όλη την app). Deltas (μη-υποβαθμίσεις): ύψος tile +~36 dp (scroll) · θέση thumb (`node` 620→~426 px @100%· κριτήριο = screenshot) · drag ~1.7× πιο ακριβές αλλά **ίδιες 7 τιμές** (`divisions: 6` + `_discretize` ⇒ ίδια DB). analyze clean + test **234/234** (**4 νέα** `settings_font_scale_tile_test.dart`: δομικό `RenderParagraph.constraints.maxWidth ≥ content` + σημασιολογικό ≥ intrinsic πλάτος «γραμματοσειράς» (probe με ίδιο style/scale path) · **red-on-old ✅ 4/4** με inlined παλιό layout: `maxWidth` = **104.69999999999999** / **136.3** = byte-identical με `ui_fs2/ui_fs3.xml`). Απορρίφθηκαν: μικρότερο slider (σπάει στο 140%) · συντομότερος τίτλος · `Wrap` · `ListTile.trailing` · bottom-sheet · νέο `SettingsSliderTile` (anti-SPoT). **Device pass T5 ✅ 19/10/2026** (M2007J20CG: portrait 100%/140% = **1 γραμμή**, tile 297/336 px · landscape = tablet 2-col με content **227.6 dp** ⇒ 140% = 2 γραμμές **στο κενό** — καμία τομή μέσα στη λέξη · όλο το εύρος 0.8–1.4 με **ίδιες διακριτές τιμές** · **persist** μετά kill/relaunch ✅ · **επαναφορά** 100% ✅ · 0 ERR/overflow). Commit `a707933`.

> **⏭️ Τρέχουσα λίστα εκκρεμοτήτων (μετά το device pass T5 — 19/10/2026):** **1. F13b** (perf) bulk-delete αντίστοιχο του F13 — το `_cascadeCollectionEntries` είναι private ⇒ μεγαλύτερο scope · **2. F19** (dead code) `pendingRemindersProvider`/`pendingRemindersStreamProvider` (`reminder_provider.dart:13,18`) = 0 readers — αγγίζει `supernote.md:597-598` ⇒ θέλει απόφαση · **3. Ανοιχτό:** P2#4 a11y device pass · P2#6 grid auto-height · micros F2/F3/F4 (§7.8· F9c ✅ CLOSED S258) · **4. P3/P5** Snooze UI (§7.3, θέλει spec) · B2.3 · DetailAppBar · stale TODOs ×7 (§8#12). **Git baseline:** κώδικας F9 = `5b05033` · F18 = `0f289d9` (**device test ✅ 19/10/2026**) · **S258 (F9c) = `c2d4893`** · **S259 (F17) = `a707933`** + docs `f9744bd` + device pass T5 (docs) · docs device test S257 = `cc356d0` · docs S258 smoke = `41c2f56`.
10. `take(10)` magic (`items_query_provider:64` — S255 split από `item_provider`).
11. §3.8 εκκρεμή χωρίς επαλήθευση: `if(!mounted)return` κενό · `✓` αντί `Icon` · `day/month/year` αντί intl · `DateTime.now()` σε build · `O(n²) block_editor` · `BlockTileWidget Stateful` (`:146-170`) · delete πάντα ορατό · `types` `📅` (`folder_create_sheet:28,33`) · stats journal/appointment (ασαφές) · `Colors.white/black`.
12. Stale scaffolding TODOs ×7 σε `models/` (`// TODO: Σελίδα προς Ανάπτυξη`) — απόφαση: διαγραφή ή υλοποίηση.
13. Accepted-by-design (0 κώδικα): `collection_detail` dialog-ctrls (§3.5:85) · main `0xFF1E1E2E` ×2 (§3.6:92).

### 💤 P5 — By-design / ασαφή / πιθανόν obsolete (καμία ενέργεια)
14. iOS parked ×2 (supernote `:474,493`) — Android-first.
15. 6-actions overflow (note_detail) — watch-only.
16. Zombie-overlap residual (S245) — αποδεκτός συμβιβασμός (dedup guards).
17. Αρχαίες σημειώσεις S~92 (oldsessions `:801`): SnackBar-orphan · stats/search-project — πιθανόν obsolete.
18. «reorder/dots/counts — θέλουν spec» (παλιό a11y session) — ασαφές.
