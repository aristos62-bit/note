# SuperNote

Προσωπική εφαρμογή σημειώσεων/οργάνωσης σε **Flutter + Isar** (Android/iOS/desktop), με 13 τύπους item
(note, task, event, contact, habit, project/collection, goal, finance, bookmark, journal, appointment,
checklist, knowledge entry), real-time streams, υπενθυμίσεις (topUp + OS alarms), συλλογές με πεδία,
συνημμένα, αναζήτηση, app-lock και backup/restore.

## Τεκμηρίωση (πού τι βρίσκεται)

| Αρχείο | Περιεχόμενο |
|---|---|
| `AGENTS.md` | Κανόνες συνεργασίας (πάντα πρώτο) |
| `error_list.md` | **Μοναδική πηγή** για εκκρεμότητες (P1–P4, κάρτες, logs) — η πρόοδος πάει στο `oldsessions.md` |
| `supernote.md` | Αρχιτεκτονική (models, services, providers, routing, patterns) |
| `oldsessions.md` | Ιστορικό sessions (ενημερώνεται μόνο στο τελικό κλείσιμο) |
| `code_refactor.md` | Ιστορικός οδηγός ποιότητας σελίδων (παγωμένο ως προς εκκρεμότητες) |
| `a11y.md` | Σχέδιο accessibility — **PARKED** (E01) |

## Ανάπτυξη

```bash
flutter pub get
flutter run
flutter analyze
flutter test -j 1 --reporter compact
```

Τρέχουσα κατάσταση (26/10/2026): `flutter analyze` clean · tests **339/339** · `catch (_) {}` = 0.

> Τα δεδομένα της συσκευής δεν δημιουργούνται/αλλάζουν ποτέ μέσω `adb` — μόνο in-app (AGENTS.md #12).
