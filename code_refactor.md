# Φ4 — Οδηγός διόρθωσης ποιότητας σελίδων (τελικός, δεσμευτικός)

> **⚠️ ΠΑΓΩΜΕΝΟ ΩΣ ΠΡΟΣ ΤΙΣ ΕΚΚΡΕΜΟΤΗΤΕΣ (21/10/2026):** όλες οι ενότητες με λίστες/status (§3.x, §7, §8, §9, σημειώσεις S###) είναι **ιστορικό**. Οι εκκρεμότητες **υπάρχουν, ενημερώνονται και προστίθενται ΜΟΝΟ** στο **`error_list.md`**. Απαγορεύεται η προσθήκη/αλλαγή εκκρεμοτήτων εδώ — αν χρειαστεί διόρθωση, γίνεται στο `error_list.md` και (μετά το τέλος) συγχρονίζεται το παρόν.

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

## 3. Διορθώσεις bugs — ιστορικό (αρχειοθετημένο)

> **⚠️ ΙΣΤΟΡΙΚΟ (24/10/2026):** το περιεχόμενο των §3/§7/§8/§9 **αφαιρέθηκε** στο sync του τελικού κλεισίματος (E26 βήμα 2 · κανόνας 9 — καμία διπλή λίστα). Δεν χάθηκε: πλήρες αντίγραφο στο `backups/s273_docs_sync/code_refactor.md`.
> - **Τι διορθώθηκε/κλείστηκε:** `oldsessions.md` κεφάλαια **S141–S273** (κυρίως S253–S263 Φ4c, S270–S273).
> - **Ενεργές εκκρεμότητες:** **`error_list.md`** (μοναδική πηγή — §1 P1–P4, §6 ομάδες) · **πρόοδος:** `oldsessions.md`.
> - Οι κανόνες **R0–R4** (§1), ο χάρτης splits (§2) και τα βήματα υλοποίησης (§4) παραμένουν ως δεσμευτικό ιστορικό πλαίσιο.

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

## 7–9. Ανοιχτά / οδικός χάρτης / τρέχουσα κατάσταση — ιστορικό (αρχειοθετημένο)

> **⚠️ ΙΣΤΟΡΙΚΟ (24/10/2026):** τα §7 (ανοιχτά refactor), §8 (οδικός χάρτης P1–P5, 17/10) και §9 (canonical 19/10 — P2–P5 + S262-b) **αντικαταστάθηκαν** από την παρούσα παραπομπή, γιατί ήταν λίστες εκκρεμοτήτων που ζουν πλέον **μόνο** στο `error_list.md` (κανόνας 9).
> - **Ενεργά:** `error_list.md` §1 (P1–P4) + §6 (ομάδες υλοποίησης).
> - **Ιστορικό κλεισίματος:** `oldsessions.md` S253–S273.
> - **Πλήρες αντίγραφο προ-συγχρονισμού:** `backups/s273_docs_sync/code_refactor.md`.
