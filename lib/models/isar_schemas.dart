// lib/models/isar_schemas.dart
//
// S-02 (C2): μία και μόνη λίστα schema για το Isar.
//
// Χρησιμοποιείται από:
//  • SuperNoteHelper.init() — το live instance
//  • BackupDbProbe — trial open αντιγράφου σε temp dir
//
// Έτσι δεν υπάρχει «δεύτερη λίστα» που θα ξεμείνει όταν προστεθεί collection.
import 'package:isar/isar.dart';

import 'app_settings.dart';
import 'attachment.dart';
import 'device.dart';
import 'folder.dart';
import 'item.dart';
import 'item_block.dart';
import 'item_property.dart';
import 'item_tag.dart';
import 'relation.dart';
import 'reminder.dart';
import 'tag.dart';
import 'user.dart';
import 'workspace.dart';

/// Όλα τα collections της εφαρμογής, με τη σειρά που ανοίγει το live DB.
final List<CollectionSchema<dynamic>> isarSchemas = <CollectionSchema<dynamic>>[
  ItemSchema,
  ItemBlockSchema,
  ItemPropertySchema,
  TagSchema,
  ItemTagSchema,
  RelationSchema,
  ReminderSchema,
  FolderSchema,
  WorkspaceSchema,
  AttachmentSchema,
  UserSchema,
  DeviceSchema,
  AppSettingsSchema,
];
