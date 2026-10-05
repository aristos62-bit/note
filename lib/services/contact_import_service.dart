import 'dart:convert';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:isar/isar.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/models/models.dart';
import 'package:super_note/helpers/super_note_helper.dart';

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

class ContactImportService {
  ContactImportService._internal();
  static final ContactImportService instance = ContactImportService._internal();

  Future<bool> requestPermission() async {
    DebugConfig.print('ContactImportService.requestPermission: called');
    try {
      final currentStatus = await FlutterContacts.permissions.check(PermissionType.read);
      if (currentStatus == PermissionStatus.granted) {
        DebugConfig.print('ContactImportService.requestPermission: already granted');
        return true;
      }
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      final granted = status == PermissionStatus.granted;
      DebugConfig.print('ContactImportService.requestPermission: granted=$granted');
      return granted;
    } catch (e, stack) {
      DebugConfig.error('[ContactImportService] requestPermission failed', e, stack);
      return false;
    }
  }

  Future<List<Contact>> fetchContacts() async {
    DebugConfig.print('ContactImportService.fetchContacts: called');
    try {
      final contacts = await FlutterContacts.getAll(
        properties: ContactProperties.all,
      );
      DebugConfig.print('ContactImportService.fetchContacts: count=${contacts.length}');
      return contacts;
    } catch (e, stack) {
      DebugConfig.error('[ContactImportService] fetchContacts failed', e, stack);
      rethrow;
    }
  }

  // ── Κύρια μέθοδος import ─────────────────────────────────
  Future<ImportResult> importContacts({
    required List<Contact> contacts,
    required List<ContactField> fields,
    required int workspaceId,
    int? folderId,
    void Function(ImportProgress)? onProgress,
  }) async {
    if (contacts.isEmpty) return const ImportResult();

    int imported = 0, skipped = 0, errors = 0;
    final errorDetails = <String>[];
    final helper = SuperNoteHelper.instance;

    // Batch dedup (Φ4a βήμα 16): 2 queries/run αντί N+1 — τίτλοι + phones
    // (phones + legacy phone keys, non-deleted, workspace-scoped).
    // Σε DB error: κενά sets (προχωράμε — καλύτερα duplicate από ολικό fail).
    final titleSet = <String>{};
    final phoneSet = <String>{};
    try {
      final existing = await helper.items.getByWorkspace(
        workspaceId,
        type: ItemType.contact,
        includeArchived: true,
      );
      for (final c in existing) {
        final t = (c.title ?? '').trim().toLowerCase();
        if (t.isNotEmpty) titleSet.add(t);
      }
      final propsMap = await helper.properties.getAllForItems(
        [for (final c in existing) c.id],
      );
      propsMap.forEach((_, props) {
        final cp = ContactProps.fromProperties(props);
        phoneSet.addAll(cp.phones);
        final fb = cp.phoneFallback;
        if (fb != null && fb.isNotEmpty) phoneSet.add(fb);
      });
      DebugConfig.db(
          'ContactImport dedup sets: titles=${titleSet.length} phones=${phoneSet.length}');
    } catch (e, stack) {
      DebugConfig.error('[ContactImportService] dedup prefetch failed', e, stack);
    }

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
        if (ContactImportService.isDuplicate(contact, titleSet, phoneSet)) {
          DebugConfig.print('ContactImport: skipped duplicate "$displayName"');
          skipped++;
          continue;
        }

        await _mapContactToItem(contact, fields, workspaceId, folderId, helper);
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

  Future<List<int>> getImportedContactIds() async {
    try {
      final props = await SuperNoteHelper.instance.isar.itemPropertys
          .filter()
          .keyEqualTo('_imported')
          .valueEqualTo('true')
          .findAll();
      return props.map((p) => p.itemId).toList();
    } catch (e, stack) {
      DebugConfig.error(
          '[ContactImportService] getImportedContactIds failed', e, stack);
      rethrow;
    }
  }

  Future<void> deleteImported(Set<int> itemIds) async {
    if (itemIds.isEmpty) return;
    final helper = SuperNoteHelper.instance;
    for (final id in itemIds) {
      try {
        await helper.items.softDelete(id);
        await helper.isar.writeTxn(() async {
          await helper.isar.itemPropertys
              .filter()
              .itemIdEqualTo(id)
              .deleteAll();
        });
      } catch (e, stack) {
        DebugConfig.error(
            '[ContactImportService] deleteImported failed for id=$id', e, stack);
        // Συνεχίζουμε με τις υπόλοιπες — μία αποτυχία δεν σταματά τις άλλες
      }
    }
  }

  // ── Βοηθητικές ───────────────────────────────────────────

  String _displayName(Contact contact) {
    final display = contact.displayName;
    if (display != null && display.isNotEmpty) return display;
    if (contact.phones.isNotEmpty) return contact.phones.first.number;
    return '(χωρίς όνομα)';
  }

  /// Pure duplicate-check πάνω σε pre-fetched sets (Φ4a βήμα 16 — testable,
  /// 0 DB calls· αντικαθιστά το per-contact `_existsInDb` N+1).
  /// Σκόπιμα workspace-scoped + archived-inclusive (parity με παλιό query).
  static bool isDuplicate(
    Contact contact,
    Set<String> titleSet,
    Set<String> phoneSet,
  ) {
    final name = (contact.displayName ?? '').trim().toLowerCase();
    if (name.isNotEmpty && titleSet.contains(name)) return true;
    for (final phone in contact.phones) {
      if (phone.number.isNotEmpty && phoneSet.contains(phone.number)) {
        return true;
      }
    }
    return false;
  }

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

    final futures = <Future<void>>[];

    for (final field in fields) {
      switch (field) {
        case ContactField.name:
          break;

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
            // SPoT resize: προτίμησε thumbnail (μικρό) αντί fullSize για αποφυγή OOM.
            final bytes = photo.thumbnail ?? photo.fullSize;
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