import 'package:firebase_core/firebase_core.dart';
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

  await configureDependencies();

  getIt<PushService>().initialize(flavor);
  getIt<AppStateService>().start();

  runApp(IncilApp(flavor: flavor));
}
