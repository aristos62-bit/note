import 'package:riverpod/riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (build ${info.buildNumber})';
});
