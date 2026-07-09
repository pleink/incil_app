import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/flavor.dart';
import '../services/analytics_service.dart';
import '../services/app_state_service.dart';
import '../services/connectivity_service.dart';
import '../services/image_prewarm_service.dart';
import '../services/local_storage_service.dart';
import '../services/push_service.dart';
import '../services/url_service.dart';
import '../services/version_service.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies(Flavor flavor) async {
  if (getIt.isRegistered<LocalStorageService>()) return;

  final prefs = await SharedPreferences.getInstance();
  final version = await VersionService.create();

  getIt
    ..registerSingleton<Flavor>(flavor)
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerSingleton<LocalStorageService>(LocalStorageService(prefs))
    ..registerSingleton<VersionService>(version)
    ..registerLazySingleton<ConnectivityService>(ConnectivityService.new)
    ..registerLazySingleton<UrlService>(UrlService.new)
    ..registerLazySingleton<ImagePrewarmService>(ImagePrewarmService.new)
    ..registerLazySingleton<PushService>(PushService.new)
    ..registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance)
    ..registerLazySingleton<AnalyticsService>(() {
      final analytics = FirebaseAnalytics.instance;
      // Same rule as Crashlytics in bootstrap(): debug runs stay out of the
      // production dashboards.
      analytics.setAnalyticsCollectionEnabled(!kDebugMode);
      return AnalyticsService(analytics);
    })
    ..registerLazySingleton<AppStateService>(
      () => AppStateService(
        firestore: getIt<FirebaseFirestore>(),
        storage: getIt<LocalStorageService>(),
        fallback: flavor.defaultAppState,
      ),
    );
}
