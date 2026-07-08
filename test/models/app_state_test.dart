import 'package:flutter_test/flutter_test.dart';

import 'package:incil_camp_app/models/app_state.dart';
import 'package:incil_camp_app/models/emergency_config.dart';
import 'package:incil_camp_app/models/force_update_config.dart';
import 'package:incil_camp_app/models/onboarding_config.dart';

void main() {
  const forceUpdate = ForceUpdateConfig(
    enabled: true,
    minIosBuildNumber: 12,
    minAndroidVersionCode: 34,
    title: 'Update',
    message: 'Bitte aktualisieren',
    iosStoreUrl: 'https://apps.apple.com/x',
    androidStoreUrl: 'https://play.google.com/x',
  );

  const state = AppState(
    webviewUrl: 'https://incil.huulo.io/app',
    allowedHosts: ['incil.huulo.io'],
    emergency: EmergencyConfig.empty,
    forceUpdate: forceUpdate,
    onboarding: OnboardingConfig.empty,
    oneSignalTags: {'app': 'incil'},
  );

  group('AppState', () {
    test(
      'toJson -> fromJson round-trip preserves forceUpdate (cache path)',
      () {
        // Simulates the SharedPreferences offline-cache write/read cycle.
        final restored = AppState.fromJson(state.toJson());
        expect(restored, state);
        expect(restored.forceUpdate, forceUpdate);
      },
    );

    test('copyWith replaces forceUpdate and preserves other fields', () {
      final copy = state.copyWith(forceUpdate: ForceUpdateConfig.empty);
      expect(copy.forceUpdate, ForceUpdateConfig.empty);
      expect(copy.webviewUrl, state.webviewUrl);
      expect(copy.allowedHosts, state.allowedHosts);
      expect(copy.emergency, state.emergency);
      expect(copy.onboarding, state.onboarding);
      expect(copy.oneSignalTags, state.oneSignalTags);
    });

    test('copyWith with no arguments returns an equal state', () {
      expect(state.copyWith(), state);
    });

    test('fromConfigDocs maps the flat config collection documents', () {
      final restored = AppState.fromConfigDocs({
        'webview': {'url': 'https://incil.huulo.io/app'},
        'allowedHosts': {
          'urls': ['incil.huulo.io'],
        },
        'emergency': const {},
        'forceUpdate': forceUpdate.toJson(),
        'onboarding': const {},
        'oneSignalTags': {'app': 'incil'},
      });
      expect(restored, state);
    });

    test('fromConfigDocs accepts the short ios/android force-update keys', () {
      final restored = AppState.fromConfigDocs({
        'forceUpdate': {'enabled': true, 'ios': 2, 'android': 3},
      });
      expect(restored.forceUpdate.enabled, isTrue);
      expect(restored.forceUpdate.minIosBuildNumber, 2);
      expect(restored.forceUpdate.minAndroidVersionCode, 3);
    });

    test('fromConfigDocs tolerates missing documents', () {
      final restored = AppState.fromConfigDocs(const {});
      expect(restored.webviewUrl, '');
      expect(restored.allowedHosts, isEmpty);
      expect(restored.emergency, EmergencyConfig.empty);
      expect(restored.forceUpdate, ForceUpdateConfig.empty);
      expect(restored.onboarding, OnboardingConfig.empty);
      expect(restored.oneSignalTags, isEmpty);
    });
  });
}
