# SuperNote

Προσωπική εφαρμογή σημειώσεων/οργάνωσης σε **Flutter + Isar** (Android/iOS/desktop), με 13 τύπους item
(note, task, event, contact, habit, project/collection, goal, finance, bookmark, journal, appointment,
checklist, knowledge entry), real-time streams, υπενθυμίσεις (topUp + OS alarms), συλλογές με πεδία,
συνημμένα, αναζήτηση, app-lock και backup/restore.

## Τεκμηρίωση (πού τι βρίσκεται)

| Αρχείο | Περιεχόμενο |
|---|---|
| `AGENTS.md` | Κανόνες συνεργασίας (πάντα πρώτο) |
| `supernote.md` | Αρχιτεκτονική (models, services, providers, routing, patterns) |
| `security_v2.md` | Έκθεση ασφάλειας **v2.3** (25 ευρήματα) + ιεραρχημένο πλάνο P0–P4 |
| `oldsessions.md` | Ιστορικό sessions (ενημερώνεται μόνο στο τελικό κλείσιμο) |
| `code_refactor.md` | Ιστορικός οδηγός ποιότητας σελίδων (παγωμένο ως προς εκκρεμότητες) |
| `a11y.md` | Σχέδιο accessibility — **ΟΛΟΚΛΗΡΩΘΗΚΕ 03/11/2026** (E01/S288) |

> **Εκκρεμότητες:** **0 ανοιχτές** (05/11/2026, S293). Ο tracker `error_list.md` αρχειοθετήθηκε στο `backups/e48_filtered_empty_20261105_180802/error_list.md.final` και διαγράφηκε (E26/S293 → τελικό E48/S295)· αν προκύψει **νέο εύρημα**, το `error_list.md` **επαναδημιουργείται** (AGENTS.md #6/#9).

## Ανάπτυξη

```bash
flutter pub get
flutter run
flutter analyze
flutter test -j 1 --reporter compact
```

Τρέχουσα κατάσταση (08/11/2026): `flutter analyze` clean · tests **620/620** · `catch (_) {}` = 0 · εκκρεμότητες **0**.

> Τα δεδομένα της συσκευής δεν δημιουργούνται/αλλάζουν ποτέ μέσω `adb` — μόνο in-app (AGENTS.md #12).
