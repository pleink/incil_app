import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

import '../models/force_update_config.dart';

class VersionService {
  VersionService(this._packageInfo, {bool? isIos})
    : _isIos = isIos ?? Platform.isIOS;

  final PackageInfo _packageInfo;
  final bool _isIos;

  static Future<VersionService> create() async {
    final info = await PackageInfo.fromPlatform();
    return VersionService(info);
  }

  /// Display-only: falls back to 0 when the build number is unparseable.
  int get currentBuild => buildNumberOrNull ?? 0;
  String get currentVersion => _packageInfo.version;

  /// Null when [PackageInfo.buildNumber] is not a valid integer.
  int? get buildNumberOrNull => int.tryParse(_packageInfo.buildNumber);

  bool mustForceUpdate(ForceUpdateConfig config) {
    if (!config.enabled) return false;
    final required = _isIos
        ? config.minIosBuildNumber
        : config.minAndroidVersionCode;
    if (required == null) return false;
    final build = buildNumberOrNull;
    // Fail-open: never lock users out on an unparseable build number.
    if (build == null) return false;
    return build < required;
  }
}
