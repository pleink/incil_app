import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/firebase/firebase_options.dart';
import 'config/flavor.dart';
import 'di/service_locator.dart';
import 'services/app_state_service.dart';
import 'services/push_service.dart';

Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: firebaseOptionsFor(flavor));

  // Crash reporting is off in debug builds so local runs don't pollute the
  // dashboards; analytics collection follows the same rule (set in
  // configureDependencies via AnalyticsService's backing instance).
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );

  // Route all uncaught errors into Crashlytics: framework errors as fatal
  // Flutter errors, everything escaping the zone (async, platform) as fatal
  // generic ones.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await configureDependencies(flavor);

  getIt<PushService>().initialize(flavor);
  getIt<AppStateService>().start();

  runApp(IncilApp(flavor: flavor));
}
