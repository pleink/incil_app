import 'package:equatable/equatable.dart';

import '../../models/emergency_config.dart';
import '../../models/force_update_config.dart';
import '../../models/onboarding_config.dart';

sealed class AppShellState extends Equatable {
  const AppShellState();

  @override
  List<Object?> get props => const [];
}

final class AppShellSplash extends AppShellState {
  const AppShellSplash();
}

final class AppShellEmergency extends AppShellState {
  const AppShellEmergency(this.config);
  final EmergencyConfig config;

  @override
  List<Object?> get props => [config];
}

final class AppShellForceUpdate extends AppShellState {
  const AppShellForceUpdate(this.config);
  final ForceUpdateConfig config;

  @override
  List<Object?> get props => [config];
}

final class AppShellOnboarding extends AppShellState {
  const AppShellOnboarding(this.config);
  final OnboardingConfig config;

  @override
  List<Object?> get props => [config];
}

final class AppShellWebView extends AppShellState {
  const AppShellWebView({
    required this.url,
    required this.allowedHosts,
    required this.oneSignalTags,
  });

  final String url;
  final List<String> allowedHosts;
  final Map<String, String> oneSignalTags;

  @override
  List<Object?> get props => [url, allowedHosts, oneSignalTags];
}

final class AppShellOffline extends AppShellState {
  const AppShellOffline();
}
