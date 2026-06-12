import 'package:flutter/material.dart';

import 'app.dart';
import 'config/flavor.dart';

Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialization — wired in M2.
  // OneSignal initialization — wired in M12.
  // DI (GetIt) registration — wired in M5.

  runApp(IncilApp(flavor: flavor));
}
