# SuperNote — Πλήρης Τεκμηρίωση Εφαρμογής

## Στοιχεία Έργου

| Πεδίο | Τιμή |
|---|---|
| Όνομα | super_note (SuperNote) |
| Version | 1.0.2+2 |
| Flutter | 3.41.9 (stable) |
| Dart | 3.11.5 |
| GitHub | https://github.com/aristos62-bit/note |
| Τοπικό path | `C:\Users\Vaggelis\Flutter Projects\super_note` |
| IDE | Android Studio Panda 4 \| 2025.3.4 Patch 1 |
| Multi-platform | Android, iOS, Linux, macOS, Windows, Web (web not supported — Isar) |
| Γλώσσα UI | Ελληνικά (με δυνατότητα English/Auto) |

---

## Τεχνολογίες & Dependencies

### Database
- **Isar v3** (`^3.1.0+1`) — embedded NoSQL DB, annotations `@Collection()`, `@Index()`, `@Enumerated()`
- `isar_flutter_libs` + `isar_generator` + `build_runner` — code generation (`*.g.dart`)
- `path_provider` — app documents directory για DB file

### State Management
- **Riverpod** (`flutter_riverpod ^2.5.1`, `riverpod ^2.5.1`)
  - Providers: `Provider`, `StateProvider`, `FutureProvider`, `StreamProvider`, `AsyncNotifierProvider`
  - Family providers: `FutureProvider.family`, `StreamProvider.family`, `AsyncNotifierProviderFamily`
  - No `autoDispose` used anywhere

### Routing
- **go_router** (`^17.1.0`) — `ShellRoute` with `GoRouter`, declarative routing
- Custom page transitions: `AppTransitions.fade()`, `.slideRight()`, `.slideUp()`
- `NavigatorObserver` (`_RouterObserver`) for debug logging

### Notifications
- `flutter_local_notifications` (`^17.2.2`)
- `timezone` (`^0.9.4`) — timezone-aware scheduling
- Δεν χρησιμοποιείται `flutter_native_timezone` — manual timezone setup στο `NotificationService`

### Files & Import
- `file_picker` (`^8.0.7`) — SAF file picker/save
- `mime` (`^1.0.5`) — MIME type lookup
- `path` (`^1.9.0`) — path manipulation

### Contacts
- `flutter_contacts` (`^2.1.0`) — read device contacts

### Other
- `intl` (`^0.20.2`) — date formatting (Greek locale `'el'`)
- `uuid` (`^4.4.0`) — unique IDs
- `rxdart` (`^0.27.7`) — reactive extensions
- `reorderable_grid` (`^1.0.13`) — grid with drag & drop
- `share_plus` (`^12.0.2`) — share functionality
- `collection` (`^1.18.0`) — collection utilities

---

## Αρχιτεκτονική Project

```
lib/
├── main.dart                     — Entrypoint, init, ProviderContainer setup
├── core/
│   ├── core.dart                 — Barrel export
│   ├── router/
│   │   └── app_router.dart       — GoRouter + ShellRoute + AppShell
│   └── theme/
│       ├── app_spacing.dart      — Spacing, Radius, Shadows, Duration, Icon sizes
│       ├── app_theme.dart        — ThemeData light/dark builder
│       └── ui_tokens.dart        — ColorsUI, TypographyUI, Context extensions
│   └── utils/
│       ├── date_utils.dart       — Date formatting (relative, due, journal, grouping)
│       ├── debug_config.dart     — Log categories (startup, db, nav, provider, notif, error)
│       ├── string_utils.dart     — String operations
│       ├── responsive.dart       — ResponsiveLayout, breakpoints
│       ├── transitions.dart      — AppTransitions (fade, slideRight, slideUp)
│       ├── recurrence_utils.dart — Recurrence UI helpers
│       └── reminder_picker.dart  — Reminder time picker
├── models/
│   ├── models.dart               — Barrel export
│   ├── item.dart                 — Item collection (core entity)
│   ├── item_block.dart           — ItemBlock (rich content blocks)
│   ├── item_property.dart        — ItemProperty (EAV key-value)
│   ├── item_tag.dart             — ItemTag (M:N join)
│   ├── tag.dart                  — Tag collection
│   ├── folder.dart               — Folder collection
│   ├── workspace.dart            — Workspace collection
│   ├── relation.dart             — Relations between items
│   ├── reminder.dart             — Reminder collection
│   ├── attachment.dart           — Attachment (files)
│   ├── user.dart                 — User collection
│   ├── device.dart               — Device collection
│   ├── app_settings.dart         — AppSettings singleton
│   └── recurrence.dart           — Recurrence (not Isar, plain Dart class)
├── providers/
│   ├── providers.dart            — Barrel export
│   ├── db_provider.dart          — SuperNoteHelper instance
│   ├── workspace_provider.dart   — Workspaces, activeWorkspaceId
│   ├── folder_provider.dart      — Folders stream, selectedFolderId
│   ├── item_provider.dart        — Items CRUD, streams, pinned/favorites
│   ├── block_provider.dart       — ItemBlocks CRUD, streams
│   ├── property_provider.dart    — ItemProperties CRUD
│   ├── tag_provider.dart         — Tags CRUD
│   ├── habit_provider.dart       — Habit stats stream
│   ├── task_provider.dart        — Tasks with details, subtasks
│   ├── reminder_provider.dart    — Reminders CRUD
│   ├── attachment_provider.dart  — Attachments CRUD
│   ├── settings_provider.dart    — Settings CRUD, derived providers
│   └── ui_provider.dart          — UI state (selectedFolder, viewMode, isDragging)
├── services/
│   ├── services.dart             — Barrel export
│   ├── notification_service.dart — flutter_local_notifications init
│   ├── reminder_scheduler.dart   — Schedule/cancel platform notifications
│   ├── search_service.dart       — Full-text search
│   ├── habit_service.dart        — Habit stats, streak, progress
│   ├── attachment_service.dart   — File pick + save + delete
│   ├── backup_service.dart       — Export/import Isar DB
│   ├── contact_import_service.dart — Import device contacts
│   └── share_service.dart        — Share items
├── helpers/
│   ├── super_note_helper.dart    — Singleton + sub-repositories (ItemRepository, etc.)
│   └── item_color_helper.dart    — Background/text colors per ItemType
├── features/
│   ├── home/
│   │   ├── home.dart             — Barrel
│   │   ├── home_screen.dart      — Main home with pinned/favorites/recent
│   │   ├── home_folder_view.dart — Folder-specific view
│   │   └── folder_browser_screen.dart — Browse all folders
│   ├── notes/
│   │   ├── notes.dart            — Barrel
│   │   ├── note_list_screen.dart — All notes list
│   │   └── note_detail_screen.dart — Note editor with blocks
│   ├── tasks/
│   │   ├── tasks.dart            — Barrel
│   │   ├── task_list_screen.dart — Tasks with subtasks, due dates
│   │   └── task_detail_screen.dart — Task detail editor
│   ├── habits/
│   │   ├── habits.dart           — Barrel
│   │   ├── habit_list_screen.dart — Habits with streak calendar
│   │   └── habit_detail_screen.dart — Habit editor (goal, recurrence, reminders)
│   ├── calendar/
│   │   ├── calendar.dart         — Barrel
│   │   ├── calendar_screen.dart  — Month view
│   │   └── event_detail_screen.dart — Event editor
│   ├── contacts/
│   │   ├── contacts.dart         — Barrel
│   │   ├── contact_list_screen.dart — Contacts list (imported + manual)
│   │   └── contact_detail_screen.dart — Contact editor
│   ├── journal/
│   │   ├── journal.dart          — Barrel
│   │   ├── journal_list_screen.dart — Journal entries by date
│   │   └── journal_detail_screen.dart — Journal entry editor
│   ├── collections/
│   │   ├── collections.dart      — Barrel
│   │   ├── collections_screen.dart — All collections
│   │   ├── collection_detail_screen.dart — Single collection
│   │   └── collection_entries_screen.dart — Collection items
│   ├── appointments/
│   │   ├── appointments.dart     — Barrel
│   │   ├── appointment_list_screen.dart — Appointments list
│   │   └── appointment_detail_screen.dart — Appointment editor
│   ├── search/
│   │   ├── search.dart           — Barrel
│   │   └── search_screen.dart    — Full-text search UI
│   ├── settings/
│   │   ├── settings.dart         — Barrel
│   │   └── settings_screen.dart  — All settings (theme, colors, data)
│   └── trash/
│       └── trash_screen.dart     — Soft-deleted items
└── shared/
    ├── mixins/
    │   ├── detail_screen_mixin.dart — Central mixin for all detail screens
    │   └── folder_auto_select_mixin.dart — Auto-select folder on screen load
    └── widgets/
        ├── widgets.dart          — Barrel export
        ├── item_card.dart        — Unified card widget for all item types
        ├── responsive_item_list.dart — Responsive list/grid with ItemCards
        ├── item_list_screen.dart  — Generic item list screen
        ├── item_list_embedded.dart — Embedded item list
        ├── reorderable_item_list.dart — Drag-to-reorder list
        ├── draggable_item_wrapper.dart — LongPressDraggable wrapper
        ├── draggable_folder_selector.dart — Folder chips with drag target
        ├── block_editor_widget.dart — Rich text block editor (notes)
        ├── content_field_widget.dart — Debounced text field
        ├── empty_state.dart       — Empty/error/search state widgets
        ├── confirm_dialog.dart    — Responsive confirm dialog/sheet
        ├── folder_selector.dart   — Folder picker
        ├── item_type_icon.dart    — Icon per ItemType
        ├── priority_badge.dart    — Priority indicator
        ├── tag_chip.dart          — Tag display chip
        ├── tag_picker_sheet.dart  — Tag selection sheet
        ├── reminder_section.dart  — Reminder date/time picker
        ├── view_mode_toggle.dart  — Pinned/Favorites/All toggle
        ├── archive_helper.dart    — Central archive/unarchive function
        └── reorder_handle.dart    — Drag handle icon
```

---

## Core Entity: Item

Το `Item` είναι η κεντρική entity. **Όλα τα objects της εφαρμογής είναι Items** — notes, tasks, events, contacts, habits, projects, goals, finance, bookmarks, journals, appointments, checklists, knowledge.

### ItemType enum (13 types)
```
note, task, event, contact, habit, project, goal, finance, bookmark, journal, appointment, checklist, knowledge
```

### ItemStatus enum
```
active, done, cancelled, archived, draft, inProgress
```

### ItemPriority enum
```
none(0), low(1), medium(2), high(3), urgent(4)
```

### Item fields
| Field | Type | Notes |
|---|---|---|
| id | `Id` (int) | Isar autoIncrement |
| workspaceId | `int` @Index | Multi-workspace |
| folderId | `int?` @Index | Optional folder |
| type | `ItemType` @Index @Enumerated | Discriminator |
| title | `String?` @Index | FTS searchable |
| icon | `String?` | Emoji/icon ref |
| color | `String?` | Hex "#FF5733" |
| pinned | `bool` @Index | |
| archived | `bool` @Index | |
| favorite | `bool` @Index | |
| priority | `ItemPriority` @Enumerated | ordinal |
| status | `ItemStatus` @Index @Enumerated | |
| sortOrder | `double` | For reordering |
| pinnedOrder | `double?` | Pinned sort |
| favoriteOrder | `double?` | Favorite sort |
| templateId | `int?` | Template source |
| createdAt | `DateTime` @Index | |
| updatedAt | `DateTime?` | |
| deletedAt | `DateTime?` | Soft delete |
| syncedAt | `DateTime?` | |
| localVersion | `int` | Optimistic locking |
| serverVersion | `int?` | |
| isDirty | `bool` @Index | Needs sync |

### Computed getters
- `isDeleted` → `deletedAt != null`
- `isVisible` → `deletedAt == null && !archived`

---

## Secondary Models

### ItemBlock (rich content blocks per item)
- 21 BlockTypes: text, heading1-3, checklist, bulletList, numbered, image, file, link, quote, code, divider, table, bookmark, callout, toggle, embed, mention, formula
- Fields: `itemId`, `parentBlockId` (nesting), `text`, `checked`, `url`, `filePath`, `order`, `metadata` (JSON), timestamps, sync
- Stream: `blocksStreamProvider(itemId)`

### ItemProperty (EAV — Entity-Attribute-Value)
- 16 PropertyTypes: text, number, date, boolean, url, email, phone, currency, percent, rating, select, multiSelect, location, duration, color, json
- Key-value per item: `itemId + key` unique
- Typed helpers: `dateValue`, `numberValue`, `boolValue`, `displayValue`
- Stream: `itemPropertiesProvider(itemId)`

### Folder
- Tree hierarchy: `parentFolderId`, `workspaceId`, `sortOrder`
- `isSystem` flag — protected from deletion (default "Γενικά" folder)
- Stream: `foldersStreamProvider`

### Workspace
- Multi-workspace support, `isDefault`, `sortOrder`
- Default: "Προσωπικός Βοηθός"

### Reminder
- RRULE support (iCalendar standard)
- Status: pending, sent, dismissed, snoozed
- `parentReminderId` for cascade delete
- `notificationId` for platform notification management

### Tag + ItemTag
- M:N relationship via ItemTag join table
- `usageCount` for sorting by popularity

### Relation
- Item connections: parent, child, related, blocks, blockedBy, references, duplicate, linkedTo

### Attachment
- File metadata: `localPath`, `mimeType`, `fileSize`, `thumbnailPath`
- Image/video/audio detection: `isImage`, `isVideo`, `isAudio`

### Recurrence (NOT Isar — plain Dart class)
- Types: daily, weekly, monthly, yearly, custom
- `getPeriodStart()`, `nextPeriodStart()`, `nextOccurrence()`
- `toRRULE()` / `describe()` (Greek text)
- Used by HabitService

### AppSettings (singleton, id=1)
- Theme: `AppTheme.system/light/dark`
- Language: `AppLanguage.greek/english/auto`
- Font scale, default view, archived/deleted visibility
- Notifications toggle, sound, vibration
- Sync settings (syncEnabled, wifiOnly, interval)
- `defaultWorkspaceId`, `preferredFolderId`
- `itemTypeColorsJson` — JSON map `{"typeName":"#RRGGBB"}` for per-type card colors
- `hasCompletedOnboarding`

---

## Database Layer — SuperNoteHelper (Singleton)

### Initialization (`lib/helpers/super_note_helper.dart`)
```dart
await SuperNoteHelper.init();  // στο main()
final db = SuperNoteHelper.instance;
```

### Sub-repositories
| Repository | Key Methods | Stream Methods |
|---|---|---|
| `ItemRepository` | create, getById, getByWorkspace, getByFolder, getPinned, getFavorites, search, update, softDelete, restore, hardDelete, reorder, reorderPinned, reorderFavorites, reorderCombined, count | watchByWorkspace, watchByFolder, watchPinnedByWorkspace, watchFavoritesByWorkspace, watchDeletedByWorkspace, watchById |
| `BlockRepository` | create, getByItem, getChildren, updateText, toggleCheck, delete, reorder | watchByItem |
| `PropertyRepository` | set (upsert), get, getValue, getAll, delete + typed helpers (setDate, setNumber, setBool, setCurrency) | — |
| `TagRepository` | createOrGet, addToItem, removeFromItem, getForItem, getItemsWithTag, getAll | — |
| `RelationRepository` | create, getFrom, getTo, getRelatedItems, delete | — |
| `ReminderRepository` | create, getPending, getForItem, markSent, snooze, delete, cleanupOldPending, getPastPending, updateRootReminderForItem | watchPending |
| `FolderRepository` | create, getByWorkspace, delete, getById, update, reorder | watchByWorkspace, watchById |
| `WorkspaceRepository` | create, getAll, getDefault | — |
| `AttachmentRepository` | create, getForItem, getById, delete | — |
| `SettingsRepository` | get, update | watch (object id=1) |

---

## Services Layer

### NotificationService (`lib/services/notification_service.dart`)
- Singleton pattern
- `init()` — initialize flutter_local_notifications
- `requestPermission()` — Android notification permission
- `showNotification(id, title, body, payload)` — display notification
- `cancel(id)`, `cancelAll()` — cancel notifications
- `getLaunchPayload()` — cold start payload
- `onNotificationTap` — static callback for tap handling (set in `main()`)

### ReminderScheduler (`lib/services/reminder_scheduler.dart`)
- `scheduleAll()` — schedule all pending reminders
- `scheduleReminder(Reminder)` — single reminder scheduling
- `cancelAllForItem(int itemId)` — cancel all for an item
- `refreshRecurringReminders()` — re-schedule recurring reminders
- `debouncedRefreshRecurringReminders()` — with debounce for app resume

### HabitService (`lib/services/habit_service.dart`)
- `getStats(int habitId)` → `HabitStats` (streak, bestStreak, completedCount, dailyProgress, progressPercent, todayTimeProgress)
- `incrementProgress(int habitId)`, `decrementProgress(int habitId)`
- `incrementByTime(int habitId, String time)`, `decrementByTime(int habitId, String time)` — for daily habits with times
- `markCompleted(int habitId)` — alias for incrementProgress
- `setGoal()`, `setUnit()`, `setRecurrence()`, `setReminderTime()`, `setReminderTimes()`
- Streak calculation: `_calculateStreak()`, `_countCompletedPeriods()`
- Period awareness: respects recurrence type (daily/weekly/monthly/yearly)

### ContactImportService (`lib/services/contact_import_service.dart`)
- `requestPermission()` — FlutterContacts permission
- `fetchContacts()` — getAll with all properties
- `importContacts()` → `ImportResult` (imported/skipped/errors counts)
- Duplicate detection: same name (case-insensitive) or same phone
- `ContactField` enum: name, phones, email, company, website, address, birthday, notes, photo
- Marker `_imported` property for identifying imported contacts
- `getImportedContactIds()`, `deleteImported(Set<int>)`

### AttachmentService (`lib/services/attachment_service.dart`)
- `pickAndSave(itemId, blockId, allowedExtensions)` → `Attachment?`
- `saveFile(itemId, sourcePath, blockId)` → `Attachment`
- `delete(attachmentId)` — file + DB deletion
- Internal: copies to `attachments/` subdirectory in app documents

### BackupService (`lib/services/backup_service.dart`)
- `export()` — reads Isar DB file, saves via SAF FilePicker
- `import({fromPath})` — closes DB, copies file, re-initializes
- Backup file name: `super_note_backup_<timestamp>.isar`

### SearchService (`lib/services/search_service.dart`)
- Full-text search on Item title: `search(query, workspaceId)` → `List<Item>`
- Uses Isar `titleContains()` filter (case-insensitive)

### ShareService (`lib/services/share_service.dart`)
- Uses `share_plus` package

---

## Providers Layer (Riverpod)

### Database Provider
```
dbProvider → Provider<SuperNoteHelper>
```

### Workspace Providers
```
workspacesProvider → FutureProvider<List<Workspace>>
defaultWorkspaceProvider → FutureProvider<Workspace?>
activeWorkspaceIdProvider → StateProvider<int?>
workspaceNotifierProvider → AsyncNotifierProvider<WorkspaceNotifier, List<Workspace>>
```

### Folder Providers
```
foldersStreamProvider → StreamProvider<List<Folder>>         // root folders, real-time
subFoldersStreamProvider → StreamProvider.family<List<Folder>, int>  // children
foldersProvider → FutureProvider<List<Folder>>
folderByIdProvider → StreamProvider.family<Folder?, int>
selectedFolderIdProvider → StateProvider<int?>               // shared state
folderNotifierProvider → AsyncNotifierProvider<FolderNotifier, List<Folder>>
```

### Item Providers
```
activeItemTypeFilterProvider → StateProvider<ItemType?>
showArchivedProvider → StateProvider<bool>
itemsStreamProvider → StreamProvider<List<Item>>             // filtered items
itemsByFolderProvider → FutureProvider.family<List<Item>, int>
pinnedItemsProvider → FutureProvider<List<Item>>
favoriteItemsProvider → FutureProvider<List<Item>>
itemByIdProvider → FutureProvider.family<Item?, int>
itemStreamProvider → StreamProvider.family<Item?, int>
itemCountProvider → FutureProvider.family<int, ItemType>
itemNotifierProvider → AsyncNotifierProvider<ItemNotifier, List<Item>>

// Dedicated high-performance streams:
itemsByFolderStreamProvider → StreamProvider.family<List<Item>, int>
trashedItemsStreamProvider → StreamProvider<List<Item>>
pinnedItemsStreamProvider → StreamProvider<List<Item>>
pinnedAndFavoritesProvider → StreamProvider<({List<Item> pinned, List<Item> favorites})>

// Composite:
folderViewDataProvider → StreamProvider.family<FolderViewData, int>
```

### Block Providers
```
blocksStreamProvider → StreamProvider.family<List<ItemBlock>, int>
blocksProvider → FutureProvider.family<List<ItemBlock>, int>
childBlocksProvider → FutureProvider.family<List<ItemBlock>, int>
blockNotifierProvider → AsyncNotifierProviderFamily<BlockNotifier, List<ItemBlock>, int>
```

### Property Providers
```
itemPropertiesProvider → FutureProvider.family<List<ItemProperty>, int>
itemPropertyProvider → FutureProvider.family<ItemProperty?, (int, String)>
dueDateProvider → FutureProvider.family<DateTime?, int>
propertyNotifierProvider → AsyncNotifierProviderFamily<PropertyNotifier, List<ItemProperty>, int>
```

### Tag Providers
```
tagsProvider → FutureProvider<List<Tag>>
itemTagsProvider → FutureProvider.family<List<Tag>, int>
itemsByTagProvider → FutureProvider.family<List<Item>, int>
tagNotifierProvider → AsyncNotifierProvider<TagNotifier, List<Tag>>
```

### Habit Providers
```
habitStreamProvider → StreamProvider.family<Item?, int>
habitStatsProvider → FutureProvider.family<HabitStats, int>  // invalidates on habitStreamProvider change
```

### Task Providers
```
tasksStreamProvider → StreamProvider<List<Item>>             // only ItemType.task
tasksWithDetailsProvider → StreamProvider<List<TaskWithDetails>>  // Task + dueDate + tags + subtasks
subtasksStreamProvider → StreamProvider.family<List<Item>, int>   // from cache
```

### Reminder Providers
```
pendingRemindersProvider → FutureProvider<List<Reminder>>
pendingRemindersStreamProvider → StreamProvider<List<Reminder>>
itemRemindersProvider → FutureProvider.family<List<Reminder>, int>
reminderNotifierProvider → AsyncNotifierProviderFamily<ReminderNotifier, List<Reminder>, int>
```

### Attachment Providers
```
attachmentsProvider → FutureProvider.family<List<Attachment>, int>
attachmentNotifierProvider → AsyncNotifierProviderFamily<AttachmentNotifier, List<Attachment>, int>
```

### Settings Providers
```
settingsStreamProvider → StreamProvider<AppSettings?>        // real-time
settingsProvider → FutureProvider<AppSettings>
settingsNotifierProvider → AsyncNotifierProvider<SettingsNotifier, AppSettings>
appThemeProvider → Provider<AppTheme>
onboardingCompleteProvider → Provider<bool>
preferredFolderIdProvider → Provider<int?>
itemTypeCardColorOverrideProvider → Provider.family<Color?, ItemType>
```

### UI State Providers
```
homeSelectedFolderProvider → StateProvider<int?>
listViewModeProvider → StateProvider<ListViewMode>           // pinned / favorites / all
isDraggingProvider → StateProvider<bool>                     // blocks back gesture during drag
```

---

## Routing

### Route Table (GoRouter + ShellRoute)
```
/               → HomeScreen
/notes          → NoteListScreen
/notes/:id      → NoteDetailScreen
/tasks          → TaskListScreen
/tasks/:id      → TaskDetailScreen
/appointments   → AppointmentListScreen
/appointments/:id → AppointmentDetailScreen
/settings       → SettingsScreen
/habits         → HabitListScreen
/habits/:id     → HabitDetailScreen
/calendar       → CalendarScreen
/calendar/:id   → EventDetailScreen
/collections    → CollectionsScreen
/collections/:id → CollectionDetailScreen
/journal        → JournalListScreen
/journal/:id    → JournalDetailScreen
/contacts       → ContactListScreen
/contacts/:id   → ContactDetailScreen
```

### Static route helpers (`AppRoutes` class)
```dart
AppRoutes.note(id), .task(id), .habit(id), .event(id), .appointment(id),
.journal_(id), .contact(id), .collection(id)
```

### Navigation
- `context.go(path)` — replace current (shell nav uses this)
- `context.push(path)` — push new route
- `context.pop()` — go back
- `context.go(AppRoutes.home)` — error fallback

### App Shell (`_AppShell`)
- Mobile: scrollable bottom nav with 10 items (Αρχική, Σημειώσεις, Εργασίες, Συνήθειες, Συμβάντα, Ημερολόγιο, Επαφές, Συλλογές, Ραντεβού, Ρυθμίσεις)
- Tablet: `NavigationRail` (scrollable if needed)
- Route path matching for active tab
- Home tap resets `homeSelectedFolderProvider`

### Page Transitions
- `AppTransitions.fade(state, child)` — standard navigation
- `AppTransitions.slideRight(state, child)` — detail screens
- `AppTransitions.slideUp(state, child)` — settings, event detail

---

## Core Theme System

### ColorsUI
- All colors defined as static const for light/dark
- Semantic getters: `getPrimary(b)`, `getBackground(b)`, `getSurface(b)`, etc.
- Item type colors: `itemTypeColor(ItemType, Brightness)` — per-type icon/card accent
- Priority colors: `priorityColor(ItemPriority, Brightness)`
- Streak colors: `streakColor(int streak, Brightness)` — gradient orange→red
- Accessibility: `getAccessibleTextColor(Color bg)`, `hasGoodContrast(foreground, background)`
- WCAG contrast ratio calculation

### TypographyUI
- Full Material 3 type scale: display, headline, title, label, body
- Editor-specific: editorBody, editorH1/H2/H3, editorCode
- Specialized: currencyLarge/Medium/Small, streakNumber
- Greek-optimized (line heights, font features)

### Context Extensions (`ThemeContextX`)
- Colors: `context.cPrimary`, `context.cBg`, `context.cCard`, `context.cText`, etc.
- Typography: `context.h1`, `context.bodyMd`, `context.titleLg`, etc.
- Special: `context.itemTypeColor(type)`, `context.priorityColor(p)`
- All theme-aware (auto light/dark)

### Spacing System
- `Spacing` class: xxs(2) → xxxl(64), semantic aliases (pagePadding, cardPadding, etc.)
- `AppRadius`: xs(4) → full(999), semantic (card, button, chip, dialog)
- `AppShadows`: card, elevated, fab per brightness
- `AppDuration`: instant, fast(150ms), normal(250ms), slow(400ms)
- `AppIconSize`: xs(14) → xxl(64)

---

## Shared Mixins

### DetailScreenMixin (used by ALL detail screens)
- `_isSaving` gate — prevents double-save
- `_disposeGuard` — safety net: auto-deletes empty new items on screen dismiss
- `mounted` checks after every async gap
- `executeSave(saveFn)` → bool — empty title check, try-catch, SnackBar on error
- `executeSaveOrDelete(saveFn, deleteFn?)` — for back button: empty+new → delete
- `safePop()`, `showSnackBar()`, `showConfirm()`

### FolderAutoSelectMixin
- `tryAutoSelectFolder()` — runs in build(): auto-selects folder from settings or system folder
- `onUserSelectFolder()` — marks explicit user selection, updates `selectedFolderIdProvider`
- `userExplicitlySelected` flag — prevents override after user choice

---

## Key Shared Widgets

### ItemCard (`lib/shared/widgets/item_card.dart`)
- Unified card for ALL item types
- Props: `Item item`, `Color? customBackgroundColor`, `VoidCallback? onTap`, `Widget? trailing`
- Background: `customBackgroundColor ?? backgroundColorForType(item.type)`
- Shows: icon, title, subtitle (type label + date), trailing actions
- Wrapped in `DraggableItemWrapper` for drag-to-folder

### ResponsiveItemList (`lib/shared/widgets/responsive_item_list.dart`)
- Adapts: list on mobile, grid on tablet/desktop
- `ItemCardBuilder` callback — passes `customBackgroundColor` via provider
- DragTarget integration for folder drop

### DraggableItemWrapper
- `LongPressDraggable<int>` with 400ms delay
- Haptic feedback on drag start, `isDraggingProvider` management
- Feedback widget with elevation shadow

### DraggableFolderSelector
- Horizontal scrollable folder chips
- `DragTarget<int>` — accepts item drops for folder reassignment
- Visual feedback (border color change) on drag over
- Updates `selectedFolderIdProvider`

### BlockEditorWidget
- Rich text editor for notes: text, headings, checklists, bullet/numbered lists, quote, code
- Auto-delete empty text blocks
- Debounced text saving (500ms)
- `ContentFieldWidget` — shared debounced text field with auto-delete on focus loss

### ConfirmDialog
- Responsive: bottom sheet on mobile, dialog on tablet/desktop
- Pre-built: `delete()`, `archive()`, `discardChanges()` + generic `show()`
- Destructive mode (red confirm button)

### EmptyState
- `EmptyState.forType(ItemType, onAction)` — auto icon + message per type
- `EmptyState.search(query)` — search-specific
- `EmptyState.error(message, onRetry)` — error state with retry
- Compact mode for embedded use

### ArchiveHelper
- Central function for archive/unarchive with consistent UX
- Archive: confirm dialog → toggle → SnackBar → pop
- Unarchive: no confirm → toggle → SnackBar → stay

---

## Features — Screen Overview

### HomeScreen (`/`)
- Greeting, pinned items, favorites, recent items
- Folder selector (DraggableFolderSelector) at top
- `FolderViewData` provider for composite data
- `_PinnedFavoritesSection` — isolated ConsumerStatefulWidget
- `_SquareItemCard`, `_FolderItemCard` — specialized cards

### NoteListScreen (`/notes`) + NoteDetailScreen (`/notes/:id`)
- Full block editor (BlockEditorWidget) with multiple block types
- Auto-save, debounced text fields
- DetailScreenMixin for lifecycle management

### TaskListScreen (`/tasks`) + TaskDetailScreen (`/tasks/:id`)
- `tasksWithDetailsProvider` → `TaskWithDetails` (task + dueDate + tags + parentId + subtasks)
- Subtasks computed from cache (no extra DB queries)
- `_TaskCard` — one widget per task with all detail

### HabitListScreen (`/habits`) + HabitDetailScreen (`/habits/:id`)
- `habitStatsProvider` → `HabitStats` (streak, calendar, progress)
- Weekly streak calendar (Mon-Sun)
- Time-based daily habits (multiple times per day)
- Rich habit editor: goal, unit, recurrence (daily/weekly/monthly/yearly), reminder times

### CalendarScreen (`/calendar`) + EventDetailScreen (`/calendar/:id`)
- Month view with event dots
- Event creation/editing with date/time pickers

### ContactListScreen (`/contacts`) + ContactDetailScreen (`/contacts/:id`)
- Two sources: manually created (ItemType.contact) + imported (ContactImportService)
- Imported contacts have `_imported` property marker
- `_DraggableContactTile` with drag support
- Dedicated fields: phones, email, company, website, address, birthday, notes, photo

### JournalListScreen (`/journal`) + JournalDetailScreen (`/journal/:id`)
- Entries grouped by date headers
- Journal-specific formatting (full date display)
- Rich text editor via blocks

### CollectionsScreen (`/collections`) + CollectionDetailScreen + CollectionEntriesScreen
- Collections are `ItemType.project` items
- `CollectionsScreen`: grid of collection cards with item count
- `CollectionDetailScreen`: header + list of entries
- Custom color already uses `customColor ?? backgroundColorForType(ItemType.project)`

### AppointmentListScreen (`/appointments`) + AppointmentDetailScreen (`/appointments/:id`)
- Appointments (ItemType.appointment)
- Date/time scheduling

### SearchScreen (`/search`)
- Full-text search on Item.title via SearchService
- EmptyState.search for no results

### SettingsScreen (`/settings`)
- Theme (System/Light/Dark), accent color
- Font scale slider
- Default view, language
- Notification toggles
- Data management: backup export/import
- Per-type card color picker (two-level: 19 Material color families → 10 shades)
- Visible types filtered: note, task, event, contact, habit, journal, appointment (hidden: goal, bookmark, finance, checklist, knowledge)

### TrashScreen
- Soft-deleted items (Item.deletedAt != null)
- Restore or permanent delete

---

## Color System for Cards

### Default colors (per ItemType)
Defined in `item_color_helper.dart`:
```
note:       light #FFF0B5  / dark Colors.yellow.shade300
journal:    light #E0C0FF  / dark Colors.purple.shade400
task:       light #D0F0C0  / dark Colors.blue.shade600
habit:      light #FFD6A5  / dark Colors.green.shade100
event:      light #B8D9FF  / dark Colors.orange.shade400
appointment: light #D0F0C0 / dark Colors.green.shade400
contact:    light #E0D0C0  / dark Colors.cyanAccent.shade100
knowledge:  light #B2DFDB  / dark Colors.teal.shade400
project:    light #B8D9FF  / dark Colors.green.shade800
```

### Custom overrides (Settings)
- Stored as JSON in `AppSettings.itemTypeColorsJson`: `{"habit":"#0000FF","task":"#FF0000"}`
- Two-level picker: 19 Material color families → 10 shades (shade50–shade900)
- `itemTypeCardColorOverrideProvider.family<Color?, ItemType>`
- All card locations pass override: `customBackgroundColor ?? backgroundColorForType(item.type)`

---

## Error Handling Status

### Unprotected operations (no try-catch):
- **HIGH** - `attachment_service.dart`: 5 file I/O + 1 DB write (lines 45-78)
- **MEDIUM** - `contact_import_service.dart`: JSON parsing (line 38), file ops (55-64)
- **MEDIUM** - `backup_service.dart`: partial failure in single try-catch (leaves partial files)
- **MEDIUM** - `reminder_scheduler.dart`: `cancelAll()`, `pendingNotificationRequests()`
- **MEDIUM** - Most DB operations in SuperNoteHelper repositories have zero try-catch

### Protected:
- `item_color_helper.dart`: `_parseHex()` has try-catch ✅

### User-facing error messages:
- None — exceptions propagate raw

---

## Performance Notes

### Provider architecture:
- No `autoDispose` — all providers live forever
- `pinnedAndFavoritesProvider` uses StreamController (manually disposed)
- `habitStatsProvider` uses `ref.listen` for invalidation (not `ref.watch`)
- `tasksWithDetailsProvider` batch-loads properties + tags in `Future.wait`

### Rebuild issues found:
- `settings_screen.dart` `_FontScaleTile`: full Settings rebuild on every slider drag (uses `settingsStreamProvider` not `.select()`)
- `task_list_screen.dart`: `_TaskCard` rebuilds on `showArchivedProvider` change even for non-archived
- `home_screen.dart`: `_GreetingSection`, `_LoadingSkeleton` missing `const` constructors

### Isar query optimization:
- Dedicated streams for pinned/favorites (independent of main itemsStreamProvider)
- Composite indices on critical fields
- `watch(fireImmediately: true)` on all streams

---

## Critical Implementation Patterns

1. **Singleton services**: NotificationService, ReminderScheduler, HabitService, AttachmentService, BackupService, ContactImportService
2. **Soft delete**: NEVER hard delete Items — use `Item.deletedAt`. Hard delete available but not used in normal flow
3. **Provider invalidation**: CRUD methods use `ref.invalidateSelf()` at the end
4. **Detail screen lifecycle**: DetailScreenMixin handles save/delete/new-empty-item disposal
5. **Folder-based filtering**: `selectedFolderIdProvider` is shared state read by `itemsByFolderStreamProvider`
6. **Drag & drop**: `DraggableItemWrapper` + `DraggableFolderSelector` for item → folder moves
7. **Grid responsive breakpoints**: mobile < 600, tablet 600-1024, desktop 1024+
8. **Color overrides**: `itemTypeCardColorOverrideProvider` used inside `itemBuilder` for per-card granularity
9. **Notification cold start**: `main()` checks `NotificationService.instance.getLaunchPayload()`, defers navigation after `runApp`

---

## Commands

| Command | Description |
|---|---|
| `flutter pub run build_runner build --delete-conflicting-outputs` | After Isar model changes |
| `flutter analyze` | Lint check (excludes `*.g.dart`) |
| `flutter test` | Runs widget_test.dart (stale — based on non-existent counter) |
| `flutter build apk` | Android APK build |
| `flutter build ios` | iOS build |
| `flutter build windows` | Windows build |
| `flutter build linux` | Linux build |
| `flutter build macos` | macOS build |
