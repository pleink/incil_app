import '../models/app_state.dart';
import '../models/emergency_config.dart';
import '../models/force_update_config.dart';
import '../models/onboarding_config.dart';

enum Flavor {
  dev(
    name: 'dev',
    displayName: 'Incil CampApp (Dev)',
    oneSignalAppId: '028782a9-e433-4e82-8ccb-37b83aeb3b89',
    firebaseProjectId: 'incil-campapp-dev',
    defaultWebviewUrl: 'https://incil-24-4366.huulo.app/',
  ),
  prod(
    name: 'prod',
    displayName: 'Incil CampApp',
    oneSignalAppId: '3e8f7a53-8b01-4d37-8748-058896c8329b',
    firebaseProjectId: 'incil-campapp',
    defaultWebviewUrl: 'https://incil-24-4366.huulo.app/',
  );

  const Flavor({
    required this.name,
    required this.displayName,
    required this.oneSignalAppId,
    required this.firebaseProjectId,
    required this.defaultWebviewUrl,
  });

  final String name;
  final String displayName;
  final String oneSignalAppId;
  final String firebaseProjectId;

  /// Used until the Firestore `apps/incil/config/app_state` document is set up.
  /// Once Firestore has a real document, that value takes over on the first
  /// snapshot — this only seeds the very first frame.
  final String defaultWebviewUrl;

  AppState get defaultAppState => AppState(
    webviewUrl: defaultWebviewUrl,
    allowedHosts: const ['incil-24-4366.huulo.app', 'huulo.app', 'huulo.io'],
    inAppBrowserHosts: const ['shop.incil.ch'],
    externalBrowserUrls: const ['/signup'],
    emergency: EmergencyConfig.empty,
    forceUpdate: ForceUpdateConfig.empty,
    onboarding: OnboardingConfig.empty,
    oneSignalTags: const {},
  );
}
