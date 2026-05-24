import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:isar/isar.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/helpers/super_note_helper.dart';

// ─────────────────────────────────────────────────────────────
// Επιλογή πεδίων για import από το κινητό
// ─────────────────────────────────────────────────────────────
enum ContactField {
  name,
  phones,
  email,
  company,
  website,
  address,
  birthday,
  notes,
  photo,
}

extension ContactFieldLabel on ContactField {
  String get label => switch (this) {
    ContactField.name     => 'Όνομα',
    ContactField.phones   => 'Τηλέφωνο',
    ContactField.email    => 'Email',
    ContactField.company  => 'Εταιρεία',
    ContactField.website  => 'Website',
    ContactField.address  => 'Διεύθυνση',
    ContactField.birthday => 'Γενέθλια',
    ContactField.notes    => 'Σημειώσεις',
    ContactField.photo    => 'Φωτογραφία',
  };
}

// ─────────────────────────────────────────────────────────────
// Πρόοδος import (για real‑time UI update)
// ─────────────────────────────────────────────────────────────
class ImportProgress {
  final int current;
  final int total;
  final String contactName;
  final String status;

  const ImportProgress({
    required this.current,
    required this.total,
    this.contactName = '',
    this.status = '',
  });

  double get fraction => total > 0 ? current / total : 0.0;
}

// ─────────────────────────────────────────────────────────────
// Αποτέλεσμα import (στατιστικά)
// ─────────────────────────────────────────────────────────────
class ImportResult {
  final int imported;
  final int skipped;
  final int errors;
  final List<String> errorDetails;

  const ImportResult({
    this.imported = 0,
    this.skipped = 0,
    this.errors = 0,
    this.errorDetails = const [],
  });

  int get totalProcessed => imported + skipped + errors;
}

// ─────────────────────────────────────────────────────────────
// Service — Singleton
// ─────────────────────────────────────────────────────────────
class ContactImportService {
  ContactImportService._internal();
  static final ContactImportService instance = ContactImportService._internal();

  Future<bool> requestPermission() async {
    DebugConfig.print('ContactImportService.requestPermission: called');
    // Πρώτα έλεγχος αν ήδη έχει άδεια
    final currentStatus = await FlutterContacts.permissions.check(PermissionType.read);
    if (currentStatus == PermissionStatus.granted) {
      DebugConfig.print('ContactImportService.requestPermission: already granted');
      return true;
    }
    // Αίτηση μόνο για read (δεν χρειάζεται write)
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final granted = status == PermissionStatus.granted;
    DebugConfig.print('ContactImportService.requestPermission: granted=$granted');
    return granted;
  }

  Future<List<Contact>> fetchContacts() async {
    DebugConfig.print('ContactImportService.fetchContacts: called');
    final contacts = await FlutterContacts.getAll(
      properties: ContactProperties.all,
    );
    DebugConfig.print('ContactImportService.fetchContacts: count=${contacts.length}');
    return contacts;
  }

  // ── Κύρια μέθοδος import ─────────────────────────────────

  /// Εισάγει επαφές από το κινητό στη βάση.
  /// [contacts] — λίστα επαφών προς εισαγωγή (ήδη fetched + φιλτραρισμένες)
  /// [fields] — ποια πεδία να μεταφερθούν
  /// [workspaceId] — σε ποιο workspace
  /// [folderId] — optional folder
  /// [onProgress] — callback για real‑time ενημέρωση UI
  Future<ImportResult> importContacts({
    required List<Contact> contacts,
    required List<ContactField> fields,
    required int workspaceId,
    int? folderId,
    void Function(ImportProgress)? onProgress,
  }) async {
    if (contacts.isEmpty) {
      return const ImportResult();
    }

    int imported = 0, skipped = 0, errors = 0;
    final errorDetails = <String>[];
    final helper = SuperNoteHelper.instance;

    for (int i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      final displayName = _displayName(contact);

      onProgress?.call(ImportProgress(
        current: i,
        total: contacts.length,
        contactName: displayName,
        status: 'Επεξεργασία...',
      ));

      try {
        if (await _existsInDb(contact, helper)) {
          DebugConfig.print('ContactImport: skipped duplicate "$displayName"');
          skipped++;
          continue;
        }

        await _mapContactToItem(
          contact, fields, workspaceId, folderId, helper,
        );
        imported++;
      } catch (e) {
        DebugConfig.error('ContactImport: error for "$displayName"', e);
        errors++;
        errorDetails.add('$displayName: $e');
      }
    }

    onProgress?.call(ImportProgress(
      current: contacts.length,
      total: contacts.length,
      status: 'Ολοκληρώθηκε',
    ));

    return ImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
      errorDetails: errorDetails,
    );
  }

  // ── Διαχείριση εισαγμένων επαφών ─────────────────────────

  /// Επιστρέφει IDs όσων items έχουν marker `_imported`
  Future<List<int>> getImportedContactIds() async {
    final props = await SuperNoteHelper.instance.isar.itemPropertys
        .filter()
        .keyEqualTo('_imported')
        .valueEqualTo('true')
        .findAll();
    return props.map((p) => p.itemId).toList();
  }

  /// Soft delete εισαγμένων επαφών (μία ή πολλές)
  Future<void> deleteImported(Set<int> itemIds) async {
    final helper = SuperNoteHelper.instance;
    for (final id in itemIds) {
      await helper.items.softDelete(id);
      // Καθαρισμός ItemProperty για να μην βγαίνουν orphaned στα queries
      await helper.isar.writeTxn(() async {
        await helper.isar.itemPropertys
            .filter()
            .itemIdEqualTo(id)
            .deleteAll();
      });
    }
  }

  // ── Βοηθητικές ───────────────────────────────────────────

  String _displayName(Contact contact) {
    final display = contact.displayName;
    if (display != null && display.isNotEmpty) return display;
    if (contact.phones.isNotEmpty) return contact.phones.first.number;
    return '(χωρίς όνομα)';
  }

  /// Έλεγχος duplicate — ίδιο όνομα (case insensitive) Ή ίδιο τηλέφωνο
  Future<bool> _existsInDb(Contact contact, SuperNoteHelper helper) async {
    final name = (contact.displayName ?? '').trim().toLowerCase();
    if (name.isNotEmpty) {
      final byName = await helper.isar.items
          .filter()
          .typeEqualTo(ItemType.contact)
          .titleEqualTo(name)
          .deletedAtIsNull()
          .findAll();
      if (byName.isNotEmpty) return true;
    }

    if (contact.phones.isNotEmpty) {
      final existingPhoneProps = await helper.isar.itemPropertys
          .filter()
          .keyEqualTo('phones')
          .findAll();
      for (final prop in existingPhoneProps) {
        if (prop.value == null) continue;
        // Παράλειψη αν το parent item είναι soft-deleted
        final parent = await helper.items.getById(prop.itemId);
        if (parent == null || parent.deletedAt != null) continue;
        try {
          final phones = jsonDecode(prop.value!) as List;
          for (final phone in contact.phones) {
            if (phone.number.isNotEmpty && phones.contains(phone.number)) {
              return true;
            }
          }
        } catch (_) {
          // ignore malformed JSON
        }
      }
    }

    return false;
  }

  /// Mapping Contact (flutter_contacts) → Item + ItemProperty (Isar)
  Future<Item> _mapContactToItem(
    Contact contact,
    List<ContactField> fields,
    int workspaceId,
    int? folderId,
    SuperNoteHelper helper,
  ) async {
    final title = _displayName(contact);

    final item = await helper.items.create(
      type: ItemType.contact,
      workspaceId: workspaceId,
      folderId: folderId,
      title: title,
    );

    // Παράλληλη αποθήκευση properties
    final futures = <Future<void>>[];

    for (final field in fields) {
      switch (field) {
        case ContactField.name:
          break; // ήδη αποθηκεύτηκε ως Item.title

        case ContactField.phones:
          if (contact.phones.isNotEmpty) {
            final phones = contact.phones.map((p) => p.number).toList();
            futures.add(helper.properties.set(
              itemId: item.id,
              key: 'phones',
              value: jsonEncode(phones),
              type: PropertyType.json,
            ));
          }
          break;

        case ContactField.email:
          if (contact.emails.isNotEmpty) {
            futures.add(helper.properties.set(
              itemId: item.id,
              key: 'email',
              value: contact.emails.first.address,
              type: PropertyType.email,
            ));
          }
          break;

        case ContactField.company:
          if (contact.organizations.isNotEmpty) {
            final org = contact.organizations.first;
            final orgName = org.name;
            if (orgName != null && orgName.isNotEmpty) {
              futures.add(helper.properties.set(
                itemId: item.id,
                key: 'company',
                value: orgName,
              ));
            }
          }
          break;

        case ContactField.website:
          if (contact.websites.isNotEmpty) {
            futures.add(helper.properties.set(
              itemId: item.id,
              key: 'website',
              value: contact.websites.first.url,
              type: PropertyType.url,
            ));
          }
          break;

        case ContactField.address:
          if (contact.addresses.isNotEmpty) {
            final addr = contact.addresses.first;
            final parts = [
              addr.street,
              addr.city,
              addr.state,
              addr.postalCode,
              addr.country,
            ].where((s) => s != null && s.isNotEmpty).join(', ');
            if (parts.isNotEmpty) {
              futures.add(helper.properties.set(
                itemId: item.id,
                key: 'address',
                value: parts,
              ));
            }
          }
          break;

        case ContactField.birthday:
          if (contact.events.isNotEmpty) {
            final ev = contact.events.first;
            if (ev.year != null) {
              futures.add(helper.properties.setDate(
                item.id, 'birthday',
                DateTime(ev.year!, ev.month, ev.day),
              ));
            }
          }
          break;

        case ContactField.notes:
          if (contact.notes.isNotEmpty) {
            final notesText = contact.notes
                .map((n) => n.note)
                .where((t) => t.isNotEmpty)
                .join('\n');
            if (notesText.isNotEmpty) {
              futures.add(helper.properties.set(
                itemId: item.id,
                key: 'notes',
                value: notesText,
              ));
            }
          }
          break;

        case ContactField.photo:
          final photo = contact.photo;
          if (photo != null) {
            final bytes = photo.fullSize ?? photo.thumbnail;
            if (bytes != null && bytes.isNotEmpty) {
              futures.add(helper.properties.set(
                itemId: item.id,
                key: 'photo',
                value: base64Encode(bytes),
              ));
            }
          }
          break;
      }
    }

    // Marker για αναγνώριση εισαγμένων επαφών
    futures.add(helper.properties.set(
      itemId: item.id,
      key: '_imported',
      value: 'true',
      isVisible: false,
    ));

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    return item;
  }
}