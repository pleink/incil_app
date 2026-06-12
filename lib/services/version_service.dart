import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

import '../models/force_update_config.dart';

class VersionService {
  VersionService(this._packageInfo);

  final PackageInfo _packageInfo;

  static Future<VersionService> create() async {
    final info = await PackageInfo.fromPlatform();
    return VersionService(info);
  }

  int get currentBuild => int.tryParse(_packageInfo.buildNumber) ?? 0;
  String get currentVersion => _packageInfo.version;

  bool mustForceUpdate(ForceUpdateConfig config) {
    if (!config.enabled) return false;
    final required = Platform.isIOS
        ? config.minIosBuild
        : config.minAndroidBuild;
    if (required == null) return false;
    return currentBuild < required;
  }
}
