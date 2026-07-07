import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:incil_camp_app/models/app_state.dart';
import 'package:incil_camp_app/models/force_update_config.dart';
import 'package:incil_camp_app/services/version_service.dart';

PackageInfo _packageInfo({String buildNumber = '10'}) => PackageInfo(
  appName: 'Incil',
  packageName: 'ch.incil.camp_app.dev',
  version: '1.0.0',
  buildNumber: buildNumber,
  buildSignature: '',
);

VersionService _service({String buildNumber = '10', required bool isIos}) =>
    VersionService(_packageInfo(buildNumber: buildNumber), isIos: isIos);

void main() {
  group('VersionService.mustForceUpdate', () {
    test('disabled config returns false even when build is below minimum', () {
      final service = _service(buildNumber: '1', isIos: true);
      const config = ForceUpdateConfig(
        enabled: false,
        minIosBuildNumber: 999,
        minAndroidVersionCode: 999,
      );
      expect(service.mustForceUpdate(config), isFalse);
    });

    group('iOS', () {
      test('build below minIosBuildNumber returns true', () {
        final service = _service(buildNumber: '10', isIos: true);
        const config = ForceUpdateConfig(enabled: true, minIosBuildNumber: 11);
        expect(service.mustForceUpdate(config), isTrue);
      });

      test('build equal to minIosBuildNumber returns false', () {
        final service = _service(buildNumber: '11', isIos: true);
        const config = ForceUpdateConfig(enabled: true, minIosBuildNumber: 11);
        expect(service.mustForceUpdate(config), isFalse);
      });

      test('build above minIosBuildNumber returns false', () {
        final service = _service(buildNumber: '12', isIos: true);
        const config = ForceUpdateConfig(enabled: true, minIosBuildNumber: 11);
        expect(service.mustForceUpdate(config), isFalse);
      });

      test('only Android minimum set returns false on iOS', () {
        final service = _service(buildNumber: '1', isIos: true);
        const config = ForceUpdateConfig(
          enabled: true,
          minAndroidVersionCode: 999,
        );
        expect(service.mustForceUpdate(config), isFalse);
      });
    });

    group('Android', () {
      test('build below minAndroidVersionCode returns true', () {
        final service = _service(buildNumber: '10', isIos: false);
        const config = ForceUpdateConfig(
          enabled: true,
          minAndroidVersionCode: 11,
        );
        expect(service.mustForceUpdate(config), isTrue);
      });

      test('build equal to minAndroidVersionCode returns false', () {
        final service = _service(buildNumber: '11', isIos: false);
        const config = ForceUpdateConfig(
          enabled: true,
          minAndroidVersionCode: 11,
        );
        expect(service.mustForceUpdate(config), isFalse);
      });

      test('build above minAndroidVersionCode returns false', () {
        final service = _service(buildNumber: '12', isIos: false);
        const config = ForceUpdateConfig(
          enabled: true,
          minAndroidVersionCode: 11,
        );
        expect(service.mustForceUpdate(config), isFalse);
      });

      test('only iOS minimum set returns false on Android', () {
        final service = _service(buildNumber: '1', isIos: false);
        const config = ForceUpdateConfig(enabled: true, minIosBuildNumber: 999);
        expect(service.mustForceUpdate(config), isFalse);
      });
    });

    group('boundary values', () {
      test('minimum of 0 never forces (build 0 is not below 0)', () {
        final service = _service(buildNumber: '0', isIos: true);
        const config = ForceUpdateConfig(enabled: true, minIosBuildNumber: 0);
        expect(service.mustForceUpdate(config), isFalse);
      });

      test('negative build number parses and is below minimum 0', () {
        final service = _service(buildNumber: '-1', isIos: false);
        const config = ForceUpdateConfig(
          enabled: true,
          minAndroidVersionCode: 0,
        );
        expect(service.buildNumberOrNull, -1);
        expect(service.mustForceUpdate(config), isTrue);
      });
    });

    test('enabled with no minimum for the current platform returns false', () {
      final service = _service(buildNumber: '1', isIos: true);
      const config = ForceUpdateConfig(enabled: true);
      expect(service.mustForceUpdate(config), isFalse);
    });

    group('unparseable buildNumber fails open', () {
      const config = ForceUpdateConfig(
        enabled: true,
        minIosBuildNumber: 999,
        minAndroidVersionCode: 999,
      );

      test('empty buildNumber returns false', () {
        final service = _service(buildNumber: '', isIos: true);
        expect(service.buildNumberOrNull, isNull);
        expect(service.mustForceUpdate(config), isFalse);
      });

      test('non-numeric buildNumber returns false', () {
        final service = _service(buildNumber: 'abc', isIos: false);
        expect(service.buildNumberOrNull, isNull);
        expect(service.mustForceUpdate(config), isFalse);
      });
    });
  });

  group('ForceUpdateConfig.fromJson', () {
    test('parses double minimums to int', () {
      final config = ForceUpdateConfig.fromJson({
        'enabled': true,
        'minIosBuildNumber': 42.0,
        'minAndroidVersionCode': 7.0,
      });
      expect(config.minIosBuildNumber, 42);
      expect(config.minAndroidVersionCode, 7);
    });

    test('missing keys parse to null / defaults', () {
      final config = ForceUpdateConfig.fromJson({});
      expect(config.enabled, isFalse);
      expect(config.minIosBuildNumber, isNull);
      expect(config.minAndroidVersionCode, isNull);
      expect(config.title, isNull);
      expect(config.message, isNull);
      expect(config.iosStoreUrl, isNull);
      expect(config.androidStoreUrl, isNull);
    });

    test('toJson -> fromJson round-trip preserves all fields', () {
      const config = ForceUpdateConfig(
        enabled: true,
        minIosBuildNumber: 12,
        minAndroidVersionCode: 34,
        title: 'Update',
        message: 'Please update',
        iosStoreUrl: 'https://apps.apple.com/x',
        androidStoreUrl: 'https://play.google.com/x',
      );
      expect(ForceUpdateConfig.fromJson(config.toJson()), config);
    });

    test('toJson omits null fields', () {
      const config = ForceUpdateConfig(enabled: true, minIosBuildNumber: 12);
      expect(config.toJson(), {'enabled': true, 'minIosBuildNumber': 12});
    });

    test('toJson -> fromJson round-trip with only enabled', () {
      const config = ForceUpdateConfig(enabled: true);
      expect(ForceUpdateConfig.fromJson(config.toJson()), config);
    });

    test('legacy keys are ignored (no fallback)', () {
      final config = ForceUpdateConfig.fromJson({
        'enabled': true,
        'minIosBuild': 5,
        'minAndroidBuild': 6,
      });
      expect(config.enabled, isTrue);
      expect(config.minIosBuildNumber, isNull);
      expect(config.minAndroidVersionCode, isNull);
    });

    test('boolean forceUpdate in AppState doc parses to empty config', () {
      final appState = AppState.fromJson({
        'webviewUrl': 'https://incil.huulo.io/app',
        'forceUpdate': true,
      });
      expect(appState.forceUpdate, ForceUpdateConfig.empty);
    });
  });
}
