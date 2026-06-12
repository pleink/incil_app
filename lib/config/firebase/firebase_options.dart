import 'package:firebase_core/firebase_core.dart';

import '../flavor.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

FirebaseOptions firebaseOptionsFor(Flavor flavor) {
  switch (flavor) {
    case Flavor.dev:
      return dev.DefaultFirebaseOptions.currentPlatform;
    case Flavor.prod:
      return prod.DefaultFirebaseOptions.currentPlatform;
  }
}
