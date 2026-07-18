import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_lock_service.dart';

final appLockStateProvider = StateProvider<bool>((ref) {
  return AppLockService.instance.isLocked;
});
