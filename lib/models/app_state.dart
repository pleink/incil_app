import 'package:equatable/equatable.dart';

import 'emergency_config.dart';
import 'force_update_config.dart';
import 'onboarding_config.dart';

class AppState extends Equatable {
  const AppState({
    required this.webviewUrl,
    required this.allowedHosts,
    required this.inAppBrowserHosts,
    required this.externalBrowserUrls,
    required this.emergency,
    required this.forceUpdate,
    required this.onboarding,
    required this.oneSignalTags,
  });

  final String webviewUrl;
  final List<String> allowedHosts;
  final List<String> inAppBrowserHosts;
  final List<String> externalBrowserUrls;
  final EmergencyConfig emergency;
  final ForceUpdateConfig forceUpdate;
  final OnboardingConfig onboarding;
  final Map<String, String> oneSignalTags;

  factory AppState.fromJson(Map<String, dynamic> json) {
    final rawHosts = json['allowedHosts'];
    final hosts = rawHosts is List
        ? rawHosts.whereType<String>().toList(growable: false)
        : const <String>[];

    final rawInAppBrowserHosts = json['inAppBrowserHosts'];
    final inAppBrowserHosts = rawInAppBrowserHosts is List
        ? rawInAppBrowserHosts.whereType<String>().toList(growable: false)
        : const <String>[];

    final rawExternalBrowserUrls = json['externalBrowserUrls'];
    final externalBrowserUrls = rawExternalBrowserUrls is List
        ? rawExternalBrowserUrls.whereType<String>().toList(growable: false)
        : const <String>[];

    final rawTags = json['oneSignalTags'];
    final tags = rawTags is Map
        ? rawTags.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
        : const <String, String>{};

    return AppState(
      webviewUrl: json['webviewUrl'] as String? ?? '',
      allowedHosts: hosts,
      inAppBrowserHosts: inAppBrowserHosts,
      externalBrowserUrls: externalBrowserUrls,
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

  /// Builds an [AppState] from the flat Firestore `config` collection, where
  /// each concern lives in its own document keyed by id (`webview`,
  /// `allowedHosts`, `inAppBrowserHosts`, `externalBrowserUrls`, `emergency`,
  /// `forceUpdate`, `onboarding`, `oneSignalTags`). Missing documents fall
  /// back to the same defaults as [fromJson].
  factory AppState.fromConfigDocs(Map<String, Map<String, dynamic>> docs) {
    return AppState.fromJson({
      'webviewUrl': docs['webview']?['url'],
      'allowedHosts': docs['allowedHosts']?['urls'],
      'inAppBrowserHosts': docs['inAppBrowserHosts']?['urls'],
      'externalBrowserUrls': docs['externalBrowserUrls']?['urls'],
      'emergency': docs['emergency'],
      'forceUpdate': docs['forceUpdate'],
      'onboarding': docs['onboarding'],
      'oneSignalTags': docs['oneSignalTags'],
    });
  }

  Map<String, dynamic> toJson() => {
    'webviewUrl': webviewUrl,
    'allowedHosts': allowedHosts,
    'inAppBrowserHosts': inAppBrowserHosts,
    'externalBrowserUrls': externalBrowserUrls,
    'emergency': emergency.toJson(),
    'forceUpdate': forceUpdate.toJson(),
    'onboarding': onboarding.toJson(),
    'oneSignalTags': oneSignalTags,
  };

  AppState copyWith({
    String? webviewUrl,
    List<String>? allowedHosts,
    List<String>? inAppBrowserHosts,
    List<String>? externalBrowserUrls,
    EmergencyConfig? emergency,
    ForceUpdateConfig? forceUpdate,
    OnboardingConfig? onboarding,
    Map<String, String>? oneSignalTags,
  }) {
    return AppState(
      webviewUrl: webviewUrl ?? this.webviewUrl,
      allowedHosts: allowedHosts ?? this.allowedHosts,
      inAppBrowserHosts: inAppBrowserHosts ?? this.inAppBrowserHosts,
      externalBrowserUrls: externalBrowserUrls ?? this.externalBrowserUrls,
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
    inAppBrowserHosts,
    externalBrowserUrls,
    emergency,
    forceUpdate,
    onboarding,
    oneSignalTags,
  ];
}
