// lib/models/user.dart
// TODO: Σελίδα προς Ανάπτυξη
import 'package:isar/isar.dart';
part 'user.g.dart';

@Collection()
class User {
  Id id = Isar.autoIncrement;

  @Index(unique: true, caseSensitive: false)
  late String email;

  String? name;
  String? avatarPath;
  String? avatarUrl;

  @Index()
  bool isActive = true;

  DateTime createdAt = DateTime.now();
  DateTime? lastLoginAt;

  String? syncToken;
  DateTime? tokenExpiresAt;
}