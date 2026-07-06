import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../config/flavor.dart';

typedef PushTargetHandler = void Function(Uri uri);

class PushService {
  PushService({PushTargetHandler? onTargetUrl}) : _onTargetUrl = onTargetUrl;

  PushTargetHandler? _onTargetUrl;

  /// Buffers the last click target that arrived before a handler was attached
  /// (cold start: the OneSignal click listener is registered in `bootstrap()`
  /// but the handler is only attached in `IncilApp.initState`).
  Uri? _bufferedTarget;

  /// Attaching a handler flushes any buffered cold-start click target.
  set onTargetUrl(PushTargetHandler? handler) {
    _onTargetUrl = handler;
    if (handler == null) return;
    final buffered = _bufferedTarget;
    if (buffered == null) return;
    // Clear before calling so a re-entrant set can't double-fire.
    _bufferedTarget = null;
    handler(buffered);
  }

  void _dispatchTarget(Uri uri) {
    final handler = _onTargetUrl;
    if (handler != null) {
      handler(uri);
    } else {
      // Last-write-wins while nobody is listening yet.
      _bufferedTarget = uri;
    }
  }

  @visibleForTesting
  void debugDispatchTarget(Uri uri) => _dispatchTarget(uri);

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
      _dispatchTarget(uri);
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
