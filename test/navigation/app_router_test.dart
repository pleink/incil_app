import 'package:flutter_test/flutter_test.dart';

import 'package:incil_camp_app/cubits/app_shell/app_shell_state.dart';
import 'package:incil_camp_app/models/emergency_config.dart';
import 'package:incil_camp_app/models/force_update_config.dart';
import 'package:incil_camp_app/models/onboarding_config.dart';
import 'package:incil_camp_app/navigation/app_router.dart';
import 'package:incil_camp_app/style/incil_system_ui.dart';

void main() {
  group('overlayStyleFor keeps status-bar icons legible per screen', () {
    const lightIconStates = <AppShellState>[
      AppShellSplash(),
      AppShellEmergency(EmergencyConfig.empty),
      AppShellOnboarding(OnboardingConfig.empty),
    ];
    const darkIconStates = <AppShellState>[
      AppShellForceUpdate(ForceUpdateConfig.empty),
      AppShellWebView(
        url: 'https://x',
        allowedHosts: [],
        inAppBrowserHosts: [],
        externalBrowserUrls: [],
        oneSignalTags: {},
      ),
      AppShellOffline(),
    ];

    for (final state in lightIconStates) {
      test('${state.runtimeType} → light icons', () {
        expect(overlayStyleFor(state), IncilSystemUi.lightIcons);
      });
    }

    for (final state in darkIconStates) {
      test('${state.runtimeType} → dark icons', () {
        expect(overlayStyleFor(state), IncilSystemUi.darkIcons);
      });
    }

    test('covers every AppShellState (no state left unstyled)', () {
      expect(lightIconStates.length + darkIconStates.length, 6);
    });
  });
}
