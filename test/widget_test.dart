// Real tests land in M14 (host allowlist, version service, cubit priority).
// This placeholder keeps `fvm flutter test` green during scaffolding.

import 'package:flutter_test/flutter_test.dart';

import 'package:incil_camp_app/models/app_state.dart';
import 'package:incil_camp_app/models/emergency_config.dart';
import 'package:incil_camp_app/models/force_update_config.dart';
import 'package:incil_camp_app/models/onboarding_config.dart';

void main() {
  test('AppState round-trips through fromJson/toJson', () {
    const state = AppState(
      webviewUrl: 'https://example.com',
      allowedHosts: ['example.com'],
      inAppBrowserHosts: ['shop.example.com'],
      externalBrowserUrls: ['/signup'],
      emergency: EmergencyConfig.empty,
      forceUpdate: ForceUpdateConfig.empty,
      onboarding: OnboardingConfig.empty,
      oneSignalTags: {'app': 'incil'},
    );

    final decoded = AppState.fromJson(state.toJson());

    expect(decoded.webviewUrl, state.webviewUrl);
    expect(decoded.allowedHosts, state.allowedHosts);
    expect(decoded.inAppBrowserHosts, state.inAppBrowserHosts);
    expect(decoded.externalBrowserUrls, state.externalBrowserUrls);
    expect(decoded.oneSignalTags, state.oneSignalTags);
    expect(decoded.emergency.enabled, false);
    expect(decoded.forceUpdate.enabled, false);
    expect(decoded.onboarding.enabled, false);
  });
}
