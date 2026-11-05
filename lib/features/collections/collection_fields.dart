// lib/features/collections/collection_fields.dart
//
// E39 — μετακόμιση: `FieldType` / `FieldDef` ζουν πλέον στο core
// (`lib/core/utils/collection_fields.dart`) για να τα χρησιμοποιεί και το
// share pipeline. Το αρχείο μένει ως re-export → 0 αλλαγή σε call sites/tests.
export '../../core/utils/collection_fields.dart' show FieldDef, FieldType;