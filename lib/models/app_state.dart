import 'package:equatable/equatable.dart';

import 'emergency_config.dart';
import 'force_update_config.dart';
import 'onboarding_config.dart';

class AppState extends Equatable {
  const AppState({
    required this.webviewUrl,
    required this.allowedHosts,
    required this.emergency,
    required this.forceUpdate,
    required this.onboarding,
    required this.oneSignalTags,
  });

  final String webviewUrl;
  final List<String> allowedHosts;
  final EmergencyConfig emergency;
  final ForceUpdateConfig forceUpdate;
  final OnboardingConfig onboarding;
  final Map<String, String> oneSignalTags;

  factory AppState.fromJson(Map<String, dynamic> json) {
    final rawHosts = json['allowedHosts'];
    final hosts = rawHosts is List
        ? rawHosts.whereType<String>().toList(growable: false)
        : const <String>[];

    final rawTags = json['oneSignalTags'];
    final tags = rawTags is Map
        ? rawTags.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
        : const <String, String>{};

    return AppState(
      webviewUrl: json['webviewUrl'] as String? ?? '',
      allowedHosts: hosts,
      emergency: json['emergency'] is Map
          ? EmergencyConfig.fromJson(
              Map<String, dynamic>.from(json['emergency'] as Map),
            )
          : EmergencyConfig.empty,
      forceUpdate: json['forceUpdate'] is Map
          ? ForceUpdateConfig.fromJson(
              Map<String, dynamic>.from(json['forceUpdate'] as Map),
            )
          : ForceUpdateConfig.empty,
      onboarding: json['onboarding'] is Map
          ? OnboardingConfig.fromJson(
              Map<String, dynamic>.from(json['onboarding'] as Map),
            )
          : OnboardingConfig.empty,
      oneSignalTags: Map<String, String>.from(tags),
    );
  }

  Map<String, dynamic> toJson() => {
    'webviewUrl': webviewUrl,
    'allowedHosts': allowedHosts,
    'emergency': emergency.toJson(),
    'forceUpdate': forceUpdate.toJson(),
    'onboarding': onboarding.toJson(),
    'oneSignalTags': oneSignalTags,
  };

  AppState copyWith({
    String? webviewUrl,
    List<String>? allowedHosts,
    EmergencyConfig? emergency,
    ForceUpdateConfig? forceUpdate,
    OnboardingConfig? onboarding,
    Map<String, String>? oneSignalTags,
  }) {
    return AppState(
      webviewUrl: webviewUrl ?? this.webviewUrl,
      allowedHosts: allowedHosts ?? this.allowedHosts,
      emergency: emergency ?? this.emergency,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      onboarding: onboarding ?? this.onboarding,
      oneSignalTags: oneSignalTags ?? this.oneSignalTags,
    );
  }

  @override
  List<Object?> get props => [
    webviewUrl,
    allowedHosts,
    emergency,
    forceUpdate,
    onboarding,
    oneSignalTags,
  ];
}
