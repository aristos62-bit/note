// lib/models/device.dart
// TODO: Σελίδα προς Ανάπτυξη
import 'package:isar/isar.dart';
part 'device.g.dart';

@Collection()
class Device {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String deviceId;

  late String deviceName;
  late String platform;

  String? appVersion;
  String? osVersion;

  @Index()
  late int userId;

  DateTime registeredAt = DateTime.now();
  DateTime? lastSeenAt;

  bool isCurrentDevice = false;
}