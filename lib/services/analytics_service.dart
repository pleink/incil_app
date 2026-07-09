import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around [FirebaseAnalytics] for screen tracking.
///
/// Navigation in this app is redirect-driven (see `buildAppRouter`), so
/// screen views are logged from the router's redirect resolver instead of a
/// navigator observer. The redirect runs on every cubit emission — including
/// ones that keep the current screen — so consecutive duplicates are
/// swallowed here.
class AnalyticsService {
  AnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;
  String? _lastScreen;

  /// Logs a `screen_view` for [path] (a route path like `/webview`) unless
  /// it is the screen most recently logged.
  void logScreen(String path) {
    final name = path.startsWith('/') ? path.substring(1) : path;
    if (name.isEmpty || name == _lastScreen) return;
    _lastScreen = name;
    unawaited(_analytics.logScreenView(screenName: name));
  }
}
