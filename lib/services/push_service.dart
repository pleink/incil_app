import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/flavor.dart';

typedef PushTargetHandler = void Function(Uri uri);

class PushService {
  PushService({this.onTargetUrl});

  PushTargetHandler? onTargetUrl;

  bool _initialized = false;

  void initialize(Flavor flavor) {
    if (_initialized) return;
    _initialized = true;

    if (kDebugMode) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    }
    OneSignal.initialize(flavor.oneSignalAppId);

    OneSignal.Notifications.addClickListener((event) {
      final raw = event.notification.additionalData?['targetUrl'];
      if (raw is! String) return;
      final uri = Uri.tryParse(raw);
      if (uri == null) return;
      onTargetUrl?.call(uri);
    });
  }

  Future<void> requestPermission() async {
    try {
      await OneSignal.Notifications.requestPermission(true);
    } catch (e, st) {
      developer.log(
        'OneSignal permission request failed.',
        name: 'PushService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> applyTags(Map<String, String> tags) async {
    if (tags.isEmpty) return;
    try {
      await OneSignal.User.addTags(tags);
    } catch (e, st) {
      developer.log(
        'OneSignal addTags failed.',
        name: 'PushService',
        error: e,
        stackTrace: st,
      );
    }
  }
}
